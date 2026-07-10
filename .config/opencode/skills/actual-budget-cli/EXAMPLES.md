# Actual Budget CLI — Examples

Assumes server configured via env/`.actualrc`. `<acct>` = account id, `<cat>` = category id.

## Resolve ids by name

```bash
acct=$(actual server get-id --type accounts --name "Checking")
cat=$(actual server get-id --type categories --name "Groceries")
pay=$(actual server get-id --type payees --name "Kroger")
```

## 1. Import a CSV export (full reconciliation workflow)

### Step 1 — Convert CSV to the JSON shape `import` expects
Required keys: `date` (`YYYY-MM-DD`), `amount` (cents; negative=expense), optional `payee_name`, `category`, `notes`, `imported_id` (bank id → exact dedup), `cleared`, `subtransactions`.

```bash
# Example txns.json
cat > txns.json <<'EOF'
[
  {"date":"2026-07-01","amount":-5432,"payee_name":"Kroger","imported_id":"BANK-001"},
  {"date":"2026-07-02","amount":-1500,"payee_name":"Coffee Shop","imported_id":"BANK-002"},
  {"date":"2026-07-02","amount":250000,"payee_name":"Payroll","imported_id":"BANK-003","cleared":true}
]
EOF
```

### Step 2 — Dry-run to preview
```bash
actual transactions import --account "$acct" --file txns.json --dry-run --format json
```
Read `added`/`updated` arrays. If `errors` is non-empty, fix the offending rows before real import. Dry-run writes nothing.

### Step 3 — Real import
```bash
actual transactions import --account "$acct" --file txns.json
```
Rules run (auto-categorize, payee cleanup), `imported_id` dedupes, transfer payees create matching txn in the other account.

### Step 4 — Verify: uncategorized in import window
```bash
actual query run --table transactions \
  --filter '{"account":"'"$acct"'","category":null,"date":{"$gte":"2026-07-01"}}' \
  --select "date,amount,payee.name,imported_id,notes" \
  --order-by "date:desc" --format table
```

### Step 5 — Categorize stragglers
```bash
actual transactions update <txnId> --data '{"category":"'"$cat"'"}'
```

## 2. Split transaction (one receipt, multiple categories)

```bash
# Parent holds total; children sum to it. CLI takes the parent object with subtransactions[].
cat > split.json <<'EOF'
[{
  "date":"2026-07-03","amount":-10000,"payee_name":"Target","is_parent":true,
  "subtransactions":[
    {"amount":-7000,"category":"<groceriesCat>","date":"2026-07-03","is_child":true,"is_parent":false,"account":"<acct>"},
    {"amount":-3000,"category":"<householdCat>","date":"2026-07-03","is_child":true,"is_parent":false,"account":"<acct>"}
  ]
}]
EOF
actual transactions import --account "$acct" --file split.json --dry-run
actual transactions import --account "$acct" --file split.json
```
`is_parent:true` on parent is mandatory or subtransactions are silently ignored. Child needs `account`, `date`, `parent_id` (auto-linked when nested in import), `is_child:true`, `is_parent:false`.

## 3. Transfer between accounts

Don't construct both sides — use the destination account's transfer payee:
```bash
# Find the transfer payee for the savings account
sav=$(actual server get-id --type accounts --name "Savings")
# list payees, find one with transfer_acct == savings id, then:
actual transactions import --account "$acct" --file - <<EOF
[{"date":"2026-07-04","amount":-20000,"payee":"<transferPayeeId>","notes":"Move to savings"}]
EOF
```
A mirrored txn is auto-created in the savings account. Never edit `transfer_id` afterward.

## 4. Dedup audit (did import create doubles?)

```bash
# Group by imported_id; any group with >1 row means a duplicate slipped through
echo '{"table":"transactions","filter":{"account":"'"$acct"'","imported_id":{"$ne":null}},"groupBy":["imported_id"],"select":["imported_id",{"n":{"$count":"*"}}]}' \
  | actual query run --file - --format table
```
Rows where `n>1` = duplicates → delete one with `actual transactions delete <id>`.

## 5. Post-import sanity sums

```bash
total=$(actual query run --table transactions \
  --filter '{"account":"'"$acct"'","is_parent":false,"date":{"$gte":"2026-07-01","$lte":"2026-07-31"}}' \
  --select '{"total":{"$sum":"$amount"}}' --file - --format json)
# (use --file or echo the object form for aggregates)
```
Per-category spend for the month:
```bash
echo '{"table":"transactions","filter":{"account":"'"$acct"'","is_parent":false,"date":{"$gte":"2026-07-01","$lte":"2026-07-31"}},"groupBy":["category.name"],"orderBy":[{"amount":"desc"}],"select":["category.name",{"amount":{"$sum":"$amount"}}]}' \
  | actual query run --file - --format table
```
`is_parent:false` is the guard — see SKILL.md Gotchas.

## 6. Restart: delete all transactions + set starting balances

Per <https://actualbudget.org/docs/advanced/restart>. **Back up first** — this is destructive and irreversible. All bulk/delete operations below use the JS API because the CLI has no bulk-delete or export surface.

### Step 1 — Back up the budget (JS API)
```bash
# (JS API)
cat > backup.mjs <<'EOF'
import actual from "@actual-app/api";
import { writeFile } from "node:fs/promises";
await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,
  syncID: process.env.ACTUAL_SYNC_ID,
});
await actual.sync();
const zip = await actual.exportBudget();
await writeFile("actual-backup.zip", zip);
await actual.shutdown();
EOF
node backup.mjs && ls -l actual-backup.zip
```

### Step 2 — Bulk delete every transaction per account (JS API)
```bash
# (JS API)
cat > wipe.mjs <<'EOF'
import actual from "@actual-app/api";
await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,
  syncID: process.env.ACTUAL_SYNC_ID,
});
const accounts = await actual.getAccounts();
for (const a of accounts) {
  if (a.closed) continue;
  const txns = await actual.getTransactions(a.id, null, null);
  for (const t of txns) await actual.deleteTransaction(t.id);
  console.log(`${a.name}: deleted ${txns.length}`);
}
await actual.shutdown();
EOF
node wipe.mjs
```
No `deleteTransactions([ids])` exists and `batchBudgetUpdates` coalesces budget writes only — the in-process loop is the only path.

### Step 3 — Set starting balances on the wiped accounts (JS API)
There is no system "Starting Balance" payee. New accounts should use `createAccount(acct, initialBalance)` directly; for existing accounts post a starting-balance txn via `importTransactions` with `payee_name: "Starting Balance"` (creates a normal payee — delete it afterwards if you don't want it lingering).
```bash
# (JS API)
cat > starting.mjs <<'EOF'
import actual from "@actual-app/api";
await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,
  syncID: process.env.ACTUAL_SYNC_ID,
});
const balances = [
  { acct: "<checkingId>", amount: 125000, date: "2026-07-01" },
  { acct: "<savingsId>",  amount:  500000, date: "2026-07-01" },
];
for (const b of balances) {
  const { errors, added } = await actual.importTransactions(b.acct, [
    { date: b.date, amount: b.amount, payee_name: "Starting Balance", cleared: true },
  ]);
  if (errors.length) console.error(errors);
}
await actual.shutdown();
EOF
node starting.mjs
```

### Step 4 — Zero out prior-month category balances
See [§8](#8-restart-zero-out-prior-month-category-balances).

## 7. Restart: keep transactions + Budget Reset category

Preserves history. Stray/uncategorized spending gets parked in a temporary "Budget Reset" category, then prior-month balances are zeroed.

### Step 1 — Back up (JS API)
Same as [§6 Step 1](#6-restart-delete-all-transactions--set-starting-balances).

### Step 2 — Categorize stragglers (CLI)
```bash
# (CLI)
acct=$(actual server get-id --type accounts --name "Checking")
cat=$(actual server get-id --type categories --name "Groceries")

# List uncategorized txns in the window you're resetting from
actual query run --table transactions \
  --filter '{"account":"'"$acct"'","category":null,"date":{"$gte":"2026-07-01"}}' \
  --select "id,date,amount,payee.name" --order-by "date:desc" --format table | tee strays.txt

# Categorize each one (loop in bash; ids/amounts read from strays.txt or by hand)
actual transactions update <txnId> --data '{"category":"'"$cat"'"}'
```

### Step 3 — Park remaining stragglers in a temp "Budget Reset" category (CLI)
```bash
# (CLI)
gid=$(actual category-groups list --format json | jq -r '.[] | select(.is_income==false) | .id' | head -1)
reset=$(actual categories create --name "Budget Reset" --group-id "$gid" --format json | jq -r .id)

# Bulk assign leftover uncategorized txns to it (read ids from strays.txt, loop updates)
actual transactions update <txnId> --data '{"category":"'"$reset"'"}'
```

### Step 4 — Reconcile against bank balances (JS API)
```bash
# (JS API)
cat > reconcile.mjs <<'EOF'
import actual from "@actual-app/api";
await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,
  syncID: process.env.ACTUAL_SYNC_ID,
});
const acct = "<checkingId>";
const bankReported = 125000;            // cents, from your bank statement
const actualBal = await actual.getAccountBalance(acct);
const diff = bankReported - actualBal;
if (diff !== 0) {
  const { errors } = await actual.importTransactions(acct, [
    {
      date: "2026-07-01",
      amount: diff,                    // + tops up, - withdraws
      payee_name: "Reconciliation Adjustment",
      notes: "Restart reconciliation",
    },
  ]);
  if (errors.length) console.error(errors);
}
await actual.shutdown();
EOF
node reconcile.mjs
```

### Step 5 — Zero out prior-month category balances
See [§8](#8-restart-zero-out-prior-month-category-balances).

After the cycle settles, delete the "Budget Reset" temp category once it's no longer needed:
```bash
actual categories delete "$reset"   # transfer-to another category if it holds a balance
```

## 8. Restart: zero out prior-month category balances

Shared step 3 of both restarts. For every expense category in the prior month, zero the balance you carry: overspent (negative) → fund to zero; surplus (positive) → release back to "To Budget". This is a per-category allocation change, NOT `resetBudgetHold` (which only undoes `holdBudgetForNextMonth`, a separate whole-budget hold).

### Pure CLI path
```bash
# (CLI)
prior="2026-06"
# Per-category balance for the prior month — group by category, sum amounts
echo '{"table":"transactions","filter":{"is_parent":false,"date":{"$transform":"$month","$eq":"'"$prior"'"}},"groupBy":["category"],"select":["category",{"balance":{"$sum":"$amount"}}]}' \
  | actual query run --file - --format json | jq -c '.[]' | while read row; do
  cat=$(echo "$row" | jq -r '.category')
  bal=$(echo "$row" | jq -r '.balance')
  if [ "$bal" -lt 0 ]; then
    # Overspent: allocate enough to cover the deficit (amount = -bal ⇒ moves balance to 0)
    actual budgets set-amount --month "$prior" --category "$cat" --amount "$(( -bal ))"
  elif [ "$bal" -gt 0 ]; then
    # Surplus: zero the allocation and turn off carryover so surplus returns to To Budget
    actual budgets set-amount --month "$prior" --category "$cat" --amount 0
    actual budgets set-carryover --month "$prior" --category "$cat" --flag false
  fi
done
```

### Atomic batch path (JS API)
```bash
# (JS API)
cat > zero.mjs <<'EOF'
import actual from "@actual-app/api";
await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,
  syncID: process.env.ACTUAL_SYNC_ID,
});
const prior = "2026-06";
const rows = await actual.runQuery({
  table: "transactions",
  filter: { is_parent: false, date: { $transform: "$month", $eq: prior } },
  groupBy: ["category"],
  select: ["category", { balance: { $sum: "$amount" } }],
});
await actual.batchBudgetUpdates(async () => {
  for (const r of rows) {
    if (r.balance < 0) {
      await actual.setBudgetAmount(prior, r.category, -r.balance);
    } else if (r.balance > 0) {
      await actual.setBudgetAmount(prior, r.category, 0);
      await actual.setBudgetCarryover(prior, r.category, false);
    }
  }
});
await actual.shutdown();
EOF
node zero.mjs
```

`batchBudgetUpdates` coalesces only budget writes — fine here, since step 3 is purely budget allocation. For income categories the same logic applies if you want to clear residual income allocations; usually income categories are left alone.