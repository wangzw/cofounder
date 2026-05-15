#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-checkers.sh"

# --- empty but well-formed plan dir + clean source -> PASS ------------
plan=$(mktempdir); mkdir -p "$plan/plans" "$plan/reports"
cat > "$plan/README.md" <<'MD'
# Plan: Demo
## Design Input
| Field | Value |
|---|---|
| Threshold | 80 |
## Dependency Graph
empty
## Phase Breakdown
P1
## Module Plans
none
## Module Status
| Module | Plan | Status |
|---|---|---|
## Phase Status
P1: planned
## Acceptance
threshold 80
## Reports
none yet
MD
src=$(mktempdir)
start_test "minimal plan dir -> exit 0 PASS"
out=$("$SCRIPT" "$plan" --source-root "$src" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- discipline scan finds soft-pass in source -> exit 1 -------------
src2=$(mktempdir)
cat > "$src2/bad.ts" <<'TS'
expect([200,400,403]).toContain(res.status);
TS
start_test "soft-pass in source -> aggregator exit 1"
out=$("$SCRIPT" "$plan" --source-root "$src2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  aggregator surfaces CR-AF12"
assert_stdout_contains "CR-AF12" "$out"
start_test "  scope=discipline-scan label present"
assert_stdout_contains "discipline-scan" "$out"

# --- missing plan-dir -> ERROR ----------------------------------------
start_test "missing plan-dir -> exit 2 ERROR"
out=$("$SCRIPT" /tmp/this-does-not-exist 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

# --- --phase argument validation --------------------------------------
start_test "--phase=bogus -> exit 2 ERROR"
out=$("$SCRIPT" "$plan" --source-root "$src" --phase=bogus 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

start_test "--phase=plan + --gate=delivery-tag conflict -> exit 2"
out=$("$SCRIPT" "$plan" --source-root "$src" --phase=plan --gate=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

# --- --phase=plan suppresses acceptance / traceability / e2e ----------
# Build a plan-dir with a stale (delivery N-1) acceptance.md + traceability.json
# that would normally fire CR-AF24 / CR-AF06 / etc. With --phase=plan they
# must be skipped entirely.
stale=$(mktempdir); mkdir -p "$stale/plans" "$stale/reports"
cp "$plan/README.md" "$stale/README.md"
# Deliberately malformed acceptance.md and traceability.json — anything that
# would make check-acceptance-report / check-traceability emit findings.
# Missing the required sentinel line + every required section is enough.
cat > "$stale/reports/acceptance.md" <<'MD'
# Stale Delivery-N-1 Acceptance Report
This file is leftover from a prior delivery. Has no sentinel, no Summary
section, no Failed Items, no E2E Test Run — checking it at plan time
would gate against N-1 history.
MD
cat > "$stale/reports/traceability.json" <<'JSON'
{ "this is not": "a valid traceability schema" }
JSON

start_test "stale acceptance.md without --phase=plan -> exit 1 (mismatch fires)"
out=$("$SCRIPT" "$stale" --source-root "$src" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc" "stale reports should trigger E6-time gates without --phase=plan"
start_test "  acceptance-report label present in mismatch case"
assert_stdout_contains "acceptance-report" "$out"

start_test "stale acceptance.md WITH --phase=plan -> exit 0 (suppressed)"
out=$("$SCRIPT" "$stale" --source-root "$src" --phase=plan 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "--phase=plan must suppress acceptance/traceability/e2e even when files exist"
start_test "  no acceptance-report scope label fires at plan phase"
# Tight match on the JSON `"scope": "acceptance-report"` so a future
# stray substring elsewhere doesn't mask a regression. Also catches the
# stderr error form `[acceptance-report] script error`.
if printf '%s' "$out" | grep -qE '"scope": *"acceptance-report"|\[acceptance-report\]'; then
  fail "acceptance-report dispatched at --phase=plan; it should be suppressed"
else
  pass
fi
start_test "  no traceability scope label fires at plan phase"
# Tight match avoiding accidental hits on the word "traceability"
# inside other strings (e.g. `plan-pollution` always appears in output,
# but is unrelated; the prior assertion was vacuously passing because
# `! grep plan-pollution` was always false).
if printf '%s' "$out" | grep -qE '"scope": *"traceability"|\[traceability\]'; then
  fail "traceability dispatched at --phase=plan; it should be suppressed"
else
  pass
fi
start_test "  no e2e-coverage scope label fires at plan phase"
if printf '%s' "$out" | grep -qE '"scope": *"e2e-coverage"|\[e2e-coverage\]'; then
  fail "e2e-coverage dispatched at --phase=plan; it should be suppressed"
else
  pass
fi

# --- --phase=plan still fires discipline-scan -------------------------
# Source-code soft-pass patterns must still be caught at plan phase. The
# suppression is scoped to acceptance/traceability/e2e only.
src_softpass=$(mktempdir)
cat > "$src_softpass/bad.ts" <<'TS'
expect([200,400,403]).toContain(res.status);
TS
start_test "--phase=plan still fires discipline-scan (CR-AF12)"
out=$("$SCRIPT" "$stale" --source-root "$src_softpass" --phase=plan 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  CR-AF12 finding present at plan phase"
assert_stdout_contains "CR-AF12" "$out"

# --- --phase=execute matches --phase=plan suppression -----------------
start_test "stale acceptance.md WITH --phase=execute -> exit 0 (also suppressed)"
out=$("$SCRIPT" "$stale" --source-root "$src" --phase=execute 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc"

# --- --phase=accept re-enables acceptance checks ----------------------
start_test "stale acceptance.md WITH --phase=accept -> exit 1 (acceptance gate fires)"
out=$("$SCRIPT" "$stale" --source-root "$src" --phase=accept 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc" "--phase=accept must dispatch acceptance/traceability against present reports"
start_test "  --phase=accept dispatches acceptance-report"
assert_stdout_contains "acceptance-report" "$out"

# --- --phase=accept with no acceptance.md: skips check, returns 0 -----
# Without --gate, missing acceptance.md is allowed (it's a "no live
# acceptance to gate against" condition). The --phase=accept invocation
# should NOT fire CR-AF27 (that's gate-mode only); it just skips the
# acceptance-report dispatch as the artifact-presence rule still applies.
no_acc=$(mktempdir); mkdir -p "$no_acc/plans" "$no_acc/reports"
cp "$plan/README.md" "$no_acc/README.md"
start_test "--phase=accept with missing acceptance.md -> PASS (skip, not gate)"
out=$("$SCRIPT" "$no_acc" --source-root "$src" --phase=accept 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "missing acceptance.md should not fail outside delivery-tag gate"
start_test "  no CR-AF27 critical at --phase=accept without --gate"
if printf '%s' "$out" | grep -qF "CR-AF27"; then
  fail "CR-AF27 fired at --phase=accept; it's a gate-mode-only preflight"
else
  pass
fi

# --- --phase=delivery-tag equivalent to --gate=delivery-tag -----------
start_test "--phase=delivery-tag accepted (alias for --gate=delivery-tag)"
# Plan dir is missing acceptance/traceability of its own; delivery-tag
# gate must fire preflight CR-AF27 + CR-AF28.
empty_plan=$(mktempdir); mkdir -p "$empty_plan/plans" "$empty_plan/reports"
cp "$plan/README.md" "$empty_plan/README.md"
out=$("$SCRIPT" "$empty_plan" --source-root "$src" --phase=delivery-tag 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  CR-AF27 fires under --phase=delivery-tag"
assert_stdout_contains "CR-AF27" "$out"

# --- auto-detect: .evolve-N/impact.md without versions/N.md -> plan ---
auto=$(mktempdir); mkdir -p "$auto/plans" "$auto/reports" "$auto/.evolve-3"
cp "$plan/README.md" "$auto/README.md"
echo "stub impact analysis" > "$auto/.evolve-3/impact.md"
# Same stale stuff that would normally fire acceptance checks.
cat > "$auto/reports/acceptance.md" <<'MD'
# Stale Delivery-2 Acceptance Report — would fail E6-time gates
MD

start_test "auto-detect: .evolve-3 marker without versions/3.md -> plan-phase"
out=$("$SCRIPT" "$auto" --source-root "$src" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "auto-detect should suppress acceptance checks; out=$out"
start_test "  auto-detect NOTE printed"
assert_stdout_contains "auto-detected --phase=plan" "$out"
start_test "  cites delivery-3 in NOTE"
assert_stdout_contains "delivery-3" "$out"

# --- auto-detect: mixed state (one done + one in-progress) -------------
# Both .evolve-2 (with versions/2.md = done) and .evolve-10 (no versions/10.md
# = in progress). The script must skip the completed pair and flag the
# in-progress one. Also verifies lexical sort doesn't pick `.evolve-10`
# before `.evolve-2` and accidentally short-circuit.
mixed=$(mktempdir); mkdir -p "$mixed/plans" "$mixed/reports" "$mixed/.evolve-2" "$mixed/.evolve-10" "$mixed/versions"
cp "$plan/README.md" "$mixed/README.md"
echo "stub d2 impact" > "$mixed/.evolve-2/impact.md"
echo "stub d10 impact" > "$mixed/.evolve-10/impact.md"
echo "# delivery 2 summary" > "$mixed/versions/2.md"
# acceptance.md left stale on purpose
cat > "$mixed/reports/acceptance.md" <<'MD'
# Stale acceptance — should be suppressed because d10 is in progress
MD
start_test "auto-detect mixed: d2 done + d10 in-progress -> plan-phase"
out=$("$SCRIPT" "$mixed" --source-root "$src" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "auto-detect should fire on d10; out=$out"
start_test "  NOTE cites delivery-10 as in progress (not d2)"
assert_stdout_contains "delivery-10" "$out"
start_test "  NOTE cites delivery-2 as the prior completed run"
assert_stdout_contains "delivery-2" "$out"

# --- auto-detect: completed evolution does NOT trigger -----------------
done_dir=$(mktempdir); mkdir -p "$done_dir/plans" "$done_dir/reports" "$done_dir/.evolve-2" "$done_dir/versions"
cp "$plan/README.md" "$done_dir/README.md"
echo "stub impact analysis" > "$done_dir/.evolve-2/impact.md"
echo "# delivery 2 summary" > "$done_dir/versions/2.md"
# Fresh acceptance for delivery-2 (well-formed minimally) — should be
# considered live, not suppressed.
cat > "$done_dir/reports/acceptance.md" <<'MD'
# Stale acceptance — but auto-detect should NOT suppress because
# .evolve-2/impact.md is paired with versions/2.md (evolution complete).
MD
start_test "auto-detect: completed evolution (.evolve-2 + versions/2.md) does NOT trigger plan-phase"
out=$("$SCRIPT" "$done_dir" --source-root "$src" 2>&1) && rc=0 || rc=$?
# Without --phase, completed evolution = default behavior = stale
# acceptance.md gates as before. So acceptance-report fires -> exit 1.
assert_exit_code 1 "$rc"
start_test "  no auto-detect NOTE printed"
if printf '%s' "$out" | grep -qF "auto-detected --phase=plan"; then
  fail "auto-detect fired on completed evolution; it should not"
else
  pass
fi

summary
