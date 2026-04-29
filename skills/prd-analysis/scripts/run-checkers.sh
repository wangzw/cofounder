#!/usr/bin/env bash
# run-checkers.sh — formal-review aggregator (guide §1.1 + §10)
#
# Runs every formal-review script against a PRD bundle and concatenates
# their JSON output into one document on stdout. Convenience wrapper for
# writer self-audit (guide §4) and review-mode formal hard gate (guide §5).
#
# Usage: run-checkers.sh <prd-dir>
#
# Sub-checks invoked (in order):
#   scripts/check-prd-formal.sh    — PRD-shape structural / format checks
#   scripts/check-issue-schema.sh  — review-artifact self-closure (§10)
#
# Returncode (per guide §9.1):
#   0  every sub-check passed
#   1  one or more sub-checks reported issues — JSON document on stdout
#   2  script-level error in one of the sub-checks
#
# Stdout (per guide §9.2): always restates the meaning. On exit 1 the
# document has shape `{"issues": [...]}`, the same shape that
# `create-issues.sh` consumes.

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: run-checkers.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR" <<'PYEOF'
import os, sys, json, subprocess

prd_root = sys.argv[1]
script_dir = sys.argv[2]

CHECKERS = [
    ("check-prd-formal.sh", [prd_root]),
    ("check-issue-schema.sh", [prd_root]),
]

aggregated = []
worst = 'info'
order = {'info': 0, 'warning': 1, 'error': 2, 'critical': 3}
script_error = False

for name, args in CHECKERS:
    path = os.path.join(script_dir, name)
    if not os.path.isfile(path):
        print(f"ERROR: missing checker: {name}", file=sys.stderr)
        sys.exit(2)
    try:
        proc = subprocess.run([path, *args], capture_output=True, text=True, check=False)
    except OSError as e:
        print(f"ERROR: cannot invoke {name}: {e}", file=sys.stderr)
        sys.exit(2)
    if proc.returncode == 2:
        sys.stderr.write(proc.stderr)
        print(f"ERROR: sub-checker {name} reported a script error", file=sys.stderr)
        script_error = True
        continue
    if proc.returncode == 0:
        continue
    if proc.returncode != 1:
        print(f"ERROR: {name} returned unexpected code {proc.returncode}", file=sys.stderr)
        sys.exit(2)
    # exit 1 — issues found. The first stdout line is "FOUND ...:"; the rest is JSON.
    body = proc.stdout
    nl = body.find('\n')
    json_body = body[nl + 1:] if nl >= 0 else body
    try:
        doc = json.loads(json_body)
    except json.JSONDecodeError as e:
        print(f"ERROR: {name} stdout is not valid JSON after summary line: {e}", file=sys.stderr)
        sys.exit(2)
    issues = doc.get('issues', []) if isinstance(doc, dict) else []
    aggregated.extend(issues)
    for it in issues:
        sev = it.get('severity', 'info')
        if order.get(sev, 0) > order[worst]:
            worst = sev

if script_error:
    sys.exit(2)

if not aggregated:
    print("PASS 0 issues found across all formal-review checkers")
    sys.exit(0)

print(f"FOUND {len(aggregated)} issue(s) across formal-review checkers (worst severity: {worst}):")
print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
