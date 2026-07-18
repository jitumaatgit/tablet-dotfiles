"""Score a shift text showing per-rule breakdown. Runs actual pipeline in dry-run."""
import subprocess
import sys


def score(text: str) -> None:
    result = subprocess.run(
        ["python", "src/main.py", "--json", "--text", text],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    print(result.stdout)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:])
        score(text)
    else:
        print("Usage: python scripts/score_shift.py '<shift text>'", file=sys.stderr)
        sys.exit(1)
