---
name: actual-budget-cli
description: >
  Drive Actual Budget from the terminal — the `actual` CLI (`@actual-app/cli`)
  and JS API (`@actual-app/api`) against a sync server. Use when the user
  mentions Actual Budget, `actual`, `@actual-app/api`, or ActualQL, or asks to
  import or reconcile transactions, review spending, back up a budget, restart
  a budget, or manage accounts, categories, payees, rules, or schedules from a
  shell or Node script.
---

# Actual Budget CLI

## Quick start

Server pre-configured (env vars or `.actualrc`). Amounts are integer cents — see Core conventions.

```bash
# Inspect available tables/fields before querying
actual query tables
actual query fields transactions

# Last 5 transactions (default table shortcut)
actual query run --last 5

# Find an entity id by name (accounts | categories | payees | schedules)
actual server get-id --type accounts --name "Checking"

# Transfer payee: get-id CANNOT resolve by transfer_acct. List payees and grep:
actual payees list --format json | jq -r '.[] | select(.transfer_acct=="<destAcctId>") | .id'
```

## Core conventions

- **Amounts are integer cents** in JSON; `--format table`/`csv` auto-convert to decimals. JSON output stays raw cents.
- Output formats: `json` (default, bare array), `table`, `csv`. Add `--verbose` for stderr info.
- Non-zero exit = error; errors go to stderr as `Error: ...`.
- Each invocation opens a new server connection — **batch with date-range filters**, never loop per month.
- **CLI reads the local cache** in `--data-dir`. Query results reflect the last `actual budgets sync`, not live server state. Run `actual budgets sync` first when freshness matters (post bank-sync, post another-device edit, long gap since last CLI use). Writes from one CLI run are visible locally to the next run without re-sync.

## Workflows

### Import & reconcile transactions

```bash
# 1. Dry-run import to preview dup detection (no writes)
actual transactions import --account <id> --file txns.json --dry-run

# 2. Real import — runs rules, dedups by imported_id, creates transfers
actual transactions import --account <id> --file txns.json

# 3. Review what landed: uncategorized txns in last 30 days
actual query run --table transactions \
  --filter '{"category":null,"date":{"$gte":"2026-06-09"}}' \
  --select "date,amount,payee.name,notes" --order-by "date:desc"

# 4. Split parents polluting sums (see Gotchas)
actual query run --table transactions \
  --filter '{"is_parent":false,"amount":{"$lt":0}}' \
  --select "date,amount,category.name" --limit 20
```

**`add` vs `import`:** `import` reconciles (dedup via `imported_id`, matches amount+date+payee) AND **runs rules** (payee-rules + categorization rules, including those from `rules payee-rules <payeeId>`) AND creates transfers when a transfer payee is given. `add` skips all that — raw insert, no dedup, no rules, no auto-transfers. So: anything from a bank/file/external → `import` (always `--dry-run` first); trusted single-purpose rows you control → `add`. A run of unmatched-payee "uncategorized" rows after `import` is normal (no rule matched), not a bug — step 3 catches them. Output of `import --dry-run` shows `added`/`updated` arrays of ids.

See [EXAMPLES.md](EXAMPLES.md) for full reconciliation walkthroughs (CSV prep, splits, transfers, post-import rule fixing).

## Commands at a glance (CLI)

`accounts`, `budgets`, `categories`, `category-groups`, `transactions`, `payees`, `tags`, `rules`, `schedules`, `query`, `server`. Full flags + object schemas: see [REFERENCE.md](REFERENCE.md).

For the JS API (`@actual-app/api`) — backup/export, bulk delete, starting balances, atomic budget batches — see [SCRIPTING.md](SCRIPTING.md). Restart walk-throughs mixing CLI + JS live in [EXAMPLES.md](EXAMPLES.md) §6–§8.

## Querying (ActualQL)

`actual query run` flags: `--table`, `--select`, `--filter`/`--where`, `--order-by "field:desc"`, `--limit`, `--offset`, `--last N`, `--count`, `--group-by`, `--file`. For aggregates use `--file`/stdin with the object form (`{"table":...,"groupBy":...,"select":[{"x":{"$sum":"$amount"}}]}`).

Operators: `$eq $lt $lte $gt $gte $ne $oneof $regex $like $notlike`; combine with `$and`/`$or`. Joins via dotted fields (`category.name`, `payee.name`). Date parts need `$transform`: `{"date":{"$transform":"$month","$eq":"2026-03"}}` — `date.month` is NOT supported as a field. Full ActualQL reference: [REFERENCE.md](REFERENCE.md).

## Gotchas

- Filter `"is_parent":false` when summing/counting — split parents hold the total, children hold parts; including both double-counts.
- `category.name` is `null` for uncategorized — account for it in filters/groups.
- Aggregates must be named in `select` (e.g. `{"total":{"$sum":"$amount"}}`).
- Self-signed cert server: `NODE_TLS_REJECT_UNAUTHORIZED=0` (insecure — trusted nets only).