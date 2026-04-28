#!/usr/bin/env bash
# test-run-checkers-carry-forward-unconditional.sh
# Verifies the unconditional-carry-forward invariant in run-checkers.sh:
#   1. Open prior-round issues are carried forward regardless of whether the
#      target leaf is in cross_reviewer_focus or cross_reviewer_skip — this
#      closes the Step-1-short-circuit gap where focus-leaf LLM issues would
#      otherwise silently disappear when cross-reviewer doesn't dispatch.
#   2. Issues with status=resolved or status=dismissed (post-revise mutations
#      by the per-issue-reviser) are NOT carried forward — they exit the
#      open set permanently.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_CHECKERS="$HERE/../../scripts/run-checkers.sh"
[ -x "$RUN_CHECKERS" ] || { echo "FAIL: $RUN_CHECKERS not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

mkdir -p "$TMP/common" "$TMP/generate"

# Minimal criteria (llm-type only — no script invocations needed; the test
# focuses on the carry-forward block which runs regardless).
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria

## CR-LLM-X

```yaml
- id: CR-LLM-X
  name: "test-only-llm"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```
EOF

cat > "$TMP/SKILL.md" <<'EOF'
---
name: fixture
version: 0.0.1
description: "Use when running carry-forward unit tests."
---
EOF

# ─────────────────────────────────────────────────────────────────────────
# Test 1: focus-leaf prior issue IS carried forward (the new invariant)
# ─────────────────────────────────────────────────────────────────────────
echo "# original" > "$TMP/generate/foo.md"

# Synthesize a round-1 LLM-source issue. (We plant it directly rather than
# running a real cross-reviewer dispatch — the test exercises the carry-forward
# block, not LLM judgement.)
mkdir -p "$TMP/.review/round-1/issues"
cat > "$TMP/.review/round-1/issues/R1-007.md" <<'EOF'
---
id: R1-007
status: new
severity: error
criterion_id: CR-LLM-X
file: generate/foo.md
round: 1
source: cross-reviewer
reviewer_variant: cross
---

# Synthetic LLM finding
EOF

# Bump foo.md so round-2 puts it in cross_reviewer_focus (changed leaf).
echo "# edited" > "$TMP/generate/foo.md"

"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

ISSUES_DIR="$TMP/.review/round-2/issues"
if [ ! -d "$ISSUES_DIR" ]; then
  fail "round-2 issues/ not created"
else
  CARRIED=$(grep -l "carries_from: R1-007" "$ISSUES_DIR"/*.md 2>/dev/null | head -1 || true)
  if [ -z "$CARRIED" ]; then
    fail "focus-leaf prior issue R1-007 was NOT carried forward (regression — old behavior was focus-skip-only)"
    ls "$ISSUES_DIR/" >&2
  else
    pass "focus-leaf prior LLM issue carried forward"
    if grep -q '^status: persistent$' "$CARRIED"; then
      pass "carry-forward status is persistent"
    else
      fail "carry-forward status is not persistent: $(grep '^status:' "$CARRIED")"
    fi
    if grep -q '^source: carry-forward$' "$CARRIED"; then
      pass "carry-forward source is carry-forward"
    else
      fail "carry-forward source is not carry-forward: $(grep '^source:' "$CARRIED")"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────
# Test 2: status=resolved is NOT carried forward
# ─────────────────────────────────────────────────────────────────────────
rm -rf "$TMP/.review"
mkdir -p "$TMP/.review/round-1/issues"
cat > "$TMP/.review/round-1/issues/R1-007.md" <<'EOF'
---
id: R1-007
status: resolved
severity: error
criterion_id: CR-LLM-X
file: generate/foo.md
round: 1
source: cross-reviewer
reviewer_variant: cross
---

# Synthetic finding — fixed by reviser
EOF

"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

if grep -l "carries_from: R1-007" "$TMP/.review/round-2/issues/"*.md >/dev/null 2>&1; then
  fail "status=resolved was wrongly carried forward"
else
  pass "status=resolved drops out of carry-forward"
fi

# ─────────────────────────────────────────────────────────────────────────
# Test 3: status=dismissed is NOT carried forward
# ─────────────────────────────────────────────────────────────────────────
rm -rf "$TMP/.review"
mkdir -p "$TMP/.review/round-1/issues"
cat > "$TMP/.review/round-1/issues/R1-008.md" <<'EOF'
---
id: R1-008
status: dismissed
severity: error
criterion_id: CR-LLM-X
file: generate/foo.md
round: 1
source: cross-reviewer
reviewer_variant: cross
dismiss_reason: "false positive — criterion clause does not apply here"
---

# Synthetic finding — dismissed by reviser
EOF

"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

if grep -l "carries_from: R1-008" "$TMP/.review/round-2/issues/"*.md >/dev/null 2>&1; then
  fail "status=dismissed was wrongly carried forward"
else
  pass "status=dismissed drops out of carry-forward"
fi

# ─────────────────────────────────────────────────────────────────────────
# Test 4: skip-leaf prior issue still carried (no regression on the prior
# carry-forward purpose)
# ─────────────────────────────────────────────────────────────────────────
rm -rf "$TMP/.review"
echo "# stable" > "$TMP/generate/foo.md"
mkdir -p "$TMP/.review/round-1/issues"
cat > "$TMP/.review/round-1/issues/R1-009.md" <<'EOF'
---
id: R1-009
status: new
severity: error
criterion_id: CR-LLM-X
file: generate/foo.md
round: 1
source: cross-reviewer
reviewer_variant: cross
---

# Synthetic finding on a leaf that won't change between rounds
EOF
# Do NOT touch foo.md — it stays byte-identical → cross_reviewer_skip in round 2.

"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

if grep -l "carries_from: R1-009" "$TMP/.review/round-2/issues/"*.md >/dev/null 2>&1; then
  pass "skip-leaf prior issue still carried (legacy behavior preserved)"
else
  fail "skip-leaf prior issue lost — regression on legacy carry-forward"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
