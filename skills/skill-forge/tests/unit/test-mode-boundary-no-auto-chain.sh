#!/usr/bin/env bash
# test-mode-boundary-no-auto-chain.sh — assert user-triggered --review and
# --revise modes exit at their verdict and do NOT auto-chain into the next
# phase. Regression guard for skill-forge 0.3.0: prior to 0.3.0, review/
# index.md Step 7 said "Revise phase: load `revise/index.md`, increment
# round" on a `progressing` verdict, and revise/index.md Step 5 said
# "Increment round N; loop back to `review/index.md` Step 3 (cross-reviewer)".
# Both auto-chained inside one /skill-forge invocation, producing an
# operator-invisible cascade of dispatches and an inconsistent post-state
# (revisers fix files but issue frontmatter still says status:new because
# only cross-reviewer transitions status).
#
# 0.3.0 makes each top-level /skill-forge --<mode> invocation single-phase:
# the orchestrator updates state.yml mode_phase to signal the next phase
# the operator should invoke, and exits. This test asserts that property
# at the spec level (canonical + document skeleton).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# The 2 review/index.md files (canonical + document skeleton) MUST contain
# the exit-on-progressing semantics on Step 7's `progressing` row, and MUST
# NOT contain the legacy auto-chain phrase.
REVIEW_FILES=(
  "$ROOT/review/index.md"
  "$ROOT/common/skeleton/document/review/index.md"
)

for f in "${REVIEW_FILES[@]}"; do
  [ -f "$f" ] || fail "missing file: $f"

  # Required: explicit MUST NOT auto-load directive on the Step 7 progressing row.
  # The directive must appear at least twice — once for the Step 7 verdict-routing
  # row, and once for the Step 1 Phase-A exit-1 path (both are auto-chain entry
  # points that the 0.3.0 fix closes).
  if [ "$(grep -cF 'MUST NOT auto-load `revise/index.md`' "$f")" -lt 2 ]; then
    fail "$f: 'MUST NOT auto-load \`revise/index.md\`' directive must appear at least twice (Step 1 exit-1 path + Step 7 verdict-routing)"
  fi

  # Required: state.yml mode_phase signal pointing at --revise (also at least 2 sites).
  if [ "$(grep -cF 'idle-awaiting-revise-round-' "$f")" -lt 2 ]; then
    fail "$f: 'idle-awaiting-revise-round-<N>' mode_phase signal must appear at least twice (Step 1 exit-1 path + Step 7 verdict-routing)"
  fi

  # Forbidden: legacy auto-chain wording (verdict-routing path).
  if grep -qF '| `progressing` | Revise phase: load `revise/index.md`, increment round |' "$f"; then
    fail "$f: legacy auto-chain row 'Revise phase: load \`revise/index.md\`, increment round' is back — regression of 0.3.0"
  fi

  # Forbidden: legacy auto-chain wording (Phase A exit-1 path).
  if grep -qF 'jump directly to Revise Phase' "$f"; then
    fail "$f: legacy 'jump directly to Revise Phase' wording from Step 1 exit-1 path is back — regression of 0.3.0"
  fi
done

# The 2 revise/index.md files MUST contain the exit-on-progressing semantics
# on Step 5's `progressing` row, and MUST NOT contain the legacy
# loop-back-to-review phrase.
REVISE_FILES=(
  "$ROOT/revise/index.md"
  "$ROOT/common/skeleton/document/revise/index.md"
)

for f in "${REVISE_FILES[@]}"; do
  [ -f "$f" ] || fail "missing file: $f"

  # Required: explicit MUST NOT auto-load directive on the progressing row.
  if ! grep -qF 'MUST NOT auto-load `review/index.md`' "$f"; then
    fail "$f: missing 'MUST NOT auto-load \`review/index.md\`' directive on Step 5 progressing row"
  fi

  # Required: state.yml mode_phase signal pointing at --review.
  if ! grep -qF 'idle-awaiting-review-round-' "$f"; then
    fail "$f: missing 'idle-awaiting-review-round-<N+1>' mode_phase signal on Step 5 progressing row"
  fi

  # Forbidden: legacy loop-back wording.
  if grep -qF '| `progressing` | Increment round N; loop back to `review/index.md` Step 3 (cross-reviewer) |' "$f"; then
    fail "$f: legacy loop-back row 'Increment round N; loop back to \`review/index.md\` Step 3' is back — regression of 0.3.0"
  fi
done

echo "OK mode-boundary no-auto-chain (4 files: 2 review + 2 revise)"
