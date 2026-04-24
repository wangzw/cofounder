#!/usr/bin/env bash
# test-build-depgraph.sh — unit tests for build-depgraph.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

cleanup() {
  rm -rf "${FIXTURES_DIR}/wikilink-test/.review"
}
trap cleanup EXIT

# --- Positive: smoke test against skill-forge itself ---
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TMPDIR_REVIEW=$(mktemp -d)
# Run on temp dir so we don't litter the repo
set +e
"${SCRIPTS_DIR}/build-depgraph.sh" "$SKILL_ROOT" round-99 >/dev/null 2>&1
EXIT_CODE=$?
set -e
# Clean up
rm -rf "${SKILL_ROOT}/.review/round-99"
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "build-depgraph.sh runs against skill-forge (exit 0)"
else
  fail "build-depgraph.sh should exit 0; got $EXIT_CODE"
fi

# --- Positive: wikilink fixture -> graph contains edge ---
FIXTURE="${FIXTURES_DIR}/wikilink-test"
set +e
"${SCRIPTS_DIR}/build-depgraph.sh" "$FIXTURE" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e
DEPGRAPH="${FIXTURE}/.review/round-1/depgraph.yml"
if [ "$EXIT_CODE" -eq 0 ] && [ -f "$DEPGRAPH" ]; then
  pass "wikilink fixture -> depgraph.yml written (exit 0)"
else
  fail "wikilink fixture should produce depgraph.yml (exit $EXIT_CODE)"
fi

# Check the graph contains the SKILL.md entry
if grep -q '"SKILL.md"' "$DEPGRAPH" 2>/dev/null; then
  pass "depgraph.yml contains SKILL.md entry"
else
  fail "depgraph.yml should contain SKILL.md entry"
fi

# Check the graph contains the wikilink edge to common/config.md
if grep -q '"common/config.md"' "$DEPGRAPH" 2>/dev/null; then
  pass "depgraph.yml contains wikilink edge to common/config.md"
else
  fail "depgraph.yml should show edge from SKILL.md to common/config.md"
fi

# Check generated_at field present
if grep -q '^generated_at:' "$DEPGRAPH" 2>/dev/null; then
  pass "depgraph.yml has generated_at field"
else
  fail "depgraph.yml missing generated_at field"
fi

# --- Negative: non-existent target -> exit 2 ---
set +e
"${SCRIPTS_DIR}/build-depgraph.sh" "/nonexistent" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent target -> exit 2"
else
  fail "non-existent target should exit 2; got $EXIT_CODE"
fi

# --- Negative: missing round argument -> exit 2 ---
set +e
"${SCRIPTS_DIR}/build-depgraph.sh" "$FIXTURE" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "missing round arg -> exit 2"
else
  fail "missing round arg should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
