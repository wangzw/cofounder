#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-verdict.sh"

GOOD='round: 1
delivery_id: 1
verdict: progressing
next_action: revise
evidence:
  total_issues: 5
  new_count: 2
  error_count: 1
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 when no verdict files"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 for well-formed verdict"
setup_fixture
write_file ".review/round-1/verdict.yml" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-VD01: invalid verdict value"
setup_fixture
write_file ".review/round-1/verdict.yml" 'round: 1
delivery_id: 1
verdict: bogus
next_action: revise
evidence:
  x: 1
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "verdict"
teardown_fixture

test_case "CR-VD02: verdict / next_action mismatch"
setup_fixture
write_file ".review/round-1/verdict.yml" 'round: 1
delivery_id: 1
verdict: converged
next_action: revise
evidence:
  x: 1
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-VD02"
teardown_fixture

test_case "CR-VD01: missing evidence block"
setup_fixture
write_file ".review/round-1/verdict.yml" 'round: 1
delivery_id: 1
verdict: progressing
next_action: revise
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "evidence"
teardown_fixture

end_tests
