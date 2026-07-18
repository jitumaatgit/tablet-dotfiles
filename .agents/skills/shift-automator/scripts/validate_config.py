"""Check config.yaml for consistency issues and missing keys."""
import os
import sys
from pathlib import Path

project = os.getcwd()
sys.path.insert(0, project)
sys.path.insert(0, str(Path(project) / "src"))

import yaml
from config import DEFAULTS


def validate(path: str = "config.yaml") -> None:
    errors = []
    warnings = []

    data = yaml.safe_load(Path(path).read_text()) or {}

    active = data.get("active_rules", [])
    if active is None:
        errors.append("active_rules is null — must be a list")
        active = []

    for rule in active:
        if rule not in {
            "wakefulness_gate", "calendar_conflict", "day_hours_cap", "post_cap_break",
            "rest_gap_sleep", "location_preference", "shift_type_preference",
            "title_preference", "time_of_day", "weekly_hours_cap",
        }:
            warnings.append(f"Unknown rule in active_rules: '{rule}'")

    active_set = set(active)

    config_key_to_rule = {
        "wakefulness_gate_start": "wakefulness_gate",
        "wakefulness_gate_end": "wakefulness_gate",
        "wakefulness_gate_current": "wakefulness_gate",
        "day_hours_cap": "day_hours_cap",
        "post_cap_break_hours": "post_cap_break",
        "rest_gap_sleep_start": "rest_gap_sleep",
        "rest_gap_sleep_end": "rest_gap_sleep",
        "rest_gap_sleep_hours": "rest_gap_sleep",
        "rest_gap_penalty": "rest_gap_sleep",
        "weekly_hours_cap": "weekly_hours_cap",
        "location_preferences": "location_preference",
        "location_liked_bonus": "location_preference",
        "location_disliked_penalty": "location_preference",
        "shift_type_preferences": "shift_type_preference",
        "title_preferences": "title_preference",
        "title_keywords": "title_preference",
        "preferred_hours": "time_of_day",
        "preferred_time_bonus": "time_of_day",
        "undesired_hours": "time_of_day",
        "undesired_time_penalty": "time_of_day",
        "veto_undesired_hours": "time_of_day",
    }

    for key, rule_name in config_key_to_rule.items():
        if rule_name not in active_set and key in data:
            warnings.append(f"Key '{key}' configured but '{rule_name}' not in active_rules (dead config)")

    for key, rule_name in config_key_to_rule.items():
        if rule_name in active_set and key not in data:
            default_val = DEFAULTS.get(key)
            warnings.append(f"Rule '{rule_name}' active but '{key}' not in config (default: {default_val})")

    loc_prefs = data.get("location_preferences", {}) or {}
    liked = loc_prefs.get("liked", []) or []
    disliked = loc_prefs.get("disliked", []) or []
    if liked and disliked:
        overlap = set(l.lower() for l in liked) & set(d.lower() for d in disliked)
        if overlap:
            errors.append(f"Location(s) in both liked and disliked: {overlap}")

    undesired = data.get("undesired_hours", []) or []
    for i, entry in enumerate(undesired):
        if len(entry) != 2:
            errors.append(f"undesired_hours[{i}] = {entry} — must be [start, end] pair")

    preferred = data.get("preferred_hours", []) or []
    for i, entry in enumerate(preferred):
        if len(entry) != 2:
            errors.append(f"preferred_hours[{i}] = {entry} — must be [start, end] pair")

    if data.get("dry_run") is False and data.get("sms_transport") == "stub":
        warnings.append("dry_run: false but sms_transport: 'stub' — no real SMS will be sent")

    if data.get("dry_run") is False and not data.get("staffing_number"):
        errors.append("dry_run: false but staffing_number is empty — cannot send SMS")

    threshold = data.get("auto_decline_threshold", DEFAULTS["auto_decline_threshold"])
    if threshold is not None and threshold > 0:
        warnings.append(f"auto_decline_threshold is {threshold} (positive) — most shifts will auto-accept")

    print(f"  Config: {path}")
    if errors:
        print(f"\n  ERRORS ({len(errors)}):")
        for e in errors:
            print(f"    [ERR] {e}")
    if warnings:
        print(f"\n  WARNINGS ({len(warnings)}):")
        for w in warnings:
            print(f"    [WARN] {w}")
    if not errors and not warnings:
        print("  [OK] No issues found.")


if __name__ == "__main__":
    validate(sys.argv[1] if len(sys.argv) > 1 else "config.yaml")
