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

# ════════════════════════════════════════════════
# Regression: silent-exit-1 from grep -oE no-match under pipefail
# (bug 2026-05-06-check-readme-references-silent-exit.md)
# A README line that contains `(` but no markdown link must NOT make
# the script abort silently before _finalize.
# ════════════════════════════════════════════════

test_case "regression: line with stray '(' but no link → PASS, not silent exit 1"
setup_fixture
write_file "README.md" '---
title: Test
---
# Test

This README has no links and no violations.
A line with a paren (but no link) at the end.
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "regression: violations still emitted when README also has stray '(' lines"
setup_fixture
write_file "README.md" '# Design

## Modules

- [M-001](modules/M-001-x.md)
- [M-002](modules/M-002-y.md)

**Review Required**: Yes (pending formal pre-check and self-review)
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "M-001-x.md"
assert_stdout_contains "M-002-y.md"
teardown_fixture

end_tests
