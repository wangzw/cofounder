#!/usr/bin/env bash
# test-prepare-input-bootstrap-subdir.sh — F8 fix
# Verifies prepare-input.sh + glossary-probe.sh honor --bootstrap-subdir flag,
# so new-version delivery-N bootstrap doesn't overwrite delivery-1's round-0.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PREP="$HERE/../../scripts/prepare-input.sh"
PROBE="$HERE/../../scripts/glossary-probe.sh"
GLOSSARY="$HERE/../../common/domain-glossary.md"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Delivery-1 bootstrap writes to default round-0
"$PREP" "First delivery prompt" "$TMP/review" >/dev/null 2>&1
[ -f "$TMP/review/round-0/input.md" ] || { echo "FAIL: default round-0 not created"; exit 1; }
D1_CONTENT=$(cat "$TMP/review/round-0/input.md")

# Delivery-2 bootstrap with explicit subdir — must NOT overwrite delivery-1 input
"$PREP" --bootstrap-subdir round-5 "Second delivery prompt" "$TMP/review" >/dev/null 2>&1
[ -f "$TMP/review/round-5/input.md" ] || { echo "FAIL: round-5 not created"; exit 1; }
[ -f "$TMP/review/round-0/input.md" ] || { echo "FAIL: round-0 disappeared"; exit 1; }
D1_CONTENT_AFTER=$(cat "$TMP/review/round-0/input.md")
[ "$D1_CONTENT" = "$D1_CONTENT_AFTER" ] || { echo "FAIL: delivery-1 round-0 overwritten"; exit 1; }
grep -q "Second delivery prompt" "$TMP/review/round-5/input.md" || { echo "FAIL: round-5 missing new prompt"; exit 1; }

# Glossary probe with matching --bootstrap-subdir reads from round-5
"$PROBE" --bootstrap-subdir round-5 "$TMP/review" "$GLOSSARY" >/dev/null 2>&1
[ -f "$TMP/review/round-5/trigger-flags.yml" ] || { echo "FAIL: round-5 trigger-flags.yml not written"; exit 1; }

# Back-compat: old positional form (no flag) still works
"$PROBE" "$TMP/review" "$GLOSSARY" >/dev/null 2>&1
[ -f "$TMP/review/round-0/trigger-flags.yml" ] || { echo "FAIL: default round-0 trigger-flags missing"; exit 1; }

echo "PASS test-prepare-input-bootstrap-subdir.sh"
