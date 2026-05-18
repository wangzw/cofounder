#!/usr/bin/env bash
# tests/test-check-feature.sh — coverage for scripts/check-feature.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"

CHECK="$REPO_SCRIPTS/check-feature.sh"

# ─── Reusable fixture content ────────────────────────────────────────
GOOD_FEATURE_BODY='---
id: F-001
title: Checkout
status: draft
---

# Checkout

## Acceptance Criteria
- Given a user with items in cart
- When they click checkout
- Then they see the payment page
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
test_case "exit 0 + PASS when single well-formed feature"
setup_fixture
write_file "features/F-001-checkout.md" "$GOOD_FEATURE_BODY"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP02 detects bad filename pattern"
setup_fixture
write_file "features/checkout.md" "$GOOD_FEATURE_BODY"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP02"
assert_stdout_contains "checkout.md"
teardown_fixture

# ============================================================
test_case "CR-PP02 detects duplicate ids"
setup_fixture
write_file "features/F-001-a.md" "$GOOD_FEATURE_BODY"
write_file "features/F-001-b.md" "$GOOD_FEATURE_BODY"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "duplicate feature id F-001"
teardown_fixture

# ============================================================
test_case "CR-PP02 warns on gap in id sequence"
setup_fixture
write_file "features/F-001-one.md" "$GOOD_FEATURE_BODY"
write_file "features/F-003-three.md" "$(printf '%s' "$GOOD_FEATURE_BODY" | sed 's/F-001/F-003/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "gap in feature ids"
assert_stdout_contains "F-002"
teardown_fixture

# ============================================================
test_case "CR-PP02 warns when ids do not start at F-001"
setup_fixture
write_file "features/F-002-two.md" "$(printf '%s' "$GOOD_FEATURE_BODY" | sed 's/F-001/F-002/')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "feature ids start at F-002"
teardown_fixture

# ============================================================
test_case "CR-FM01 detects missing frontmatter block"
setup_fixture
write_file "features/F-001-x.md" "# Just a title

## Acceptance Criteria
- Given x When y Then z
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-FM01"
assert_stdout_contains "missing leading frontmatter block"
teardown_fixture

# ============================================================
test_case "CR-FM01 detects missing required field"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
---

## Acceptance Criteria
- Given x When y Then z
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-FM01"
assert_stdout_contains "status"
teardown_fixture

# ============================================================
test_case "CR-PP04 detects TODO marker"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

# TODO: write description

## Acceptance Criteria
- Given x When y Then z
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP04"
assert_stdout_contains "TODO"
teardown_fixture

# ============================================================
test_case "CR-PP15F detects missing Acceptance Criteria section"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

# Body
some content
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP15F"
assert_stdout_contains "missing"
teardown_fixture

# ============================================================
test_case "CR-PP15F detects missing BDD keywords"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given a user does a thing
- it should work
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP15F"
assert_stdout_contains "When, Then"
teardown_fixture

# ============================================================
# ============================================================
test_case "CR-PP15 detects compound AC with 'then:' + list"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given chaos is installed, When the operator runs install.sh, Then: the daemon stops, the binaries replace the old, the data dir is preserved, the DNS snapshot is rewritten, and the script exits 0.
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP15F"
assert_stdout_contains "compound"
teardown_fixture

# ============================================================
test_case "CR-PP15 detects compound AC without colon (>=4 commas)"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given the daemon is starting, When bootstrap runs, Then it creates chaos0, establishes an SSH session, starts the userspace stack, installs policy routes, and chaos status returns healthy.
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP15F"
assert_stdout_contains "compound"
teardown_fixture

# ============================================================
test_case "CR-PP15 does not fire on simple single-assertion AC"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given a user with Viewer role, When they POST to /api/projects, Then the system returns HTTP 403 and no database record is created.
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP15 does not fire on AC with commas inside backticks"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given the installer runs, When it executes, Then it prints `"hello, world, again, friend, hello"` and exits with code 0.
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP15 does not fire below comma threshold"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
status: draft
---

## Acceptance Criteria
- Given a setup, When an action happens, Then result A occurs, result B occurs.
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "idempotent — same input twice yields identical stdout"
setup_fixture
write_file "features/F-001-x.md" '---
id: F-001
title: x
---

## Acceptance Criteria
- Given x
'
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
