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

# Test 3: idempotent (running twice produces same output)
"$SCRIPT" "idempotent test prompt" "$TMP/.review3" >/dev/null 2>&1
HASH1=$(sha256sum "$TMP/.review3/round-0/input.md" | awk '{print $1}')
"$SCRIPT" "idempotent test prompt" "$TMP/.review3" >/dev/null 2>&1
HASH2=$(sha256sum "$TMP/.review3/round-0/input.md" | awk '{print $1}')
# Allow input-meta.yml to differ in generated_at timestamp; check input.md body only
[ "$HASH1" = "$HASH2" ] || { echo "FAIL: input.md not idempotent ($HASH1 vs $HASH2)"; exit 1; }

echo "PASS test-prepare-input.sh"
