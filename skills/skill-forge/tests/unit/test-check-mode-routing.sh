#!/usr/bin/env bash
# test-check-mode-routing.sh — unit tests for check-mode-routing.sh (CR-S02)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-mode-routing.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill — valid routing table, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for complete-skill; out=$OUT"; exit 1; }
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: no-mode-routing fixture — expect CR-S02, exit 1
OUT=$("$SCRIPT" "$FIXTURES/no-mode-routing" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for no-mode-routing"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S02' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S02 not reported for no-mode-routing"; exit 1; }

# Test 3: missing-mode fixture (no --diagnose row) — expect CR-S02, exit 1
OUT=$("$SCRIPT" "$FIXTURES/missing-mode" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing-mode"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('diagnose' in i.get('description','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: --diagnose missing not reported"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

# Test 5: missing-loaded-files-col fixture — all mode rows present but no Loaded Files column — expect CR-S02 with 'Loaded Files' in description
OUT=$("$SCRIPT" "$FIXTURES/missing-loaded-files-col" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing-loaded-files-col"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('Loaded Files' in i.get('description','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: 'Loaded Files' column missing not reported; out=$OUT"; exit 1; }

echo "PASS test-check-mode-routing.sh"
