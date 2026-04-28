#!/usr/bin/env bash
# test-criteria-references.sh — regression guard for the CR-L11 addition
# (round-6 reviewer-drift fix).
#
# Without this test, count references like "10 LLM-type criteria" or
# "CR-L01..CR-L10" can drift out of sync with the actual review-criteria.md
# entries when criteria are added, removed, or renamed. The round-6 audit
# surfaced exactly this class of drift; CR-L11 was added to formalize the
# pattern, but nothing else was guarding the documentation references.
#
# This test asserts:
#   1. SKILL.md `(N CR entries: M script + K LLM)` matches the actual count
#      from review-criteria.md.
#   2. cross-reviewer-subagent.md and review/index.md both cite the correct
#      CR-Lxx upper bound.
#   3. cross-reviewer-subagent.md prose count ("all N LLM-type criteria")
#      matches the actual LLM count.
#   4. No stale `CR-L01..CR-L10` references exist outside of historical
#      review-archive content (.review/) or test files.
#   5. CR-L11 specifically is present in main + the document skeleton
#      (forward regression guard for the round-6 fix).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."

LLM_COUNT=$(grep -c '^- id: CR-L' "$ROOT/common/review-criteria.md")
SCRIPT_COUNT=$(grep -c '^- id: CR-S' "$ROOT/common/review-criteria.md")
TOTAL=$((LLM_COUNT + SCRIPT_COUNT))

# Test 1: SKILL.md count line matches review-criteria.md
SKILL_LINE=$(grep -E '\([0-9]+ CR entries:.*script.*LLM\)' "$ROOT/SKILL.md" | head -1)
[ -n "$SKILL_LINE" ] || { echo "FAIL: SKILL.md missing '(N CR entries: M script + K LLM)' line"; exit 1; }
DECL_TOTAL=$(echo "$SKILL_LINE" | grep -oE '[0-9]+ CR entries' | grep -oE '[0-9]+')
DECL_SCRIPT=$(echo "$SKILL_LINE" | grep -oE '[0-9]+ script' | grep -oE '[0-9]+')
DECL_LLM=$(echo "$SKILL_LINE" | grep -oE '[0-9]+ LLM' | grep -oE '[0-9]+')
[ "$DECL_TOTAL" = "$TOTAL" ] \
  || { echo "FAIL: SKILL.md says '$DECL_TOTAL CR entries' but review-criteria.md has $TOTAL"; exit 1; }
[ "$DECL_SCRIPT" = "$SCRIPT_COUNT" ] \
  || { echo "FAIL: SKILL.md says '$DECL_SCRIPT script' but $SCRIPT_COUNT actual"; exit 1; }
[ "$DECL_LLM" = "$LLM_COUNT" ] \
  || { echo "FAIL: SKILL.md says '$DECL_LLM LLM' but $LLM_COUNT actual"; exit 1; }
echo "PASS: SKILL.md count line consistent ($TOTAL = $DECL_SCRIPT script + $DECL_LLM LLM)"

# Test 2: cross-reviewer-subagent.md and review/index.md cite the correct upper bound
for f in "$ROOT/review/cross-reviewer-subagent.md" "$ROOT/review/index.md"; do
  if ! grep -q "CR-L01\.\.CR-L${LLM_COUNT}\b" "$f"; then
    echo "FAIL: $(basename "$f") does not reference 'CR-L01..CR-L${LLM_COUNT}' (actual LLM count $LLM_COUNT)"
    exit 1
  fi
done
echo "PASS: cross-reviewer-subagent.md and review/index.md cite CR-L01..CR-L${LLM_COUNT}"

# Test 3: cross-reviewer-subagent.md prose count matches
PROSE_LLM=$(grep -oE '[0-9]+ LLM-type criteria' "$ROOT/review/cross-reviewer-subagent.md" | head -1 | grep -oE '[0-9]+')
[ "$PROSE_LLM" = "$LLM_COUNT" ] \
  || { echo "FAIL: cross-reviewer-subagent.md says '$PROSE_LLM LLM-type criteria' but $LLM_COUNT actual"; exit 1; }
echo "PASS: cross-reviewer-subagent.md prose count matches ($LLM_COUNT)"

# Test 4: stale CR-L01..CR-L10 references must not exist outside /.review/ + /tests/
STALE_HITS=$(grep -rn 'CR-L01\.\.CR-L10\b' "$ROOT" 2>/dev/null \
              | grep -v '/\.review/' \
              | grep -v '/tests/' \
              || true)
[ -z "$STALE_HITS" ] \
  || { echo "FAIL: stale 'CR-L01..CR-L10' references exist:"; echo "$STALE_HITS"; exit 1; }
echo "PASS: no stale CR-L01..CR-L10 references"

# Test 5: CR-L11 present in main + document skeleton
grep -q '^- id: CR-L11$' "$ROOT/common/review-criteria.md" \
  || { echo "FAIL: CR-L11 missing from main review-criteria.md"; exit 1; }
grep -q '^- id: CR-L11$' "$ROOT/common/skeleton/document/common/review-criteria.md" \
  || { echo "FAIL: CR-L11 missing from skeleton/document/common/review-criteria.md"; exit 1; }
echo "PASS: CR-L11 cross-reference-consistency present in main + document skeleton"

echo "=== PASS test-criteria-references.sh (5 sub-tests) ==="
