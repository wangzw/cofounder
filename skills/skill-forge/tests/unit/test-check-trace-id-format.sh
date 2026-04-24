#!/usr/bin/env bash
# test-check-trace-id-format.sh — unit tests for check-trace-id-format.sh (CR-S10)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-trace-id-format.sh"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT

# Build good.md with valid trace_ids
cat > "$TMP/good.md" <<'MD'
# Good trace IDs
trace_id: R1-C-001
trace_id: R3-W-007
trace_id: R5-V-003
trace_id=R10-J-001
MD

# Build bad.md with malformed trace_ids
cat > "$TMP/bad.md" <<'MD'
# Bad trace IDs
trace_id: R1-X-001
trace_id: R3-WW-007
trace_id: round1-W-007
MD

# Test 1: good file — exit 0, 0 issues
OUT=$("$SCRIPT" "$TMP/good.md" 2>/dev/null)
CODE=$?
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for good.md"; exit 1; }
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES"; exit 1; }

# Test 2: bad file — exit 1, issues reported
OUT=$("$SCRIPT" "$TMP/bad.md" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for bad.md"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S10' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S10 not reported for bad.md"; exit 1; }

# Test 3: directory scan — only bad.md produces issues
OUT=$("$SCRIPT" "$TMP" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for dir containing bad.md"; exit 1; }

# Test 4: non-existent path — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

# Test 5: empty dir (no .md files) — exit 0
EMPTYDIR=$(mktemp -d)
trap "rm -rf $EMPTYDIR" EXIT
OUT=$("$SCRIPT" "$EMPTYDIR" 2>/dev/null)
CODE=$?
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for empty dir"; exit 1; }

# Test 6: absolute file path — file field in issues must be basename-only (not absolute path)
ABS_BAD_DIR=$(mktemp -d)
trap "rm -rf $ABS_BAD_DIR" EXIT
ABS_BAD="$ABS_BAD_DIR/abs-bad.md"
cat > "$ABS_BAD" <<'MD'
trace_id: R1-X-001
MD
OUT=$("$SCRIPT" "$ABS_BAD" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for absolute-file-path test"; exit 1; }
FILE_FIELD=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d[0]['file'] if d else '')" <<< "$OUT")
BASENAME=$(basename "$ABS_BAD")
[ "$FILE_FIELD" = "$BASENAME" ] || { echo "FAIL: file field '$FILE_FIELD' is not basename-only '$BASENAME'"; exit 1; }

echo "PASS test-check-trace-id-format.sh"
