#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-feature-module-mapping.sh"

VALID_README='---
id: SD-test
title: Test
owner: alice
status: draft
version: 0.1
prd_ref: na
---

# Test

## Modules
- [M-001](modules/M-001-x.md)

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 a | ✦ |
'

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on bad flag"
setup_fixture
run_command "$CHECK" "$FIXTURE" --bogus
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD05 module coverage
# ════════════════════════════════════════════════

test_case "CR-SD05: module declared but missing from matrix"
setup_fixture
write_file "README.md" "$VALID_README"
write_file "modules/M-001-x.md" "stub"
write_file "modules/M-002-y.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD05"
assert_stdout_contains "M-002"
teardown_fixture

test_case "CR-SD05: PASS when all modules in matrix"
setup_fixture
write_file "README.md" "$VALID_README"
write_file "modules/M-001-x.md" "stub"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

# ════════════════════════════════════════════════
# Matrix structural problems
# ════════════════════════════════════════════════

test_case "CR-SD05: missing matrix section"
setup_fixture
write_file "README.md" "---
id: a
title: t
owner: a
status: d
version: 0.1
prd_ref: na
---
# x
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD05"
assert_stdout_contains "Feature-Module Mapping"
teardown_fixture

test_case "CR-SD05: matrix without M-NNN header"
setup_fixture
write_file "README.md" "---
id: a
title: t
owner: a
status: d
version: 0.1
prd_ref: na
---
# x

## Feature-Module Mapping

| Feature | Service |
|---------|---------|
| F-001 | ✦ |
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD05"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD05 feature coverage (with PRD)
# ════════════════════════════════════════════════

test_case "CR-SD05: PRD feature missing ✦ allocation"
setup_fixture
mkdir -p "$FIXTURE/prd/features"
write_file "prd/features/F-001-a.md" "stub"
write_file "prd/features/F-002-b.md" "stub"
write_file "README.md" "$VALID_README"
write_file "modules/M-001-x.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE" --prd-dir "$FIXTURE/prd"
assert_stdout_contains "CR-SD05"
assert_stdout_contains "F-002"
teardown_fixture

test_case "CR-SD05: PASS when all PRD features have ✦"
setup_fixture
mkdir -p "$FIXTURE/prd/features"
write_file "prd/features/F-001-a.md" "stub"
write_file "README.md" "$VALID_README"
write_file "modules/M-001-x.md" "stub"
assert_exit 0 "$CHECK" "$FIXTURE" --prd-dir "$FIXTURE/prd"
teardown_fixture

test_case "CR-SD05: feature with only △ flagged (needs ✦)"
setup_fixture
mkdir -p "$FIXTURE/prd/features"
write_file "prd/features/F-001-a.md" "stub"
write_file "README.md" '---
id: a
title: t
owner: a
status: d
version: 0.1
prd_ref: na
---

# t

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 | △ |
'
write_file "modules/M-001-x.md" "stub"
assert_exit 1 "$CHECK" "$FIXTURE" --prd-dir "$FIXTURE/prd"
assert_stdout_contains "CR-SD05"
teardown_fixture

# ════════════════════════════════════════════════
# state.yml-based prd_ref
# ════════════════════════════════════════════════

test_case "PRD path resolved from .review/state.yml"
setup_fixture
mkdir -p "$FIXTURE/prd/features"
write_file "prd/features/F-001-a.md" "stub"
write_file "README.md" "$VALID_README"
write_file "modules/M-001-x.md" "stub"
write_file ".review/state.yml" "prd_ref: prd
"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

end_tests
