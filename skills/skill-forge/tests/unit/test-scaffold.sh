#!/usr/bin/env bash
# test-scaffold.sh — unit tests for scaffold.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
SCAFFOLD="${SCRIPTS_DIR}/scaffold.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Assert script exists and is executable ---
if [ -x "$SCAFFOLD" ]; then
  pass "scaffold.sh exists and is executable"
else
  fail "scaffold.sh not found or not executable at $SCAFFOLD"
fi

# --- --help contains "variant" ---
HELP_OUTPUT=$("$SCAFFOLD" --help 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -q 'variant'; then
  pass "--help output contains 'variant'"
else
  fail "--help should contain 'variant'"
fi

# --- Unknown variant -> exit 2 with clear error ---
set +e
OUTPUT=$("$SCAFFOLD" "unknownvariant" "/tmp/test-scaffold-target" "/dev/null" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "unknown variant -> exit 2"
else
  fail "unknown variant should exit 2; got $EXIT_CODE"
fi
if echo "$OUTPUT" | grep -qi 'unknown variant\|must be one of'; then
  pass "unknown variant error message is clear"
else
  fail "unknown variant error should mention variant; got: $OUTPUT"
fi

# --- Non-existent skeleton path -> exit 2 ---
# 'document' variant skeleton doesn't exist yet (Phase 7)
SKILL_FORGE_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
SKEL_DIR="${SKILL_FORGE_DIR}/common/skeleton/document"
if [ ! -d "$SKEL_DIR" ]; then
  set +e
  OUTPUT=$("$SCAFFOLD" "document" "/tmp/test-scaffold-doc-target" "/dev/null" 2>&1)
  EXIT_CODE=$?
  set -e
  if [ "$EXIT_CODE" -eq 2 ]; then
    pass "non-existent skeleton -> exit 2"
  else
    fail "non-existent skeleton should exit 2; got $EXIT_CODE"
  fi
  if echo "$OUTPUT" | grep -qi 'not yet implemented\|skeleton'; then
    pass "non-existent skeleton error message is clear"
  else
    fail "non-existent skeleton error should mention skeleton; got: $OUTPUT"
  fi
else
  pass "skeleton/document exists — non-existent test skipped (Phase 7 complete)"
  pass "non-existent skeleton error message skipped"
fi

# --- Missing arguments -> exit 2 ---
set +e
"$SCAFFOLD" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "missing arguments -> exit 2"
else
  fail "missing arguments should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
