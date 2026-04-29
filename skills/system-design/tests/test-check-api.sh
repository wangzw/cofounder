#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-api.sh"

VALID_API='---
id: API-001
title: Widget API
owner: alice
status: draft
version: 0.1.0
module_ref: M-001
---

# Widget API

## Surface

| Endpoint | Method | Auth | Idempotent |
|----------|--------|------|------------|
| /widgets | GET | bearer | yes |

## Endpoints

### List widgets

Method: GET
Path: /widgets
Request: query params `limit`
Response: `Widget[]`
Errors: 401, 500
'

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "PASS when api/ dir does not exist"
setup_fixture
write_file "README.md" "# x"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD10 monotonicity
# ════════════════════════════════════════════════

test_case "CR-SD10: gap in API ids"
setup_fixture
write_file "api/API-001-a.md" "$VALID_API"
write_file "api/API-003-b.md" "$(printf '%s' "$VALID_API" | sed 's/API-001/API-003/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD10"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SDFM03 frontmatter
# ════════════════════════════════════════════════

test_case "CR-SDFM03: missing module_ref"
setup_fixture
write_file "api/API-001-a.md" "$(printf '%s' "$VALID_API" | grep -v '^module_ref:')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM03"
assert_stdout_contains "module_ref"
teardown_fixture

test_case "CR-SDFM03: id mismatch"
setup_fixture
write_file "api/API-001-a.md" "$(printf '%s' "$VALID_API" | sed 's/^id: API-001/id: API-099/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SDFM03"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD11 per-endpoint blocks
# ════════════════════════════════════════════════

test_case "CR-SD11: endpoint missing 'Errors' slot"
setup_fixture
write_file "api/API-001-a.md" '---
id: API-001
title: T
owner: a
status: draft
version: 0.1
module_ref: M-001
---

## Surface

| Endpoint | Method | Auth | Idempotent |
|----------|--------|------|------------|
| /x | GET | none | yes |

## Endpoints

### Get x

Method: GET
Path: /x
Request: none
Response: ok
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD11"
assert_stdout_contains "Errors"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD12 surface columns
# ════════════════════════════════════════════════

test_case "CR-SD12: missing 'Auth' column"
setup_fixture
write_file "api/API-001-a.md" '---
id: API-001
title: T
owner: a
status: draft
version: 0.1
module_ref: M-001
---

## Surface

| Endpoint | Method | Idempotent |
|----------|--------|------------|
| /x | GET | yes |

## Endpoints

### Get x

Method: GET
Path: /x
Request: none
Response: ok
Errors: 500
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD12"
assert_stdout_contains "Auth"
teardown_fixture

test_case "CR-SD12: missing Surface section entirely"
setup_fixture
write_file "api/API-001-a.md" '---
id: API-001
title: T
owner: a
status: draft
version: 0.1
module_ref: M-001
---

## Endpoints

### Get x

Method: GET
Path: /x
Request: none
Response: ok
Errors: 500
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD12"
teardown_fixture

# ════════════════════════════════════════════════
# CR-SD13 endpoint-literal-vs-api
# ════════════════════════════════════════════════

test_case "CR-SD13: module references endpoint not declared in any api/"
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
calls POST /widgets/import to bulk-import data
'
write_file "api/API-001-a.md" "$VALID_API"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD13"
assert_stdout_contains "POST /widgets/import"
teardown_fixture

test_case "CR-SD13: PASS when module endpoint is declared"
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
queries GET /widgets to list them
'
write_file "api/API-001-a.md" "$VALID_API"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ════════════════════════════════════════════════
# Happy path
# ════════════════════════════════════════════════

test_case "PASS on a single valid API"
setup_fixture
write_file "api/API-001-a.md" "$VALID_API"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
