#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-placeholder-json.sh"

test_case "exit 2 on missing design-dir arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-xyz-$$"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 on bundle with no api/ or modules/"
setup_fixture
write_file "README.md" "# x"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 on clean json blocks"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```json
{"id": "u-1", "name": "alice"}
```
'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "default mode: findings present, exits 1 (script always exits 1 on findings per guide §9.1)"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```json
{"id": "TODO", "value": "x"}
```
'
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (findings) got $LAST_EXIT"
teardown_fixture

test_case "--strict mode: exit 1 when findings present"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```json
{"placeholder": "TODO"}
```
'
run_command "$CHECK" "$FIXTURE" --strict
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (strict) got $LAST_EXIT"
teardown_fixture

test_case "scans api/ directory"
setup_fixture
write_file "api/API-001-users.md" '# Users API

```json
{"path": "<...>"}
```
'
run_command "$CHECK" "$FIXTURE" --strict
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (api scanned) got $LAST_EXIT"
teardown_fixture

end_tests
