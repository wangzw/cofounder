#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-review-readiness.sh"

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

ISSUE_FIXED=$(printf '%s' "$ISSUE_NEW" | sed 's/state: new/state: fixed/' | sed 's/created_in_round: 1/created_in_round: 1\nfixed_in_round: 2/')

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-prd-dir-xyz"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + READY when no .review history"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "READY"
teardown_fixture

test_case "exit 0 + READY when .review exists but no rounds"
setup_fixture
mkdir -p "$FIXTURE/.review"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "READY"
teardown_fixture

test_case "exit 0 + READY when all issues are fixed"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_FIXED"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "READY"
teardown_fixture

test_case "exit 1 + NOT_READY when prior round has state:new"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "NOT_READY"
assert_stdout_contains "I-001"
teardown_fixture

test_case "counts multiple state:new issues across rounds"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
write_file ".review/round-1/issues/I-002.md" "$(printf '%s' "$ISSUE_NEW" | sed 's/I-001/I-002/')"
write_file ".review/round-2/issues/I-003.md" "$(printf '%s' "$ISSUE_NEW" | sed 's/I-001/I-003/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "3 issue(s)"
teardown_fixture

test_case "exit 2 on issue file with bad frontmatter"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "no frontmatter"
assert_exit 2 "$CHECK" "$FIXTURE"
teardown_fixture

end_tests
