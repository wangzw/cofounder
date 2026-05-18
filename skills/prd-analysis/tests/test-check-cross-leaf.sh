#!/usr/bin/env bash
# tests/test-check-cross-leaf.sh — coverage for scripts/check-cross-leaf.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"

CHECK="$REPO_SCRIPTS/check-cross-leaf.sh"

# Helper — minimal well-formed feature
mk_feature() {
    local fid="$1" extra_body="${2:-}"
    printf -- '---
id: %s
title: %s
status: draft
---

# %s

## Acceptance Criteria
- Given a setup, When something happens, Then result occurs.

%s
' "$fid" "$fid" "$fid" "$extra_body"
}

# ============================================================
test_case "exit 2 when prd-dir missing"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected exit 2 got $LAST_EXIT"

# ============================================================
test_case "exit 0 + PASS on empty PRD bundle"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "exit 0 + PASS on internally consistent bundle"
setup_fixture
write_file "features/F-001-login.md" "$(mk_feature F-001 'The login uses `--user-name` flag and references F-002.')"
write_file "features/F-002-logout.md" "$(mk_feature F-002 'Pairs with F-001 via `--user-name` flag.')"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-PP27 detects CLI flag underscore vs kebab inconsistency"
setup_fixture
write_file "features/F-001-cli.md" "$(mk_feature F-001 'CLI accepts `--route-via <name>` flag.')"
write_file "features/F-002-cli.md" "$(mk_feature F-002 'Subcommand exposes `--route_via <name>` flag.')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP27"
assert_stdout_contains "--route-via"
assert_stdout_contains "--route_via"
teardown_fixture

# ============================================================
test_case "CR-PP27 flag conflict emits one finding per affected leaf"
setup_fixture
write_file "features/F-001-cli.md" "$(mk_feature F-001 'CLI accepts `--route-via <name>` flag.')"
write_file "features/F-002-cli.md" "$(mk_feature F-002 'Subcommand exposes `--route_via <name>` flag.')"
run_command "$CHECK" "$FIXTURE"
# Both leaves should be referenced as the `file:` of separate findings
# so Step 8d can dispatch one fix-up writer per leaf.
count_f1=$(echo "$LAST_STDOUT" | grep -c '"file": "features/F-001-cli.md"' || true)
count_f2=$(echo "$LAST_STDOUT" | grep -c '"file": "features/F-002-cli.md"' || true)
if [ "$count_f1" -ge 1 ] && [ "$count_f2" -ge 1 ]; then
    _record_pass
else
    _record_fail "expected both leaves to appear as file: in JSON; got f1=$count_f1 f2=$count_f2"
fi
teardown_fixture

# ============================================================
test_case "CR-PP27 detects conflicting error code numeric assignments"
setup_fixture
write_file "architecture/shared-conventions.md" "---
id: arch-shared-conventions
---

# Shared conventions

| Code name | JSON-RPC code |
|---|---|
| AUTH_DENIED | -32000 |
| VALIDATION_FAILED | -32001 |
"
write_file "features/F-008-rpc.md" "$(mk_feature F-008 '| Code name | JSON-RPC code |
|---|---|
| AUTH_DENIED | -32001 |
| VALIDATION_FAILED | -32002 |')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP27"
assert_stdout_contains "AUTH_DENIED"
teardown_fixture

# ============================================================
test_case "CR-PP27 code conflict without canonical leaf routes to HITL"
setup_fixture
# Both F-008 and F-009 disagree on AUTH_DENIED, no shared-conventions
# leaf in the bundle. The suggested_fix must explicitly route to HITL
# (no canonical authority to align to).
write_file "features/F-008-rpc.md" "$(mk_feature F-008 '| AUTH_DENIED | -32000 |')"
write_file "features/F-009-cli.md" "$(mk_feature F-009 '| AUTH_DENIED | -32001 |')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP27"
assert_stdout_contains "AUTH_DENIED"
assert_stdout_contains "no canonical authority"
teardown_fixture

# ============================================================
test_case "CR-PP27 code conflict emits one finding per affected leaf"
setup_fixture
write_file "architecture/shared-conventions.md" "---
id: arch
---

| AUTH_DENIED | -32000 |
"
write_file "features/F-008-rpc.md" "$(mk_feature F-008 '| AUTH_DENIED | -32001 |')"
run_command "$CHECK" "$FIXTURE"
count_arch=$(echo "$LAST_STDOUT" | grep -c '"file": "architecture/shared-conventions.md"' || true)
count_feat=$(echo "$LAST_STDOUT" | grep -c '"file": "features/F-008-rpc.md"' || true)
if [ "$count_arch" -ge 1 ] && [ "$count_feat" -ge 1 ]; then
    _record_pass
else
    _record_fail "expected both leaves as file: in JSON; got arch=$count_arch feat=$count_feat"
fi
teardown_fixture

# ============================================================
test_case "CR-PP06 detects dangling F-NNN reference"
setup_fixture
write_file "features/F-001-x.md" "$(mk_feature F-001 'Depends on F-999 for auth.')"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP06"
assert_stdout_contains "F-999"
teardown_fixture

# ============================================================
test_case "CR-PP06 detects dangling J-NNN reference"
setup_fixture
write_file "features/F-001-x.md" "$(mk_feature F-001 'Covers J-042 user journey.')"
write_file "journeys/J-001-jx.md" "---
id: J-001
title: jx
persona: p
---

# jx
"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-PP06"
assert_stdout_contains "J-042"
teardown_fixture

# ============================================================
test_case "self-reference to own F-NNN does not fire dangling"
setup_fixture
write_file "features/F-001-self.md" "$(mk_feature F-001 'F-001 covers this case.')"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "idempotent — same input twice yields identical stdout"
setup_fixture
write_file "features/F-001-x.md" "$(mk_feature F-001 'See F-999.')"
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
