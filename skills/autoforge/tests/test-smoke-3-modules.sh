#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
FIXT="$DIR/fixtures/dag-3-modules"
INIT="$DIR/../scripts/run-state-init.sh"
UPDATE="$DIR/../scripts/run-state-update.sh"

start_test "init produces expected tier breakdown"
plan=$(mktempdir)
cp "$FIXT/modules.json" "$plan/"
bash "$INIT" "$plan" "$plan/modules.json" >/dev/null
out=$(python3 -c "
import json
expected = json.load(open('$FIXT/expected-tiers.json'))
s = json.load(open('$plan/run-state.json'))
for mid, want in expected.items():
    got = s['modules'][mid]['tier']
    assert got == want, f'{mid}: got tier={got} want={want}'
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "ready_set_planning advances through DAG"
plan=$(mktempdir)
cp "$FIXT/modules.json" "$plan/"
bash "$INIT" "$plan" "$plan/modules.json" >/dev/null
out=$(python3 -c "
import sys, json; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import load_state, ready_set_planning, save_state
s = load_state('$plan/run-state.json')
assert ready_set_planning(s) == ['M-001'], ready_set_planning(s)
s['modules']['M-001']['plan_status'] = 'planned'
# Now M-002 and M-004 are tier 2, both planning-ready
assert sorted(ready_set_planning(s)) == ['M-002', 'M-004']
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "full progression: plan + execute all modules end state"
plan=$(mktempdir)
cp "$FIXT/modules.json" "$plan/"
bash "$INIT" "$plan" "$plan/modules.json" >/dev/null
for mid in M-001 M-002 M-003 M-004; do
  bash "$UPDATE" "$plan" set-plan-status "$mid" planned
done
for mid in M-001 M-004 M-002 M-003; do
  bash "$UPDATE" "$plan" set-exec-status "$mid" merged
done
out=$(python3 -c "
import sys; sys.path.insert(0, '$DIR/../scripts/lib')
from run_state import load_state, ready_set_planning, ready_set_execution
s = load_state('$plan/run-state.json')
assert ready_set_planning(s) == []
assert ready_set_execution(s) == []
assert all(m['exec_status'] == 'merged' for m in s['modules'].values())
print('OK')
")
assert_stdout_contains "OK" "$out"

summary
