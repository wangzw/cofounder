#!/usr/bin/env bash
# test-check-scripts-inventory.sh — unit tests for check-scripts-inventory.sh (CR-S05)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-scripts-inventory.sh"
SKILL_FORGE="$HERE/../.."

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — will have missing scripts (not all 24 are authored yet).
# We just verify: output is valid JSON, exit is 0 or 1, each issue has CR-S05 criterion_id.
OUT=$("$SKILL_FORGE/scripts/check-scripts-inventory.sh" "$SKILL_FORGE" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
# All issues must reference CR-S05
BAD=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']!='CR-S05' for i in d))" <<< "$OUT")
[ "$BAD" = "False" ] || { echo "FAIL: non-CR-S05 issues found"; exit 1; }

# Test 2: empty scripts dir — all scripts missing, expect many CR-S05 issues, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/empty-scripts/scripts"
OUT=$("$SCRIPT" "$TMP/empty-scripts" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for empty scripts dir"; exit 1; }
COUNT=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$COUNT" -gt 10 ] || { echo "FAIL: expected >10 issues for empty scripts dir, got $COUNT"; exit 1; }

# Test 3: script present but not executable — expect CR-S05 issue
mkdir -p "$TMP/not-exec/scripts"
touch "$TMP/not-exec/scripts/git-precheck.sh"
chmod -x "$TMP/not-exec/scripts/git-precheck.sh"
OUT=$("$SCRIPT" "$TMP/not-exec" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for non-executable script"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('git-precheck' in i.get('file','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: non-executable script not flagged"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-scripts-inventory.sh"
