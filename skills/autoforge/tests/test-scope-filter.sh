#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-checkers.sh"
INIT="$DIR/../scripts/run-state-init.sh"

setup_plan() {
  local plan="$1"
  mkdir -p "$plan/plans" "$plan/reports"
  cat > "$plan/README.md" <<'MD'
# Plan: Demo
## Design Input
| Field | Value |
|---|---|
| Threshold | 80 |
## Dependency Graph
```mermaid
flowchart LR
  M001 --> M002
```
## Phase Breakdown
P1: M-001, M-002
## Module Plans
| Module | Status |
|---|---|
| M-001 | planned |
| M-002 | planned |
MD
  for m in M-001 M-002; do
    cat > "$plan/plans/plan-${m}.md" <<EOF
# Plan ${m}
## Goal
stub
## Steps
1. step 1
## Tests
## Files Touched
## Dependencies
## Acceptance Criteria
EOF
  done
  cat > "$plan/modules.json" <<'JSON'
[
  {"id": "M-001", "deps": []},
  {"id": "M-002", "deps": ["M-001"]}
]
JSON
  bash "$INIT" "$plan" "$plan/modules.json" >/dev/null
}

start_test "default scope (--scope=all) runs module-plan for every module"
plan=$(mktempdir); setup_plan "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$plan" --phase=plan --json-only 2>/dev/null)
set -e
echo "$out" | grep -q '"scope": "module-plan(plan-M-001.md)"' || \
  fail "expected module-plan for M-001"
echo "$out" | grep -q '"scope": "module-plan(plan-M-002.md)"' || \
  fail "expected module-plan for M-002"
pass

start_test "scope=tier-1 limits to tier-1 modules"
plan=$(mktempdir); setup_plan "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$plan" --phase=plan \
        --scope=tier-1 --json-only 2>/dev/null)
set -e
# M-001 is tier 1, M-002 is tier 2 in our fixture.
echo "$out" | grep -q '"scope": "module-plan(plan-M-001.md)"' || \
  fail "expected module-plan for M-001 under tier-1"
if echo "$out" | grep -q '"scope": "module-plan(plan-M-002.md)"'; then
  fail "tier-1 scope should not include M-002"
fi
pass

start_test "scope=module-M-002 limits to that one module"
plan=$(mktempdir); setup_plan "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$plan" --phase=plan \
        --scope=module-M-002 --json-only 2>/dev/null)
set -e
echo "$out" | grep -q '"scope": "module-plan(plan-M-002.md)"' || \
  fail "expected module-plan for M-002 under module scope"
if echo "$out" | grep -q '"scope": "module-plan(plan-M-001.md)"'; then
  fail "module-M-002 scope should not include M-001"
fi
pass

start_test "unknown scope rejected"
plan=$(mktempdir); setup_plan "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" --source-root "$plan" --phase=plan \
        --scope=tier-bogus 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

summary
