#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-reviewer-output.sh"

GOOD='{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "category_applied": "module-boundary",
  "issues": [
    {
      "criterion_id": "CR-SD05",
      "file": "features/F-001.md",
      "severity": "error",
      "description": "missing traceability link to journey J-001",
      "suggested_fix": "add a touchpoint reference to J-001 in F-001 user-story"
    }
  ]
}'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 + PASS when no reviewer-output files"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 + PASS for well-formed reviewer output"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-RO01: invalid JSON"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{not json'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "invalid JSON"
teardown_fixture

test_case "CR-RO01: invalid reviewer_variant"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{"reviewer_variant": "bogus", "issues": []}'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "reviewer_variant"
teardown_fixture

test_case "CR-RO02: issue missing required field"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "issues": [
    {"criterion_id": "CR-SD05", "severity": "error"}
  ]
}'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "description"
teardown_fixture

test_case "CR-RO02: invalid severity"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "category_applied": "module-boundary",
  "issues": [
    {
      "criterion_id": "CR-SD05",
      "file": "x.md",
      "severity": "huge",
      "description": "longer than five chars",
      "suggested_fix": "longer than five chars"
    }
  ]
}'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "huge"
teardown_fixture

test_case "category_applied present passes"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "category_applied": "module-boundary",
  "issues": []
}'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "category_applied missing fails CR-RO02"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "issues": []
}'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "category_applied"
teardown_fixture

test_case "adversarial reviewer output with category_applied: meta passes"
setup_fixture
write_file ".review/round-1/reviewer-output/R1-V-002.json" '{
  "round": 1,
  "reviewer_variant": "adversarial",
  "trace_id": "R1-V-002",
  "scope_applied": "incremental",
  "category_applied": "meta",
  "issues": []
}'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
