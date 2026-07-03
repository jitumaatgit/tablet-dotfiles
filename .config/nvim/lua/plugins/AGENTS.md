## Non-obvious Learnings

### Wiki-link reference update bug (`extend-mini-files.lua`)

`update_obsidian_refs` builds `old_forms` and `new_forms` as flattened arrays of 6 forms each (from `get_ref_forms`). Position-wise replacement means `old_forms[i]` → `new_forms[i]`. When moving a file without renaming, `old_id == new_id` but `old_rel_noext != new_rel_noext`. For root notes, `old_id == old_rel_noext`, so the third group matches the same links as the first group. On the second pass, `[[Note|label]]` gets degraded to `[[path/Note|label]]`. Fix: use `new_id` (basename) for the third group instead of `new_rel_noext`.

### `get_ref_forms` generates 6 link variants

`get_ref_forms(ref)` returns: `[[ref]]`, `[[ref|`, `[[ref\\|`, `[[ref#`, `](ref)`, `](ref#`. The `\\|` form handles escaped pipes in wiki link titles (e.g., titles containing literal `|` characters).

### Snacks picker grep: excluding dirs with `--no-ignore`

`Snacks.picker.grep({ args = { "--no-ignore" } })` bypasses `.gitignore`, so gitignored dirs are not auto-excluded. Add `--glob "!<path>/**"` to `args` for explicit exclusion.

### `leader tt` / `leader tc` share grep args structure

Both pickers in `snacks.lua` use identical `args`, `dirs`, and `regex` patterns. Changes to one likely apply to the other — keep in sync.

### Marksman LSP: completion disabled + ARM64 timeout fix

Marksman's LSP completion is intentionally disabled (`completionProvider = nil` in `extend-nvim-lspconfig.lua:10`) — obsidian.nvim provides completion instead. Marksman still provides diagnostics, goto-definition, and cross-references.

On this ARM64 tablet with a large vault (~756 .md files), marksman crashes with `MailboxProcessor.PostAndAsyncReply timed out` (known upstream: #373, #408). Fix: `incremental_references = true` in vault root `.marksman.toml`. The timeout occurs in F#'s MailboxProcessor when processing vault documents on slow CPUs.
