#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-readme.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "CR-PP01: missing README.md"
setup_fixture
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP01"
assert_stdout_contains "missing"
teardown_fixture

test_case "exit 0 when README exists with no leaves"
setup_fixture
write_file "README.md" "# Test PRD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PP03: leaf not referenced"
setup_fixture
write_file "README.md" "# Test PRD
no links here
"
write_file "features/F-001-x.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP03"
assert_stdout_contains "F-001-x.md not referenced"
teardown_fixture

test_case "CR-PP03: dangling README link"
setup_fixture
write_file "README.md" "# Test PRD
- [F-099-missing](features/F-099-missing.md)
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP03"
assert_stdout_contains "does not resolve"
teardown_fixture

test_case "exit 0 with both directions matching"
setup_fixture
write_file "README.md" "# Test PRD
- [J-001](journeys/J-001-x.md)
- [F-001](features/F-001-x.md)
"
write_file "journeys/J-001-x.md" "stub"
write_file "features/F-001-x.md" "stub"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PP04: TODO marker in README"
setup_fixture
write_file "README.md" "# Test PRD
TODO: write product overview
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP04"
teardown_fixture

end_tests
