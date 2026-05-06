#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/snapshot-leaves.sh"

test_case "exit 2 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-design-xyz" 1
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-integer round"
setup_fixture
run_command "$CHECK" "$FIXTURE" "abc"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"
teardown_fixture

test_case "writes empty leaves manifest for empty bundle"
setup_fixture
run_command "$CHECK" "$FIXTURE" "1"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -f "$FIXTURE/.review/round-1/leaves-manifest.yml" ] && _record_pass || _record_fail "manifest not written"
grep -q "leaves:" "$FIXTURE/.review/round-1/leaves-manifest.yml" && _record_pass || _record_fail "missing leaves: key"
teardown_fixture

test_case "single leaf hash is stable across calls"
setup_fixture
write_file "README.md" "# Hello"
"$CHECK" "$FIXTURE" "1" >/dev/null 2>&1
hash1=$(grep -oE 'sha256: [a-f0-9]+' "$FIXTURE/.review/round-1/leaves-manifest.yml" | head -1)
"$CHECK" "$FIXTURE" "2" >/dev/null 2>&1
hash2=$(grep -oE 'sha256: [a-f0-9]+' "$FIXTURE/.review/round-2/leaves-manifest.yml" | head -1)
[ -n "$hash1" ] && [ "$hash1" = "$hash2" ] && _record_pass || _record_fail "hash differs across calls (h1=$hash1 h2=$hash2)"
teardown_fixture

test_case "hash changes when leaf content changes"
setup_fixture
write_file "README.md" "# Initial"
"$CHECK" "$FIXTURE" "1" >/dev/null 2>&1
hash1=$(grep -oE 'sha256: [a-f0-9]+' "$FIXTURE/.review/round-1/leaves-manifest.yml" | head -1)
write_file "README.md" "# Different content here"
"$CHECK" "$FIXTURE" "2" >/dev/null 2>&1
hash2=$(grep -oE 'sha256: [a-f0-9]+' "$FIXTURE/.review/round-2/leaves-manifest.yml" | head -1)
[ -n "$hash1" ] && [ -n "$hash2" ] && [ "$hash1" != "$hash2" ] && _record_pass || _record_fail "hash should change with content"
teardown_fixture

test_case "manifest enumerates module leaves"
setup_fixture
write_file "README.md" "# X"
write_file "modules/M-001-auth.md" "# auth"
write_file "modules/M-002-users.md" "# users"
"$CHECK" "$FIXTURE" "1" >/dev/null 2>&1
manifest="$FIXTURE/.review/round-1/leaves-manifest.yml"
grep -q "modules/M-001-auth.md" "$manifest" && _record_pass || _record_fail "M-001 missing from manifest"
grep -q "modules/M-002-users.md" "$manifest" && _record_pass || _record_fail "M-002 missing from manifest"
teardown_fixture

end_tests
