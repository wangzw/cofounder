#!/usr/bin/env bash
# Tests for scripts/check-architecture-coverage.sh (CR-X3).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-architecture-coverage.sh"

setup_design_with_prd() {
  setup_fixture
  mkdir -p "$FIXTURE/design" "$FIXTURE/prd/architecture"
}

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# CR-X3 — architecture-coverage
# ════════════════════════════════════════════════

test_case "CR-X3: blocker when architecture file missing from Implementation Conventions"
setup_design_with_prd
write_file "prd/architecture/data-models.md" '# Data Models'
write_file "prd/architecture/auth-model.md" '# Auth Model'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Implementation Conventions

| Category | Source PRD file | Conformance |
|----------|-----------------|-------------|
| Data | architecture/data-models.md | adopted |
'
assert_exit 1 "$CHECK" "$FIXTURE/design"
assert_stdout_contains "CR-SD14"
assert_stdout_contains "auth-model.md"
teardown_fixture

test_case "CR-X3: PASS when every architecture file is referenced"
setup_design_with_prd
write_file "prd/architecture/data-models.md" '# Data Models'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Implementation Conventions

| Category | Source PRD file | Conformance |
|----------|-----------------|-------------|
| Data | architecture/data-models.md | adopted |
'
assert_exit 0 "$CHECK" "$FIXTURE/design"
teardown_fixture

test_case "CR-X3: PASS when N/A — note explicitly cites the file"
setup_design_with_prd
write_file "prd/architecture/i18n.md" '# i18n'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Implementation Conventions

N/A — architecture/i18n.md (single-language MVP, deferred)

| Category | Source PRD file | Conformance |
|----------|-----------------|-------------|
'
assert_exit 0 "$CHECK" "$FIXTURE/design"
teardown_fixture

# ════════════════════════════════════════════════
# Skip behavior
# ════════════════════════════════════════════════

test_case "skip when PRD path unresolvable"
setup_fixture
mkdir -p "$FIXTURE/design"
write_file "design/README.md" '# Design

## Implementation Conventions
'
assert_exit 0 "$CHECK" "$FIXTURE/design"
teardown_fixture

end_tests
