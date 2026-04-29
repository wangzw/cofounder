#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/create-issues.sh"

GOOD_JSON='{"round": 1, "issues": [
  {"criterion_id": "CR-PP06", "file": "features/F-001.md", "severity": "error",
   "description": "missing traceability link to journey J-001", "suggested_fix": "add a touchpoint reference"}
]}'

# Wrapper: always runs CHECK with stdin from $1
run_with_stdin() {
    local stdin_payload="$1"; shift
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    set +e
    printf '%s' "$stdin_payload" | "$@" >"$stdout_file" 2>"$stderr_file"
    LAST_EXIT=$?
    set -e
    LAST_STDOUT=$(cat "$stdout_file")
    LAST_STDERR=$(cat "$stderr_file")
    rm -f "$stdout_file" "$stderr_file"
}

test_case "exit 2 on missing args"
run_with_stdin '' "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on non-numeric round"
setup_fixture
run_with_stdin "$GOOD_JSON" "$CHECK" "$FIXTURE" "abc"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 2 on empty --stdin"
setup_fixture
run_with_stdin "" "$CHECK" "$FIXTURE" "1" --stdin
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "default (from-dir): no reviewer-output → 0 issues, exit 0"
setup_fixture
run_with_stdin "" "$CHECK" "$FIXTURE" "1"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q "0 issue" && _record_pass || _record_fail "no '0 issue' message"
teardown_fixture

test_case "default (from-dir): reads reviewer-output JSON files"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
cat > "$FIXTURE/.review/round-1/reviewer-output/R1-V-001.json" <<'EOFJSON'
{"round":1,"reviewer_variant":"cross","issues":[
  {"criterion_id":"CR-PP06","file":"features/F-001.md","severity":"error","description":"some problem found","suggested_fix":"fix it specifically"}
]}
EOFJSON
run_with_stdin "" "$CHECK" "$FIXTURE" "1"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-1/issues/I-001.md" ] && _record_pass || _record_fail "I-001 not created"
teardown_fixture

test_case "default (from-dir): merges multiple reviewer-output files"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
cat > "$FIXTURE/.review/round-1/reviewer-output/R1-V-001.json" <<'EOFJSON'
{"issues":[{"criterion_id":"CR-PP06","file":"a.md","severity":"error","description":"problem A","suggested_fix":"fix A specifically"}]}
EOFJSON
cat > "$FIXTURE/.review/round-1/reviewer-output/R1-V-002.json" <<'EOFJSON'
{"issues":[{"criterion_id":"CR-PP24","file":"b.md","severity":"warning","description":"problem B","suggested_fix":"fix B specifically"}]}
EOFJSON
run_with_stdin "" "$CHECK" "$FIXTURE" "1"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
count=$(ls "$FIXTURE/.review/round-1/issues/" | wc -l | tr -d ' ')
[ "$count" = "2" ] && _record_pass || _record_fail "expected 2 issue files, got $count"
teardown_fixture

test_case "default (from-dir): exit 2 on malformed reviewer-output JSON"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
echo "{not json" > "$FIXTURE/.review/round-1/reviewer-output/R1-V-001.json"
run_with_stdin "" "$CHECK" "$FIXTURE" "1"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 1 on invalid JSON"
setup_fixture
run_with_stdin "{not json" "$CHECK" "$FIXTURE" "1" --stdin
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
teardown_fixture

test_case "exit 1 when issue missing required field"
setup_fixture
run_with_stdin '{"issues": [{"criterion_id": "CR-X", "severity": "error"}]}' "$CHECK" "$FIXTURE" "1" --stdin
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
teardown_fixture

test_case "exit 0 + writes one issue file per finding"
setup_fixture
run_with_stdin "$GOOD_JSON" "$CHECK" "$FIXTURE" "1" --stdin
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-1/issues/I-001.md" ] && _record_pass || _record_fail "I-001 not written"
teardown_fixture

test_case "monotonic ID allocation across rounds"
setup_fixture
run_with_stdin "$GOOD_JSON" "$CHECK" "$FIXTURE" "1" --stdin
run_with_stdin '{"issues":[{"criterion_id":"CR-X","file":"x.md","severity":"error","description":"another problem in x","suggested_fix":"fix it more concretely"}]}' "$CHECK" "$FIXTURE" "2" --stdin
[ -f "$FIXTURE/.review/round-1/issues/I-001.md" ] && _record_pass || _record_fail "I-001 missing"
[ -f "$FIXTURE/.review/round-2/issues/I-002.md" ] && _record_pass || _record_fail "I-002 missing in round-2"
teardown_fixture

test_case "same-batch dedup — duplicate findings collapse"
setup_fixture
run_with_stdin '{"issues": [
  {"criterion_id":"CR-X","file":"x.md","severity":"error","description":"same description here","suggested_fix":"fix it concretely"},
  {"criterion_id":"CR-X","file":"x.md","severity":"error","description":"same description here","suggested_fix":"fix it concretely"}
]}' "$CHECK" "$FIXTURE" "1" --stdin
count=$(ls "$FIXTURE/.review/round-1/issues/" | wc -l | tr -d ' ')
[ "$count" = "1" ] && _record_pass || _record_fail "expected 1 file got $count"
echo "$LAST_STDOUT" | grep -q "deduped 1" && _record_pass || _record_fail "did not report dedup"
teardown_fixture

test_case "auto-fills recurrence_of from prior signature match"
setup_fixture
# Pre-existing issue with same signature in earlier round
run_with_stdin '{"issues":[{"criterion_id":"CR-X","file":"x.md","severity":"error","description":"same problem here","suggested_fix":"fix it concretely"}]}' "$CHECK" "$FIXTURE" "1" --stdin
# Now in round 2, same signature should get recurrence_of: I-001
run_with_stdin '{"issues":[{"criterion_id":"CR-X","file":"x.md","severity":"error","description":"same problem here","suggested_fix":"fix it concretely"}]}' "$CHECK" "$FIXTURE" "2" --stdin
grep -q "recurrence_of: I-001" "$FIXTURE/.review/round-2/issues/I-002.md" && _record_pass || _record_fail "recurrence_of not set"
grep -q "recurrence_count: 1" "$FIXTURE/.review/round-2/issues/I-002.md" && _record_pass || _record_fail "recurrence_count not 1"
teardown_fixture

test_case "recurrence_count chain — prior count + 1"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-X
file: x.md
severity: error
state: fixed
created_in_round: 1
fixed_in_round: 2
---

## Description
the original problem

## Suggested fix
fix it
'
write_file ".review/round-2/issues/I-002.md" '---
id: I-002
criterion_id: CR-X
file: x.md
severity: error
state: fixed
created_in_round: 2
fixed_in_round: 3
recurrence_of: I-001
recurrence_count: 1
---

## Description
recurred once

## Suggested fix
fix again
'
run_with_stdin '{"issues":[{"criterion_id":"CR-X","file":"x.md","severity":"error","description":"recurred yet again","suggested_fix":"fix more carefully","recurrence_of":"I-002"}]}' "$CHECK" "$FIXTURE" "3" --stdin
grep -q "recurrence_count: 2" "$FIXTURE/.review/round-3/issues/I-003.md" && _record_pass || _record_fail "recurrence_count not chained correctly"
teardown_fixture

test_case "--dry-run does not write files"
setup_fixture
run_with_stdin "$GOOD_JSON" "$CHECK" "$FIXTURE" "1" --stdin "--dry-run"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0"
[ ! -d "$FIXTURE/.review/round-1/issues" ] && _record_pass || _record_fail "files were written despite --dry-run"
teardown_fixture

end_tests
