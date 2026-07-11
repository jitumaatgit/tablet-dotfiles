---
name: toggle-model-provider
description: >
  Flip all model refs and the active provider block between opencode-go and
  deepseek. Use when hitting opencode-go rate limits, or when the user asks
  to switch/toggle/migrate providers.
---

# Toggle Model Provider

Flip model refs and the provider block between `opencode-go` and `deepseek`.
The transform is reversible — applying it again returns to the original provider.

## Files and fields

| File | Fields to flip |
|------|----------------|
| `~/.config/opencode/opencode.json` | `model`, `small_model`, `agent.*.model` |
| `~/.config/opencode/command/commit.md` | YAML frontmatter `model:` (line 3) |

Flip every field in the list. Do not rename provider keys or model keys inside
the provider block — only the `provider/model` ref strings in the fields above.

## Model mapping

Read the files to find which provider is active, then apply every matching row:

| opencode-go | deepseek |
|---|---|
| `opencode-go/deepseek-v4-pro` | `deepseek/deepseek-v4-pro` |
| `opencode-go/deepseek-v4-flash` | `deepseek/deepseek-v4-flash` |
| `opencode-go/glm-5.2` | `deepseek/deepseek-v4-pro` |

The `glm-5.2` row is **one-way**: replace `opencode-go/glm-5.2` with
`deepseek/deepseek-v4-pro` when flipping to deepseek, but never replace
`deepseek/deepseek-v4-pro` with `glm-5.2` when flipping back (use the
exact-name row instead).

## Provider block

The `"provider"` object in `opencode.json` contains both provider blocks.
Exactly one is uncommented (not wrapped in `/*` … `*/`).

1. Find which block is active (not inside `/*` … `*/`)
2. Wrap it in JSONC block comments (`/*` before the key, `*/` after the closing brace)
3. Unwrap the other block (remove its `/*` and `*/`)

## Completion

After flipping, every model ref in every file must point at the active
provider. Scan both files to confirm no old-provider ref remains.

DeepSeek needs `DEEPSEEK_API_KEY` in the environment — source from
`~/notes/deepseek.env` if not already set.
