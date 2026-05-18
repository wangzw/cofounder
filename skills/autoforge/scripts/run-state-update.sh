#!/usr/bin/env bash
# run-state-update.sh — apply a state transition to run-state.json.
#
# Usage:
#   run-state-update.sh <plan-dir> <action> <args...>
#
# Actions:
#   set-plan-status <module-id> <pending|planning|planned|revising>
#   set-exec-status <module-id> <pending|ready|running|approved|integrating|merged|cancelled|needs_patch|failed>
#   inflight-add <bucket> <module-id>
#   inflight-remove <bucket> <module-id>
#   gate-approve <G0_approved|G1_skeleton_approved|G3_acceptance_approved>
#   freeze <revision-seq>
#   unfreeze
#
# Side effects:
#   1. Updates run-state.json (atomic write).
#   2. Updates last_event_at to now (UTC ISO 8601).
#   3. Regenerates run-status.md.
#   4. NOTE: does NOT commit. The orchestrator commits on the
#      status_commit_every_k / status_commit_every_seconds cadence.
#
# Exit codes:
#   0  state updated
#   2  invalid argument

set -euo pipefail

PLAN_DIR="${1:-}"
ACTION="${2:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  exit 2
fi
if [ -z "$ACTION" ]; then
  echo "ERROR: action required" >&2
  exit 2
fi
shift 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AF_PLAN_DIR="$PLAN_DIR"
export AF_SCRIPT_DIR="$SCRIPT_DIR"
export AF_ACTION="$ACTION"
export AF_ARGS_JSON
AF_ARGS_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "$@")

python3 - <<'PYEOF'
import json, os, sys, datetime as dt
plan_dir = os.environ["AF_PLAN_DIR"]
script_dir = os.environ["AF_SCRIPT_DIR"]
action = os.environ["AF_ACTION"]
args = json.loads(os.environ["AF_ARGS_JSON"])

sys.path.insert(0, os.path.join(script_dir, "lib"))
from run_state import (
    load_state, save_state, PLAN_STATES, EXEC_STATES,
)
from run_status_render import render_status_md

state_path = os.path.join(plan_dir, "run-state.json")
state = load_state(state_path)

def err(msg, code=2):
    print(f"ERROR: {msg}", file=sys.stderr); sys.exit(code)

now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

if action == "set-plan-status":
    if len(args) != 2:
        err("set-plan-status <module-id> <status>")
    mid, status = args
    if mid not in state["modules"]:
        err(f"unknown module: {mid}")
    if status not in PLAN_STATES:
        err(f"invalid plan_status: {status} (valid: {sorted(PLAN_STATES)})")
    state["modules"][mid]["plan_status"] = status
elif action == "set-exec-status":
    if len(args) != 2:
        err("set-exec-status <module-id> <status>")
    mid, status = args
    if mid not in state["modules"]:
        err(f"unknown module: {mid}")
    if status not in EXEC_STATES:
        err(f"invalid exec_status: {status} (valid: {sorted(EXEC_STATES)})")
    state["modules"][mid]["exec_status"] = status
elif action in ("inflight-add", "inflight-remove"):
    if len(args) != 2:
        err(f"{action} <bucket> <module-id>")
    bucket, mid = args
    if bucket not in state["inflight"]:
        err(f"invalid bucket: {bucket} (valid: {sorted(state['inflight'])})")
    lst = state["inflight"][bucket]
    if action == "inflight-add":
        if mid not in lst:
            lst.append(mid)
    else:
        state["inflight"][bucket] = [x for x in lst if x != mid]
elif action == "gate-approve":
    if len(args) != 1:
        err("gate-approve <gate-key>")
    key = args[0]
    if key not in state["human_gates"]:
        err(f"invalid gate: {key}")
    state["human_gates"][key] = True
elif action == "freeze":
    if len(args) != 1:
        err("freeze <revision-seq>")
    state["frozen_at"] = now
    state["current_revision"] = int(args[0])
elif action == "unfreeze":
    state["frozen_at"] = None
    state["current_revision"] = None
else:
    err(f"unknown action: {action}")

state["last_event_at"] = now
save_state(state_path, state)

with open(os.path.join(plan_dir, "run-status.md"), "w", encoding="utf-8") as f:
    f.write(render_status_md(state))

print(f"applied {action} {args}")
PYEOF
