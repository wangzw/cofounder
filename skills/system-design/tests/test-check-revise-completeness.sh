#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-revise-completeness.sh"

ISSUE_NEW='---
id: I-001
criterion_id: CR-PP01
file: README.md
severity: error
state: new
created_in_round: 1
---

## Description
x

## Suggested fix
y
'

ISSUE_FIXED=$(printf '%s' "$ISSUE_NEW" | sed 's/state: new/state: fixed/')

test_case "exit 2 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on missing round arg"
setup_fixture
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 2 on non-numeric round"
setup_fixture
run_command "$CHECK" "$FIXTURE" "not-a-number"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 2 when round dir does not exist"
setup_fixture
run_command "$CHECK" "$FIXTURE" "5"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 0 + COMPLETE when round has no issues"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1"
assert_exit 0 "$CHECK" "$FIXTURE" "1"
assert_stdout_contains "COMPLETE"
teardown_fixture

test_case "exit 0 + COMPLETE when all issues left state:new"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_FIXED"
assert_exit 0 "$CHECK" "$FIXTURE" "1"
assert_stdout_contains "COMPLETE"
teardown_fixture

test_case "exit 1 + INCOMPLETE when issue still in state:new"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 1 "$CHECK" "$FIXTURE" "1"
assert_stdout_contains "INCOMPLETE"
assert_stdout_contains "I-001"
teardown_fixture

test_case "scoped to current round only — prior round state:new ignored"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
write_file ".review/round-2/issues/I-002.md" "$ISSUE_FIXED"
assert_exit 0 "$CHECK" "$FIXTURE" "2"
assert_stdout_contains "COMPLETE"
teardown_fixture

end_tests
