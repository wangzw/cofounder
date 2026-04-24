#!/usr/bin/env bash
# test-extract-criteria.sh — unit tests for extract-criteria.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Positive: skill-forge itself has 24 criteria ---
OUTPUT=$("${SCRIPTS_DIR}/extract-criteria.sh" "$SKILL_ROOT")
COUNT=$(echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))")
if [ "$COUNT" -ge 24 ]; then
  pass "skill-forge criteria count >= 24 (got $COUNT)"
else
  fail "expected >= 24 criteria; got $COUNT"
fi

# --- Positive: output is valid JSON array ---
if echo "$OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,list)" 2>/dev/null; then
  pass "output is valid JSON array"
else
  fail "output is not valid JSON array"
fi

# --- Positive: first element has expected keys ---
KEYS=$(echo "$OUTPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
c=d[0]
required={'id','name','checker_type','severity'}
missing=required-set(c.keys())
print('missing:'+','.join(sorted(missing)) if missing else 'ok')
")
if [ "$KEYS" = "ok" ]; then
  pass "first criterion has required keys"
else
  fail "first criterion missing keys: $KEYS"
fi

# --- Negative: missing review-criteria.md -> exit 2 ---
TMPDIR_MISSING=$(mktemp -d)
mkdir -p "${TMPDIR_MISSING}/common"
set +e
"${SCRIPTS_DIR}/extract-criteria.sh" "$TMPDIR_MISSING" >/dev/null 2>&1
EXIT_CODE=$?
set -e
rm -rf "$TMPDIR_MISSING"
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "missing review-criteria.md -> exit 2"
else
  fail "missing review-criteria.md should exit 2; got $EXIT_CODE"
fi

# --- Negative: non-existent target dir -> exit 2 ---
set +e
"${SCRIPTS_DIR}/extract-criteria.sh" "/nonexistent/path" >/dev/null 2>&1
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
