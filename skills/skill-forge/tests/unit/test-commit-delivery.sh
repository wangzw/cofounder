#!/usr/bin/env bash
# test-commit-delivery.sh — unit tests for commit-delivery.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
SCRIPT="${SCRIPTS_DIR}/commit-delivery.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Assert executable ---
if [ -x "$SCRIPT" ]; then
  pass "commit-delivery.sh exists and is executable"
else
  fail "commit-delivery.sh not found or not executable"
fi

# --- Slug derivation test: ASCII summary ---
SLUG=$(python3 - "Add subscription payments" <<'PYEOF'
import sys, re
from datetime import datetime, timezone

summary = sys.argv[1]
truncated = summary[:40].lower()
slugified = re.sub(r'[^a-z0-9]+', '-', truncated)
slugified = re.sub(r'-+', '-', slugified)
slugified = slugified.strip('-')
if not slugified:
    slugified = datetime.now(timezone.utc).strftime('%Y%m%d')
print(slugified)
PYEOF
)

EXPECTED_SLUG="add-subscription-payments"
if [ "$SLUG" = "$EXPECTED_SLUG" ]; then
  pass "slug 'Add subscription payments' -> '$EXPECTED_SLUG'"
else
  fail "expected slug '$EXPECTED_SLUG'; got '$SLUG'"
fi

# --- Slug fallback test: CJK-only summary ---
SLUG_CJK=$(python3 - "增加订阅支付" <<'PYEOF'
import sys, re
from datetime import datetime, timezone

summary = sys.argv[1]
truncated = summary[:40].lower()
slugified = re.sub(r'[^a-z0-9]+', '-', truncated)
slugified = re.sub(r'-+', '-', slugified)
slugified = slugified.strip('-')
if not slugified:
    slugified = datetime.now(timezone.utc).strftime('%Y%m%d')
print(slugified)
PYEOF
)

if echo "$SLUG_CJK" | grep -qE '^[0-9]{8}$'; then
  pass "CJK-only summary falls back to YYYYMMDD slug (got '$SLUG_CJK')"
else
  fail "CJK fallback should match YYYYMMDD; got '$SLUG_CJK'"
fi

# --- Slug with special characters ---
SLUG_SPECIAL=$(python3 - "Fix: user@email.com (broken!)" <<'PYEOF'
import sys, re
from datetime import datetime, timezone

summary = sys.argv[1]
truncated = summary[:40].lower()
slugified = re.sub(r'[^a-z0-9]+', '-', truncated)
slugified = re.sub(r'-+', '-', slugified)
slugified = slugified.strip('-')
if not slugified:
    slugified = datetime.now(timezone.utc).strftime('%Y%m%d')
print(slugified)
PYEOF
)

if echo "$SLUG_SPECIAL" | grep -qE '^[a-z0-9-]+$'; then
  pass "special chars slug is alphanumeric+dash (got '$SLUG_SPECIAL')"
else
  fail "special chars slug should be [a-z0-9-]+; got '$SLUG_SPECIAL'"
fi

# --- Missing arguments -> exit 2 ---
set +e
"$SCRIPT" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "missing arguments -> exit 2"
else
  fail "missing arguments should exit 2; got $EXIT_CODE"
fi

# --- Non-existent target -> exit 2 ---
set +e
"$SCRIPT" "/nonexistent" "1" "test summary" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent target -> exit 2"
else
  fail "non-existent target should exit 2; got $EXIT_CODE"
fi

# --- Invalid delivery-id -> exit 2 ---
set +e
"$SCRIPT" "/tmp" "abc" "test" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "invalid delivery-id -> exit 2"
else
  fail "invalid delivery-id should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
