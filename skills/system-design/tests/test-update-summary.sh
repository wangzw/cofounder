#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/update-summary.sh"

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
fix it
'

ISSUE_DEFERRED='---
id: I-002
criterion_id: CR-SD04
file: features/F-001.md
severity: warning
state: deferred
defer_until: round-5
defer_reason: scope-overflow
created_in_round: 1
---

## Description
deferred problem

## Suggested fix
fix later
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + OK when no .review history"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "OK"
teardown_fixture

test_case "writes summary.yml when issues exist"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
assert_exit 0 "$CHECK" "$FIXTURE"
[ -f "$FIXTURE/.review/issues/summary.yml" ] && _record_pass || _record_fail "summary.yml not written"
teardown_fixture

test_case "summary.yml contains all issues across rounds"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
write_file ".review/round-2/issues/I-002.md" "$ISSUE_DEFERRED"
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "I-001" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "I-001 missing from summary"
grep -q "I-002" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "I-002 missing from summary"
teardown_fixture

test_case "summary records state correctly"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
write_file ".review/round-1/issues/I-002.md" "$ISSUE_DEFERRED"
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "state: new" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "state new not recorded"
grep -q "state: deferred" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "state deferred not recorded"
teardown_fixture

test_case "summary records defer_until and defer_reason"
setup_fixture
write_file ".review/round-1/issues/I-002.md" "$ISSUE_DEFERRED"
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "defer_until: round-5" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "defer_until missing"
grep -q "scope-overflow" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "defer_reason missing"
teardown_fixture

test_case "summary records last_seen_in_round"
setup_fixture
write_file ".review/round-3/issues/I-001.md" "$(printf '%s' "$ISSUE_NEW" | sed 's/created_in_round: 1/created_in_round: 3/')"
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "last_seen_in_round: 3" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "last_seen_in_round missing"
teardown_fixture

test_case "exit 1 on malformed issue file"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "no frontmatter at all"
assert_exit 1 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "summary records history list per issue"
setup_fixture
write_file ".review/round-2/issues/I-001.md" '---
id: I-001
criterion_id: CR-SD01
file: README.md
severity: error
state: fixed
created_in_round: 1
fixed_in_round: 2
history:
  - {round: 1, action: created}
  - {round: 2, action: state-change, from: new, to: fixed}
fix_history: []
---

## Description
some problem

## Suggested fix
fix it
'
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "history:" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "history block missing"
grep -q "action: created" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "history entries missing"
grep -q "state-change" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "state-change history missing"
teardown_fixture

test_case "summary records fix_history list per issue"
setup_fixture
write_file ".review/round-3/issues/I-002.md" '---
id: I-002
criterion_id: CR-SD01
file: README.md
severity: error
state: fixed
created_in_round: 2
fixed_in_round: 3
recurrence_of: I-001
recurrence_count: 1
history:
  - {round: 2, action: created}
fix_history:
  - {round: 3, summary: "rewrote AC#2 with explicit Given block"}
---

## Description
recurred problem

## Suggested fix
fix again
'
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "fix_history:" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "fix_history block missing"
grep -q "rewrote AC#2" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "fix_history entries missing"
teardown_fixture

test_case "summary records recurrence_of and recurrence_count"
setup_fixture
write_file ".review/round-2/issues/I-002.md" '---
id: I-002
criterion_id: CR-SD01
file: README.md
severity: error
state: new
created_in_round: 2
recurrence_of: I-001
recurrence_count: 2
---

## Description
keeps coming back

## Suggested fix
investigate root cause
'
assert_exit 0 "$CHECK" "$FIXTURE"
grep -q "recurrence_of: I-001" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "recurrence_of missing"
grep -q "recurrence_count:" "$FIXTURE/.review/issues/summary.yml" && _record_pass || _record_fail "recurrence_count missing"
teardown_fixture

test_case "idempotent — running twice produces same summary"
setup_fixture
write_file ".review/round-1/issues/I-001.md" "$ISSUE_NEW"
run_command "$CHECK" "$FIXTURE"
out1=$(cat "$FIXTURE/.review/issues/summary.yml" | grep -v "generated_at:")
run_command "$CHECK" "$FIXTURE"
out2=$(cat "$FIXTURE/.review/issues/summary.yml" | grep -v "generated_at:")
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic summary"
teardown_fixture

end_tests
