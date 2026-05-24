#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
MIGRATE="$REPO_SCRIPTS/migrate-issues-add-category.sh"

test_case "exit 2 on missing arg"
run_command "$MIGRATE"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "adds category line after criterion_id"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD-DESIGN01
file: modules/M-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
result=$(cat "$FIXTURE/.review/round-1/issues/I-001.md")
case "$result" in
  *"category: module-boundary"*) _record_pass ;;
  *) _record_fail "category not injected; got: $result" ;;
esac
teardown_fixture

test_case "idempotent on already-migrated issue"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD-DESIGN01
category: module-boundary
file: modules/M-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
result=$(grep -c "^category:" "$FIXTURE/.review/round-1/issues/I-001.md")
[ "$result" = "1" ] && _record_pass || _record_fail "expected 1 category line, got $result"
teardown_fixture

test_case "unknown criterion_id emits WARNING and skips"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-UNKNOWN-XX
file: modules/M-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
assert_stdout_contains "WARNING"
assert_stdout_contains "CR-UNKNOWN-XX"
! grep -q "^category:" "$FIXTURE/.review/round-1/issues/I-001.md" && _record_pass \
    || _record_fail "category was written for unknown CR"
teardown_fixture

test_case "migrates across multiple rounds"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD-DESIGN01
file: modules/M-001.md
severity: error
state: new
created_in_round: 1
history: []
fix_history: []
---

## Description
x

## Suggested fix
y
'
write_file ".review/round-2/issues/I-002.md" '---
id: I-002
criterion_id: CR-SD-DESIGN06
file: modules/M-002.md
severity: error
state: new
created_in_round: 2
history: []
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
grep -q "^category: module-boundary$" "$FIXTURE/.review/round-1/issues/I-001.md" && _record_pass || _record_fail "round-1 issue not migrated"
grep -q "^category: failure-modes$" "$FIXTURE/.review/round-2/issues/I-002.md" && _record_pass || _record_fail "round-2 issue not migrated"
teardown_fixture

end_tests
