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

## Verify and report (mandatory)

Do NOT stop after editing. Report what you did so the user can trust the
state without guessing. The model NAMES (`deepseek-v4-flash`,
`deepseek-v4-pro`) are identical across both providers, so the name alone
is NOT a reliable signal — users regularly mistake an active opencode-go
run for the deepseek provider because the name says "deepseek". The only
reliable signals are listed below.

1. Determine the active provider: the provider block in `opencode.json`
   that is NOT wrapped in `/* … */` is active; the other is inactive. Name
   it out loud in the report.
2. Confirm no active ref points at the inactive provider:
   `rg -n 'deepseek/deep|opencode-go/glm' .config/opencode/`
   should return nothing outside this SKILL.md (commented lines and this
   file's own table are fine).
3. State the expected opencode UI display, since this is what the user
   will actually see in a session:
   - opencode-go active → models show `from NVIDIA NIM` (e.g.
     "deepseek v4 flash from NVIDIA NIM", "glm 5.2 from NVIDIA NIM").
   - deepseek active → models show `from DeepSeek`.
4. Tell the user explicitly: "the model name is shared between providers;
   trust the `from <X>` suffix, not the name. `from NVIDIA NIM` means
   opencode-go is active."
