#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-idle-timeout.sh"

setup() {
  local plan="$1"; local last_event="$2"
  mkdir -p "$plan"
  python3 - <<PYEOF
import json, sys, os
sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import create_initial_state, save_state
modules = [
  {'id': 'M-001', 'deps': []},
  {'id': 'M-002', 'deps': []},
]
s = create_initial_state(modules)
# Make M-001 planning-ready (it already is at init time).
s['scheduler']['idle_timeout_minutes'] = 1
s['last_event_at'] = '$last_event'
save_state('$plan/run-state.json', s)
PYEOF
}

start_test "PASS when last_event_at is recent"
plan=$(mktempdir)
now=$(python3 -c "import datetime as dt; print(dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'))")
setup "$plan" "$now"
set +e
out=$(bash "$SCRIPT" "$plan" 2>&1)
rc=$?
set -e
assert_exit_code 0 "$rc" "$out"

start_test "FAIL with CR-AF32 when idle > timeout AND ready set non-empty"
plan=$(mktempdir)
old=$(python3 -c "import datetime as dt; print((dt.datetime.now(dt.timezone.utc)-dt.timedelta(minutes=10)).isoformat(timespec='seconds'))")
setup "$plan" "$old"
set +e
out=$(bash "$SCRIPT" "$plan" 2>&1)
rc=$?
set -e
assert_exit_code 1 "$rc" "$out"
echo "$out" | grep -q '"criterion_id": "CR-AF32"' || \
  fail "expected CR-AF32 finding in $out"

start_test "PASS when idle but ready set empty (nothing to do)"
plan=$(mktempdir)
old=$(python3 -c "import datetime as dt; print((dt.datetime.now(dt.timezone.utc)-dt.timedelta(minutes=10)).isoformat(timespec='seconds'))")
setup "$plan" "$old"
# Mark every module merged so ready sets are empty.
python3 - <<PYEOF
import sys; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import load_state, save_state
s = load_state('$plan/run-state.json')
for m in s['modules'].values():
    m['plan_status'] = 'planned'
    m['exec_status'] = 'merged'
save_state('$plan/run-state.json', s)
PYEOF
set +e
out=$(bash "$SCRIPT" "$plan" 2>&1)
rc=$?
set -e
assert_exit_code 0 "$rc" "$out"

summary
