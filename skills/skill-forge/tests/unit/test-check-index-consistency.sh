#!/usr/bin/env bash
# test-check-index-consistency.sh — unit tests for check-index-consistency.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Positive: skill-forge has no index.md -> exit 0 with [] ---
OUTPUT=$("${SCRIPTS_DIR}/check-index-consistency.sh" "$SKILL_ROOT")
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && [ "$OUTPUT" = "[]" ]; then
  pass "skill-forge (no index.md) -> exit 0 with []"
else
  fail "skill-forge should exit 0 with []; got exit=$EXIT_CODE output=$OUTPUT"
fi

# --- Positive: index-test fixture with all files listed -> exit 0 ---
FIXTURE="${FIXTURES_DIR}/index-test"
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-index-consistency.sh" "$FIXTURE" 2>/dev/null)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "index-test (all files listed) -> exit 0"
else
  fail "index-test should exit 0; got $EXIT_CODE; output: $OUTPUT"
fi

# --- Negative: index.md with missing file link -> exit 1 ---
TMPDIR_IDX=$(mktemp -d)
cat > "${TMPDIR_IDX}/index.md" << 'EOF'
# Index
- [Missing](missing.md)
EOF
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-index-consistency.sh" "$TMPDIR_IDX" 2>/dev/null)
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_IDX"
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "index.md with missing linked file -> exit 1"
else
  fail "index.md with missing link should exit 1; got $EXIT_CODE"
fi

# --- Negative: directory has unlisted .md file -> exit 1 ---
TMPDIR_UNLIST=$(mktemp -d)
cat > "${TMPDIR_UNLIST}/index.md" << 'EOF'
# Index
- [Alpha](alpha.md)
EOF
touch "${TMPDIR_UNLIST}/alpha.md"
touch "${TMPDIR_UNLIST}/unlisted.md"
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-index-consistency.sh" "$TMPDIR_UNLIST" 2>/dev/null)
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_UNLIST"
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "directory with unlisted .md file -> exit 1"
else
  fail "unlisted .md should exit 1; got $EXIT_CODE"
fi

# --- Negative: non-existent dir -> exit 2 ---
set +e
"${SCRIPTS_DIR}/check-index-consistency.sh" "/nonexistent" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent dir -> exit 2"
else
  fail "non-existent dir should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
