#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"

LIB="$DIR/../scripts/lib"

start_test "create_initial_state builds modules dict from index"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
    {'id': 'M-003', 'deps': ['M-001', 'M-002']},
]
s = create_initial_state(modules)
assert s['modules']['M-001']['tier'] == 1
assert s['modules']['M-002']['tier'] == 2
assert s['modules']['M-003']['tier'] == 3
assert s['modules']['M-003']['closure'] == ['M-001', 'M-002']
assert s['modules']['M-001']['plan_status'] == 'pending'
assert s['modules']['M-001']['exec_status'] == 'pending'
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "ready_set_planning returns modules with all-planned closure"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state, ready_set_planning
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
]
s = create_initial_state(modules)
# M-001 has empty closure -> planning-ready immediately
assert ready_set_planning(s) == ['M-001'], ready_set_planning(s)
# Mark M-001 planned -> M-002 becomes planning-ready
s['modules']['M-001']['plan_status'] = 'planned'
assert ready_set_planning(s) == ['M-002'], ready_set_planning(s)
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "ready_set_execution requires closure.all(exec_status=merged)"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state, ready_set_execution
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
]
s = create_initial_state(modules)
# Both pending -> M-001 not exec-ready (plan_status != planned)
assert ready_set_execution(s) == []
s['modules']['M-001']['plan_status'] = 'planned'
# M-001 plan_status=planned + empty closure -> exec-ready
assert ready_set_execution(s) == ['M-001']
# Merge M-001 -> M-002 still not ready (plan_status pending)
s['modules']['M-001']['exec_status'] = 'merged'
assert ready_set_execution(s) == []
# Plan M-002 -> ready
s['modules']['M-002']['plan_status'] = 'planned'
assert ready_set_execution(s) == ['M-002']
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "ready_set_execution priorities needs_patch first"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state, ready_set_execution
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': []},
]
s = create_initial_state(modules)
# Both plan_status=planned, M-001 needs_patch, M-002 pending
s['modules']['M-001']['plan_status'] = 'planned'
s['modules']['M-001']['exec_status'] = 'needs_patch'
s['modules']['M-002']['plan_status'] = 'planned'
ready = ready_set_execution(s)
# needs_patch must come first
assert ready[0] == 'M-001', ready
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "load_and_save roundtrip preserves state"
tmp=$(mktempdir); state="$tmp/run-state.json"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state, save_state, load_state
modules = [{'id': 'M-001', 'deps': []}]
s = create_initial_state(modules)
s['modules']['M-001']['plan_status'] = 'planned'
save_state('$state', s)
s2 = load_state('$state')
assert s2['modules']['M-001']['plan_status'] == 'planned'
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "filter_modules_by_scope all four code paths"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state, filter_modules_by_scope
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
    {'id': 'M-003', 'deps': ['M-001', 'M-002']},
]
s = create_initial_state(modules)

# 'all' returns full list
result = filter_modules_by_scope(s, 'all')
assert isinstance(result, list), type(result)
assert set(result) == {'M-001', 'M-002', 'M-003'}, result

# 'tier-1' returns only tier-1 modules
result = filter_modules_by_scope(s, 'tier-1')
assert isinstance(result, list), type(result)
assert result == ['M-001'], result

# 'module-M-001' returns single-element list
result = filter_modules_by_scope(s, 'module-M-001')
assert isinstance(result, list), type(result)
assert result == ['M-001'], result

# unknown module raises ValueError
try:
    filter_modules_by_scope(s, 'module-M-999')
    assert False, 'expected ValueError'
except ValueError:
    pass

# unknown scope shape raises ValueError
try:
    filter_modules_by_scope(s, 'banana')
    assert False, 'expected ValueError'
except ValueError:
    pass

print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "cycle detection raises ValueError mentioning cycle"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state
try:
    create_initial_state([
        {'id': 'A', 'deps': ['B']},
        {'id': 'B', 'deps': ['A']},
    ])
    print('FAIL: no error raised')
except ValueError as e:
    msg = str(e)
    assert 'cycle' in msg.lower(), f'expected cycle in message, got: {msg!r}'
    print('OK')
")
assert_stdout_contains "OK" "$out"

summary
