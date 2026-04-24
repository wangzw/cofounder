#!/usr/bin/env bash
# test-check-changelog-consistency.sh — unit tests for check-changelog-consistency.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Positive: skill-forge (no CHANGELOG, no .review/versions) -> exit 0 with [] ---
OUTPUT=$("${SCRIPTS_DIR}/check-changelog-consistency.sh" "$SKILL_ROOT")
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && [ "$OUTPUT" = "[]" ]; then
  pass "no CHANGELOG/versions -> exit 0 with []"
else
  fail "no CHANGELOG/versions should exit 0 with []; got exit=$EXIT_CODE output=$OUTPUT"
fi

# --- Positive: changelog-test fixture (aligned) -> exit 0 ---
FIXTURE="${FIXTURES_DIR}/changelog-test"
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-changelog-consistency.sh" "$FIXTURE" 2>/dev/null)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "aligned CHANGELOG/versions -> exit 0"
else
  fail "aligned changelog should exit 0; got $EXIT_CODE; output: $OUTPUT"
fi

# --- Negative: CHANGELOG has entry but version file missing -> exit 1 ---
TMPDIR_MISS=$(mktemp -d)
mkdir -p "${TMPDIR_MISS}/.review/versions"
cat > "${TMPDIR_MISS}/CHANGELOG.md" << 'EOF'
# Changelog
## Delivery 1 — First
## Delivery 2 — Second
EOF
cat > "${TMPDIR_MISS}/.review/versions/1.md" << 'EOF'
delivery_id: 1
EOF
# No 2.md
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-changelog-consistency.sh" "$TMPDIR_MISS" 2>/dev/null)
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_MISS"
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "CHANGELOG entry without version file -> exit 1"
else
  fail "missing version file should exit 1; got $EXIT_CODE"
fi

# --- Negative: version file without CHANGELOG entry -> exit 1 ---
TMPDIR_EXTRA=$(mktemp -d)
mkdir -p "${TMPDIR_EXTRA}/.review/versions"
cat > "${TMPDIR_EXTRA}/CHANGELOG.md" << 'EOF'
# Changelog
## Delivery 1 — First
EOF
cat > "${TMPDIR_EXTRA}/.review/versions/1.md" << 'EOF'
delivery_id: 1
EOF
cat > "${TMPDIR_EXTRA}/.review/versions/2.md" << 'EOF'
delivery_id: 2
EOF
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-changelog-consistency.sh" "$TMPDIR_EXTRA" 2>/dev/null)
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_EXTRA"
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "version file without CHANGELOG entry -> exit 1"
else
  fail "orphan version file should exit 1; got $EXIT_CODE"
fi

# --- Negative: non-monotonic delivery IDs -> exit 1 ---
TMPDIR_GAP=$(mktemp -d)
mkdir -p "${TMPDIR_GAP}/.review/versions"
cat > "${TMPDIR_GAP}/CHANGELOG.md" << 'EOF'
# Changelog
## Delivery 1 — First
## Delivery 3 — Third (gap)
EOF
cat > "${TMPDIR_GAP}/.review/versions/1.md" << 'EOF'
delivery_id: 1
EOF
cat > "${TMPDIR_GAP}/.review/versions/3.md" << 'EOF'
delivery_id: 3
EOF
set +e
OUTPUT=$("${SCRIPTS_DIR}/check-changelog-consistency.sh" "$TMPDIR_GAP" 2>/dev/null)
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_GAP"
if [ "$EXIT_CODE" -eq 1 ]; then
  pass "non-monotonic delivery IDs (gap) -> exit 1"
else
  fail "delivery ID gap should exit 1; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
