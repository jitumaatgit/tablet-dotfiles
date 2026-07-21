---
name: tasker-automation
description: Generate valid Tasker XML from natural language. Use when the user asks for Tasker automation, profiles, tasks, projects, widgets, or Android automation XML.
---

# Tasker Automation

Generate Tasker XML from natural language. The AI infers whether to create a **Profile** (triggered automatically), **Standalone Task** (manual trigger), or **Project** (multi-component).

## Quick Start

1. User makes a request (e.g. "When I get home, turn on wifi")
2. Determine entity type (Profile / Task / Project)
3. Select components from REFERENCE.md catalogs
4. Build XML following the structure descriptions
5. Output: explanatory sentence + XML code block

## Entity Selection

- **Profile**: Automation triggered by conditions/events/states/times/apps/location
- **Standalone Task**: Manual sequence (shortcut, tile, widget button)
- **Project**: Multiple profiles + named tasks, state tracking + manual actions, widget calling separate tasks

## Key References

See [REFERENCE.md](REFERENCE.md) for: event/state/action catalogs (§1-3), XML schema (§4), structure guides (§5-7), examples (§8, 13-14), clarification protocol (§9-10), built-in variables and structured access (§11-12), widget v2 schema and examples (§15-16), pattern matching (§17), command system (§18), and modification handling (§19).

## Critical Rules

**Generation**
- **No plugins**: Refuse AutoApps, AutoNotification, Join, etc. — refuse before asking clarification
- **No hallucination**: Only `code` values from the catalogs. If a code isn't cataloged, refuse.
- **No built-in variable hallucination**: Only built-in variables from the Built-in Variable Catalog (§11). Never invent global vars.
- **XML tag types**: `"a"` field in catalog is sole determinant of XML tag type
- **XML escaping**: `&`→`&amp;` `>`→`&gt;` `<`→`&lt;` `"`→`&quot;` `'`→`&apos;`
- **`s` field constraints**: Respect MIN:MAX ranges (e.g. `1:999999` for Array Push Position)
- **Profile context limits**: Max 3 State, 1 Event, 1 Time, 1 App per Profile

**Arguments**
- **Bundle args ALWAYS generated** (even when empty) — they contribute to sequential `arg0, arg1, ...` mapping
- **Int with literal**: `<Int sr="arg0" val="5"/>`. **Int with variable**: `<Int sr="arg0"><var>%MyVar</var></Int>` (no `val`)
- **Anchor (300)**: ZERO arguments. Use `<label>` child ONLY. `<Str sr="arg0">` is forbidden — Goto fails silently.
- **Flash (548)**: Always set `arg2` (Tasker Layout) to `1`

**Conditions**
- **Operator codes** for `<op>` tag: `0`=eq, `1`=ne, `2`=Matches, `3`=!Match, `4`=~R, `5`=!~R, `6`=<, `7`=>, `8`==, `9`=!=, `10`=Even, `11`=Odd, `12`=Set, `13`=NotSet
- **Operators 6-11 ONLY for numbers** — use 0-3 for strings
- **N conditions → N-1 `<boolN>` connectors** between `<Condition>` elements

**Variables & Dialogs**
- **Variable naming**: Local vars ≥3 chars, all lowercase. Global vars ≥3 chars, has uppercase. No digit start. Apply to generated loop/index vars too — use `%index`, never `%i`.
- **1-based arrays**: Tasker arrays start at 1, not 0
- **Array Push to end = 999999** (value from `s` field), never 0 or `%arr(#)`
- **Dialog outputs**: `%ld_selected` (List Dialog), `%input` (Input/Pick Input), `%td_button` (Text/Image)
- **`%evtprm1` maps to FIRST param in `parameter_catalog`** (by position), `arg0`→`%evtprm1`, `arg1`→`%evtprm2`, etc. Only Event contexts generate `%evtprm`.
- **Enable Structured Output** before using structured access (`%json[key]`): set the `bosta`-style param to `1`
- **Variable Value state (165)**: Use to monitor built-in vars lacking dedicated contexts
- **Multi-app App context → `App Info` (335) first action**, not `%WIN`

**Widgets**
- **One `Multiple Variables Set` (389) BEFORE** `Widget v2` (461) — define colors (Material You names from §15 `colorString` enum ONLY, or hex)
- **`useMaterialYouColors` OMIT** from widget JSON
- **Prefer Task Calling** (`"task"`/`"taskVariables"`) over Command System for interactions
- **Auto-infer widget name** — never ask unless ambiguous
- **Dynamic lists**: `Array Merge` (393) when all data in parallel arrays; `For` loop otherwise

**Flow**
- **Early returns for validation**: `If` check NOT met → `Flash` (548, msg) → `Stop` (137) → `End If`. Main logic AFTER checks.
- **Action errors**: Enable `<se>false</se>` on the action → check `If %err Is Set` (op 12) → `Notify` (523) `%errmsg` with error icon → `Stop` (137)
- **State inversion**: `<pin>true</pin>` in `<State>`/`<App>`. Never modify parameters (e.g. Wifi arg3) for inversion.

**Project**
- **`<Project sr="proj0">`** — `sr` is always the literal string `"proj0"`. Tasker rejects any other value.
- **Exit Task**: For State profiles with `flags=40`, manually restore settings via Exit Task (`mid1`)
- **Empty `<pids>` OMIT** the tag entirely — not `<pids></pids>`

**Modification**
- **Preserve original IDs/names** when modifying existing XML, unless user explicitly asks to rename

**Variable Search Replace (598)**
- **Stores WHOLE matches in the array, not capture groups**: `%array1`, `%array2` etc. contain the full text matched by the search pattern, not regex capture groups. Tasker's implementation discards capture groups immediately after the action completes.
- **Use lookbehind/lookahead instead of capture groups** when you need to extract only part of a match: `(?<=prefix)suffix` matches `suffix` only, without consuming `prefix`.
- **Example**: to extract digits from `reply 1867694`, use `(?<=reply\s)\d{5,8}` (not `reply\s+(\d{5,8})`). The former stores `1867694`; the latter stores `reply 1867694`.
