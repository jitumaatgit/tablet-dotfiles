---
name: shift-automator
description: Shift-automator: code, config, SMS logs, pipeline. Use when the user touches this repo.
---

# Shift Automator

## Quick Start

```bash
# Score a sample shift with full rule breakdown
python src/main.py --sample 1

# Score raw text, JSON output for automation
python src/main.py --json --text "Open shift at [Starlight] FD ..."

# Run tests (always run parser tests first)
pytest tests/test_parser.py tests/test_rules.py -v
pytest tests/ -v
```

## Core Workflows

### 1. Analyze shift offers from SMS logs

The log file (`shift_automator_log.json`) records every pipeline run. Each entry has: `dept`, `title`, `code`, `accepted`, `score`, `reasons`, `elapsed_ms`, `raw_preview`.

Use `scripts/analyze_log.py` to surface patterns:

```bash
python .agents/skills/shift-automator/scripts/analyze_log.py shift_automator_log.json
```

For live phone logs, pull fresh first: `adb pull /sdcard/shift_automator_log.json .` (ensure file path in config matches — Termux may write to home dir, not sdcard).

Key signals in logs:
- Score near threshold (e.g. -5.0): boundary decisions — check if one rule pushed it over
- `[VETO-DECLINE]` in reasons: hard block by a gate rule — check if gate is too aggressive
- `accepted: true` but no follow-up confirmation: silent claim-send failure (check `Popen` vs `run`)
- `elapsed_ms` only covers `_process_shift()` — not the full end-to-end (query `content://sms` for true timing)

### 2. Audit pipeline decisions end-to-end

Trace the full flow: SMS → classify → parse → score → act → calendar → push.

```bash
# Dry-run a sample to see what would happen without side effects
python src/main.py --sample 1

# Check which rules fired and why
python src/main.py --json --text "$(cat some_shift.txt)" | python -m json.tool
```

Decision factors to audit:
- **Veto rules** (wakefulness_gate, calendar_conflict, day_hours_cap, post_cap_break): block regardless of score
- **Scoring rules**: accumulate toward the binary threshold (`score > auto_decline_threshold`)
- **FLAG rules**: informational only, no score impact
- **Config gaps**: a rule in `active_rules` but missing from config keys → silent fail or wrong behavior

### 3. Tune scoring rules and thresholds

Rules are configured in `config.yaml` and ordered in `active_rules`. Change config, re-run sample:

```bash
# After editing config.yaml, test against known samples
python src/main.py --sample 1
python src/main.py --sample 5
```

Tuning guide:
- **`auto_decline_threshold`**: binary cutoff (strict greater-than). Lower = more accepting.
- **`shift_type_preferences`**: per-building base scores. Add new buildings here after parser can resolve them.
- **`title_preferences`**: exact role match; `title_keywords`: partial match. Add keywords when titles vary.
- **`location_preferences`**: checks `display_address` AND `building.name`. Both liked/disliked lists.
- **`undesired_hours`**: pairs of `[start, end]`. With `veto_undesired_hours: true`, these hard-block instead of penalize.
- **Veto gate thresholds**: `weekly_hours_cap`, `day_hours_cap`, `post_cap_break_hours`, `rest_gap_sleep_hours`, `wakefulness_gate_*`

## Reference

See [REFERENCE.md](REFERENCE.md) for full architecture, module internals, data flow, config key reference, and rule contract details.

## Scripts

- `scripts/analyze_log.py` — Parse log JSON and surface decision patterns
- `scripts/score_shift.py` — Score a shift text showing per-rule breakdown
- `scripts/validate_config.py` — Check config.yaml for consistency
