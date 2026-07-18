"""Parse shift_automator_log.json and surface decision patterns."""
import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path


def analyze(log: str) -> None:
    entries = [json.loads(line) for line in Path(log).read_text().strip().splitlines() if line.strip()]
    offers = [e for e in entries if e.get("dept")]

    if not offers:
        print("No processed offers in log.")
        return

    accepted = sum(1 for e in offers if e.get("accepted"))
    declined = len(offers) - accepted
    scores = [e.get("score", 0) for e in offers]
    score_range = (min(scores), max(scores))
    avg_score = sum(scores) / len(scores) if scores else 0

    print(f"Total offers: {len(offers)}")
    print(f"Accepted: {accepted} ({accepted/len(offers)*100:.0f}%)")
    print(f"Declined: {declined} ({declined/len(offers)*100:.0f}%)")
    print(f"Score range: {score_range[0]:.1f} to {score_range[1]:.1f} (avg {avg_score:.1f})")

    vetoes: Counter[str] = Counter()
    for e in offers:
        for r in e.get("reasons", []):
            if "[VETO-DECLINE]" in r:
                rule = r.split("[VETO-DECLINE] ")[1].split(":")[0] if "[VETO-DECLINE] " in r else "unknown"
                vetoes[rule] += 1

    if vetoes:
        print("\nVeto reasons:")
        for rule, count in vetoes.most_common():
            print(f"  {rule}: {count}")

    depts: Counter[str] = Counter()
    for e in offers:
        depts[e.get("dept", "Unknown")] += 1
    print("\nTop departments:")
    for dept, count in depts.most_common(10):
        print(f"  {dept}: {count}")

    boundary = [e for e in offers if abs(e.get("score", 0)) <= 6]
    if boundary:
        print(f"\nBoundary decisions (score within ±6 of threshold): {len(boundary)}")
        for e in boundary[-5:]:
            print(f"  {e.get('dept')} {e.get('title')}: {e.get('score', 0):.1f} → {'ACCEPT' if e.get('accepted') else 'DECLINE'}")
            for r in e.get("reasons", []):
                print(f"    {r[:100]}")

    elapsed = [e.get("elapsed_ms", 0) for e in offers if e.get("elapsed_ms")]
    if elapsed:
        print(f"\nPipeline latency: min {min(elapsed):.0f}ms, max {max(elapsed):.0f}ms, avg {sum(elapsed)/len(elapsed):.0f}ms")


if __name__ == "__main__":
    analyze(sys.argv[1] if len(sys.argv) > 1 else "shift_automator_log.json")
