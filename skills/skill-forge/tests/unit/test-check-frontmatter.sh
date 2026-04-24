#!/usr/bin/env bash
# test-check-frontmatter.sh — unit tests for check-frontmatter.sh (CR-S01)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-frontmatter.sh"
FIXTURES="$HERE/fixtures"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: complete-skill — valid frontmatter, exit 0
OUT=$("$SCRIPT" "$FIXTURES/complete-skill" 2>/dev/null)
CODE=$?
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for complete-skill; out=$OUT"; exit 1; }
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: no-frontmatter fixture — expect CR-S01, exit 1
OUT=$("$SCRIPT" "$FIXTURES/no-frontmatter" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for no-frontmatter"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S01' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S01 not reported for no-frontmatter"; exit 1; }

# Test 3: bad-description (not starting with "Use when") — expect CR-S01
OUT=$("$SCRIPT" "$FIXTURES/bad-description" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for bad-description"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('Use when' in i.get('description','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: 'Use when' violation not reported"; exit 1; }

# Test 4: description too long — expect CR-S01
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
LONG_DESC="Use when $(python3 -c "print('x'*1100)")"
mkdir -p "$TMP/long-desc"
printf -- "---\nname: test\nversion: 0.1.0\ndescription: %s\n---\n" "$LONG_DESC" > "$TMP/long-desc/SKILL.md"
OUT=$("$SCRIPT" "$TMP/long-desc" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for long description"; exit 1; }

# Test 5: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-frontmatter.sh"
