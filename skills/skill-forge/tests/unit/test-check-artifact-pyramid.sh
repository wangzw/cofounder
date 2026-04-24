#!/usr/bin/env bash
# test-check-artifact-pyramid.sh — unit tests for check-artifact-pyramid.sh (CR-S13)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-artifact-pyramid.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill — artifact-template.md with README.md + subdir path, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for complete-skill; out=$OUT"; exit 1; }
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: flat-artifact fixture — no subdir path, expect CR-S13, exit 1
OUT=$("$SCRIPT" "$FIXTURES/flat-artifact" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for flat-artifact"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S13' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S13 not reported for flat-artifact"; exit 1; }

# Test 3: missing artifact-template.md — expect CR-S13, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/no-template/common/templates"
OUT=$("$SCRIPT" "$TMP/no-template" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing template"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-artifact-pyramid.sh"
