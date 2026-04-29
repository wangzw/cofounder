#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/synthesize-clarification.sh"

test_case "exit 1 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"

test_case "exit 1 on partial args"
run_command "$CHECK" "/tmp" "name"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"

test_case "exit 2 on non-existent prd-dir"
run_command "$CHECK" "/nonexistent-dir-xyz" "name" "1.0.0" "desc" "docs/raw"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "writes clarification yml with required flat keys"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE" "test-skill" "0.1.0" "Use when testing" "docs/raw/test/"
out=$(ls "$FIXTURE/.review/round-0/clarification/"*.yml | head -1)
[ -f "$out" ] && _record_pass || _record_fail "clarification yml not created"
grep -q '^SKILL_NAME: "test-skill"' "$out" && _record_pass || _record_fail "SKILL_NAME missing"
grep -q '^SKILL_VERSION:' "$out" && _record_pass || _record_fail "SKILL_VERSION missing"
grep -q '^SKILL_DESCRIPTION:' "$out" && _record_pass || _record_fail "SKILL_DESCRIPTION missing"
grep -q '^ARTIFACT_ROOT:' "$out" && _record_pass || _record_fail "ARTIFACT_ROOT missing"
teardown_fixture

test_case "all R-001..R-007 entries set to deferred"
setup_fixture
"$CHECK" "$FIXTURE" "x" "0.1" "y" "docs/" >/dev/null
out=$(ls "$FIXTURE/.review/round-0/clarification/"*.yml | head -1)
for r in R-001 R-002 R-003 R-004 R-005 R-006 R-007; do
  grep -q "  $r:" "$out" && _record_pass || _record_fail "$r missing"
done
deferred_count=$(grep -c "status: deferred" "$out")
[ "$deferred_count" = "7" ] && _record_pass || _record_fail "expected 7 deferred status, got $deferred_count"
teardown_fixture

test_case "output passes check-clarification.sh schema"
setup_fixture
"$CHECK" "$FIXTURE" "x" "0.1.0" "Use when testing" "docs/raw/x/" >/dev/null
run_command "$REPO_SCRIPTS/check-clarification.sh" "$FIXTURE"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "synthesized clarification failed schema check: $LAST_STDOUT"
teardown_fixture

test_case "flat keys appear before any nested block"
setup_fixture
"$CHECK" "$FIXTURE" "x" "0.1" "y" "docs/" >/dev/null
out=$(ls "$FIXTURE/.review/round-0/clarification/"*.yml | head -1)
# First flat key (line 1) should be one of the four flat keys; first
# indented line should appear AFTER all four flat keys
flat_lines=$(grep -nE '^(SKILL_NAME|SKILL_VERSION|SKILL_DESCRIPTION|ARTIFACT_ROOT|clarification_at|synthesized_via):' "$out" | head -6 | tail -1 | cut -d: -f1)
first_indent=$(grep -nE '^\s+\S' "$out" | head -1 | cut -d: -f1)
[ "$flat_lines" -lt "$first_indent" ] && _record_pass || _record_fail "flat keys not before nested block"
teardown_fixture

end_tests
