#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-architecture-index.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "CR-PP01 when neither architecture.md nor architecture/ exists"
setup_fixture
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP01"
teardown_fixture

test_case "exit 0 when architecture.md alone exists"
setup_fixture
write_file "architecture.md" "# Architecture index"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 0 when only architecture/ dir exists (no index)"
setup_fixture
write_file "architecture/tech-stack.md" "# Tech stack"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PP04: TODO in architecture.md"
setup_fixture
write_file "architecture.md" "# Index
TODO: link the topic files
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP04"
teardown_fixture

test_case "CR-PP03 warning when topic not linked from index"
setup_fixture
write_file "architecture.md" "# Architecture index"
write_file "architecture/tech-stack.md" "# Tech stack"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP03"
assert_stdout_contains "tech-stack.md"
teardown_fixture

end_tests
