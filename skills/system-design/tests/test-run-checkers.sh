#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/run-checkers.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# Helper to write a minimum-valid system-design bundle (passes all dispatched checkers)
write_minimal_valid_design() {
    write_file "README.md" '---
id: SD-test
title: Test
owner: alice
status: draft
version: 0.1
prd_ref: na
---

# Test

## Modules
- [M-001](modules/M-001-widget.md)

## Feature-Module Mapping

| Feature | M-001 |
|---------|-------|
| F-001 a | ✦ |
'
    write_file "modules/M-001-widget.md" '---
id: M-001
title: Widget
owner: alice
status: draft
version: 0.1
depends_on: []
---

# Widget

## Responsibilities
- a
- b

## Public Interfaces

```typescript
export type WidgetId = string;
```

## Data Models
- WidgetId

## Dependencies
- none

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| n/a | n/a | n/a | n/a |
'
}

test_case "exit 0 + PASS on minimal-valid design"
setup_fixture
write_minimal_valid_design
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "PASS line includes checker count"
setup_fixture
write_minimal_valid_design
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "formal-review checker(s)"
teardown_fixture

test_case "exit 1 + FOUND with aggregated JSON on bad design"
setup_fixture
write_file "README.md" "# TODO: write design overview"
write_file "modules/M-002-x.md" '---
id: M-002
title: x
status: draft
---

# x
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "FOUND"
assert_stdout_contains "issues"
assert_stdout_contains "criterion_id"
teardown_fixture

test_case "aggregates findings from multiple checkers"
setup_fixture
write_file "README.md" "TODO: x"
write_file "modules/M-002-x.md" '---
id: M-002
title: x
status: draft
---

# x
'
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1"
# Should contain findings from both check-readme (CR-SD03/CR-SDFM01) and check-module (CR-SD04 / CR-SDFM02)
echo "$LAST_STDOUT" | grep -q "CR-SD" && _record_pass || _record_fail "missing CR-SD findings"
echo "$LAST_STDOUT" | grep -q "CR-SD04\|CR-SDFM02" && _record_pass || _record_fail "missing CR-SD04/CR-SDFM02"
teardown_fixture

test_case "phase gates excluded from dispatch"
# run-checkers.sh should NOT invoke check-review-readiness or check-revise-completeness
# (those have different argument shapes and orchestration semantics).
setup_fixture
write_minimal_valid_design
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "phase gates leaked into dispatch (exit=$LAST_EXIT)"
teardown_fixture

test_case "idempotent — same input → identical output"
setup_fixture
write_file "README.md" "TODO: x"
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
