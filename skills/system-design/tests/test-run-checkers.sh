#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/run-checkers.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# Helper to write a minimum-valid PRD bundle (passes all 14 checkers)
write_minimal_valid_prd() {
    write_file "README.md" "# Test PRD"
    write_file "architecture.md" "# Architecture index"
}

test_case "exit 0 + PASS on minimal-valid PRD"
setup_fixture
write_minimal_valid_prd
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "PASS line includes checker count"
setup_fixture
write_minimal_valid_prd
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "formal-review checker(s)"
teardown_fixture

test_case "exit 1 + FOUND with aggregated JSON on bad PRD"
setup_fixture
write_file "README.md" "# TODO: write product overview"
write_file "features/F-002-x.md" '---
id: F-002
title: x
status: draft
---

# x
'
write_file "journeys/J-001-y.md" '---
id: J-001
title: y
persona: z
---
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "FOUND"
assert_stdout_contains "issues"
assert_stdout_contains "criterion_id"
teardown_fixture

test_case "aggregates findings from multiple checkers"
setup_fixture
write_file "README.md" "TODO: x"
write_file "features/F-002-x.md" '---
id: F-002
title: x
status: draft
---

# title
'
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1"
# Should contain findings from both check-readme (CR-SD03) and check-feature (CR-SD04 + CR-SD06F)
echo "$LAST_STDOUT" | grep -q "CR-SD03" && _record_pass || _record_fail "missing CR-SD03"
echo "$LAST_STDOUT" | grep -q "CR-SD04\|CR-SD06F" && _record_pass || _record_fail "missing CR-SD04/PP15F"
teardown_fixture

test_case "phase gates excluded from dispatch"
# run-checkers.sh should NOT invoke check-review-readiness or check-revise-completeness
# (those have different argument shapes and orchestration semantics).
setup_fixture
write_minimal_valid_prd
run_command "$CHECK" "$FIXTURE"
# Phase-gate scripts would normally fail with "missing round arg" and
# emit a script error. If they were dispatched, we'd see exit 2.
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "phase gates leaked into dispatch (exit=$LAST_EXIT)"
teardown_fixture

test_case "idempotent — same input → identical output"
setup_fixture
write_file "README.md" "TODO: x"
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
