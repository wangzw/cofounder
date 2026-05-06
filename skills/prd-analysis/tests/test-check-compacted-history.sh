#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-compacted-history.sh"

GOOD='---
delivery_id: 1
final_round: 5
compacted_rounds:
  - 1
  - 2
  - 3
  - 4
compacted_round_count: 4
total_issues_seen: 12
generated_at: 2026-05-01T10:00:00Z
aggregate_state_counts:
  fixed_count: 8
---

# Delivery 1 — Compacted Review History
x
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 when no compacted-history.md exists"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 for well-formed file"
setup_fixture
write_file ".review/round-5/compacted-history.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-CH01: missing delivery_id"
setup_fixture
BAD=$(printf '%s' "$GOOD" | sed '/delivery_id:/d')
write_file ".review/round-5/compacted-history.md" "$BAD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "delivery_id"
teardown_fixture

test_case "CR-CH01: missing final_round"
setup_fixture
BAD=$(printf '%s' "$GOOD" | sed '/^final_round:/d')
write_file ".review/round-5/compacted-history.md" "$BAD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "final_round"
teardown_fixture

test_case "CR-CH01: missing generated_at"
setup_fixture
BAD=$(printf '%s' "$GOOD" | sed '/^generated_at:/d')
write_file ".review/round-5/compacted-history.md" "$BAD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "generated_at"
teardown_fixture

test_case "CR-CH02: file under wrong round directory"
setup_fixture
write_file ".review/round-3/compacted-history.md" "$GOOD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-CH02"
teardown_fixture

test_case "CR-CH01: missing frontmatter block"
setup_fixture
write_file ".review/round-5/compacted-history.md" "no frontmatter here"
assert_exit 1 "$CHECK" "$FIXTURE"
teardown_fixture

end_tests
