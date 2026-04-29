#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/verify-phase-entry.sh"

ISSUE_NEW='---
id: I-001
criterion_id: CR-SD01
file: README.md
severity: error
state: new
created_in_round: 1
---

## Description
some problem here

## Suggested fix
fix it specifically
'

ISSUE_FIXED=$(printf '%s' "$ISSUE_NEW" | sed 's/state: new/state: fixed/' | sed '/^state: fixed$/a\
fixed_in_round: 2')

write_minimal_valid_bundle() {
    write_file "README.md" '---
id: SD-test
title: Test
owner: alice
status: draft
version: 0.1.0
prd_ref: na
---

# Test Design

## Modules

- [M-001 widget](modules/M-001-widget.md)

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 widget | ✦ |
'
    write_file "modules/M-001-widget.md" '---
id: M-001
title: Widget
owner: alice
status: draft
version: 0.1.0
depends_on: []
---

## Responsibilities
Holds the widget.

## Public Interfaces
- `getWidget() -> Widget` returns the current widget.

## Data Models
- `Widget { id: str, name: str }`

## Dependencies
None.

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| input | schema check | api boundary | reject 400 |
'
}

# ════════════════════════════════════════════════
# General arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on unknown phase"
setup_fixture
run_command "$CHECK" bogus-phase "$FIXTURE"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "exit 2 on non-existent prd-dir"
run_command "$CHECK" read "/nonexistent-xyz-$$"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# Phase: read
# ════════════════════════════════════════════════

test_case "read: PASS on clean bundle, no prior issues"
setup_fixture
write_minimal_valid_bundle
assert_exit 0 "$CHECK" read "$FIXTURE"
assert_stdout_contains "OK read-phase entry verified"
teardown_fixture

test_case "read: FAIL when prior round has state:new issue"
setup_fixture
write_minimal_valid_bundle
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 1 "$CHECK" read "$FIXTURE"
assert_stdout_contains "REFUSE entering read"
teardown_fixture

test_case "read: PASS when prior issues all fixed"
setup_fixture
write_minimal_valid_bundle
write_file ".review/round-1/issues/I-001.md" "$ISSUE_FIXED"
assert_exit 0 "$CHECK" read "$FIXTURE"
assert_stdout_contains "OK read-phase"
teardown_fixture

test_case "read: FAIL when bundle fails formal review"
setup_fixture
# Don't write README.md → CR-SD01 missing
assert_exit 1 "$CHECK" read "$FIXTURE"
assert_stdout_contains "REFUSE entering read"
teardown_fixture

test_case "read: FAIL when both readiness AND formal fail"
setup_fixture
# No README + state:new issue
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 1 "$CHECK" read "$FIXTURE"
assert_stdout_contains "REFUSE entering read"
teardown_fixture

# ════════════════════════════════════════════════
# Phase: revise
# ════════════════════════════════════════════════

test_case "revise: exit 2 on missing round arg"
setup_fixture
run_command "$CHECK" revise "$FIXTURE"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "revise: exit 2 on non-numeric round arg"
setup_fixture
run_command "$CHECK" revise "$FIXTURE" "abc"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "revise: FAIL when round dir does not exist"
setup_fixture
run_command "$CHECK" revise "$FIXTURE" "5"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q "round-5 directory does not exist" \
    && _record_pass || _record_fail "expected diagnostic about missing round-5"
teardown_fixture

test_case "revise: FAIL when round has no state:new issues"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/issues"
write_file ".review/round-1/issues/I-001.md" "$ISSUE_FIXED"
assert_exit 1 "$CHECK" revise "$FIXTURE" "1"
assert_stdout_contains "nothing to do"
teardown_fixture

test_case "revise: PASS when round has state:new issue"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 0 "$CHECK" revise "$FIXTURE" "1"
assert_stdout_contains "OK revise-phase entry verified"
assert_stdout_contains "1 state:new"
teardown_fixture

test_case "revise: counts multiple state:new issues correctly"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
write_file ".review/round-1/issues/I-002.md" "$(printf '%s' "$ISSUE_NEW" | sed 's/I-001/I-002/')"
write_file ".review/round-1/issues/I-003.md" "$ISSUE_FIXED"
run_command "$CHECK" revise "$FIXTURE" "1"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0"
echo "$LAST_STDOUT" | grep -q "2 state:new" \
    && _record_pass || _record_fail "expected '2 state:new' in output, got: $LAST_STDOUT"
teardown_fixture

# ════════════════════════════════════════════════
# Phase: generate-fresh
# ════════════════════════════════════════════════

test_case "generate-fresh: PASS on empty dir"
setup_fixture
assert_exit 0 "$CHECK" generate-fresh "$FIXTURE"
assert_stdout_contains "OK generate-fresh"
teardown_fixture

test_case "generate-fresh: FAIL when README.md exists"
setup_fixture
write_file "README.md" "existing"
assert_exit 1 "$CHECK" generate-fresh "$FIXTURE"
assert_stdout_contains "existing design content"
assert_stdout_contains "README.md"
teardown_fixture

test_case "generate-fresh: FAIL when modules/ has files"
setup_fixture
write_file "modules/M-001-x.md" "existing"
assert_exit 1 "$CHECK" generate-fresh "$FIXTURE"
assert_stdout_contains "REFUSE entering generate-fresh"
assert_stdout_contains "modules/"
teardown_fixture

test_case "generate-fresh: PASS when only .review/ present (allows re-bootstrap)"
setup_fixture
mkdir -p "$FIXTURE/.review/round-0"
assert_exit 0 "$CHECK" generate-fresh "$FIXTURE"
teardown_fixture

# ════════════════════════════════════════════════
# Phase: generate-evolve
# ════════════════════════════════════════════════

test_case "generate-evolve: FAIL when no .review/versions/ dir"
setup_fixture
assert_exit 1 "$CHECK" generate-evolve "$FIXTURE"
assert_stdout_contains "no prior delivery"
teardown_fixture

test_case "generate-evolve: FAIL when versions/ dir exists but empty"
setup_fixture
mkdir -p "$FIXTURE/.review/versions"
assert_exit 1 "$CHECK" generate-evolve "$FIXTURE"
assert_stdout_contains "no version files"
teardown_fixture

test_case "generate-evolve: PASS when versions/<N>.md exists"
setup_fixture
write_file ".review/versions/3.md" '---
delivery_id: 3
verdict: converged
---
# Delivery 3
'
assert_exit 0 "$CHECK" generate-evolve "$FIXTURE"
assert_stdout_contains "OK generate-evolve"
teardown_fixture

end_tests
