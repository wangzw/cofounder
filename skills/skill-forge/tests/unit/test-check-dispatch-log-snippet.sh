#!/usr/bin/env bash
# test-check-dispatch-log-snippet.sh — unit tests for check-dispatch-log-snippet.sh (CR-S09)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-dispatch-log-snippet.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill (fingerprint present) — expect 0 issues, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for complete-skill"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES"; exit 1; }

# Test 2: missing-snippet-c fixture — expect CR-S09 issue, exit 1
OUT=$("$SCRIPT" "$FIXTURES/missing-snippet-c" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing-snippet-c"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S09' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S09 not reported"; exit 1; }

# Test 3: dir with no SKILL.md — expect CR-S09 issue, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/no-skill-md"
OUT=$("$SCRIPT" "$TMP/no-skill-md" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for no SKILL.md"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-dispatch-log-snippet.sh"
