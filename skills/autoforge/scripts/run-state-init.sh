#!/usr/bin/env bash
# run-state-init.sh — seed run-state.json from a Module Index JSON.
#
# Usage:
#   run-state-init.sh <plan-dir> <modules.json>
#
# <modules.json> is a JSON array of {id, deps} objects derived from the
# design README's Module Index. The orchestrator builds it from the
# design doc; this script does not parse the design README directly so
# the responsibility split stays clean.
#
# Refuses to run if <plan-dir>/run-state.json already exists. Use
# run-state-update.sh for transitions.
#
# Exit codes:
#   0  state file created
#   2  argument or filesystem error

set -euo pipefail

PLAN_DIR="${1:-}"
MODULES_JSON="${2:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  echo "Usage: run-state-init.sh <plan-dir> <modules.json>" >&2
  exit 2
fi
if [ -z "$MODULES_JSON" ] || [ ! -f "$MODULES_JSON" ]; then
  echo "ERROR: modules.json not found: ${MODULES_JSON:-<empty>}" >&2
  exit 2
fi
STATE="$PLAN_DIR/run-state.json"
if [ -e "$STATE" ]; then
  echo "ERROR: $STATE already exists; refusing to overwrite. Delete it" >&2
  echo "manually if a re-init is intended." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AF_PLAN_DIR="$PLAN_DIR"
export AF_MODULES_JSON="$MODULES_JSON"
export AF_SCRIPT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import json, os, sys
plan_dir = os.environ["AF_PLAN_DIR"]
modules_json = os.environ["AF_MODULES_JSON"]
script_dir = os.environ["AF_SCRIPT_DIR"]

sys.path.insert(0, os.path.join(script_dir, "lib"))
from run_state import create_initial_state, save_state

with open(modules_json, "r", encoding="utf-8") as f:
    modules = json.load(f)
if not isinstance(modules, list):
    print(f"ERROR: {modules_json} must be a JSON array", file=sys.stderr)
    sys.exit(2)
for m in modules:
    if not isinstance(m, dict) or "id" not in m or "deps" not in m:
        print(f"ERROR: malformed entry {m!r}; need {{id, deps}}", file=sys.stderr)
        sys.exit(2)

ids = [m["id"] for m in modules]
if len(ids) != len(set(ids)):
    dupes = sorted({mid for mid in ids if ids.count(mid) > 1})
    print(f"ERROR: duplicate module ids: {dupes}", file=sys.stderr)
    sys.exit(2)

try:
    state = create_initial_state(modules)
except ValueError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    sys.exit(2)

save_state(os.path.join(plan_dir, "run-state.json"), state)
print(f"initialized run-state.json with {len(modules)} modules")
PYEOF
