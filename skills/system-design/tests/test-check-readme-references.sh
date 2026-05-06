#!/usr/bin/env bash
# Tests for scripts/check-readme-references.sh (CR-X8).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-readme-references.sh"

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# CR-X8 — broken link detection
# ════════════════════════════════════════════════

test_case "CR-X8: blocker on missing module file"
setup_fixture
write_file "README.md" '# Design

## Modules

- [M-001](modules/M-001-x.md)
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD18"
assert_stdout_contains "M-001-x.md"
teardown_fixture

test_case "CR-X8: PASS when all referenced files exist"
setup_fixture
write_file "README.md" '# Design

## Modules

- [M-001](modules/M-001-x.md)
'
write_file "modules/M-001-x.md" 'stub'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "CR-X8: external URLs are skipped"
setup_fixture
write_file "README.md" '# Design

See [docs](https://example.com/docs).
See [mailto](mailto:foo@bar.com).
'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "CR-X8: anchor-only links are skipped"
setup_fixture
write_file "README.md" '# Design

[jump](#section)
'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

end_tests
