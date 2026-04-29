#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-clarification.sh"

GOOD='SKILL_NAME: "system-design"
SKILL_VERSION: "0.1.0"
SKILL_DESCRIPTION: "Use when ..."
ARTIFACT_ROOT: "docs/raw/prd/test/"

clarification_at: "2026-04-29T00:00:00Z"
normalized_requirements:
  R-001:
    status: confirmed
  R-002:
    status: confirmed
  R-003:
    status: confirmed
  R-004:
    status: deferred
  R-005:
    status: deferred
  R-006:
    status: deferred
  R-007:
    status: confirmed
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 + PASS when no clarification dir"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 0 + PASS for well-formed clarification"
setup_fixture
write_file ".review/round-0/clarification/2026-04-29.yml" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-CL01: missing flat key"
setup_fixture
write_file ".review/round-0/clarification/x.yml" 'SKILL_NAME: "x"
SKILL_VERSION: "1"
ARTIFACT_ROOT: "docs/"
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "SKILL_DESCRIPTION"
teardown_fixture

test_case "CR-CL02: flat key after nested block"
setup_fixture
write_file ".review/round-0/clarification/x.yml" 'SKILL_NAME: "x"
normalized_requirements:
  R-001:
    status: confirmed
  R-002:
    status: confirmed
  R-003:
    status: confirmed
  R-004:
    status: confirmed
  R-005:
    status: confirmed
  R-006:
    status: confirmed
  R-007:
    status: confirmed
SKILL_VERSION: "1"
SKILL_DESCRIPTION: "x"
ARTIFACT_ROOT: "docs/"
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-CL02"
teardown_fixture

test_case "CR-CL01: missing R-NNN entry"
setup_fixture
write_file ".review/round-0/clarification/x.yml" 'SKILL_NAME: "x"
SKILL_VERSION: "1"
SKILL_DESCRIPTION: "x"
ARTIFACT_ROOT: "docs/"

normalized_requirements:
  R-001:
    status: confirmed
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "R-002"
teardown_fixture

end_tests
