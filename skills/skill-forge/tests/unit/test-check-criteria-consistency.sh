#!/usr/bin/env bash
# test-check-criteria-consistency.sh — unit tests for check-criteria-consistency.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Positive: skill-forge itself passes consistency ---
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-criteria-consistency.sh" "$SKILL_ROOT" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "skill-forge passes criteria consistency (exit 0)"
else
  fail "skill-forge should pass criteria consistency; got exit $EXIT_CODE; output: $OUTPUT"
fi

# --- Positive: output is empty array [] ---
CLEAN_OUTPUT=$("${SCRIPTS_DIR}/check-criteria-consistency.sh" "$SKILL_ROOT")
if [ "$CLEAN_OUTPUT" = "[]" ]; then
  pass "skill-forge outputs empty issues array"
else
  fail "skill-forge should output []; got: $CLEAN_OUTPUT"
fi

# --- Negative: mutual conflicts_with with different severities -> exit 1 with issue ---
FIXTURE="${FIXTURES_DIR}/consistency-test"
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-criteria-consistency.sh" "$FIXTURE" 2>/dev/null)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "mutual conflicts_with different severities -> exit 1"
else
  fail "mutual conflicts_with different severities should exit 1; got $EXIT_CODE"
fi
ISSUE_COUNT=$(echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))")
if [ "$ISSUE_COUNT" -ge 1 ]; then
  pass "mutual severity mismatch emits at least 1 issue"
else
  fail "expected at least 1 issue; got $ISSUE_COUNT"
fi

# --- Negative: non-existent dir -> exit 2 ---
set +e
"${SCRIPTS_DIR}/check-criteria-consistency.sh" "/nonexistent" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent dir -> exit 2"
else
  fail "non-existent dir should exit 2; got $EXIT_CODE"
fi

# --- Negative: bad-criteria fixture has invalid checker_type -> exit 1 ---
BAD_FIXTURE="${FIXTURES_DIR}/bad-criteria"
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-criteria-consistency.sh" "$BAD_FIXTURE" 2>/dev/null)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "bad-criteria (invalid checker_type) -> exit 1"
else
  fail "bad-criteria should exit 1; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
