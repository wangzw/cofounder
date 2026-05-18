#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-single-source-of-truth.sh"

test_case "exit 2 on missing design-dir arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-xyz-$$"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 0 on bundle without modules"
setup_fixture
write_file "README.md" "# x"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 when each type appears in only one file"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```ts
interface User {
  id: string;
}
```
'
write_file "modules/M-002-orders.md" '# Orders

## Data Models

```ts
interface Order {
  id: string;
}
```
'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 on identical type with excerpt-from marker"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```ts
interface User {
  id: string;
}
```
'
write_file "modules/M-002-orders.md" '# Orders

## Data Models

<!-- excerpt-from: M-001-auth -->
```ts
interface User {
  id: string;
}
```
'
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

# Duplication-detection tests. The extractor was previously gated by gawk's
# 3-arg match() but has been rewritten to use the portable 2-arg form, so the
# checker now runs on BSD awk (macOS) and gawk (Linux) alike.
test_case "--strict: exit 1 when type duplicated without excerpt marker"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```ts
interface User {
  id: string;
}
```
'
write_file "modules/M-002-orders.md" '# Orders

## Data Models

```ts
interface User {
  id: string;
}
```
'
run_command "$CHECK" "$FIXTURE" --strict
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (strict missing-marker) got $LAST_EXIT"
teardown_fixture

test_case "--strict: exit 1 on content divergence"
setup_fixture
write_file "modules/M-001-auth.md" '# Auth

## Data Models

```ts
interface User {
  id: string;
}
```
'
write_file "modules/M-002-orders.md" '# Orders

## Data Models

<!-- excerpt-from: M-001-auth -->
```ts
interface User {
  id: number;
}
```
'
run_command "$CHECK" "$FIXTURE" --strict
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (strict divergence) got $LAST_EXIT"
teardown_fixture

end_tests
