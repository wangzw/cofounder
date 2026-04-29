#!/usr/bin/env bash
# tests/lib/test_helpers.sh — bash test framework for system-design scripts.
#
# Usage from a test runner:
#
#   #!/usr/bin/env bash
#   set -e
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/test_helpers.sh"
#
#   test_case "well-formed feature passes formal review"
#   setup_fixture
#   write_file features/F-001-checkout.md '---
#   id: F-001
#   title: Checkout
#   ...'
#   assert_exit 0 "$REPO_SCRIPTS/check-feature.sh" "$FIXTURE"
#   assert_stdout_contains "PASS"
#   teardown_fixture
#
#   end_tests   # prints summary, exits non-zero on any failure

set -uo pipefail

# ─── State ────────────────────────────────────────────────────────────

TEST_PASS=0
TEST_FAIL=0
TEST_NAMES_FAILED=()
CURRENT_TEST=""
LAST_STDOUT=""
LAST_STDERR=""
LAST_EXIT=0
FIXTURE=""

# Resolve repo paths relative to this file
_TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_ROOT="$(cd "$_TEST_LIB_DIR/.." && pwd)"
SKILL_ROOT="$(cd "$TESTS_ROOT/.." && pwd)"
REPO_SCRIPTS="$SKILL_ROOT/scripts"

# ─── Test lifecycle ───────────────────────────────────────────────────

test_case() {
    CURRENT_TEST="$1"
}

setup_fixture() {
    FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/prd-test.XXXXXX")"
}

teardown_fixture() {
    if [ -n "$FIXTURE" ] && [ -d "$FIXTURE" ]; then
        rm -rf "$FIXTURE"
    fi
    FIXTURE=""
}

write_file() {
    local rel="$1"
    local content="$2"
    local target="$FIXTURE/$rel"
    mkdir -p "$(dirname "$target")"
    printf '%s' "$content" > "$target"
}

# ─── Command runner ───────────────────────────────────────────────────

run_command() {
    # Captures stdout / stderr / exit code into LAST_* globals.
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    set +e
    "$@" >"$stdout_file" 2>"$stderr_file"
    LAST_EXIT=$?
    set -e
    LAST_STDOUT=$(cat "$stdout_file")
    LAST_STDERR=$(cat "$stderr_file")
    rm -f "$stdout_file" "$stderr_file"
}

# ─── Assertions ───────────────────────────────────────────────────────

_record_pass() {
    TEST_PASS=$((TEST_PASS + 1))
    printf '  ✓ %s\n' "$CURRENT_TEST"
}

_record_fail() {
    TEST_FAIL=$((TEST_FAIL + 1))
    TEST_NAMES_FAILED+=("$CURRENT_TEST")
    printf '  ✗ %s\n' "$CURRENT_TEST"
    printf '    %s\n' "$1"
    if [ -n "$LAST_STDOUT" ]; then
        printf '    --- stdout ---\n'
        printf '    %s\n' "$LAST_STDOUT" | sed 's/^/    /'
    fi
    if [ -n "$LAST_STDERR" ]; then
        printf '    --- stderr ---\n'
        printf '    %s\n' "$LAST_STDERR" | sed 's/^/    /'
    fi
}

assert_exit() {
    local expected="$1"
    shift
    run_command "$@"
    if [ "$LAST_EXIT" = "$expected" ]; then
        _record_pass
    else
        _record_fail "expected exit $expected, got $LAST_EXIT (cmd: $*)"
    fi
}

assert_stdout_contains() {
    local pattern="$1"
    if echo "$LAST_STDOUT" | grep -qF -- "$pattern"; then
        _record_pass
    else
        _record_fail "stdout did not contain $pattern (last command's output)"
    fi
}

assert_stdout_not_contains() {
    local pattern="$1"
    if echo "$LAST_STDOUT" | grep -qF -- "$pattern"; then
        _record_fail "stdout unexpectedly contained $pattern"
    else
        _record_pass
    fi
}

assert_stdout_eq() {
    local expected="$1"
    if [ "$LAST_STDOUT" = "$expected" ]; then
        _record_pass
    else
        _record_fail "stdout mismatch — expected $expected, got $LAST_STDOUT"
    fi
}

assert_stderr_contains() {
    local pattern="$1"
    if echo "$LAST_STDERR" | grep -qF -- "$pattern"; then
        _record_pass
    else
        _record_fail "stderr did not contain $pattern"
    fi
}

# ─── End-of-tests reporter ────────────────────────────────────────────

end_tests() {
    local total=$((TEST_PASS + TEST_FAIL))
    printf '\n%d passed, %d failed (%d total)\n' "$TEST_PASS" "$TEST_FAIL" "$total"
    if [ "$TEST_FAIL" -gt 0 ]; then
        printf 'Failing tests:\n'
        for name in "${TEST_NAMES_FAILED[@]}"; do
            printf '  - %s\n' "$name"
        done
        exit 1
    fi
    exit 0
}
