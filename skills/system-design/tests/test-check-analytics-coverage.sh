#!/usr/bin/env bash
# Tests for scripts/check-analytics-coverage.sh (CR-X4).
#
# Critical regression coverage: PRD feature template emits
# `### Analytics & Tracking` (level-3); the script's section detector
# MUST match that, not the legacy `## Analytics` (level-2). Rounds 1-2
# audit found this silently no-op-ing on every real PRD.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-analytics-coverage.sh"

# Build a fixture: a design dir whose README points at a sibling PRD dir.
# $FIXTURE/design/  — design-dir under test
# $FIXTURE/prd/     — sibling PRD with features/F-001-x.md emitting one event
setup_design_with_prd() {
  setup_fixture
  mkdir -p "$FIXTURE/design" "$FIXTURE/prd/features"
}

# ════════════════════════════════════════════════
# Arg validation
# ════════════════════════════════════════════════

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on missing design-dir"
run_command "$CHECK" "/nonexistent/path"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

# ════════════════════════════════════════════════
# CR-X4: regression — must detect level-3 ### Analytics & Tracking
# ════════════════════════════════════════════════

test_case "CR-X4: detects ### Analytics & Tracking and reports gap when README missing event"
setup_design_with_prd
write_file "prd/features/F-001-checkout.md" '---
id: F-001
title: Checkout
---

# F-001 Checkout

### Analytics & Tracking

| Event | Trigger | Payload | Purpose |
|-------|---------|---------|---------|
| checkout_started | user clicks Buy | order_id | conversion |
'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Analytics Coverage

| Feature | Event | Trigger | Emitting Channel | Responsible Module |
|---------|-------|---------|------------------|--------------------|
'
assert_exit 1 "$CHECK" "$FIXTURE/design"
assert_stdout_contains "CR-SD15"
assert_stdout_contains "checkout_started"
teardown_fixture

test_case "CR-X4: PASS when ### Analytics & Tracking event is covered"
setup_design_with_prd
write_file "prd/features/F-001-checkout.md" '---
id: F-001
title: Checkout
---

### Analytics & Tracking

| Event | Trigger | Payload | Purpose |
|-------|---------|---------|---------|
| checkout_started | click | order_id | conversion |
'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Analytics Coverage

| Feature | Event | Trigger | Emitting Channel | Responsible Module |
|---------|-------|---------|------------------|--------------------|
| F-001 | checkout_started | click | M-001 | M-001 |
'
assert_exit 0 "$CHECK" "$FIXTURE/design"
teardown_fixture

test_case "CR-X4: legacy ## Analytics (level-2) is NOT used as section detector"
# This negative test proves the parser binds to level-3, not level-2.
# A feature using only the legacy ## Analytics heading should yield zero
# extracted events (events are skipped because the wrong-level section
# is never entered) → result is PASS with no coverage gap reported,
# even when the README's Analytics Coverage table is empty.
setup_design_with_prd
write_file "prd/features/F-001-x.md" '---
id: F-001
---

## Analytics

| Event | Trigger | Payload | Purpose |
|-------|---------|---------|---------|
| legacy_event | x | y | z |
'
write_file "design/README.md" '# Design

**Source:** [PRD](../prd/)

## Analytics Coverage

| Feature | Event | Trigger | Emitting Channel | Responsible Module |
|---------|-------|---------|------------------|--------------------|
'
assert_exit 0 "$CHECK" "$FIXTURE/design"
assert_stdout_not_contains "legacy_event"
teardown_fixture

end_tests
