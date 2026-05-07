# Acceptance Report: {project-name}

> Validation of implemented code against PRD requirements.

## Summary

| Metric | Value |
|--------|-------|
| Features Tested | {n}/{total} |
| Acceptance Criteria Passed | {n}/{total} |
| E2E Scenarios Passed | {n}/{total} |
| Overall Pass Rate | {percentage}% |
| **Verdict** | **PASS / PARTIAL / FAIL** |

## Input

| Field | Value |
|-------|-------|
| PRD | `{path to PRD directory}` |
| Design | `{path to design directory}` |
| Feature Branch | `{branch name}` |
| Test Date | {YYYY-MM-DD} |

## Feature Acceptance

### F-{id}: {feature-name}

| # | Acceptance Criterion | Status | Test | Notes |
|---|---------------------|--------|------|-------|
| 1 | {criterion from feature spec} | PASS / FAIL / NOT_COVERED | {test name} | {failure detail or "—"} |
| 2 | {criterion} | PASS | {test name} | — |

**Edge Cases:**

| # | Edge Case | Status | Test | Notes |
|---|-----------|--------|------|-------|
| 1 | {Given/When/Then from feature spec} | PASS / FAIL / NOT_COVERED | {test name} | — |

**Feature Result:** {passed}/{total} criteria passed

<!-- Repeat for each feature -->

## Journey E2E Scenarios

### J-{id}: {journey-name}

| # | Scenario | Path | Steps | Features Exercised | Touchpoints Traversed | Status | Notes |
|---|----------|------|-------|-------------------|------------------------|--------|-------|
| 1 | {scenario from journey spec} | Happy path | {steps} | F-001, F-003 | 5/5 | PASS / FAIL | — |
| 2 | {scenario} | Error path | {steps} | F-001 | 2/4 | FAIL | {user-visible failure: e.g. "user does not see confirmation after step 3"} |

<!-- Repeat for each journey that has E2E Test Scenarios -->

## Requirements Traceability Matrix

| Feature | Total Criteria | Passed | Failed | Not Covered | Pass Rate |
|---------|---------------|--------|--------|-------------|-----------|
| F-001 {name} | 8 | 8 | 0 | 0 | 100% |
| F-002 {name} | 7 | 5 | 1 | 1 | 71% |
| **Total** | **{n}** | **{n}** | **{n}** | **{n}** | **{pct}%** |

## E2E Traceability Matrix

| Journey | Total Scenarios | Passed | Failed | Not Covered | Pass Rate |
|---------|----------------|--------|--------|-------------|-----------|
| J-001 {name} | 3 | 3 | 0 | 0 | 100% |
| J-002 {name} | 5 | 4 | 1 | 0 | 80% |
| **Total** | **{n}** | **{n}** | **{n}** | **{n}** | **{pct}%** |

## Negative-Path Coverage

<!-- Per delivery-discipline §M.2, every journey must exercise at least
one non-happy scenario (kind: error / boundary / concurrency /
idempotency). Rows where Negative Scenarios = 0 must either be fixed
this round or carry a tracked issue under `coverage_gap_issue` in
traceability.json. -->

| Journey | Happy | Error | Boundary | Concurrency | Idempotency | Coverage Gap Issue |
|---------|-------|-------|----------|-------------|-------------|--------------------|
| J-001 {name} | 1 | 1 | 1 | 0 | 0 | — |
| J-002 {name} | 1 | 0 | 0 | 0 | 0 | owner/repo#214 |

## Failed Items

<!-- Only include if there are failures. Describe failures in user-visible / journey language (delivery-discipline §J), not layer language. -->

| # | Source | Item | Expected User Outcome | Actual User Outcome | Responsible Module | Fix Suggestion |
|---|--------|------|------------------------|---------------------|--------------------|----------------|
| 1 | F-002 AC#3 | {criterion} | {expected user-visible outcome} | {actual user-visible outcome} | M-003 | {suggestion} |
| 2 | J-002 E2E#2 | {scenario} | {expected} | {actual} | M-001, M-003 | {suggestion} |

## Not Covered Items

<!-- Every NOT_COVERED entry MUST have a tracked issue link (delivery-discipline §D). Entries without an issue link are FAIL, not NOT_COVERED. -->

| # | Source | Item | Reason | Issue | Action Needed |
|---|--------|------|--------|-------|---------------|
| 1 | F-005 AC#4 | {criterion} | {why not covered} | `owner/repo#NNN` | {what to do} |

## Outstanding Debt

<!-- Required section (delivery-discipline §D, §J). List every gap between the implementation and the PRD that this run is leaving open: NOT_COVERED items, mock-only paths still in production, disabled features, soft-pass tests that were flipped, contracts not yet enforced, env-flag overrides. Do NOT use this section as a substitute for failing the gate — items here MUST have a tracked issue. -->

| # | PRD Reference | Current State | User Impact | Issue |
|---|---------------|--------------|-------------|-------|
| 1 | F-007 AC#2 | mock implementation only | user does not receive real notification | `owner/repo#142` |

## Orphan Tests

<!-- Tests in the acceptance suite that do not map to any AC or journey touchpoint. Drawn from `traceability.json`. Non-empty list is a discipline failure (§F). -->

| # | Test Path | Reason |
|---|-----------|--------|
| 1 | `tests/acceptance/test_legacy_xyz.py` | no matching AC or journey touchpoint |

## Unmapped Acceptance Criteria

<!-- AC entries with no test and no NOT_COVERED record. Non-empty list is a discipline failure (§F). -->

| # | Source | Reason |
|---|--------|--------|
| 1 | F-009 AC#5 | no test exists and no NOT_COVERED reason recorded |

## Naming-vs-Content Mismatches

<!-- Tests whose name claims to cover an AC / journey touchpoint but whose body asserts something different (delivery-discipline §E). Non-empty list is a discipline failure. -->

| # | Test Path | Claimed Coverage | Actual Assertion |
|---|-----------|------------------|-------------------|
| 1 | `tests/acceptance/test_F002_AC3_returns_403.py` | F-002/AC3 forbids unauthorized read | only asserts `status === 200` |

## Verdict

**{PASS / PARTIAL / FAIL}**

- **PASS:** All criteria pass (or NOT_COVERED with tracked issue) AND overall pass rate >= acceptance threshold AND no critical failures AND full local CI green AND traceability closure clean (no orphan tests, unmapped AC, naming mismatches, or NOT_COVERED-without-issue).
- **PARTIAL:** Overall pass rate >= acceptance threshold AND no critical failures AND full local CI green, BUT some criteria failed (non-critical) OR some closure findings remain. Outstanding Debt section MUST list each.
- **FAIL:** Any of: overall pass rate < threshold, critical failure, full local CI red, traceability closure violation, soft-pass tests detected, NOT_COVERED without issue.

A failure is **critical** if it affects a core acceptance criterion (not an edge case) of a feature appearing in multiple journeys, OR is a delivery-discipline closure violation.

{1-2 sentence summary in user-visible / journey language. Example: "Journey J-001 (sign up → first post) end-to-end verified. Journey J-002 step 4 fails: the user is shown the dashboard before their data finishes loading. F-007 notification path is mock-only — see Outstanding Debt."}
