#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-traceability.sh"

write_good() {
  cat > "$1" <<'JSON'
{
  "criteria": [
    {"id": "F-001/AC1", "status": "PASS", "tests": ["tests/foo.spec.ts::create"]}
  ],
  "journeys": [
    {
      "id": "J-001",
      "status": "PASS",
      "touchpoints_total": 3,
      "touchpoints_traversed": 3,
      "scenarios": [
        {"kind": "happy", "test": "tests/foo.spec.ts::create", "status": "PASS"},
        {"kind": "error", "test": "tests/foo.spec.ts::dup", "status": "PASS"}
      ]
    }
  ],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
}

# --- happy --------------------------------------------------------------
tmp=$(mktempdir); write_good "$tmp/t.json"
start_test "valid traceability -> exit 0 PASS"
out=$("$SCRIPT" "$tmp/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- orphan tests -------------------------------------------------------
tmp2=$(mktempdir)
cat > "$tmp2/t.json" <<'JSON'
{"criteria":[],"journeys":[],"orphan_tests":["tests/foo.spec.ts::stale"],"unmapped_criteria":[]}
JSON
start_test "orphan_tests populated -> CR-AF09"
out=$("$SCRIPT" "$tmp2/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF09"
assert_stdout_contains "CR-AF09" "$out"

# --- unmapped criteria --------------------------------------------------
tmp3=$(mktempdir)
cat > "$tmp3/t.json" <<'JSON'
{"criteria":[],"journeys":[],"orphan_tests":[],"unmapped_criteria":["F-002/AC3"]}
JSON
start_test "unmapped_criteria populated -> CR-AF08"
out=$("$SCRIPT" "$tmp3/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF08"
assert_stdout_contains "CR-AF08" "$out"

# --- NOT_COVERED without issue -> CR-AF10 -----------------------------
tmp3b=$(mktempdir)
cat > "$tmp3b/t.json" <<'JSON'
{"criteria":[{"id":"F-002/AC3","status":"NOT_COVERED"}],"journeys":[],"orphan_tests":[],"unmapped_criteria":[]}
JSON
start_test "NOT_COVERED without issue -> CR-AF10"
out=$("$SCRIPT" "$tmp3b/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF10"
assert_stdout_contains "CR-AF10" "$out"

# --- happy-path-only journey -> CR-AF21 --------------------------------
tmp4=$(mktempdir)
cat > "$tmp4/t.json" <<'JSON'
{
  "criteria": [],
  "journeys": [
    {
      "id":"J-005",
      "status":"PASS",
      "touchpoints_total": 2,
      "touchpoints_traversed": 2,
      "scenarios":[{"kind":"happy","test":"t::a","status":"PASS"}]
    }
  ],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
start_test "journey with only happy scenario -> CR-AF21"
out=$("$SCRIPT" "$tmp4/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF21"
assert_stdout_contains "CR-AF21" "$out"

# --- happy-only journey but with coverage_gap_issue is OK --------------
tmp5=$(mktempdir)
cat > "$tmp5/t.json" <<'JSON'
{
  "criteria": [],
  "journeys": [
    {
      "id":"J-006",
      "status":"PASS",
      "touchpoints_total": 1,
      "touchpoints_traversed": 1,
      "scenarios":[{"kind":"happy","test":"t::a","status":"PASS"}],
      "coverage_gap_issue": "owner/repo#9"
    }
  ],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
start_test "happy-only with coverage_gap_issue -> exit 0"
out=$("$SCRIPT" "$tmp5/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- malformed JSON -> ERROR -------------------------------------------
tmp6=$(mktempdir)
echo "{bad json" > "$tmp6/t.json"
start_test "malformed JSON -> exit 2 ERROR"
out=$("$SCRIPT" "$tmp6/t.json" 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

summary
