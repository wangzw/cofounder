#!/usr/bin/env bash
# tests/test-check-frontend-draft.sh — coverage for scripts/check-frontend-draft.sh
#
# Enforces CR-PP-FD01: every feature file containing `## Interaction Design`
# (i.e. user-facing) MUST contain a populated `#### Frontend Draft Reference`
# subsection with non-placeholder `Draft path:` and `Confirmed (experience):`
# (the latter MAY be `null` only if a sibling `Drift:` line explains why).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"

CHECK="$REPO_SCRIPTS/check-frontend-draft.sh"

# ─── Reusable fixture content ────────────────────────────────────────

# A backend (non-user-facing) feature: NO `## Interaction Design`.
BACKEND_FEATURE='---
id: F-001
title: Backend job
status: draft
---

# F-001: Backend job

## Acceptance Criteria
- Given the queue When a job lands Then the worker processes it
'

# A user-facing feature with a populated Frontend Draft Reference.
GOOD_UI_FEATURE='---
id: F-002
title: Admin Providers
status: draft
---

# F-002: Admin Providers

## Acceptance Criteria
- Given an admin When they open /admin/providers Then they see the list

## Interaction Design

#### Screen & Layout

A providers admin page.

#### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/admin/providers/`
- **Confirmed (experience):** 2026-05-07
'

# A user-facing feature with NO Frontend Draft Reference subsection.
MISSING_DRAFT_REF='---
id: F-003
title: Org LLM Config
status: draft
---

# F-003: Org LLM Config

## Acceptance Criteria
- Given an admin When they save config Then it persists

## Interaction Design

#### Screen & Layout

Per-provider toggle UI.
'

# A user-facing feature whose Frontend Draft Reference still carries the
# `feature-template.md` placeholder text (initial-write artifact never updated
# by Phase 5).
PLACEHOLDER_DRAFT='---
id: F-004
title: System Config
status: draft
---

# F-004: System Config

## Acceptance Criteria
- Given an admin When they update Then it saves

## Interaction Design

#### Screen & Layout

Tabs for each subsection.

#### Frontend Draft Reference

- **Draft path:** `{repo-root}/{frontend-implementation-path}/{feature-area}/`
- **Confirmed (experience):** {YYYY-MM-DD}
'

# A user-facing feature with Draft path: populated but Confirmed: still YYYY-MM-DD placeholder.
HALF_FILLED='---
id: F-005
title: Half filled
status: draft
---

# F-005

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

#### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/half-filled/`
- **Confirmed (experience):** {YYYY-MM-DD}
'

# A user-facing feature whose section header exists but Draft path: line missing.
MISSING_PATH='---
id: F-006
title: Missing path
status: draft
---

# F-006

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

#### Frontend Draft Reference

- **Confirmed (experience):** 2026-05-07
'

# A user-facing feature with Confirmed: null but no sibling Drift: line.
DEFERRED_NO_REASON='---
id: F-007
title: Deferred no reason
status: draft
---

# F-007

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

#### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/deferred/`
- **Confirmed (experience):** null
'

# A user-facing feature with Confirmed: null AND a sibling Drift: line. Allowed.
DEFERRED_WITH_REASON='---
id: F-008
title: Deferred with reason
status: draft
---

# F-008

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

#### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/deferred/`
- **Confirmed (experience):** null
- **Drift:** baseline draft predates schema migration; will be regenerated in delivery-3.
'

# A user-facing feature whose Frontend Draft Reference heading is at the WRONG
# level (h3 / h5 instead of h4). The check should detect this specifically
# rather than reporting a generic "missing subsection".
WRONG_LEVEL_H3='---
id: F-009
title: Wrong level h3
status: draft
---

# F-009

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/wrong-h3/`
- **Confirmed (experience):** 2026-05-07
'

WRONG_LEVEL_H5='---
id: F-010
title: Wrong level h5
status: draft
---

# F-010

## Acceptance Criteria
- Given x When y Then z

## Interaction Design

##### Frontend Draft Reference

- **Draft path:** `frontend/src/pages/wrong-h5/`
- **Confirmed (experience):** 2026-05-07
'

# ============================================================
test_case "exit 2 when prd-dir missing"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected exit 2 got $LAST_EXIT"

# ============================================================
test_case "exit 0 + PASS when no features/ dir present"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "PASS — backend feature with no Interaction Design is exempt"
setup_fixture
write_file "features/F-001-backend.md" "$BACKEND_FEATURE"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "PASS — user-facing feature with populated Frontend Draft Reference"
setup_fixture
write_file "features/F-002-admin-providers.md" "$GOOD_UI_FEATURE"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 fires when Frontend Draft Reference subsection missing"
setup_fixture
write_file "features/F-003-org-llm-config.md" "$MISSING_DRAFT_REF"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "F-003-org-llm-config.md"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 fires on placeholder template values"
setup_fixture
write_file "features/F-004-system-config.md" "$PLACEHOLDER_DRAFT"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "F-004-system-config.md"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 fires when Confirmed (experience) is YYYY-MM-DD placeholder"
setup_fixture
write_file "features/F-005-half-filled.md" "$HALF_FILLED"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "Confirmed"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 fires when Draft path: line is missing"
setup_fixture
write_file "features/F-006-missing-path.md" "$MISSING_PATH"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "Draft path"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 fires when Confirmed: null lacks sibling Drift: line"
setup_fixture
write_file "features/F-007-deferred.md" "$DEFERRED_NO_REASON"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "Drift"
teardown_fixture

# ============================================================
test_case "PASS — Confirmed: null with sibling Drift: line is an explicit deferral"
setup_fixture
write_file "features/F-008-deferred-ok.md" "$DEFERRED_WITH_REASON"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 detects wrong heading level (h3) with specific message"
setup_fixture
write_file "features/F-009-wrong-h3.md" "$WRONG_LEVEL_H3"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "wrong heading level"
assert_stdout_contains "F-009-wrong-h3.md"
teardown_fixture

# ============================================================
test_case "CR-PP-FD01 detects wrong heading level (h5) with specific message"
setup_fixture
write_file "features/F-010-wrong-h5.md" "$WRONG_LEVEL_H5"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP-FD01"
assert_stdout_contains "wrong heading level"
assert_stdout_contains "F-010-wrong-h5.md"
teardown_fixture

# ============================================================
test_case "aggregates findings across multiple features"
setup_fixture
write_file "features/F-003-a.md" "$MISSING_DRAFT_REF"
write_file "features/F-004-b.md" "$PLACEHOLDER_DRAFT"
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q "F-003-a.md" && _record_pass || _record_fail "missing F-003"
echo "$LAST_STDOUT" | grep -q "F-004-b.md" && _record_pass || _record_fail "missing F-004"
teardown_fixture

# ============================================================
test_case "idempotent — same input twice yields identical stdout"
setup_fixture
write_file "features/F-003-x.md" "$MISSING_DRAFT_REF"
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
