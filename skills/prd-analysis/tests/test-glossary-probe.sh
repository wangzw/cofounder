#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/glossary-probe.sh"
PREP="$REPO_SCRIPTS/prepare-input.sh"

# Use prd-analysis's own glossary as the test glossary
GLOSSARY="$SKILL_ROOT/common/domain-glossary.md"

test_case "exit 1 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"

test_case "writes trigger-flags.yml with required fields"
setup_fixture
mkdir -p "$FIXTURE/.review"
"$PREP" "Build a CLI tool" "$FIXTURE/.review" >/dev/null 2>&1
run_command "$CHECK" "$FIXTURE/.review" "$GLOSSARY"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-0/trigger-flags.yml" ] && _record_pass || _record_fail "trigger-flags.yml not written"
grep -q "glossary_hit" "$FIXTURE/.review/round-0/trigger-flags.yml" && _record_pass || _record_fail "glossary_hit field missing"
grep -q "sparse_input" "$FIXTURE/.review/round-0/trigger-flags.yml" && _record_pass || _record_fail "sparse_input field missing"
teardown_fixture

test_case "sparse_input flag set on tiny prompt"
setup_fixture
mkdir -p "$FIXTURE/.review"
"$PREP" "Make a thing" "$FIXTURE/.review" >/dev/null 2>&1
run_command "$CHECK" "$FIXTURE/.review" "$GLOSSARY"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0"
grep -qE "sparse_input:\s*true" "$FIXTURE/.review/round-0/trigger-flags.yml" && _record_pass || _record_fail "sparse_input not true on tiny prompt"
teardown_fixture

test_case "honors --bootstrap-subdir flag"
setup_fixture
mkdir -p "$FIXTURE/.review"
"$PREP" --bootstrap-subdir round-3 "Update v2" "$FIXTURE/.review" >/dev/null 2>&1
run_command "$CHECK" --bootstrap-subdir round-3 "$FIXTURE/.review" "$GLOSSARY"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-3/trigger-flags.yml" ] && _record_pass || _record_fail "trigger-flags.yml not in round-3"
teardown_fixture

end_tests
