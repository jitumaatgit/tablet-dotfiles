# Actual Budget — Scripting (JS API)

`@actual-app/api` — programmatic counterpart to the `actual` CLI. Same sync server, same data model. Use this when the CLI lacks a surface (backup/export, bulk delete, starting balances, scripted restart loops) or you need atomic multi-step writes in one Node process.

Entity schemas, ActualQL operators, and amount (integer cents) conventions are identical to the CLI — see [REFERENCE.md](REFERENCE.md). This file covers only what the JS API adds or differs on.

## Setup

```js
import actual from "@actual-app/api";

await actual.init({
  serverURL: process.env.ACTUAL_SERVER_URL,
  password: process.env.ACTUAL_PASSWORD,   // or sessionToken
  syncID: process.env.ACTUAL_SYNC_ID,
  // dataDir: optional cache dir
});
// ...do work...
await actual.shutdown();
```

All methods require `init()` first and `shutdown()` last (flushes + closes cache). One process = one budget loaded by `syncID`. To switch budgets, `shutdown()` then re-`init()` with a different `syncID`, or use `downloadBudget(syncId, {password})` + `loadBudget(id)` for others.

## Reading

| Method | Returns | Notes |
|--------|---------|-------|
| `getBudgets()` | `[{budgetId, syncId, groupId, name, ...}]` | |
| `budgetMonths()` / `getBudgetMonth(month)` | month metadata | month = `"YYYY-MM"` |
| `getAccounts()` / `getAccount(id)` | account rows | |
| `getAccountBalance(id, cutoff?)` | int cents | cutoff = `YYYY-MM-DD`; null = current |
| `getTransactions(acct, start, end)` | txn rows in `[start,end]` | `start`/`end` inclusive `YYYY-MM-DD` |
| `getCategoryGroups()` / `getCategories()` | group/category lists | |
| `getPayees()` / `getPayee(id)` | payee rows | `transfer_acct` set ⇒ transfer payee |
| `getSchedules()` | schedule rows | |
| `runQuery({table, ...})` | rows or aggregate | same ActualQL as CLI `query run` |
| `getIDByName({type, string})` | id (for accounts / schedules / categories / payees) | |
| `getServerVersion()` / `getPreferences()` | meta | |

Use `getIDByName` instead of `accounts list | jq` lookups inside scripts. For live server state (post bank-sync / post other device) call `await actual.sync()` before reading — CLI cache is not auto-refreshed.

## Writing transactions

| Method | What | Flags / return |
|--------|------|----------------|
| `addTransactions(acct, txns, { runTransfers?, learnCategories? })` | raw insert | `runTransfers:false` skips transfer-payee auto-create; `learnCategories:false` skips rule learning. **No dedup, no rules.** CLI analogue: `transactions add`. |
| `importTransactions(acct, txns, opts)` | reconciling insert | `opts = { defaultCleared?, dryRun?, reimportDeleted? }`. **Runs rules + dedup via `imported_id` + creates transfers.** Returns `{errors, added, updated}` (arrays of ids). CLI analogue: `transactions import --dry-run`. |
| `updateTransaction(id, fields)` | partial update | don't mutate `transfer_id` on transfer txns |
| `deleteTransaction(id)` | delete one | see bulk-delete note below |

**Bulk delete has no single API.** No `deleteTransactions([ids])` exists, and `batchBudgetUpdates` (below) only coalesces *budget-type* updates, not transaction deletes. To wipe an account, loop `deleteTransaction` in-process — still N writes to the server, but no N CLI spawns:

```js
const txns = await actual.getTransactions(acct, null, null);
for (const t of txns) await actual.deleteTransaction(t.id);
```

## Writing accounts

```js
await actual.createAccount({ name: "Checking", type: "checking" }, 50000);  // initialBalance=0 default
await actual.updateAccount(id, { name, offbudget });
await actual.closeAccount(id, { transferAccount, transferCategory });   // balance≠0 needs transfer
await actual.reopenAccount(id);
await actual.deleteAccount(id);
```

**`createAccount`'s `initialBalance` arg is the canonical starting-balance path** for a *new* account — it posts the opening balance atomically without a separate "Starting Balance" payee (no system payee exists). For an *existing* account during a restart, post a starting-balance txn manually; see [EXAMPLES.md §6](EXAMPLES.md). `getAccountBalance` honours an optional `cutoff` date for historical balances.

## Writing budgets

| Method | Purpose |
|--------|---------|
| `setBudgetAmount(month, categoryId, cents)` | allocates `cents` to a category for `month` |
| `setBudgetCarryover(month, categoryId, bool)` | toggles whether category balance carries to next month |
| `holdBudgetForNextMonth(month, cents)` | holds `cents` out of "To Budget" for next month |
| `resetBudgetHold(month)` | undoes `holdBudgetForNextMonth` for `month` |

**Carryover vs hold — two distinct mechanisms:**
- **Per-category carryover** (`setBudgetCarryover`): the per-category flag that keeps leftover/overspend in a category across month boundaries.
- **Whole-budget hold** (`holdBudgetForNextMonth` + `resetBudgetHold`): a separate pool withheld from "To Budget" globally, independent of any category's carryover flag.

"Transfer a category balance back to To Budget" (restart step 3) = `setBudgetAmount(month, cat, 0)` so nothing is allocated, **plus** `setBudgetCarryover(month, cat, false)` so the surplus isn't held in the category. `resetBudgetHold` is unrelated — do not reach for it here.

Wrap several budget writes in `batchBudgetUpdates` to coalesce into one server round-trip:

```js
await actual.batchBudgetUpdates(async () => {
  await actual.setBudgetAmount("2026-06", catA, 0);
  await actual.setBudgetCarryover("2026-06", catA, false);
  await actual.setBudgetAmount("2026-06", catB, surplusToCoverB);
});
```

`batchBudgetUpdates` is **budget updates only** — calling `deleteTransaction`/`importTransactions` inside it does NOT coalesce transaction writes.

## Backup & restore

```js
import { writeFile } from "node:fs/promises";
const zip = await actual.exportBudget();              // Promise<Uint8Array>
await writeFile("backup.zip", zip);                   // full budget snapshot
```

| Method | What |
|--------|------|
| `exportBudget()` | full budget snapshot → `Promise<Uint8Array>` (zip bytes). No CLI equivalent. Use for pre-restart backup. |
| `importBudget(input, { type, filename })` | restore an exported zip → `{ id }` |
| `downloadBudget(syncId, { password })` | loads encrypted budget from server |
| `loadBudget(id)` | switches active in-process budget |

Always `exportBudget` before bulk-delete / restart operations.

## Rules, schedules, notes

- `getRules()` / `createRule(rule)` / `updateRule(rule)` / `deleteRule(id)`. **`updateRule` requires the FULL rule object** (same gotcha as CLI); other `update*` methods accept partial fields.
- `getSchedules()` / `createSchedule(sched)` / `updateSchedule(id, fields)` / `deleteSchedule(id)`. `next_date`/`completed`/`rule` are read-only.
- `getNote(entityId)` / `updateNote(entityId, note)` — attach free text; `#template` / `#goal` directives drive budget templates and savings goals.
- `runBankSync(acctId?)` / `runImport()` — trigger bank sync / import the way the UI does.

## Gap reminders (CLI and API identical)

- **No `tags` field on transactions.** Tag CRUD exists but there is no documented JS or CLI path to *attach* a tag to a transaction; only the in-app UI does it. For tracking, fall back to `#tag` in `notes`. Verify with `actual query fields transactions` before assuming.
- **No transfer-payee lookup by `transfer_acct`.** `getIDByName({type:"payees"})` matches by name only; list all payees and select where `transfer_acct == destAcctId`.
- **No bulk transaction delete.** Loop `deleteTransaction` per id, in-process.

## When to use JS vs CLI

| Need | Reach for |
|------|-----------|
| One-shot query, CSV import, manual edit | CLI |
| Backup before destructive change | JS `exportBudget` |
| Bulk delete / scripted restart across N accounts | JS `deleteTransaction` loop |
| Atomic multi-category budget zeroing | JS `batchBudgetUpdates` |
| New account + opening balance in one step | JS `createAccount(..., initialBalance)` |
| Payee-rules inspection | CLI `rules payee-rules <id>` (cleaner output) |