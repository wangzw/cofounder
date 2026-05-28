#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-issue.sh"

GOOD_ISSUE='---
id: I-001
criterion_id: CR-SD01
file: README.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
some problem found

## Suggested fix
do this thing
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + PASS when no issues exist"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 0 + PASS for well-formed issue file"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$GOOD_ISSUE"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-IS01: missing required field"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
state: new
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-IS01"
assert_stdout_contains "criterion_id"
teardown_fixture

test_case "CR-IS01: invalid state value"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: x.md
severity: error
state: bogus
created_in_round: 1
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "state"
assert_stdout_contains "bogus"
teardown_fixture

test_case "CR-IS01: invalid id format"
setup_fixture
write_file ".review/round-1/issues/I-1.md" '---
id: I-1
criterion_id: CR-SD01
file: x.md
severity: error
state: new
created_in_round: 1
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "I-NNN"
teardown_fixture

test_case "CR-IS01: state=deferred missing defer_until"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: x.md
severity: error
state: deferred
created_in_round: 1
defer_reason: scope
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "defer_until"
teardown_fixture

test_case "CR-IS01: state=fixed missing fixed_in_round"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: x.md
severity: error
state: fixed
created_in_round: 1
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "fixed_in_round"
teardown_fixture

test_case "CR-IS01: superseded_by points to nonexistent id"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: x.md
severity: error
state: superseded
created_in_round: 1
superseded_by: I-999
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "I-999"
teardown_fixture

test_case "CR-IS01: missing body section"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: x.md
severity: error
state: new
created_in_round: 1
---

## Description
just description, no fix
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "Suggested fix"
teardown_fixture

test_case "CR-IS01: malformed frontmatter"
setup_fixture
write_file ".review/round-1/issues/I-001.md" 'no frontmatter at all'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "missing leading"
teardown_fixture

test_case "category missing emits non-fatal WARNING on legacy issue"
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
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "WARNING"
assert_stdout_contains "category"
teardown_fixture

test_case "category present and valid passes cleanly"
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
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "category with invalid value fails"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD-DESIGN01
category: not-a-real-category
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
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "category"
assert_stdout_contains "not-a-real-category"
teardown_fixture

end_tests
