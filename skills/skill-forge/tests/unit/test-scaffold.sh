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

# --- Build a minimal valid clarification.yml fixture for the substitution
# tests below. scaffold.sh requires four flat top-level keys per 91e1472 #4.
TMP_FIXTURE=$(mktemp -d)
trap "rm -rf $TMP_FIXTURE" EXIT
cat > "$TMP_FIXTURE/clarification.yml" <<'EOF'
SKILL_NAME: "test-skill"
SKILL_VERSION: "0.1.0"
SKILL_DESCRIPTION: "Use when testing scaffold.sh idempotency."
ARTIFACT_ROOT: "docs/raw/test/"
EOF

# --- Regression for 91e1472 #4: missing flat placeholder keys → fail-fast ---
# scaffold.sh's parse_yaml_simple only reads top-level flat `KEY: "val"` lines.
# A clarification.yml that puts SKILL_NAME under nested
# `normalized_requirements.R-001.value` would leave the {{SKILL_NAME}} marker
# un-substituted in the scaffolded SKILL.md. The fix requires the four keys
# at the top level and aborts if any is missing.
NESTED_BAD=$(mktemp)
cat > "$NESTED_BAD" <<'EOF'
clarification_at: "2026-04-25T00:00:00Z"
normalized_requirements:
  R-001:
    value: "test-skill"
    status: confirmed
EOF
TARGET_NESTED="$TMP_FIXTURE/target-nested-bad"
set +e
OUTPUT=$("$SCAFFOLD" document "$TARGET_NESTED" "$NESTED_BAD" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -ne 0 ]; then
  pass "missing flat placeholder keys → fail-fast (91e1472 #4)"
else
  fail "scaffold should fail-fast when SKILL_NAME/etc. missing from top-level (91e1472 #4 regression). Got exit 0 with output: $OUTPUT"
fi
if echo "$OUTPUT" | grep -qi 'SKILL_NAME\|placeholder\|clarification\|missing'; then
  pass "missing flat keys error message references the missing field (91e1472 #4)"
else
  fail "missing flat keys error should reference SKILL_NAME or 'placeholder' or 'missing'; got: $OUTPUT"
fi
rm -f "$NESTED_BAD"

# --- Regression for 04f3c9d: scaffold.sh idempotent on re-run ---
# A second invocation against an already-scaffolded target should succeed
# (sha-stable files); only drift would error. Earlier the script unconditionally
# refused if the target dir existed.
TARGET_IDEM="$TMP_FIXTURE/target-idempotent"
"$SCAFFOLD" document "$TARGET_IDEM" "$TMP_FIXTURE/clarification.yml" >/dev/null 2>&1 \
  && pass "first scaffold run succeeds" \
  || fail "first scaffold run failed unexpectedly"
set +e
OUTPUT=$("$SCAFFOLD" document "$TARGET_IDEM" "$TMP_FIXTURE/clarification.yml" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "scaffold idempotent on re-run (04f3c9d)"
else
  fail "second scaffold run should succeed when no drift; got exit $EXIT_CODE: $OUTPUT"
fi

# --- Regression for 91e1472 #3: target with only .review/ treated as fresh ---
# prepare-input.sh writes to <target>/.review/round-0/ BEFORE scaffold.sh runs.
# Earlier scaffold.sh would see the existing target dir and refuse with a
# spurious drift error. The fix: count skeleton-relative files; if zero, treat
# as a fresh-scaffold and copy the skeleton in normally.
TARGET_FRESH="$TMP_FIXTURE/target-only-review"
mkdir -p "$TARGET_FRESH/.review/round-0"
echo "input" > "$TARGET_FRESH/.review/round-0/input.md"
set +e
OUTPUT=$("$SCAFFOLD" document "$TARGET_FRESH" "$TMP_FIXTURE/clarification.yml" 2>&1)
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "target with only .review/ treated as fresh scaffold (91e1472 #3)"
else
  fail "target with only .review/ should scaffold cleanly; got exit $EXIT_CODE: $OUTPUT"
fi
# Verify the skeleton landed AND the prepare-input artifact survived.
if [ -f "$TARGET_FRESH/SKILL.md" ] && [ -f "$TARGET_FRESH/.review/round-0/input.md" ]; then
  pass "fresh-scaffold preserves prior .review/ contents (91e1472 #3)"
else
  fail "fresh-scaffold should preserve .review/ contents AND drop skeleton in"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
