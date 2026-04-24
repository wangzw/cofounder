#!/usr/bin/env bash
# test-check-criteria-yaml.sh — unit tests for check-criteria-yaml.sh (CR-S07)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-criteria-yaml.sh"
SKILL_FORGE="$HERE/../.."
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — valid criteria, expect 0 issues, exit 0
OUT=$("$SCRIPT" "$SKILL_FORGE" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for skill-forge; issues=$ISSUES; out=$OUT"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: bad-criteria fixture — missing fields + invalid checker_type
OUT=$("$SCRIPT" "$FIXTURES/bad-criteria" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for bad-criteria"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S07' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S07 not reported for bad-criteria"; exit 1; }

# Test 3: missing review-criteria.md — expect CR-S07, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/no-criteria/common"
OUT=$("$SCRIPT" "$TMP/no-criteria" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing criteria file"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-criteria-yaml.sh"
