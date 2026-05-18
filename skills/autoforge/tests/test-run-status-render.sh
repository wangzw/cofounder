#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
LIB="$DIR/../scripts/lib"

start_test "render emits snapshot with in-flight, ready, and tier sections"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state
from run_status_render import render_status_md
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
]
s = create_initial_state(modules)
s['modules']['M-001']['plan_status'] = 'planned'
s['modules']['M-001']['exec_status'] = 'merged'
s['modules']['M-002']['plan_status'] = 'planning'
s['inflight']['planners'] = ['M-002']
s['last_event_at'] = '2026-05-18T12:34:56Z'
md = render_status_md(s)
assert 'In-flight Planners: 1 / 3 cap' in md, md
assert 'M-002' in md
assert 'Tier 1:' in md
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "render_dag_mermaid emits classDef colors per status"
out=$(python3 -c "
import sys; sys.path.insert(0, '$LIB')
from run_state import create_initial_state
from run_status_render import render_dag_mermaid
modules = [
    {'id': 'M-001', 'deps': []},
    {'id': 'M-002', 'deps': ['M-001']},
]
s = create_initial_state(modules)
s['modules']['M-001']['exec_status'] = 'merged'
mm = render_dag_mermaid(s)
assert 'M-001:::merged' in mm, mm
assert 'M-002:::pending' in mm, mm
assert 'classDef merged' in mm
print('OK')
")
assert_stdout_contains "OK" "$out"

summary
