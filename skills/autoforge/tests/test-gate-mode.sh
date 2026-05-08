#!/usr/bin/env bash
# tests/test-gate-mode.sh — regression tests for run-checkers.sh
# --gate=delivery-tag mode (added in autoforge 1.5.0).
#
# Locks the four-gate behaviour against the d1 / d2 soft-pass failure
# mode:
#   - CR-AF24 sentinel required on acceptance.md
#   - CR-AF23 / CR-AF25 E2E Test Run section evidence required
#   - CR-AF26 frontend F-ID without spec → blocking
#   - CR-AF27 / CR-AF28 acceptance.md / traceability.json required
#   - CR-AF15 PASS test path must resolve to a real file under source-root
#
# This test file is the regression net the d1 / d2 retros said the gate
# itself needs. Without it, a future "polish" pass could silently
# degrade the gate (relax a regex, drop a check) and the verification
# would only surface the next time someone manually replayed the d2
# fixture.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-checkers.sh"

# ─── Helpers to build fixtures ────────────────────────────────────────────

write_compliant_acceptance() {
  # $1 = output file path
  cat > "$1" <<'MD'
<!-- generated-by: acceptance-tester-subagent; version: 1 -->

# PRD Acceptance Report

## Overall Verdict: PASS

## Summary

All acceptance criteria are accounted for.

## Input

PRD: docs/raw/prd/test-project

## Feature Acceptance

| Feature | Pass | Fail | Not Covered | Pass Rate |
|---------|------|------|-------------|-----------|
| F-001   | 0    | 0    | 1           | 0%        |

## Journey E2E Scenarios

| Journey | Touchpoints | Status |
|---------|-------------|--------|
| J-001   | 0/3         | NOT_COVERED |

## E2E Test Run

| Field | Value |
|-------|-------|
| Command | `n/a — backend-only project, no E2E layer` |
| Working Dir | n/a |
| Exit Code | n/a |

## E2E Traceability Matrix

| Journey | Spec | Status |
|---------|------|--------|
| J-001   | n/a | NOT_COVERED (see issue org/repo#43) |

## Requirements Traceability Matrix

| Criterion | Test | Status |
|-----------|------|--------|
| F-001/AC1 | n/a | NOT_COVERED (see issue org/repo#42) |

## Failed Items

None.

## Not Covered Items

| Criterion | Reason | Issue |
|-----------|--------|-------|
| F-001/AC1 | requires sandbox not yet provisioned | org/repo#42 |

## Negative-Path Coverage

J-001 has no negative path coverage; tracked in org/repo#43.

## Outstanding Debt

| Item | PRD Ref | Current State | User Impact | Issue |
|------|---------|---------------|-------------|-------|
| Sandbox tests | F-001/AC1 | not implemented | Untested feature | org/repo#42 |

## Orphan Tests

None.

## Unmapped Acceptance Criteria

None.

## Naming-vs-Content Mismatches

None.

## Verdict

PASS
MD
}

write_compliant_traceability() {
  # $1 = output file path
  cat > "$1" <<'JSON'
{
  "criteria": [
    {
      "id": "F-001/AC1",
      "feature": "F-001",
      "tests": [],
      "status": "NOT_COVERED",
      "reason": "requires sandbox not yet provisioned",
      "issue": "org/repo#42",
      "module": "M-001"
    }
  ],
  "journeys": [
    {
      "id": "J-001",
      "status": "NOT_COVERED",
      "touchpoints_traversed": 0,
      "touchpoints_total": 3,
      "scenarios": [
        {
          "kind": "happy",
          "test": "",
          "status": "NOT_COVERED"
        }
      ],
      "coverage_gap_issue": "org/repo#43",
      "tests": []
    }
  ],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
}

# ─── Fixture A: compliant fixture → gate PASSES ───────────────────────────

planA=$(mktempdir); mkdir -p "$planA/reports" "$planA/plans"
write_compliant_acceptance "$planA/reports/acceptance.md"
write_compliant_traceability "$planA/reports/traceability.json"

srcA=$(mktempdir)  # empty source root — no UI Architecture, no F-IDs

start_test "compliant fixture -> gate exit 0 (DELIVERY-TAG GATE PASSED)"
out=$("$SCRIPT" "$planA" --source-root "$srcA" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

start_test "  banner: DELIVERY-TAG GATE PASSED"
assert_stdout_contains "DELIVERY-TAG GATE PASSED" "$out"

# ─── Fixture B: bare plan dir (no acceptance.md, no traceability.json) ────

planB=$(mktempdir); mkdir -p "$planB/reports" "$planB/plans"
srcB=$(mktempdir)

start_test "missing acceptance.md + traceability.json -> gate exit 1"
out=$("$SCRIPT" "$planB" --source-root "$srcB" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF27 fires (acceptance.md missing)"
assert_stdout_contains "CR-AF27" "$out"

start_test "  CR-AF28 fires (traceability.json missing)"
assert_stdout_contains "CR-AF28" "$out"

start_test "  banner: DELIVERY-TAG GATE FAILED"
assert_stdout_contains "DELIVERY-TAG GATE FAILED" "$out"

start_test "  banner: refusing to authorize tag creation"
assert_stdout_contains "refusing to authorize tag creation" "$out"

# ─── Fixture C: acceptance.md without sentinel → CR-AF24 fires ────────────

planC=$(mktempdir); mkdir -p "$planC/reports" "$planC/plans"
write_compliant_acceptance "$planC/reports/acceptance.md"
# Strip the sentinel
python3 - "$planC/reports/acceptance.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
text = p.read_text()
# Remove the first sentinel line and any leading blank
text = re.sub(r"^<!--\s*generated-by:\s*acceptance-tester-subagent[^\n]*-->\n+", "", text, count=1)
p.write_text(text)
PY
write_compliant_traceability "$planC/reports/traceability.json"
srcC=$(mktempdir)

start_test "sentinel stripped -> gate exit 1"
out=$("$SCRIPT" "$planC" --source-root "$srcC" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF24 fires (sentinel missing)"
assert_stdout_contains "CR-AF24" "$out"

# ─── Fixture D: E2E Test Run section without Command/Exit Code rows ───────

planD=$(mktempdir); mkdir -p "$planD/reports" "$planD/plans"
write_compliant_acceptance "$planD/reports/acceptance.md"
# Replace the table-style E2E Test Run with prose only (no Command / no Exit Code rows)
python3 - "$planD/reports/acceptance.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = re.sub(
    r"## E2E Test Run\n.+?(?=## E2E Traceability Matrix)",
    "## E2E Test Run\n\nThis section exists but has no Command or Exit Code table rows.\n\n",
    text,
    count=1,
    flags=re.DOTALL,
)
p.write_text(text)
PY
write_compliant_traceability "$planD/reports/traceability.json"
srcD=$(mktempdir)

start_test "E2E Test Run section without Command/Exit Code rows -> gate exit 1"
out=$("$SCRIPT" "$planD" --source-root "$srcD" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF25 fires (Command/Exit Code rows missing)"
assert_stdout_contains "CR-AF25" "$out"

# ─── Fixture E: PASS criterion with non-existent test path → CR-AF15 ──────

planE=$(mktempdir); mkdir -p "$planE/reports" "$planE/plans"
write_compliant_acceptance "$planE/reports/acceptance.md"
cat > "$planE/reports/traceability.json" <<'JSON'
{
  "criteria": [
    {
      "id": "F-001/AC1",
      "feature": "F-001",
      "tests": ["tests/acceptance/test_F001_AC1_does_not_exist.ts"],
      "status": "PASS",
      "module": "M-001"
    }
  ],
  "journeys": [],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
srcE=$(mktempdir)

start_test "PASS with non-existent test path -> gate exit 1"
out=$("$SCRIPT" "$planE" --source-root "$srcE" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF15 fires (test path doesn't resolve)"
assert_stdout_contains "CR-AF15" "$out"

# ─── Fixture F: frontend F-ID without e2e spec → CR-AF26 ──────────────────

planF=$(mktempdir); mkdir -p "$planF/reports" "$planF/plans"
write_compliant_acceptance "$planF/reports/acceptance.md"
write_compliant_traceability "$planF/reports/traceability.json"
# A module plan that names F-099 as a Source Feature
cat > "$planF/plans/plan-M-001-test.md" <<'MD'
# M-001 Test Module Plan

## Context

| Field | Value |
|-------|-------|
| Module | M-001 |
| Source Features | F-099 |
MD

# Source root with a design module that declares F-099 as a UI feature
srcF=$(mktempdir)
mkdir -p "$srcF/docs/raw/design/test-project/modules"
cat > "$srcF/docs/raw/design/test-project/modules/M-001-test.md" <<'MD'
# M-001 Test Module

> **Source Features:** F-099

## UI Architecture

The module has a frontend UI surface.
MD
mkdir -p "$srcF/frontend/e2e"  # exists but no spec for F-099

start_test "frontend F-ID without e2e spec -> gate exit 1"
out=$("$SCRIPT" "$planF" --source-root "$srcF" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF26 fires (F-099 spec missing)"
assert_stdout_contains "CR-AF26" "$out"

# Now add the spec and confirm CR-AF26 clears
touch "$srcF/frontend/e2e/F-099-test-scenario.spec.ts"
start_test "  CR-AF26 clears once F-099 spec exists"
out=$("$SCRIPT" "$planF" --source-root "$srcF" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
# We don't assert exit 0 — there may be other findings — but CR-AF26 must NOT be present.
if printf '%s' "$out" | grep -qF "CR-AF26"; then
  fail "CR-AF26 still present after adding spec; out=$out"
else
  pass
fi

# ─── Fixture G: standard mode (no --gate) does NOT fire CR-AF23 mid-phase ─

planG=$(mktempdir); mkdir -p "$planG/plans" "$planG/reports"
# Realistic mid-phase: a plan file but no acceptance.md yet
cat > "$planG/plans/plan-M-001-test.md" <<'MD'
# M-001 Test Module Plan

## Context

| Field | Value |
|-------|-------|
| Module | M-001 |
MD
srcG=$(mktempdir)

start_test "standard mode (no --gate) without acceptance.md does NOT fire CR-AF23"
out=$("$SCRIPT" "$planG" --source-root "$srcG" 2>&1) && rc=0 || rc=$?
# rc may be 0 or 1 depending on plan-readme/module-plan findings, but
# CR-AF23 must NOT appear (the e2e checker dispatch is conditioned on
# acceptance.md existing OR --gate=delivery-tag).
if printf '%s' "$out" | grep -qF "CR-AF23"; then
  fail "CR-AF23 fired in standard mode mid-phase; out=$out"
else
  pass
fi

# ─── Fixture H: unknown gate name → script error (exit 2) ────────────────

start_test "unknown --gate value -> exit 2"
out=$("$SCRIPT" "$planA" --source-root "$srcA" --gate=bogus 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

# ─── Fixture I: n/a justification with complexity-excuse phrase → AF23 ────
# Covers delivery-discipline §L: "n/a — too complex" must not pass the gate.

planI=$(mktempdir); mkdir -p "$planI/reports" "$planI/plans"
write_compliant_acceptance "$planI/reports/acceptance.md"
# Replace the n/a justification with a forbidden complexity-excuse phrase
python3 - "$planI/reports/acceptance.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace(
    "`n/a — backend-only project, no E2E layer`",
    "`n/a — too complex to set up in CI`",
)
p.write_text(text)
PY
write_compliant_traceability "$planI/reports/traceability.json"
srcI=$(mktempdir)

start_test "n/a justification with complexity excuse -> gate exit 1"
out=$("$SCRIPT" "$planI" --source-root "$srcI" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF23 fires (complexity-excuse n/a justification)"
assert_stdout_contains "CR-AF23" "$out"

start_test "  finding mentions forbidden complexity-excuse phrase"
assert_stdout_contains "complexity-excuse" "$out"

# ─── Fixture J: traceability test path is a directory, not a file → AF15 ──
# Verifies isfile (not exists) check.

planJ=$(mktempdir); mkdir -p "$planJ/reports" "$planJ/plans"
write_compliant_acceptance "$planJ/reports/acceptance.md"
cat > "$planJ/reports/traceability.json" <<'JSON'
{
  "criteria": [
    {
      "id": "F-001/AC1",
      "feature": "F-001",
      "tests": ["tests/acceptance"],
      "status": "PASS",
      "module": "M-001"
    }
  ],
  "journeys": [],
  "orphan_tests": [],
  "unmapped_criteria": []
}
JSON
srcJ=$(mktempdir)
mkdir -p "$srcJ/tests/acceptance"  # directory, NOT a file

start_test "PASS test path is a directory (not a file) -> gate exit 1"
out=$("$SCRIPT" "$planJ" --source-root "$srcJ" --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

start_test "  CR-AF15 fires (test path is not an existing file)"
assert_stdout_contains "CR-AF15" "$out"

summary
