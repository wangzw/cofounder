#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-checkers.sh"

# --- empty but well-formed plan dir + clean source -> PASS ------------
plan=$(mktempdir); mkdir -p "$plan/plans" "$plan/reports"
cat > "$plan/README.md" <<'MD'
# Plan: Demo
## Design Input
| Field | Value |
|---|---|
| Threshold | 80 |
## Dependency Graph
empty
## Phase Breakdown
P1
## Module Plans
none
## Module Status
| Module | Plan | Status |
|---|---|---|
## Phase Status
P1: planned
## Acceptance
threshold 80
## Reports
none yet
MD
src=$(mktempdir)
start_test "minimal plan dir -> exit 0 PASS"
out=$("$SCRIPT" "$plan" --source-root "$src" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- discipline scan finds soft-pass in source -> exit 1 -------------
src2=$(mktempdir)
cat > "$src2/bad.ts" <<'TS'
expect([200,400,403]).toContain(res.status);
TS
start_test "soft-pass in source -> aggregator exit 1"
out=$("$SCRIPT" "$plan" --source-root "$src2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  aggregator surfaces CR-AF12"
assert_stdout_contains "CR-AF12" "$out"
start_test "  scope=discipline-scan label present"
assert_stdout_contains "discipline-scan" "$out"

# --- missing plan-dir -> ERROR ----------------------------------------
start_test "missing plan-dir -> exit 2 ERROR"
out=$("$SCRIPT" /tmp/this-does-not-exist 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

summary
