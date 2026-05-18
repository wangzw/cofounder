#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-state-update.sh"
INIT="$DIR/../scripts/run-state-init.sh"

setup_plan_dir() {
  local plan="$1"
  mkdir -p "$plan"
  cat > "$plan/modules.json" <<'JSON'
[
  {"id": "M-001", "deps": []},
  {"id": "M-002", "deps": ["M-001"]}
]
JSON
  bash "$INIT" "$plan" "$plan/modules.json" >/dev/null
}

start_test "update sets plan_status and writes run-status.md"
plan=$(mktempdir); setup_plan_dir "$plan"
bash "$SCRIPT" "$plan" set-plan-status M-001 planned
out=$(python3 -c "
import json
s = json.load(open('$plan/run-state.json'))
assert s['modules']['M-001']['plan_status'] == 'planned'
assert s['last_event_at']
print('OK')
")
assert_stdout_contains "OK" "$out"
test -f "$plan/run-status.md" || fail "run-status.md not generated"

start_test "update sets exec_status to merged on closure modules"
plan=$(mktempdir); setup_plan_dir "$plan"
bash "$SCRIPT" "$plan" set-plan-status M-001 planned
bash "$SCRIPT" "$plan" set-exec-status M-001 merged
out=$(python3 -c "
import json
s = json.load(open('$plan/run-state.json'))
assert s['modules']['M-001']['exec_status'] == 'merged'
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "update rejects invalid plan_status value"
plan=$(mktempdir); setup_plan_dir "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" set-plan-status M-001 bogus 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

start_test "update rejects unknown module"
plan=$(mktempdir); setup_plan_dir "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" set-plan-status M-999 planned 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

start_test "inflight add/remove updates inflight list"
plan=$(mktempdir); setup_plan_dir "$plan"
bash "$SCRIPT" "$plan" inflight-add planners M-001
out=$(python3 -c "
import json
s = json.load(open('$plan/run-state.json'))
assert s['inflight']['planners'] == ['M-001']
print('OK')
")
assert_stdout_contains "OK" "$out"
bash "$SCRIPT" "$plan" inflight-remove planners M-001
out=$(python3 -c "
import json
s = json.load(open('$plan/run-state.json'))
assert s['inflight']['planners'] == []
print('OK')
")
assert_stdout_contains "OK" "$out"

summary
