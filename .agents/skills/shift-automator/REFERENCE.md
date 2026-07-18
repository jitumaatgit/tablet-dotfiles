# Shift Automator — Deep Reference

## Architecture

```
SMS text
  │
  ▼
main.py::process() ──► classify_incoming() ──┬── "offer" ──────► process_offer()
                                              ├── "confirmation" ► _handle_confirmation()
                                              ├── "rejection" ───► _handle_rejection()
                                              └── "garbage" ─────► (discard)
```

### Pipeline (`process_offer`)

```
text → parse_with_fallback() → RulesEngine.evaluate() → [accept|decline]
         │                         │
         ▼                         ▼
    ParsedOffer              ScoredOffer
    (frozen, parser output)  (score, decision, reasons)
```

**Accept path**: sends pending ntfy push (⏳), fires `termux-sms-send` in thread. Calendar event deferred until shortcode confirmation arrives.
**Decline path**: sends decline ntfy push (❌). If fast-claimed, warns about needed dispatch cancel.

### Confirmation/Rejection handlers

- `_handle_confirmation`: parses "Congratulations..." → creates calendar event → sends BOOKED push (✅) replacing pending (⏳) via `X-Message` header
- `_handle_rejection`: sends NOT-BOOKED push (❌). Cannot link to pending push (rejection text lacks shift data to compute `shift_key`)

## Modules

### `src/models.py`

| Class | Kind | Purpose |
|-------|------|---------|
| `ParsedOffer` | frozen dataclass | Immutable parser output. Fields: `raw_text`, `building`, `title`, `start_time`, `end_time`, `claim_code`, `cancel_number`, `address`, `shift_note`, `contact_name`, `contact_phone`, `year_inferred`, `locations`, `calendar_event_id` |
| `ScoredOffer` | regular dataclass | Rules output wrapping ParsedOffer: `offer`, `score`, `decision` (ShiftDecision), `reasons` |
| `ShiftContext` | frozen dataclass | Pre-computed calendar state for rules: `timezone`, `day_hours`, `prev_day_hours`, `prev_day_last_end`, `adjacent_events`, `weekly_hours`, `conflicts` |
| `PipelineResult` | regular dataclass | Unified return type: `kind`, `parsed`, `scored`, `actions`, `elapsed_ms`, `dry_run`, `error`, `event_id` |
| `LocationSegment` | dataclass | Multi-site location block: `name`, `address`, `start_time`, `end_time` |
| `ShiftDecision` | Enum | `AUTO_ACCEPT`, `AUTO_DECLINE` |
| `Action` / `ActionKind` | dataclass + Enum | Pipeline action log entries |

Key properties on `ParsedOffer`:
- `shift_key`: deterministic MD5 from `building|title|start_time` — used as ntfy `X-Message` ID across pipeline invocations
- `duration_hours`: `(end - start) / 3600`
- `is_multi_site`: has non-empty `locations`
- `is_overtime_eligible`: "overtime approved" in `shift_note`
- `display_address`: sites joined with " / " for multi-site, raw `address` otherwise

### `src/parser.py`

**Entry points**:
- `classify_incoming(text) → str`: routes to "garbage" | "rejection" | "confirmation" | "offer"
- `parse_shift_text(text, reference_date?, known_buildings?) → (ParsedOffer, errors[])`: main parser
- `parse_with_fallback(text, ...)`: tries main parser, falls back to registered custom parsers
- `parse_confirmation(text) → Optional[ParsedOffer]`: parses confirmation SMS
- `load_sample_shifts(data_path?) → list[(id, text)]`: loads from `data/sample_shifts.md`

**Regex patterns** (module-level):
- `HEADER_RE`: strict — `Open shift available at [Building] Title starting at Day date time - time`
- `HEADER_LOOSE_RE`: relaxed — tolerates missing "Open", extra spaces, dashes
- `CLAIM_CODE_RE`: `reply NNN (only this number)` — exact match
- `CLAIM_CODE_LOOSE_RE`: `reply NNNNN` — fallback
- `CONFIRMATION_HEADER_RE`: `Congratulations! You are now booked...`
- `STAFFING_REPLY_PATTERNS`: rejection indicators ("already been taken", "sorry")
- `GARBAGE_RE`: empty/single-word messages

**Building resolution** (`_resolve_building`): maps bracket text → canonical name via `_bracket_to_building` dict. Falls back to `known_buildings` set (from `shift_type_preferences` keys). Splits on " - " for role-suffixed entries (e.g., "River Haven - CBA" → "River Haven").

**Error constants**: `_EMPTY` ("Empty text"), `_NO_HEADER` ("Could not parse header line"). Used by `parse_with_fallback` to decide whether to try custom parsers.

### `src/rules.py`

**Rule function signature**: `(ParsedOffer, Config, context?, parse_errors?) → RuleResult`

**RuleResult**: `rule_name`, `action` (VETO_DECLINE | SCORE | FLAG), `value` (score delta), `reason`

| Rule | Type | What it does |
|------|------|-------------|
| `rule_wakefulness_gate` | VETO | Blocks if shift starts in sleep window AND current hour too early |
| `rule_calendar_conflict` | VETO | Blocks if calendar has overlapping event (CC-only check) |
| `rule_day_hours_cap` | VETO | Blocks if day already has >= cap hours of CC shifts |
| `rule_post_cap_break` | VETO | Blocks if previous day hit cap AND break before this shift too short |
| `rule_rest_gap_sleep` | SCORE | Penalizes if gap to adjacent shift < required hours AND either is in sleep window |
| `rule_location_preference` | SCORE | +bonus for liked locations, -penalty for disliked (checks address + building name) |
| `rule_shift_type_preference` | SCORE | Base score from `shift_type_preferences[building]` |
| `rule_title_preference` | SCORE | Score from exact title match or keyword partial match |
| `rule_time_of_day` | VETO/SCORE | Bonus in preferred hours, penalty (or veto) in undesired hours |
| `rule_weekly_hours_cap` | VETO | Blocks if projected weekly hours > cap (unless overtime approved). Computes `week_start` from the shift's own `start_time` — no pre-computed system-wide param |

**RulesEngine**: loads rules from `BUILTIN_RULES` by `active_rules` config order. `evaluate()` computes `ShiftContext` (if calendar available), runs all rules, aggregates: veto → AUTO_DECLINE, score > threshold → AUTO_ACCEPT, else AUTO_DECLINE.

**Important**: Threshold is strict greater-than (`>`), not `>=`.

### `src/config.py`

`load_config(path?) → Config`: deep-copies DEFAULTS, merges user YAML, converts list fields to tuples.

`Config` is a frozen dataclass (immutable). Mutate in tests via `dataclasses.replace()`.

**Config key categories**:

| Category | Keys |
|----------|------|
| Decision | `auto_decline_threshold`, `active_rules` |
| Location scoring | `location_preferences`, `location_liked_bonus`, `location_disliked_penalty` |
| Building scoring | `shift_type_preferences` |
| Role scoring | `title_preferences`, `title_keywords` |
| Time scoring | `preferred_hours`, `preferred_time_bonus`, `undesired_hours`, `undesired_time_penalty`, `veto_undesired_hours` |
| Calendar gates | `weekly_hours_cap`, `day_hours_cap`, `post_cap_break_hours`, `rest_gap_sleep_start/end/hours`, `rest_gap_penalty` |
| Wakefulness | `wakefulness_gate_start/end/current` |
| Transport | `staffing_number`, `personal_number`, `sms_transport`, `work_sim_sub_id`, `ntfy_channel`, `tasker_base_url`, `cancel_warning_seconds` |
| Calendar | `calendar_id`, `calendar_credentials_path`, `calendar_timezone`, `calendar_cache_ttl_seconds` |
| Logging | `log_file`, `log_level` |
| Other | `dry_run`, `dispatch_number` |

**Syncing changes**: When adding/removing a rule from `active_rules`, update in 4 places: config.yaml list, Config dataclass defaults tuple, DEFAULTS dict, and test assertion in `tests/test_config.py`.

### `src/calendar_client.py`

`CalendarClient`: Google Calendar API wrapper delegating caching to `EventStore`.
- `authenticate()`: lazy-loads heavy Google imports, sets `_authed = True`
- `get_events_between(start, end)`: cached fetch with TTL, window-keyed invalidation
- `check_conflict(offer, cc_only?)`: overlap check; when `cc_only=True`, skips non-`[CC]` events and returns the first CC conflict (used by `rule_calendar_conflict`)
- `add_shift_event(offer)`: creates calendar event (deferred until confirmation)
- `get_weekly_hours(week_start?)`: sums CC event hours for the week
- `invalidate_cache()`: delegates to `EventStore.invalidate()` (deletes file cache + clears in-memory state)

`EventStore`: Standalone caching layer. Takes a `fetcher` callback, cache file path, TTL, and timezone. `get_events()` handles exact in-memory match → superset in-memory match via `_filter_by_window` → file cache (exact window only) → fetcher callback. `invalidate()` deletes cache file AND clears in-memory state. No file-cache superset — in-memory only (file superset caused test contamination).

`_filter_cc_events(events)`: Module-level helper that filters event list to `[CC]`-prefixed summaries. Used by `get_weekly_hours` and `rule_rest_gap_sleep`.

`FakeCalendar`: test stub with configurable return values (used in rules tests).

`CalendarProtocol`: runtime-checkable protocol for the calendar interface.

`compute_shift_context(offer, calendar)`: pre-computes all calendar-derived values for rules engine.

### `src/responder.py`

`Responder` / `TermuxResponder` / `TwilioResponder`: SMS + push notification transports.
- `send_accept(offer)`: sends claim code via SMS
- `send_pending_push(offer)`: ⏳ pending confirmation notification
- `send_decline_push(scored)`: ❌ decline notification
- `send_booking_push(offer, booked)`: ✅/❌ final status notification (with Tasker HTTP action buttons when booked)
- `log_event(data)`: appends JSON entry to log file

**SMS transport**: `TermuxResponder` uses `Popen(["termux-sms-send", "-s", slot, "-n", number])` with stdin pipe. Must guard against `FileNotFoundError` on non-Android.

**Push transport**: ntfy.sh HTTP API. Priority as integer 1-5. `X-Message` header for in-place replacement.

### `src/pipeline.py`

Entry point: `process_offer(text, config, calendar, responder) → PipelineResult`

Dispatches to `_handle_confirmation`, `_handle_rejection`, or `_process_shift` based on `classify_incoming()`.

`_execute_accept` / `_execute_decline`: coordinate with `SHIFT_AUTOMATOR_FAST_CLAIM` env var (set by fast path in main.py). Accept sends pending push → fires SMS in thread. Decline sends decline push, warns if fast-claimed.

### `src/main.py`

Entry point: `main()` — parses args, fast-path claims SMS before lazy imports, builds calendar/responder, checks Tasker health, dispatches to pipeline.

**Fast path**: extracts claim code → quick veto check → fires SMS via `Popen` → sets `SHIFT_AUTOMATOR_FAST_CLAIM` env var. Runs before heavy imports (yaml, googleapiclient, requests). `_quick_veto` hardcodes sleep window 22-6 independent of config — intentional, conservatively avoids waking user.

## Data Flow

```
SMS text (incoming)
    │
    ├─ "Open shift at [Building] Title ... reply NNN"
    │   └─ parse_with_fallback() → ParsedOffer
    │       └─ RulesEngine.evaluate() → ScoredOffer
    │           ├─ AUTO_ACCEPT: send SMS (claim code) + pending push (⏳)
    │           └─ AUTO_DECLINE: send decline push (❌)
    │
    ├─ "Congratulations! You are now booked..."
    │   └─ parse_confirmation() → ParsedOffer
    │       └─ add_shift_event() → calendar event
    │       └─ send_booking_push(booked=True) → ✅ (replaces ⏳)
    │
    └─ "Sorry, this position has already been taken"
        └─ send_booking_push(booked=False) → ❌
```

## Testing

```bash
pytest tests/test_parser.py -v    # Parser against all 41+ samples
pytest tests/test_rules.py -v     # Rules engine scoring
pytest tests/test_pipeline.py -v  # End-to-end decision flow
pytest tests/test_calendar.py -v  # Calendar client + caching
pytest tests/test_presenter.py -v # Output formatting
pytest tests/test_config.py -v    # Config validation
pytest tests/test_responder.py -v # Transport + push
pytest tests/ -v                  # Full suite
```

Tests use `FakeCalendar` for calendar-isolated rule testing and `load_sample_shifts()` for parser validation. Enum removals cascade across multiple test files — always run full suite after model changes.

## External Resources

- [Source Explorer (zread.ai)](https://zread.ai/jitumaatgit/shift-automator) — browse the codebase with AI search

## Common Pitfalls (condensed)

- **Config key absent from `active_rules`**: dead weight — key has no effect but reads as active
- **`active_rules` out of sync**: must match in config.yaml, Config defaults, DEFAULTS dict, and test assertions
- **Empty YAML list → None**: `disliked:` (no value) becomes `None`, not `[]`. Use explicit `disliked: []`
- **Threshold strict >**: `score > threshold` not `>=`. Score of exactly -5.0 with threshold -5.0 = DECLINE
- **Undesired hours must be pairs**: `[24]` crashes tuple unpacking. Malformed entries silently skipped now
- **Calendar auth failure → 0.0 weekly hours**: shifts pass through unguarded when auth is down
- **`calendar_cache.json` is runtime state**: always pull fresh from phone before analyzing
- **`elapsed_ms` measures only `_process_shift()`**: not the full end-to-end time
- **Enum removal cascades**: removing `ShiftDecision` value breaks tests in 5+ test files
- **`Popen` in daemon thread**: must use `Popen` not `run` for fire-and-forget SMS to avoid main-thread-exit race
- **File-cache superset removed**: only in-memory superset works within one process
