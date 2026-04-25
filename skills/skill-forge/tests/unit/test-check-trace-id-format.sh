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

# Regression tests for the placeholder + separator fix (commit 8ee3497).
# Before the fix the regex captured markdown placeholder syntax and code-span
# fragments inside IPC contract documentation, producing 29 false positives
# on a freshly-generated skill that just copies the boilerplate verbatim.

# Test 7: angle-bracket placeholders in IPC contract docs — must NOT trigger
PLACEHOLDER_DIR=$(mktemp -d)
trap "rm -rf $PLACEHOLDER_DIR" EXIT
cat > "$PLACEHOLDER_DIR/ipc-contract.md" <<'MD'
# IPC Contract Doc

The ACK format:
- `OK trace_id=<id> role=<role> linked_issues=<comma-separated or empty>`
- `FAIL trace_id=<trace_id> reason=<one-line>`

The trace_id format is `R{round}-{role-letter}-{nnn}`.

Example envelope: `<target>/.review/round-<N>/self-reviews/<trace_id>.md`
MD
OUT=$("$SCRIPT" "$PLACEHOLDER_DIR" 2>/dev/null)
CODE=$?
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for placeholder-only doc"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues for placeholder doc, got $ISSUES"; exit 1; }
echo "PASS: placeholder syntax (<id>, <trace_id>, R{round}-...) skipped"

# Test 8: prose mention (no `=` or `:` separator) — must NOT trigger
PROSE_DIR=$(mktemp -d)
trap "rm -rf $PROSE_DIR" EXIT
cat > "$PROSE_DIR/prose.md" <<'MD'
# Reviewer guidance

Check all examples, documentation, and inline templates in focus leaves for trace_id strings.
The trace_id appears as the literal first line of every sub-agent prompt.
A valid trace_id is in the R<digits>-<role-letter>-<nnn> format.
MD
OUT=$("$SCRIPT" "$PROSE_DIR" 2>/dev/null)
CODE=$?
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for prose-mention doc"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues for prose doc, got $ISSUES"; exit 1; }
echo "PASS: prose mention (trace_id followed by space-and-noun) skipped"

# Test 9: backtick code-span in markdown — must NOT trigger
BACKTICK_DIR=$(mktemp -d)
trap "rm -rf $BACKTICK_DIR" EXIT
cat > "$BACKTICK_DIR/markdown.md" <<'MD'
# Markdown with backticks

Suggest user verify orchestrator is injecting `trace_id:` markers.
The dispatch log records each `trace_id`, then `role`, then `linked_issues`.
MD
OUT=$("$SCRIPT" "$BACKTICK_DIR" 2>/dev/null)
CODE=$?
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for backtick doc"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues for backtick doc, got $ISSUES"; exit 1; }
echo "PASS: backtick fragments (\`trace_id:\`) skipped"

# Test 10: real malformed trace_id alongside placeholders — only the real one flagged
MIXED_DIR=$(mktemp -d)
trap "rm -rf $MIXED_DIR" EXIT
cat > "$MIXED_DIR/mixed.md" <<'MD'
# Mixed
- placeholder: trace_id=<id>
- valid: trace_id=R3-W-007
- malformed: trace_id=R3-Q-007
MD
OUT=$("$SCRIPT" "$MIXED_DIR" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
ISSUES=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(len(d), d[0]['description'] if d else '')" <<< "$OUT")
[ "$CODE" -eq 1 ] || { echo "FAIL: mixed file should exit 1 (one real malformed), got $CODE"; exit 1; }
NUM=$(echo "$ISSUES" | awk '{print $1}')
[ "$NUM" = "1" ] || { echo "FAIL: expected exactly 1 issue (the R3-Q-007 case), got $NUM"; exit 1; }
echo "$ISSUES" | grep -q "R3-Q-007" || { echo "FAIL: expected R3-Q-007 in issue description, got: $ISSUES"; exit 1; }
echo "PASS: mixed file flags real malformed only (1 of 1)"

echo "=== PASS test-check-trace-id-format.sh (10 sub-tests) ==="
