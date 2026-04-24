#!/usr/bin/env bash
# test-check-dependencies.sh — unit tests for check-dependencies.sh (CR-S14)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-dependencies.sh"
SKILL_FORGE="$HERE/../.."

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — git-precheck.sh has all 3 checks, exit 0
OUT=$("$SCRIPT" "$SKILL_FORGE" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for skill-forge; issues=$ISSUES; out=$OUT"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: git-precheck.sh missing checks — expect CR-S14, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/bad-precheck/scripts"
cat > "$TMP/bad-precheck/scripts/git-precheck.sh" <<'SH'
#!/usr/bin/env bash
# Incomplete precheck — only checks git, missing bash and python3
command -v git >/dev/null || exit 1
echo "OK"
SH
chmod +x "$TMP/bad-precheck/scripts/git-precheck.sh"
OUT=$("$SCRIPT" "$TMP/bad-precheck" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for bad-precheck"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S14' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S14 not reported for bad-precheck"; exit 1; }
COUNT=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$COUNT" -eq 2 ] || { echo "FAIL: expected 2 issues (bash+python3 missing), got $COUNT"; exit 1; }

# Test 3: no git-precheck.sh — expect CR-S14, exit 1
mkdir -p "$TMP/no-precheck/scripts"
OUT=$("$SCRIPT" "$TMP/no-precheck" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for no-precheck"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-dependencies.sh"
