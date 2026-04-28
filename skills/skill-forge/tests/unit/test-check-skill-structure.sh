#!/usr/bin/env bash
# test-check-skill-structure.sh — unit tests for check-skill-structure.sh (CR-S03/S04/S16)
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

# Test 5: CR-S16 — stray *-template.md at root → fires with suggested_fix pointing to common/templates/
unset CODE
cp -r "$FIXTURES/complete-skill/." "$TMP/stray-template/"
echo "stray template" > "$TMP/stray-template/feature-template.md"
OUT=$("$SCRIPT" "$TMP/stray-template" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for stray template"; exit 1; }
FOUND=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
hit = next((i for i in data if i['criterion_id']=='CR-S16' and i['file']=='feature-template.md'), None)
print('OK' if hit and 'common/templates/feature-template.md' in hit.get('suggested_fix','') else 'MISS')
" <<< "$OUT")
[ "$FOUND" = "OK" ] || { echo "FAIL: CR-S16 issue (stray template) not reported correctly"; echo "$OUT"; exit 1; }

# Test 6: CR-S16 — stray *-mode.md at root with role-aware suggestion
unset CODE
cp -r "$FIXTURES/complete-skill/." "$TMP/stray-mode/"
echo "stray mode doc" > "$TMP/stray-mode/review-mode.md"
echo "stray mode doc" > "$TMP/stray-mode/evolve-mode.md"
OUT=$("$SCRIPT" "$TMP/stray-mode" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for stray mode files"; exit 1; }
HITS=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
items = [i for i in data if i['criterion_id']=='CR-S16']
review_hit = next((i for i in items if i['file']=='review-mode.md'), None)
evolve_hit = next((i for i in items if i['file']=='evolve-mode.md'), None)
print('OK' if (
  review_hit and 'review/index.md' in review_hit['suggested_fix']
  and evolve_hit and 'generate/evolve-mode.md' in evolve_hit['suggested_fix']
) else 'MISS')
" <<< "$OUT")
[ "$HITS" = "OK" ] || { echo "FAIL: CR-S16 mode-file relocation suggestions wrong"; echo "$OUT"; exit 1; }

# Test 7: CR-S16 — stray subagent at root with role-aware suggestion
unset CODE
cp -r "$FIXTURES/complete-skill/." "$TMP/stray-subagent/"
echo "stray" > "$TMP/stray-subagent/writer-subagent.md"
OUT=$("$SCRIPT" "$TMP/stray-subagent" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for stray subagent"; exit 1; }
FOUND=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
hit = next((i for i in data if i['criterion_id']=='CR-S16' and i['file']=='writer-subagent.md'), None)
print('OK' if hit and 'generate/writer-subagent.md' in hit['suggested_fix'] else 'MISS')
" <<< "$OUT")
[ "$FOUND" = "OK" ] || { echo "FAIL: CR-S16 subagent-relocation suggestion wrong"; echo "$OUT"; exit 1; }

# Test 8: CR-S16 — unexpected top-level directory fires
unset CODE
cp -r "$FIXTURES/complete-skill/." "$TMP/stray-dir/"
mkdir "$TMP/stray-dir/extras"
echo "stuff" > "$TMP/stray-dir/extras/notes.md"
OUT=$("$SCRIPT" "$TMP/stray-dir" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit code $CODE (expected 1) for stray dir"; exit 1; }
FOUND=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
hit = next((i for i in data if i['criterion_id']=='CR-S16' and i['file']=='extras/'), None)
print('OK' if hit else 'MISS')
" <<< "$OUT")
[ "$FOUND" = "OK" ] || { echo "FAIL: CR-S16 stray-directory issue not reported"; echo "$OUT"; exit 1; }

# Test 9: CR-S16 — CHANGELOG.md, README.md, and dotfiles at root MUST be tolerated (no CR-S16)
unset CODE
cp -r "$FIXTURES/complete-skill/." "$TMP/with-meta/"
echo "# Changelog" > "$TMP/with-meta/CHANGELOG.md"
echo "# Readme"    > "$TMP/with-meta/README.md"
echo "ignored"     > "$TMP/with-meta/.gitignore"
mkdir "$TMP/with-meta/.review"
OUT=$("$SCRIPT" "$TMP/with-meta" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys, json; print(sum(1 for i in json.loads(sys.stdin.read()) if i['criterion_id']=='CR-S16'))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit code $CODE (expected 0) for valid root-level meta files"; echo "$OUT"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: CR-S16 fired on allowed CHANGELOG/README/dotfiles ($ISSUES issues)"; echo "$OUT"; exit 1; }

echo "PASS test-check-skill-structure.sh"
