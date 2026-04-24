#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PREPARE="$HERE/../../scripts/prepare-input.sh"
PROBE="$HERE/../../scripts/glossary-probe.sh"
GLOSSARY="$HERE/../../common/domain-glossary.md"

[ -x "$PROBE" ] || { echo "FAIL: probe not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Test 1: sparse input with no glossary hits (all short words, no terms)
"$PREPARE" "short" "$TMP/.review1" >/dev/null 2>&1
"$PROBE" "$TMP/.review1" "$GLOSSARY" >/dev/null 2>&1
[ -f "$TMP/.review1/round-0/trigger-flags.yml" ] || { echo "FAIL: trigger-flags.yml not written"; exit 1; }
grep -q 'sparse_input: true' "$TMP/.review1/round-0/trigger-flags.yml" \
  || { echo "FAIL: short prompt not flagged sparse"; exit 1; }

# Test 2: glossary hit — prompt includes the word "delivery"
"$PREPARE" "I want to generate a major version delivery release of my app with new features and tests" "$TMP/.review2" >/dev/null 2>&1
"$PROBE" "$TMP/.review2" "$GLOSSARY" >/dev/null 2>&1
grep -q 'glossary_hit: true' "$TMP/.review2/round-0/trigger-flags.yml" \
  || { echo "FAIL: 'delivery' not matched as glossary hit"; exit 1; }

# Test 3: dense prompt with no hits
"$PREPARE" "A fully self-contained specification document describing the customer-facing workflow of an internal productivity tool designed for cross-functional teams that need to coordinate asynchronously across multiple time zones during rolling-hour operations involving several distinct organizational units reporting through a central dashboard system that consolidates status updates automatically on a recurring schedule." "$TMP/.review3" >/dev/null 2>&1
"$PROBE" "$TMP/.review3" "$GLOSSARY" >/dev/null 2>&1
grep -q 'sparse_input: false' "$TMP/.review3/round-0/trigger-flags.yml" \
  || { echo "FAIL: long prompt still flagged sparse"; exit 1; }

echo "PASS test-glossary-probe.sh"
