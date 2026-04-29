#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-round-index.sh"

GOOD='---
round: 1
delivery_id: 1
total_issues: 3
new_count: 1
fixed_count: 1
false_positive_count: 0
deferred_count: 1
superseded_count: 0
critical_count: 0
error_count: 2
warning_count: 1
info_count: 0
false_positive_ratio: 0.0
deferred_ratio: 0.333
recurrence_count: 0
justified_regressions_ok: true
---

# Round 1 Review Summary

x
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 when no index files"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 for well-formed index"
setup_fixture
write_file ".review/round-1/index.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-RI01: missing required field"
setup_fixture
write_file ".review/round-1/index.md" '---
round: 1
total_issues: 1
---

x
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "delivery_id"
teardown_fixture

test_case "CR-RI01: float field out of range"
setup_fixture
GOOD_BUT_BAD_RATIO=$(printf '%s' "$GOOD" | sed 's/false_positive_ratio: 0\.0/false_positive_ratio: 1.5/')
write_file ".review/round-1/index.md" "$GOOD_BUT_BAD_RATIO"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "false_positive_ratio"
teardown_fixture

test_case "CR-RI02: state counts do not sum to total"
setup_fixture
BAD=$(printf '%s' "$GOOD" | sed 's/total_issues: 3/total_issues: 99/')
write_file ".review/round-1/index.md" "$BAD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-RI02"
teardown_fixture

end_tests
