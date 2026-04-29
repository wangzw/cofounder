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
grep -q "char_count:" "$FIXTURE/.review/round-0/input-meta.yml" && _record_pass || _record_fail "char_count missing"
teardown_fixture

test_case "CJK input: word_count includes Chinese characters (not whitespace-only)"
# Real-world bug: a 3000+ Chinese-character input produced word_count=65 because
# Python's str.split() only counts whitespace-delimited tokens, and Chinese has
# no inter-word spaces. That tripped glossary-probe's sparse_input threshold
# (< 50) on inputs that were demonstrably substantial.
setup_fixture
mkdir -p "$FIXTURE/.review"
# A 200-character Chinese paragraph (no whitespace between characters)
chinese_text="多agent的设计现在看来是错误的。和人类社会不同，人类社会中一个人就是一个实实在在的人，他的大脑是不能分离的，他的大脑也不能复制，当一个人被占用做一件事情的时候，那这个人确实就被占用了。所以在人类社会中人需要合作但代价是沟通的成本是巨大的。"
run_command "$CHECK" "$chinese_text" "$FIXTURE/.review"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
# word_count should be > 50 (the sparse_input threshold), reflecting actual content density
wc=$(grep "^word_count:" "$FIXTURE/.review/round-0/input-meta.yml" | awk '{print $2}')
[ "$wc" -gt 50 ] && _record_pass || _record_fail "word_count $wc should be > 50 for ~120-char Chinese input"
# char_count should match the actual character length
cc=$(grep "^char_count:" "$FIXTURE/.review/round-0/input-meta.yml" | awk '{print $2}')
[ "$cc" -gt 100 ] && _record_pass || _record_fail "char_count $cc should be > 100 for the test input"
teardown_fixture

test_case "Mixed CJK + ASCII counted correctly"
setup_fixture
mkdir -p "$FIXTURE/.review"
mixed="Build a 多任务系统 with 规划者 and 实施者 roles."
run_command "$CHECK" "$mixed" "$FIXTURE/.review"
wc=$(grep "^word_count:" "$FIXTURE/.review/round-0/input-meta.yml" | awk '{print $2}')
# 7 ASCII tokens + 9 CJK characters = 16
[ "$wc" -ge 14 ] && _record_pass || _record_fail "mixed word_count $wc should reflect both ASCII and CJK"
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
