#!/usr/bin/env bash
# test-check-ipc-footer.sh — unit tests for check-ipc-footer.sh (CR-S08)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-ipc-footer.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill (all footers present) — expect 0 issues, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for complete-skill"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES"; exit 1; }

# Test 2: missing-footer fixture — expect CR-S08 issues, exit 1
OUT=$("$SCRIPT" "$FIXTURES/missing-footer" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing-footer"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S08' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S08 not reported for missing-footer"; exit 1; }

# Test 3: one missing footer — only that file flagged
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
cp -r "$FIXTURES/complete-skill/." "$TMP/one-missing/"
# Remove fingerprint from one file
printf '# no footer here\n' > "$TMP/one-missing/generate/writer-subagent.md"
OUT=$("$SCRIPT" "$TMP/one-missing" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for one missing footer"; exit 1; }
COUNT=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$COUNT" -eq 1 ] || { echo "FAIL: expected 1 issue, got $COUNT"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2) for non-existent dir"; exit 1; }

echo "PASS test-check-ipc-footer.sh"
