#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-version.sh"

GOOD='---
delivery_id: 1
round: 5
git_sha: abc123def
verdict: converged
rounds_to_convergence: 5
quality_at_delivery:
  total_issues: 0
  new_count: 0
justified_regressions: []
---

# Delivery 1 Summary
x
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 when no versions/ dir"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 for well-formed version"
setup_fixture
write_file ".review/versions/5.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-VS01: missing required field"
setup_fixture
write_file ".review/versions/5.md" '---
round: 5
verdict: converged
---

x
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "delivery_id"
teardown_fixture

test_case "CR-VS02: verdict not converged"
setup_fixture
BAD=$(printf '%s' "$GOOD" | sed 's/verdict: converged/verdict: progressing/')
write_file ".review/versions/5.md" "$BAD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-VS02"
teardown_fixture

test_case "CR-VS01: missing quality_at_delivery"
setup_fixture
write_file ".review/versions/5.md" '---
delivery_id: 1
round: 5
git_sha: abc
verdict: converged
rounds_to_convergence: 5
justified_regressions: []
---

x
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "quality_at_delivery"
teardown_fixture

end_tests
