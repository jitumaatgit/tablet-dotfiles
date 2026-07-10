---
name: toggle-model-provider
description: >
  Toggle opencode model provider between opencode-go and deepseek. Use when
  hitting rate limits on opencode-go, when switching AI providers, or when
  user mentions "toggle provider", "switch to deepseek", "switch back to
  opencode-go", or "provider migration".
---

# Toggle Model Provider

Switch all model refs and provider blocks between `opencode-go` and `deepseek`.

## Files

| File | Purpose |
|------|---------|
| `~/.config/opencode/opencode.json` | Main model refs + provider blocks |
| `~/.config/opencode/command/commit.md` | YAML frontmatter `model:` on line 3 |

## Model mapping

| opencode-go | deepseek |
|---|---|
| `opencode-go/deepseek-v4-pro` | `deepseek/deepseek-v4-pro` |
| `opencode-go/deepseek-v4-flash` | `deepseek/deepseek-v4-flash` |
| `opencode-go/glm-5.2` | `deepseek/deepseek-v4-pro` |

Use the mapping table to flip every model ref in the two files. Replace the full
`provider/model` string on each line — do not rename provider keys or model keys inside
the provider blocks.

## Provider blocks in opencode.json

Both providers live in the same `"provider"` object. Exactly one must be active.

**To enable deepseek:**
1. Uncomment the deepseek block (remove `/*` and `*/`)
2. Comment out the opencode-go block

**To enable opencode-go:**
1. Uncomment the opencode-go block
2. Comment out the deepseek block

Do not delete either block — comment/uncomment only so the toggle is reversible.

## Env var

The deepseek block references `{env:DEEPSEEK_API_KEY}`. Source it from `~/notes/deepseek.env`
or set directly before running opencode.

## Rollback note

This skill is intended for temporary provider switches (e.g., rate-limit workarounds).
Reverse the steps to go back.
