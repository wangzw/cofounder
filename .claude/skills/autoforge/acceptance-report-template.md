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

| # | Scenario | Path | Steps | Features Exercised | Status | Notes |
|---|----------|------|-------|-------------------|--------|-------|
| 1 | {scenario from journey spec} | Happy path | {steps} | F-001, F-003 | PASS / FAIL | — |
| 2 | {scenario} | Error path | {steps} | F-001 | FAIL | {detail} |

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

## Failed Items

<!-- Only include if there are failures -->

| # | Source | Item | Expected | Actual | Responsible Module | Fix Suggestion |
|---|--------|------|----------|--------|--------------------|----------------|
| 1 | F-002 AC#3 | {criterion} | {expected} | {actual} | M-003 | {suggestion} |
| 2 | J-002 E2E#2 | {scenario} | {expected} | {actual} | M-001, M-003 | {suggestion} |

## Not Covered Items

<!-- Only include if there are uncovered criteria -->

| # | Source | Item | Reason | Action Needed |
|---|--------|------|--------|---------------|
| 1 | F-005 AC#4 | {criterion} | {why not covered — e.g. requires external service, manual testing needed} | {what to do} |

## Verdict

**{PASS / PARTIAL / FAIL}**

<!-- PASS: all criteria and E2E scenarios pass -->
<!-- PARTIAL: >80% pass rate, failures are non-critical -->
<!-- FAIL: <80% pass rate or critical failures exist -->

{1-2 sentence summary of the result and any important caveats.}
