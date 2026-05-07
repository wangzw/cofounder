#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-module-plan.sh"

# --- happy path --------------------------------------------------------
tmp=$(mktempdir)
cat > "$tmp/plan-M-001-foo.md" <<'MD'
# M-001 Foo

## Context
Bar.

## Implementation Steps
1. Do thing.

## Integration Points
- depends on M-002

## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| HTTP route | mount in router.go | curl returns 200 |

## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|

## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 step 3 | step 1 | tests/foo.py | status==200 AND body.id present |
MD
start_test "happy-path module plan -> exit 0 PASS"
out=$("$SCRIPT" "$tmp/plan-M-001-foo.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- missing required section -----------------------------------------
tmp2=$(mktempdir)
cat > "$tmp2/plan-M-002-bar.md" <<'MD'
# M-002 Bar

## Context
Stub.
MD
start_test "missing required sections -> CR-AF01"
out=$("$SCRIPT" "$tmp2/plan-M-002-bar.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF01"
assert_stdout_contains "CR-AF01" "$out"

# --- empty AC mapping --------------------------------------------------
tmp3=$(mktempdir)
cat > "$tmp3/plan-M-003-baz.md" <<'MD'
# M-003 Baz

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| route | mount | curl |
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
MD
start_test "empty AC mapping -> CR-AF03"
out=$("$SCRIPT" "$tmp3/plan-M-003-baz.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF03"
assert_stdout_contains "CR-AF03" "$out"

# --- out-of-scope row missing issue link ------------------------------
tmp4=$(mktempdir)
cat > "$tmp4/plan-M-004-qux.md" <<'MD'
# M-004 Qux

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| route | mount | curl |
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
| Email service | next phase | TBD |
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 t1 | step1 | tests/x.py | status==200 |
MD
start_test "out-of-scope without issue -> CR-AF04"
out=$("$SCRIPT" "$tmp4/plan-M-004-qux.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF04"
assert_stdout_contains "CR-AF04" "$out"

# --- empty Wiring & Registration table -> CR-AF02 ---------------------
tmp5=$(mktempdir)
cat > "$tmp5/plan-M-005-wire.md" <<'MD'
# M-005 Wire

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 t1 | step1 | tests/x.py | status==200 |
MD
start_test "empty wiring table -> CR-AF02"
out=$("$SCRIPT" "$tmp5/plan-M-005-wire.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF02"
assert_stdout_contains "CR-AF02" "$out"

# --- weak deferral reason -> CR-AF17 ----------------------------------
tmp6=$(mktempdir)
cat > "$tmp6/plan-M-006-weak.md" <<'MD'
# M-006

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| route | mount | curl |
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
| Email retry queue with DLQ | too complex | owner/repo#42 |
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 t1 | step1 | tests/x.py | status==200 |
MD
start_test "complexity-excuse reason -> CR-AF17"
out=$("$SCRIPT" "$tmp6/plan-M-006-weak.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF17"
assert_stdout_contains "CR-AF17" "$out"

# --- vague deferral item -> CR-AF18 -----------------------------------
tmp7=$(mktempdir)
cat > "$tmp7/plan-M-007-vague.md" <<'MD'
# M-007

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| route | mount | curl |
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
| polish UX | upstream PR github.com/o/r#9 not merged | owner/repo#9 |
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 t1 | step1 | tests/x.py | status==200 |
MD
start_test "vague item -> CR-AF18"
out=$("$SCRIPT" "$tmp7/plan-M-007-vague.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF18"
assert_stdout_contains "CR-AF18" "$out"

# --- AC double-claim -> CR-AF19 ---------------------------------------
tmp8=$(mktempdir)
cat > "$tmp8/plan-M-008-dup.md" <<'MD'
# M-008

## Context
x
## Implementation Steps
1. x
## Integration Points
- x
## Wiring & Registration
| Surface | Concrete Hook | Verify Step |
|---|---|---|
| route | mount | curl |
## Out-of-Scope / Deferred Work
| Item | Reason | Tracked In |
|---|---|---|
| Email retry F-001/AC1 done elsewhere | upstream PR not merged | owner/repo#9 |
## Acceptance Criteria Mapping
| AC | Journey Touchpoint | Impl Step | Test | Strict Assertion |
|---|---|---|---|---|
| F-001/AC1 | J-001 t1 | step1 | tests/x.py | status==200 |
MD
start_test "AC double-claim -> CR-AF19"
out=$("$SCRIPT" "$tmp8/plan-M-008-dup.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF19"
assert_stdout_contains "CR-AF19" "$out"

summary
