#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/prepare-input.sh"

test_case "rejects unknown --dir-mode value"
setup_fixture
mkdir -p "$FIXTURE/.review"
run_command "$CHECK" --dir-mode bogus "some prompt" "$FIXTURE/.review"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
teardown_fixture

test_case "writes input.md and input-meta.yml in default round-0 subdir"
setup_fixture
mkdir -p "$FIXTURE/.review"
run_command "$CHECK" "Build a todo list app" "$FIXTURE/.review"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-0/input.md" ] && _record_pass || _record_fail "input.md not written"
[ -f "$FIXTURE/.review/round-0/input-meta.yml" ] && _record_pass || _record_fail "input-meta.yml not written"
teardown_fixture

test_case "input.md preserves user prompt text"
setup_fixture
mkdir -p "$FIXTURE/.review"
run_command "$CHECK" "Make a calorie tracker" "$FIXTURE/.review"
grep -q "calorie tracker" "$FIXTURE/.review/round-0/input.md" && _record_pass || _record_fail "prompt missing from input.md"
teardown_fixture

test_case "honors --bootstrap-subdir flag"
setup_fixture
mkdir -p "$FIXTURE/.review"
run_command "$CHECK" --bootstrap-subdir round-5 "Update v2" "$FIXTURE/.review"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-5/input.md" ] && _record_pass || _record_fail "input.md not in round-5"
[ ! -f "$FIXTURE/.review/round-0/input.md" ] && _record_pass || _record_fail "should not write to round-0"
teardown_fixture

test_case "input-meta.yml records metadata fields"
setup_fixture
mkdir -p "$FIXTURE/.review"
run_command "$CHECK" "A relatively short prompt" "$FIXTURE/.review"
grep -q "word_count:" "$FIXTURE/.review/round-0/input-meta.yml" && _record_pass || _record_fail "word_count missing"
teardown_fixture

test_case "reads stdin when prompt is '-'"
setup_fixture
mkdir -p "$FIXTURE/.review"
echo "Build a habit tracker via stdin" | "$CHECK" - "$FIXTURE/.review" >/dev/null 2>&1
ec=$?
[ "$ec" = "0" ] && _record_pass || _record_fail "expected 0 got $ec"
grep -q "habit tracker" "$FIXTURE/.review/round-0/input.md" && _record_pass || _record_fail "stdin prompt missing"
teardown_fixture

end_tests
