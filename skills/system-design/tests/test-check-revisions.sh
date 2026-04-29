#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-revisions.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + PASS when REVISIONS.md absent"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-RV01: dangling Previous Version path"
setup_fixture
write_file "REVISIONS.md" '# Revisions
Previous Version: ../nonexistent-prd-2025-01-01
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-RV01"
assert_stdout_contains "does not resolve"
teardown_fixture

test_case "exit 0 when Previous Version path resolves"
mkdir -p /tmp/test-prev
setup_fixture
write_file "REVISIONS.md" "# Revisions
Previous Version: /tmp/test-prev
"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture
rm -rf /tmp/test-prev

test_case "CR-SD03: TODO in REVISIONS"
setup_fixture
write_file "REVISIONS.md" "# Revisions
TODO: write the v2 changelog
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD03"
teardown_fixture

end_tests
