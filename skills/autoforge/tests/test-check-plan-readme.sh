#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-plan-readme.sh"

# --- happy plan dir ----------------------------------------------------
tmp=$(mktempdir)
mkdir -p "$tmp/plans"
cat > "$tmp/README.md" <<'MD'
# Plan: Demo

## Design Input
| Field | Value |
|---|---|
| Threshold | 80 |

## Dependency Graph
M-001

## Phase Breakdown
P1: M-001

## Module Plans
- [M-001](plans/plan-M-001-foo.md)

## Module Status
| Module | Plan | Status |
|---|---|---|
| M-001 | plans/plan-M-001-foo.md | planned |

## Phase Status
P1: planned

## Acceptance
threshold 80

## Reports
none yet
MD
cat > "$tmp/plans/plan-M-001-foo.md" <<'MD'
# M-001
MD
start_test "valid plan dir -> exit 0 PASS"
out=$("$SCRIPT" "$tmp" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- module status row references missing plan file --------------------
tmp2=$(mktempdir)
mkdir -p "$tmp2/plans"
cat > "$tmp2/README.md" <<'MD'
# Plan: Demo

## Design Input
| Field | Value |
|---|---|
| Threshold | 80 |

## Dependency Graph
M-001 -> M-008

## Phase Breakdown
P1: M-001 M-008

## Module Plans
- [M-001](plans/plan-M-001-foo.md)
- [M-008](plans/plan-M-008-missing.md)

## Module Status
| Module | Plan | Status |
|---|---|---|
| M-001 | plans/plan-M-001-foo.md | planned |
| M-008 | plans/plan-M-008-missing.md | planned |

## Phase Status
P1: planned

## Acceptance
threshold 80

## Reports
none yet
MD
cat > "$tmp2/plans/plan-M-001-foo.md" <<'MD'
# M-001
MD
start_test "row references missing plan -> CR-AF16"
out=$("$SCRIPT" "$tmp2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF16"
assert_stdout_contains "CR-AF16" "$out"

# --- missing required README sections ---------------------------------
tmp3=$(mktempdir)
mkdir -p "$tmp3/plans"
cat > "$tmp3/README.md" <<'MD'
# Plan
just a title
MD
start_test "missing required sections -> CR-AF15"
out=$("$SCRIPT" "$tmp3" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF15"
assert_stdout_contains "CR-AF15" "$out"

summary
