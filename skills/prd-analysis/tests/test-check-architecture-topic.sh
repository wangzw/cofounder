#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-architecture-topic.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + PASS when no architecture/ dir"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 0 + PASS when topic has no placeholders"
setup_fixture
write_file "architecture/tech-stack.md" "# Tech stack
Frontend: React. Backend: Node.
"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PP04: TODO in topic file"
setup_fixture
write_file "architecture/tech-stack.md" "# Tech stack
TODO: choose database
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP04"
assert_stdout_contains "tech-stack.md"
teardown_fixture

end_tests
