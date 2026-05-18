#!/usr/bin/env bash
# Tests for scripts/check-dependency-layering.sh (CR-X6).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-dependency-layering.sh"

write_module() {
  local id="$1"
  local deps_block="$2"
  write_file "modules/${id}-x.md" "---
id: ${id}
---

# ${id}

## Dependencies

${deps_block}
"
}

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# CR-X6 — forward-only layering
# ════════════════════════════════════════════════

test_case "CR-X6: PASS for forward-only deps (M-001 layer-1 → no deps; M-002 layer-2 → M-001)"
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
| 2 | M-002 |
'
write_module "M-001" "(none)"
write_module "M-002" "- M-001"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "CR-X6: blocker on reverse import (lower layer importing higher layer)"
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
| 2 | M-002 |
'
write_module "M-001" "- M-002"
write_module "M-002" "(none)"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD16"
teardown_fixture

test_case "CR-X6: blocker when module is missing from Dependency Layering table"
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
'
write_module "M-001" "- M-002"
write_module "M-002" "(none)"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "M-002"
teardown_fixture

# ════════════════════════════════════════════════
# CR-X6 — inbound-block exclusion (parser-bug regression)
# ════════════════════════════════════════════════
#
# The module template structures `## Dependencies` as two bold-paragraph
# sub-blocks: `**Depends on (outbound):**` and `**Depended on by
# (inbound):**`. Naive M-NNN extraction over the whole section would treat
# the inbound list as outbound deps and produce mass false-positive
# reverse-layer findings (chaos round-1 saw 34 such issues — all from this
# same parsing bug, all "fixed" by writers moving the inbound list out of
# `## Dependencies` as a workaround).
test_case "CR-X6: inbound bold-paragraph sub-block must NOT be treated as outbound deps"
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
| 2 | M-002 |
'
write_file "modules/M-001-x.md" "---
id: M-001
---

# M-001

## Dependencies

**Depends on (outbound):** none.

**Depended on by (inbound):**
- M-002 — calls M-001 to do its job
"
write_module "M-002" "- M-001"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "CR-X6: lowercase outbound marker after inbound still exits exclusion"
# Regression: tolower-based inbound matching combined with case-sensitive
# exit-marker check would leave in_excluded=1 forever for writers who use
# lowercase headers, silently swallowing the outbound deps section.
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
| 2 | M-002 |
'
write_file "modules/M-001-x.md" "---
id: M-001
---

# M-001

## Dependencies

**inbound:**
- M-002 — call site (must NOT trigger reverse-layer)

**outbound:** none.
"
write_module "M-002" "- M-001"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "CR-X6: 'Inbound:' bold marker also excluded"
setup_fixture
write_file "README.md" '# Design

## Dependency Layering

| Layer | Modules |
|-------|---------|
| 1 | M-001 |
| 2 | M-002 |
'
write_file "modules/M-001-x.md" "---
id: M-001
---

# M-001

## Dependencies

**Outbound:** none.

**Inbound:**
- M-002 — caller
"
write_module "M-002" "- M-001"
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

end_tests
