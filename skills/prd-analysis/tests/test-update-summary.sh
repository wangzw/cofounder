#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/update-summary.sh"

ISSUE_NEW='---
id: I-001
criterion_id: CR-PP01
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
criterion_id: CR-PP02
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
