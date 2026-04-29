#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-self-review.sh"

GOOD='# Self-Review — R3-W-001

## Checklist

- CR-PP06 traceability-chain: PASS
- CR-PP14 self-containment: PASS

## Summary

FULL_PASS: yes
fail_count: 0
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 + PASS when no self-review files"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 + PASS for well-formed self-review"
setup_fixture
write_file ".review/round-1/self-reviews/R1-W-001.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-SR01: missing Checklist section"
setup_fixture
write_file ".review/round-1/self-reviews/R1-W-001.md" "## Summary
FULL_PASS: yes
fail_count: 0
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "Checklist"
teardown_fixture

test_case "CR-SR02: FAIL row without blocker_scope"
setup_fixture
write_file ".review/round-1/self-reviews/R1-W-001.md" '## Checklist
- CR-PP06 x: FAIL — note: bad

## Summary
FULL_PASS: no
fail_count: 1
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "blocker_scope"
teardown_fixture

test_case "CR-SR02: FAIL row with invalid blocker_scope"
setup_fixture
write_file ".review/round-1/self-reviews/R1-W-001.md" '## Checklist
- CR-PP06 x: FAIL — blocker_scope: bogus — note: bad

## Summary
FULL_PASS: no
fail_count: 1
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "bogus"
teardown_fixture

test_case "CR-SR03: FULL_PASS=yes but FAIL row present"
setup_fixture
write_file ".review/round-1/self-reviews/R1-W-001.md" '## Checklist
- CR-PP06 x: FAIL — blocker_scope: input-ambiguity — note: x

## Summary
FULL_PASS: yes
fail_count: 0
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SR03"
teardown_fixture

end_tests
