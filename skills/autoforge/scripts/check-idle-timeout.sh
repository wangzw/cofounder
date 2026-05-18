#!/usr/bin/env bash
# check-idle-timeout.sh — CR-AF32 idle-timeout exceeded
#
# Emits an error finding if:
#   now - last_event_at > scheduler.idle_timeout_minutes
#   AND (ready_set_planning OR ready_set_execution) is non-empty
#   AND inflight slots are not full (planners < cap or modules < cap)
#
# Usage: check-idle-timeout.sh <plan-dir>
#
# Exit codes:
#   0  PASS
#   1  finding emitted (JSON on stdout, banner on stderr)
#   2  script-level error

set -euo pipefail

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AF_PLAN_DIR="$PLAN_DIR"
export AF_SCRIPT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import json, os, sys, datetime as dt
plan_dir = os.environ["AF_PLAN_DIR"]
script_dir = os.environ["AF_SCRIPT_DIR"]
sys.path.insert(0, os.path.join(script_dir, "lib"))
from run_state import load_state, ready_set_planning, ready_set_execution

state_path = os.path.join(plan_dir, "run-state.json")
if not os.path.isfile(state_path):
    print("PASS no run-state.json (checker is a no-op pre-init)")
    sys.exit(0)

state = load_state(state_path)
sched = state["scheduler"]
last = state.get("last_event_at")
if not last:
    print("PASS last_event_at is null (nothing has happened yet)")
    sys.exit(0)

last_dt = dt.datetime.fromisoformat(last)
now = dt.datetime.now(dt.timezone.utc)
elapsed = (now - last_dt).total_seconds() / 60.0
timeout_min = sched.get("idle_timeout_minutes", 30)

if elapsed <= timeout_min:
    print(f"PASS idle for {elapsed:.1f}min (under {timeout_min}min threshold)")
    sys.exit(0)

ready = ready_set_planning(state) + ready_set_execution(state)
slots_open = (
    len(state["inflight"]["planners"]) < sched["max_planners"] or
    len(state["inflight"]["modules"]) < sched["max_modules"]
)
if not ready or not slots_open:
    print(f"PASS idle but no work waiting (ready={len(ready)}, slots_open={slots_open})")
    sys.exit(0)

print(
    f"FOUND CR-AF32 idle-timeout exceeded "
    f"(elapsed {elapsed:.1f}min > {timeout_min}min, "
    f"ready set non-empty, slots open)",
    file=sys.stderr,
)
doc = {
    "issues": [{
        "criterion_id": "CR-AF32",
        "file": os.path.relpath(state_path, plan_dir),
        "severity": "error",
        "description": (
            f"Event loop idle for {elapsed:.1f} minutes "
            f"(threshold {timeout_min}min) while ready set has "
            f"{len(ready)} module(s) waiting and agent slots are open. "
            f"Likely causes: a stuck inflight agent, a misconfigured cap, "
            f"or an orchestrator that lost the completion notification."
        ),
        "suggested_fix": (
            "Inspect run-state.json inflight lists. For each inflight "
            "module, check its worktree and module-state-M-*.json for "
            "recent activity. If an agent is genuinely stuck, kill its "
            "session and remove it from inflight; the next loop iteration "
            "will respawn it from the ready set."
        ),
    }]
}
print(json.dumps(doc, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
