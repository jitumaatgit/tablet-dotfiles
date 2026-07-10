# Actual Budget CLI — Reference

`@actual-app/cli` (distinct from `@actual-app/sync-server`). Requires Node v22+. Assumes a configured sync server (env vars, flags, or `.actualrc` via cosmiconfig).

## Configuration

### Environment variables

| Var | Purpose |
|-----|---------|
| `ACTUAL_SERVER_URL` | Sync server URL (required) |
| `ACTUAL_SYNC_ID` | Budget sync ID (required for most commands) |
| `ACTUAL_PASSWORD` | Server password (one of password/token required) |
| `ACTUAL_SESSION_TOKEN` | Session token (alt to password) |

### Global flags (override env vars)

`--server-url`, `--password`, `--session-token`, `--sync-id`, `--data-dir`, `--format <json|table|csv>`, `--verbose`.

### Config file

cosmiconfig — `.actualrc` (JSON/YAML), `.actualrc.{json,yaml,yml}`, `actual.config.{json,yaml,yml}`, `"actual"` key in `package.json`, or `~/.config/actual/config.{json,yaml,yml}`. Keys: `serverUrl`, `password`, `syncId`, `cacheTtl`, `lockTimeout`, `noLock`. **Never** commit plaintext passwords; prefer env vars or session token in config.

## Amount convention

Integer cents everywhere. `5000`=$50.00, `-12350`=-$123.50. `--format table`/`csv` auto-convert to decimal; JSON stays raw cents for scripting.

## Commands

### accounts
```bash
actual accounts list [--include-closed]
actual accounts create --name "Checking" [--offbudget] [--balance 50000]
actual accounts update <id> [--name "X"] [--offbudget true]
actual accounts close <id> [--transfer-account <id>] [--transfer-category <id>]  # balance≠0 needs transfer-account
actual accounts reopen <id>
actual accounts delete <id>
actual accounts balance <id> [--cutoff 2026-01-31]
```

### budgets
```bash
actual budgets list
actual budgets download <syncId> [--encryption-password <pw>]
actual budgets sync
actual budgets months
actual budgets month 2026-03
actual budgets set-amount --month 2026-03 --category <id> --amount 50000   # cents
actual budgets set-carryover --month 2026-03 --category <id> --flag true
actual budgets hold-next-month --month 2026-03 --amount 10000
actual budgets reset-hold --month 2026-03
```

### categories / category-groups
```bash
actual categories list
actual categories create --name "Groceries" --group-id <id> [--is-income]
actual categories update <id> [--name "Food"] [--hidden true]
actual categories delete <id> [--transfer-to <id>]
actual category-groups list
actual category-groups create --name "Essentials" [--is-income]
actual category-groups update <id> [--name "X"] [--hidden true]
actual category-groups delete <id> [--transfer-to <id>]
```

### transactions
```bash
actual transactions list --account <id> --start 2026-01-01 --end 2026-03-31
actual transactions add --account <id> --data '[...]' | --file txns.json   # raw, no dedup, no rules
actual transactions import --account <id> --data '[...]' | --file f.json [--dry-run]  # rules + dedup + transfers
actual transactions update <id> --data '{"notes":"x"}'
actual transactions delete <id>
```
`import` returns `{added:[ids], updated:[ids], errors:[...]}`. Dedup keys: `imported_id` (exact), else amount+similar-date+payee match. Flags via opts (only API-level; CLI surfaces `--dry-run`): `defaultCleared`, `reimportDeleted`.

#### `add` vs `import` — decision helper

| Source | Command | Why |
|--------|---------|-----|
| Bank export, OFX/CSV, anything external | `import [--dry-run]` | Dedup via `imported_id`; runs rules; creates transfers. Always dry-run first. |
| `addTransactions` from your own trusted importer that already deduped | `add` | Skips all post-processing — no rules, no dedup, no transfer creation. Use only if you control the data and already ran rule logic. |
| Split where parent+children are fully specified | `import` | Needs rules to fire for category assignment; `add` would store raw. |
| One-off manual txn you authored end-to-end | `add` | No dup risk, no rules worth running. |

### payees
```bash
actual payees list
actual payees common
actual payees create --name "Grocery Store"
actual payees update <id> --name "X"
actual payees delete <id>
actual payees merge --target <id> --ids id1,id2,id3
```

### tags
```bash
actual tags list
actual tags create --tag "vacation" [--color "#ff0000"] [--description "..."]
actual tags update <id> [--tag "trip"] [--color "#00ff00"]
actual tags delete <id>
```

### rules
```bash
actual rules list
actual rules payee-rules <payeeId>
actual rules create --data '<json>' | --file rule.json
actual rules update --data '{"id":"...","stage":"pre",...}'   # requires FULL rule incl id
actual rules delete <id>
```
Rule object: `{stage:"pre"|"default"|"post", conditionsOp:"and"|"or", conditions:[{field,op,value}], actions:[{field,op,value}]}`. `updateRule` is the lone exception to the "partial fields" rule — it needs the full object.

### schedules
```bash
actual schedules list
actual schedules create --data '{"name":"Rent","date":"1st","amount":-150000,"amountOp":"is","account":"...","payee":"..."}'
actual schedules update <id> --data '{"name":"Updated Rent"}' [--reset-next-date]
actual schedules delete <id>
```
`date`: bare `YYYY-MM-DD` (single) or a `RecurConfig` `{frequency:"daily"|"weekly"|"monthly"|"yearly", interval, start, endMode:"never"|"after_n_occurrences"|"on_date", endOccurrences, endDate, skipWeekend, patterns}`. `amountOp`: `is` | `isapprox` | `isbetween` (latter uses `{num1,num2}`).

### query (ActualQL)
```bash
actual query tables
actual query fields <table>
actual query run [options]
```
Options: `--table`, `--select "a,b,c"`, `--filter '<json>'` (or `--where`, NOT both), `--order-by "f:desc,g:asc"`, `--limit N`, `--offset N`, `--last N` (implies table=transactions, order-by date:desc), `--count`, `--group-by "a,b"`, `--file path` (`-` for stdin).

Object form via `--file` / stdin (needed for aggregates + group-by combos):
```json
{"table":"transactions","groupBy":["category.name"],"select":["category.name",{"amount":{"$sum":"$amount"}}]}
```

## ActualQL reference

### Operators
`$eq` (default), `$lt`, `$lte`, `$gt`, `$gte`, `$ne`, `$oneof`, `$regex`, `$like`, `$notlike`. Array value on a field ⇒ combined with `$and`. `$and:[...]` / `$or:[...]` combine conditions.

### Joins
Dotted field "pokes through" to referenced table: `category.name`, `payee.name`, `category.is_income`, `category.group.name`, `category.group.sort_order`, `category.sort_order`.

### Transforms
`{"date":{"$transform":"$month","$eq":"2026-03"}}`, `$year` likewise. **No** `date.month` / `date.year` field syntax.

### Aggregates
`{<name>:{"$sum":"$amount"}}` in `select` — **must be named**. `$count` for counts. `calculate` form (JS API only) names automatically.

### Split transactions
`transactions` table splits option: `inline` (default — flat, hides parent, sums cleanly), `grouped` (parent + `subtransactions[]`), `all` (flat incl both — advanced). Always filter `is_parent:false` when summing/counting to avoid double-count.

## Output formats

`json` — bare array of records, raw cents (default). `table` — human-readable, cents→decimal. `csv` — spreadsheet, cents→decimal. `--verbose` → info on stderr.

## SSL (self-signed)
`NODE_TLS_REJECT_UNAUTHORIZED=0 actual ...` — disables ALL TLS verification. Trusted nets only; prefer adding CA to system trust.

## Entity schemas (key fields)

**Transaction**: `id, account*, date*, amount, payee, payee_name* (create-only, creates-or-matches payee), imported_payee, category, notes, imported_id (dedup key), transfer_id (do NOT mutate on existing), cleared, is_parent, is_child, parent_id, subtransactions[] (get/create only)`. `*` = required on create.

**Account**: `id, name*, offbudget, closed, balance_current, type (checking|savings|credit|investment|mortgage|debt|other)`. Use `close`/`reopen` over setting `closed`.

**Category**: `id, name*, group_id*, is_income`. **CategoryGroup**: `id, name*, is_income, categories[] (get only)`. One income group max.

**Payee**: `id, name*, category, transfer_acct` (set ⇒ this is a transfer payee; use it to create transfer txns via import).

**Tag**: `id, tag*, color, description, hidden`. **Gap:** docs cover tag CRUD only — no documented CLI/API path to attach an existing tag to a transaction (no `tags` field on `Transaction`, no `transactions tag` subcommand). The in-app UI supports per-transaction tags, but driving that via CLI is undocumented/unconfirmed. Verify with `actual query fields transactions` (look for a `tags` column) before assuming a workflow that tags imported txns; fall back to `notes` with a `#tag`-style convention if the field is absent.

**Rule**: see above. **Schedule**: see above; `rule`/`next_date`/`completed` are read-only (auto-managed).

**Notes**: attach to any entity by id — `#template` and `#goal` directives drive budget templates/savings goals.

## Common pitfalls

Hot foot-guns live in SKILL.md Gotchas (`is_parent:false`, null category, named aggregates, self-signed cert). The rarer ones:

- `updateRule` needs the full rule object; other `update` commands take partial fields.
- Never mutate `transfer_id` on existing transfer txns.
- No CLI bulk-delete surface — see [SCRIPTING.md](SCRIPTING.md) for the JS loop.
- Tag-attach is undocumented — see the Tag schema note above.