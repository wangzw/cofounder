#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-journey.sh"

GOOD='---
id: J-001
title: Onboarding
persona: New user
---

# Onboarding journey
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + PASS when no journeys/ dir"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 0 + PASS for well-formed journey"
setup_fixture
write_file "journeys/J-001-x.md" "$GOOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "CR-PP02 detects bad filename"
setup_fixture
write_file "journeys/onboarding.md" "$GOOD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP02"
teardown_fixture

test_case "CR-PP02 detects duplicate id"
setup_fixture
write_file "journeys/J-001-a.md" "$GOOD"
write_file "journeys/J-001-b.md" "$GOOD"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "duplicate journey id J-001"
teardown_fixture

test_case "CR-PP02 detects gap"
setup_fixture
write_file "journeys/J-001-x.md" "$GOOD"
write_file "journeys/J-003-y.md" "$(printf '%s' "$GOOD" | sed 's/J-001/J-003/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "gap in journey ids"
teardown_fixture

test_case "CR-FM01 missing required field"
setup_fixture
write_file "journeys/J-001-x.md" '---
id: J-001
title: x
---

content
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "persona"
teardown_fixture

test_case "CR-FM01 missing frontmatter"
setup_fixture
write_file "journeys/J-001-x.md" "# Just a title"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "missing leading frontmatter"
teardown_fixture

test_case "CR-PP04 detects FIXME"
setup_fixture
write_file "journeys/J-001-x.md" '---
id: J-001
title: x
persona: y
---

FIXME: still need detail
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP04"
teardown_fixture

end_tests
