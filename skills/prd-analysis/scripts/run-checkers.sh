#!/usr/bin/env bash
# run-checkers.sh — formal-review aggregator (guide §1.1 + §10).
#
# Walks every per-artifact check-X.sh script in this skill's scripts/ dir,
# invokes each with <prd-dir>, and concatenates their JSON output into one
# document on stdout. Convenience wrapper for review-mode formal hard gate.
#
# Per the design principle "one script per artifact type", run-checkers.sh
# does NOT itself encode any rule logic — it only enumerates and dispatches.
# Adding a new check-X.sh under scripts/ that follows the guide §9 contract
# automatically participates in the next run-checkers invocation.
#
# Usage: run-checkers.sh <prd-dir>
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
import json
import os
import re
import subprocess
import sys

prd_root = sys.argv[1]
script_dir = sys.argv[2]

# Discover every check-*.sh in scripts/, EXCLUDING phase-gate scripts which
# operate on a different argument shape and are invoked at different times by
# the orchestrator (review/index.md and revise/index.md), not by run-checkers.
PHASE_GATES = {"check-review-readiness.sh", "check-revise-completeness.sh"}
checkers: list[str] = sorted(
    f for f in os.listdir(script_dir)
    if f.startswith("check-") and f.endswith(".sh") and f not in PHASE_GATES
)

aggregated: list[dict] = []
script_error_seen = False
worst = "info"
sev_order = {"info": 0, "warning": 1, "error": 2, "critical": 3}

for name in checkers:
    path = os.path.join(script_dir, name)
    try:
        proc = subprocess.run(
            [path, prd_root], capture_output=True, text=True, check=False
        )
    except OSError as e:
        print(f"ERROR: cannot invoke {name}: {e}", file=sys.stderr)
        script_error_seen = True
        continue

    if proc.returncode == 2:
        sys.stderr.write(proc.stderr)
        print(f"ERROR: sub-checker {name} reported a script error", file=sys.stderr)
        script_error_seen = True
        continue

    if proc.returncode == 0:
        continue

    if proc.returncode != 1:
        print(
            f"ERROR: {name} returned unexpected code {proc.returncode}", file=sys.stderr
        )
        script_error_seen = True
        continue

    # exit 1 — issues found. The first stdout line is "FOUND ...:"; the rest is JSON.
    body = proc.stdout
    nl = body.find("\n")
    json_body = body[nl + 1:] if nl >= 0 else body
    try:
        doc = json.loads(json_body)
    except json.JSONDecodeError as e:
        print(
            f"ERROR: {name} stdout after summary line is not valid JSON: {e}",
            file=sys.stderr,
        )
        script_error_seen = True
        continue
    issues = doc.get("issues", []) if isinstance(doc, dict) else []
    aggregated.extend(issues)
    for it in issues:
        sev = it.get("severity", "info")
        if sev_order.get(sev, 0) > sev_order[worst]:
            worst = sev

if script_error_seen:
    sys.exit(2)

if not aggregated:
    print(f"PASS 0 issues found across {len(checkers)} formal-review checker(s)")
    sys.exit(0)

aggregated.sort(key=lambda f: (f.get("criterion_id", ""), f.get("file", ""), f.get("description", "")))
print(
    f"FOUND {len(aggregated)} issue(s) across {len(checkers)} formal-review "
    f"checker(s) (worst severity: {worst}):"
)
print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
