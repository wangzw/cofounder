#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-plan.sh"

GOOD='# Plan

```yaml
mode: from-scratch
delivery_id: 1
round: 1
plan:
  delete: []
  modify: []
  add:
    - path: "features/F-001-checkout.md"
      template: "common/templates/feature-template.md"
      description: "Checkout feature"
  keep: []
rationale: |
  initial generation
```
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 + PASS when no plan.md"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 + PASS for well-formed plan"
setup_fixture
write_file ".review/round-1/plan.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PL01: missing yaml fenced block"
setup_fixture
write_file ".review/round-1/plan.md" "# Plan
no yaml here
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "fenced"
teardown_fixture

test_case "CR-PL01: invalid mode"
setup_fixture
write_file ".review/round-1/plan.md" '```yaml
mode: bogus
delivery_id: 1
round: 1
plan:
  delete: []
  modify: []
  add: []
  keep: []
rationale: |
  x
```
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "mode"
teardown_fixture

test_case "CR-PL01: non-integer delivery_id"
setup_fixture
write_file ".review/round-1/plan.md" '```yaml
mode: from-scratch
delivery_id: not-a-number
round: 1
plan:
  delete: []
  modify: []
  add: []
  keep: []
rationale: x
```
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "delivery_id"
teardown_fixture

end_tests
