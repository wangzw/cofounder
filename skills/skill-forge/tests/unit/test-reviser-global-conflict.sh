#!/usr/bin/env bash
# test-reviser-global-conflict.sh — regression guard for R7-V002-002.
#
# skill-forge had a self-contradiction: review/adversarial-reviewer-subagent.md
# attack angle #6 explicitly identifies "reviser instructed to fix
# blocker_scope: global-conflict in-place" as an anti-pattern, but the canonical
# revise/per-issue-reviser-subagent.md embodied that exact anti-pattern by
# instructing the reviser to "apply the fix as scoped to this leaf only" for
# global-conflict issues. Every skill scaffolded from skill-forge inherited
# this CR-L07 / CR-L11 violation; the prd-analysis round-7 review surfaced it.
#
# Fix: replace the in-place language with the canonical refuse + meta-issue +
# FAIL ACK pattern across all 5 copies (main + 4 skeleton variants).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."

ANTI_PATTERN_PHRASES=(
  "apply the fix as scoped to this leaf only"
  "apply the fix scoped to this leaf only"
)
REQUIRED_PHRASES=(
  "global-conflict"
  "CR-META-skip-violation"
  "global-conflict-requires-cross-artifact-pass"
)

check_file() {
  local f="$1"
  local label="$2"
  for phrase in "${ANTI_PATTERN_PHRASES[@]}"; do
    if grep -q "$phrase" "$f"; then
      echo "FAIL: $label still contains anti-pattern: '$phrase'"
      grep -n "$phrase" "$f"
      exit 1
    fi
  done
  for phrase in "${REQUIRED_PHRASES[@]}"; do
    if ! grep -q "$phrase" "$f"; then
      echo "FAIL: $label missing required phrase: '$phrase'"
      exit 1
    fi
  done
  echo "PASS: $label uses canonical refuse + meta-issue + FAIL ACK pattern"
}

# Test 1: skill-forge main
check_file "$ROOT/revise/per-issue-reviser-subagent.md" "skill-forge main"

# Test 2-5: each skeleton variant
for v in code document hybrid schema; do
  check_file "$ROOT/common/skeleton/$v/revise/per-issue-reviser-subagent.md" "skeleton/$v"
done

# Test 6: skill-forge adversarial-reviewer attack angle #6 still references
# the same anti-pattern (so the contract stays self-consistent: per-issue-
# reviser refuses, adversarial-reviewer flags any future regression).
ADV="$ROOT/review/adversarial-reviewer-subagent.md"
grep -q '6\. Reviser 硬修 of Global Conflicts\|Reviser 硬修\|fix it anyway' "$ADV" \
  || { echo "FAIL: adversarial-reviewer no longer documents the attack angle that catches this anti-pattern"; exit 1; }
echo "PASS: adversarial-reviewer attack angle #6 still in place"

echo "=== PASS test-reviser-global-conflict.sh (6 sub-tests) ==="
