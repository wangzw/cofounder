# Autoforge Plan: {project-name}

> {one-line design objective from design README}

## Design Input

| Field | Value |
|-------|-------|
| Source Design | `{path to design directory}` |
| Source PRD | `{path to PRD directory}` |
| Date | {YYYY-MM-DD} |
| Feature Branch | `autoforge/{design-dir-name}-{hash4}` |
| Worktree Root | `{project-root}/../{project-dirname}-worktrees/autoforge-{design-dir-name}-{hash4}/` |
| Acceptance Threshold | 80% (PARTIAL if >= threshold, FAIL if below) |

## Dependency Graph

```mermaid
graph TD
  %% Phase 1 — no dependencies
  M-001[M-001: {name}]
  M-008[M-008: {name}]

  %% Phase 2 — depends on Phase 1
  M-003[M-003: {name}]
  M-001 --> M-003
  M-008 --> M-003

  %% Phase 3 — depends on Phase 2
  M-006[M-006: {name}]
  M-003 --> M-006

  %% Styling
  classDef p1 fill:#e8f5e9
  classDef p2 fill:#e3f2fd
  classDef p3 fill:#fff3e0
  class M-001,M-008 p1
  class M-003 p2
  class M-006 p3
```

## Phase Breakdown

| Phase | Modules | Rationale |
|-------|---------|-----------|
| 1 | M-001, M-008, M-002 | No dependencies — can start immediately |
| 2 | M-003, M-005 | Depend on Phase 1 modules |
| 3 | M-006, M-007 | Depend on Phase 2 modules |

## Module Plans

| Module | Phase | Plan | Steps | Integration Points | Spec |
|--------|-------|------|-------|-------------------|------|
| M-001 {name} | 1 | [plan](plans/plan-M-001-{slug}.md) | {n} | M-003, M-005 | [design]({path}) |
| M-008 {name} | 1 | [plan](plans/plan-M-008-{slug}.md) | {n} | M-003 | [design]({path}) |

Integration Points: modules this module interacts with. Format: `-> M-003` (this module calls M-003), `<- M-005` (M-005 calls this module).

## Module Status

| Module | Phase | Plan | Dev | Test | Review | Merged | Notes |
|--------|-------|------|-----|------|--------|--------|-------|
| M-001  | 1     | —    | —   | —    | —      | —      | — |
| M-008  | 1     | —    | —   | —    | —      | —      | — |

Legend: `—` = not started, `Done` = complete, `Retry {n}` = in retry cycle, `Revision` = plan being revised, `Decision` = waiting for human decision, `Skipped` = human decided to skip

## Phase Status

| Phase | Modules | Completed | Integration Test | Status |
|-------|---------|-----------|-----------------|--------|
| 1     | 3       | 0/3       | —               | Pending |
| 2     | 2       | 0/2       | —               | Waiting |
| 3     | 2       | 0/2       | —               | Waiting |

## Acceptance

| Feature | Criteria Total | Passed | Failed | Not Covered | Status |
|---------|---------------|--------|--------|-------------|--------|
| — | — | — | — | — | Pending |

**Overall Verdict:** Pending

## Reports

| Report | Path | Status |
|--------|------|--------|
| Phase 1 Integration | [report](reports/integration-phase-1.md) | Pending |
| Phase 2 Integration | [report](reports/integration-phase-2.md) | Pending |
| Acceptance | [report](reports/acceptance.md) | Pending |
