#!/usr/bin/env bash
# test-check-skill-structure.sh — unit tests for check-skill-structure.sh (CR-S03/S04)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-skill-structure.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Helper: run script, capture JSON, verify it parses
run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill fixture — expect 0 issues, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys, json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit code $CODE (expected 0) for complete-skill"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES for complete-skill"; exit 1; }

# Test 2: missing-generate fixture — expect CR-S03 issue, exit 1
OUT=$("$SCRIPT" "$FIXTURES/missing-generate" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for missing-generate"; exit 1; }
FOUND=$(python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S03' for i in data))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S03 issue not reported for missing-generate"; exit 1; }

# Test 3: complete-skill but missing a subagent — expect CR-S04 issue
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cp -r "$FIXTURES/complete-skill/." "$TMP/incomplete-subagents/"
rm "$TMP/incomplete-subagents/review/adversarial-reviewer-subagent.md"
OUT=$("$SCRIPT" "$TMP/incomplete-subagents" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for missing adversarial reviewer"; exit 1; }
FOUND=$(python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S04' for i in data))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S04 issue not reported for missing adversarial reviewer"; exit 1; }

# Test 4: non-existent dir — expect exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2 for missing dir"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit code $CODE (expected 2) for non-existent dir"; exit 1; }

echo "PASS test-check-skill-structure.sh"
