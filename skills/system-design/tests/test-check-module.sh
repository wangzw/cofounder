#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-module.sh"

VALID_MOD='---
id: M-001
title: Widget
owner: alice
status: draft
version: 0.1.0
depends_on: []
---

## Responsibilities
Holds the widget.

## Public Interfaces
- `getWidget() -> Widget`
- `update(input: WidgetInput) -> Widget`

## Data Models
- `Widget { id: str, name: str }`

## Dependencies
None.

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| input | schema check | api boundary | reject 400 |
'

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 on empty modules dir"
setup_fixture
mkdir -p "$FIXTURE/modules"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD04 monotonicity
# ════════════════════════════════════════════════

test_case "CR-SD04: gap (M-001, M-003)"
setup_fixture
write_file "modules/M-001-a.md" "$VALID_MOD"
write_file "modules/M-003-b.md" "$(printf '%s' "$VALID_MOD" | sed 's/M-001/M-003/' | sed 's/Widget/Other/g')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD04"
assert_stdout_contains "M-002"
teardown_fixture

test_case "CR-SD04: PASS for sequential 001..002"
setup_fixture
write_file "modules/M-001-a.md" "$VALID_MOD"
write_file "modules/M-002-b.md" "$(printf '%s' "$VALID_MOD" | sed 's/M-001/M-002/' | sed 's/Widget/Other/g')"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SDFM02 frontmatter
# ════════════════════════════════════════════════

test_case "CR-SDFM02: missing frontmatter"
setup_fixture
write_file "modules/M-001-a.md" "no frontmatter here"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM02"
teardown_fixture

test_case "CR-SDFM02: missing depends_on"
setup_fixture
write_file "modules/M-001-a.md" '---
id: M-001
title: T
owner: a
status: draft
version: 0.1
---

## Responsibilities
ok
## Public Interfaces
- `f() -> R`
## Data Models
- X
## Dependencies
none
## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| x | y | z | w |
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM02"
assert_stdout_contains "depends_on"
teardown_fixture

test_case "CR-SDFM02: id mismatch"
setup_fixture
write_file "modules/M-001-a.md" "$(printf '%s' "$VALID_MOD" | sed 's/^id: M-001/id: M-099/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM02"
assert_stdout_contains "match"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD06 required sections
# ════════════════════════════════════════════════

test_case "CR-SD06: missing Public Interfaces section"
setup_fixture
write_file "modules/M-001-a.md" '---
id: M-001
title: T
owner: a
status: draft
version: 0.1
depends_on: []
---

## Responsibilities
ok

## Data Models
- X

## Dependencies
none

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| x | y | z | w |
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD06"
assert_stdout_contains "Public Interfaces"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD07 module-interface-types
# ════════════════════════════════════════════════

test_case "CR-SD07: bullet without type signature"
setup_fixture
write_file "modules/M-001-a.md" "$(printf '%s' "$VALID_MOD" | sed 's|`getWidget() -> Widget`|just-a-name-no-types|')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD07"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD08 deps vs protocols
# ════════════════════════════════════════════════

test_case "CR-SD08: depends_on entry missing from Dependencies section"
setup_fixture
write_file "modules/M-001-a.md" '---
id: M-001
title: T
owner: a
status: draft
version: 0.1
depends_on: [M-002]
---

## Responsibilities
ok

## Public Interfaces
- `f() -> R`

## Data Models
- X

## Dependencies
None.

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| x | y | z | w |
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD08"
assert_stdout_contains "M-002"
teardown_fixture

test_case "CR-SD08: dependency mentioned but no protocol"
setup_fixture
write_file "modules/M-001-a.md" '---
id: M-001
title: T
owner: a
status: draft
version: 0.1
depends_on: [M-002]
---

## Responsibilities
ok

## Public Interfaces
- `f() -> R`

## Data Models
- X

## Dependencies
- M-002 used somehow but no signature mentioned plainly

## Boundary Enforcement

| Boundary | Mechanism | Enforced At | Failure Mode |
|----------|-----------|-------------|--------------|
| x | y | z | w |
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD08"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD09 boundary-enforcement-cols
# ════════════════════════════════════════════════

test_case "CR-SD09: missing 'Mechanism' column"
setup_fixture
write_file "modules/M-001-a.md" '---
id: M-001
title: T
owner: a
status: draft
version: 0.1
depends_on: []
---

## Responsibilities
ok
## Public Interfaces
- `f() -> R`
## Data Models
- X
## Dependencies
none
## Boundary Enforcement

| Boundary | Enforced At | Failure Mode |
|----------|-------------|--------------|
| x | y | z |
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD09"
assert_stdout_contains "Mechanism"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD03 placeholders
# ════════════════════════════════════════════════

test_case "CR-SD03: TODO inside module body"
setup_fixture
write_file "modules/M-001-a.md" "$(printf '%s' "$VALID_MOD" | sed 's/Holds the widget./Holds the widget. TODO confirm./')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD03"
teardown_fixture

# ════════════════════════════════════════════════
# Happy path
# ════════════════════════════════════════════════

test_case "PASS on a single valid module"
setup_fixture
write_file "modules/M-001-a.md" "$VALID_MOD"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
