#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-readme.sh"

VALID_FM='---
id: SD-test
title: Test
owner: alice
status: draft
version: 0.1.0
prd_ref: na
---'

VALID_BODY='# Test Design

## Modules

- [M-001 widget](modules/M-001-widget.md)

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 widget | ✦ |
'

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-xyz-$$"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# CR-SD01 readme-shape
# ════════════════════════════════════════════════

test_case "CR-SD01: missing README.md"
setup_fixture
write_file "modules/M-001-x.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD01"
assert_stdout_contains "missing"
teardown_fixture

test_case "CR-SD01: empty bundle (no modules) flagged critical"
setup_fixture
write_file "README.md" "${VALID_FM}
${VALID_BODY}"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD01"
assert_stdout_contains "no module files"
teardown_fixture

test_case "CR-SD01: module leaf not in README"
setup_fixture
write_file "README.md" "${VALID_FM}

# Test

## Modules
(missing index)

## Feature-Module Mapping
| F | M-001 |
|---|-------|
| F-001 | ✦ |
"
write_file "modules/M-002-other.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD01"
assert_stdout_contains "M-002"
teardown_fixture

test_case "CR-SD01: api leaf not in README"
setup_fixture
write_file "README.md" "${VALID_FM}
${VALID_BODY}"
write_file "modules/M-001-widget.md" "stub"
write_file "api/API-001-widget.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD01"
assert_stdout_contains "API-001"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SDFM01 frontmatter
# ════════════════════════════════════════════════

test_case "CR-SDFM01: missing frontmatter"
setup_fixture
write_file "README.md" "# Plain README
no frontmatter
"
write_file "modules/M-001-x.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM01"
teardown_fixture

test_case "CR-SDFM01: missing required key"
setup_fixture
write_file "README.md" "---
id: SD-x
title: T
owner: a
status: d
version: 0.1
---
${VALID_BODY}"
write_file "modules/M-001-widget.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM01"
assert_stdout_contains "prd_ref"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD02 feature-module-matrix-present
# ════════════════════════════════════════════════

test_case "CR-SD02: missing matrix section"
setup_fixture
write_file "README.md" "${VALID_FM}

# Test

## Modules

- [M-001](modules/M-001-widget.md)
"
write_file "modules/M-001-widget.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD02"
assert_stdout_contains "Feature-Module Mapping"
teardown_fixture

test_case "CR-SD02: matrix has no symbols"
setup_fixture
write_file "README.md" "${VALID_FM}

# Test

## Modules

- [M-001](modules/M-001-widget.md)

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 | TBA |
"
write_file "modules/M-001-widget.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD02"
assert_stdout_contains "symbols"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD03 no-tbd-remaining
# ════════════════════════════════════════════════

test_case "CR-SD03: TODO marker"
setup_fixture
write_file "README.md" "${VALID_FM}
# Test

TODO: write the overview

## Modules

- [M-001](modules/M-001-widget.md)

## Feature-Module Mapping

| F | M-001 |
|---|-------|
| F-001 | ✦ |
"
write_file "modules/M-001-widget.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD03"
teardown_fixture

# ════════════════════════════════════════════════
# Happy path
# ════════════════════════════════════════════════

test_case "PASS on minimal valid bundle"
setup_fixture
write_file "README.md" "${VALID_FM}
${VALID_BODY}"
write_file "modules/M-001-widget.md" "stub"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
