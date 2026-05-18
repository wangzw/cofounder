#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-scheduler-state.sh"

make_repo_with_state() {
  local repo="$1"; local plan="$2"
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -q -b main
    git config user.email t@example.com; git config user.name t
    echo seed > seed.txt; git add seed.txt; git commit -q -m seed
    git branch autoforge/feature
  )
  mkdir -p "$plan"
  python3 - <<PYEOF
import sys; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import create_initial_state, save_state
modules = [{'id': 'M-001', 'deps': []}]
s = create_initial_state(modules)
save_state('$plan/run-state.json', s)
PYEOF
}

start_test "PASS when state is consistent"
repo=$(mktempdir); plan=$(mktempdir)
make_repo_with_state "$repo" "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$repo" 2>&1)
rc=$?
set -e
assert_exit_code 0 "$rc" "$out"

start_test "FAIL CR-AF33 when exec_status=merged but module branch absent"
repo=$(mktempdir); plan=$(mktempdir)
make_repo_with_state "$repo" "$plan"
python3 - <<PYEOF
import sys; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import load_state, save_state
s = load_state('$plan/run-state.json')
s['modules']['M-001']['plan_status'] = 'planned'
s['modules']['M-001']['exec_status'] = 'merged'
save_state('$plan/run-state.json', s)
PYEOF
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$repo" 2>&1)
rc=$?
set -e
assert_exit_code 1 "$rc" "$out"
echo "$out" | grep -q '"criterion_id": "CR-AF33"' || fail "expected CR-AF33"

start_test "FAIL CR-AF33 when inflight module has no worktree"
repo=$(mktempdir); plan=$(mktempdir)
make_repo_with_state "$repo" "$plan"
python3 - <<PYEOF
import sys; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import load_state, save_state
s = load_state('$plan/run-state.json')
s['inflight']['modules'] = ['M-001']
save_state('$plan/run-state.json', s)
PYEOF
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$repo" 2>&1)
rc=$?
set -e
assert_exit_code 1 "$rc" "$out"
echo "$out" | grep -q '"criterion_id": "CR-AF33"' || fail "expected CR-AF33"

summary
