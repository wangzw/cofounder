#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/prepare-input.sh"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Test 1: basic prompt, no refs
"$SCRIPT" "I want a skill that generates decision logs from meeting notes" "$TMP/.review" >/dev/null 2>&1
[ -f "$TMP/.review/round-0/input.md" ] || { echo "FAIL: input.md not written"; exit 1; }
[ -f "$TMP/.review/round-0/input-meta.yml" ] || { echo "FAIL: input-meta.yml not written"; exit 1; }
grep -q '^# User Prompt$' "$TMP/.review/round-0/input.md" || { echo "FAIL: missing # User Prompt heading"; exit 1; }
grep -q '^# Expanded References$' "$TMP/.review/round-0/input.md" || { echo "FAIL: missing # Expanded References heading"; exit 1; }
grep -q 'word_count:' "$TMP/.review/round-0/input-meta.yml" || { echo "FAIL: missing word_count"; exit 1; }

# Test 2: prompt with @ref to a real file
echo "dummy requirements" > "$TMP/requirements.md"
cd "$TMP" && "$SCRIPT" "Build @requirements.md" "$TMP/.review2" >/dev/null 2>&1
grep -q 'dummy requirements' "$TMP/.review2/round-0/input.md" \
  || { echo "FAIL: @ref content not expanded"; exit 1; }

# Test 2b: @ref pointing to a directory expands into tree + inlined text files
# (use --dir-mode full to match legacy behavior — default is now `selective`)
mkdir -p "$TMP/refdir/sub"
echo "top-level content" > "$TMP/refdir/top.md"
echo "nested content"    > "$TMP/refdir/sub/nested.md"
mkdir -p "$TMP/refdir/.review" && echo "should-be-skipped" > "$TMP/refdir/.review/skip.md"
cd "$TMP" && "$SCRIPT" --dir-mode full "Reference @refdir" "$TMP/.review2b" >/dev/null 2>&1
grep -q '^## @refdir' "$TMP/.review2b/round-0/input.md" \
  || { echo "FAIL: dir @ref heading missing"; exit 1; }
grep -q 'top.md' "$TMP/.review2b/round-0/input.md" \
  || { echo "FAIL: dir tree listing missing top.md"; exit 1; }
grep -q 'sub/nested.md' "$TMP/.review2b/round-0/input.md" \
  || { echo "FAIL: dir tree listing missing sub/nested.md"; exit 1; }
grep -q 'top-level content' "$TMP/.review2b/round-0/input.md" \
  || { echo "FAIL: full-mode should inline top.md content"; exit 1; }
grep -q 'nested content' "$TMP/.review2b/round-0/input.md" \
  || { echo "FAIL: full-mode should inline sub/nested.md content"; exit 1; }
grep -q 'should-be-skipped' "$TMP/.review2b/round-0/input.md" \
  && { echo "FAIL: dir should have skipped .review/ but inlined it"; exit 1; }

# Test 2d: dir-mode=selective (the new default) — inlines only orientation files
mkdir -p "$TMP/selref"
echo "orientation body" > "$TMP/selref/SKILL.md"
echo "other body"       > "$TMP/selref/other.md"
echo "readme body"      > "$TMP/selref/README.md"
cd "$TMP" && "$SCRIPT" "Reference @selref" "$TMP/.review2d" >/dev/null 2>&1
grep -q 'other.md' "$TMP/.review2d/round-0/input.md" \
  || { echo "FAIL: selective tree listing missing other.md"; exit 1; }
grep -q 'orientation body' "$TMP/.review2d/round-0/input.md" \
  || { echo "FAIL: selective should inline SKILL.md content"; exit 1; }
grep -q 'readme body' "$TMP/.review2d/round-0/input.md" \
  || { echo "FAIL: selective should inline README.md content"; exit 1; }
grep -q 'other body' "$TMP/.review2d/round-0/input.md" \
  && { echo "FAIL: selective should NOT inline other.md content"; exit 1; }

# Test 2e: dir-mode=listing — no inline content at all
cd "$TMP" && "$SCRIPT" --dir-mode listing "Reference @selref" "$TMP/.review2e" >/dev/null 2>&1
grep -q 'other.md' "$TMP/.review2e/round-0/input.md" \
  || { echo "FAIL: listing mode missing other.md in tree"; exit 1; }
grep -q 'orientation body' "$TMP/.review2e/round-0/input.md" \
  && { echo "FAIL: listing mode inlined SKILL.md content — should be tree only"; exit 1; }

# Test 2c: prepare-input drops .review/README.md from the review-readme template (idempotent)
"$SCRIPT" "seed" "$TMP/.review2c" >/dev/null 2>&1
[ -f "$TMP/.review2c/README.md" ] || { echo "FAIL: .review/README.md not written on first bootstrap"; exit 1; }
grep -q "Generation, Review & Delivery Archive" "$TMP/.review2c/README.md" \
  || { echo "FAIL: .review/README.md content missing expected heading"; exit 1; }
# user-edit preservation: modify README, re-run prepare-input — content must not revert
echo "USER_EDIT_MARKER" >> "$TMP/.review2c/README.md"
"$SCRIPT" "seed again" "$TMP/.review2c" >/dev/null 2>&1
grep -q "USER_EDIT_MARKER" "$TMP/.review2c/README.md" \
  || { echo "FAIL: .review/README.md was overwritten — must be idempotent"; exit 1; }

# Test 3: idempotent (running twice produces same output)
"$SCRIPT" "idempotent test prompt" "$TMP/.review3" >/dev/null 2>&1
HASH1=$(sha256sum "$TMP/.review3/round-0/input.md" | awk '{print $1}')
"$SCRIPT" "idempotent test prompt" "$TMP/.review3" >/dev/null 2>&1
HASH2=$(sha256sum "$TMP/.review3/round-0/input.md" | awk '{print $1}')
# Allow input-meta.yml to differ in generated_at timestamp; check input.md body only
[ "$HASH1" = "$HASH2" ] || { echo "FAIL: input.md not idempotent ($HASH1 vs $HASH2)"; exit 1; }

echo "PASS test-prepare-input.sh"
