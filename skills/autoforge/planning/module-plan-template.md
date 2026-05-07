# Plan: M-{id} — {module-name}

> {module responsibility from design spec, 1-2 sentences}

## Context

| Field | Value |
|-------|-------|
| Design Spec | `{path to module design spec}` |
| Source Features | {F-001, F-003, ...} |
| Phase | {n} |
| Dependencies | {M-xxx, M-yyy or "None"} |
| Promotion Action | {Promote / Extend / Rewrite / None — from design spec UI Architecture; None for backend or shared-library modules} |
| Draft Source | {`{repo-root}/{frontend-implementation-path}/{feature-area}/` from design spec Draft path, or "—" for Rewrite/None} |

## Prerequisites

<!-- Only include if this module depends on other modules. Delete section if no dependencies. -->
Before starting, verify these modules are merged to the feature branch:
- [ ] M-{dep-id}: {what this module needs from it — specific interfaces or data models}

<!-- Note: Project initialization (directory structure, dependencies, build config) is handled
     by the Orchestrator in Step 1.5 (Project Bootstrap) before any module execution begins.
     Do NOT include init steps in module plans. -->

## Implementation Steps

Each step is an atomic unit of work (2-5 minutes). Developer executes these sequentially.

### Step 1: Interface Skeleton

**Goal:** Define the module's public interfaces as declared in the design spec.

**Files:**
- `{path/to/interface/file}`

**Code:**
```{lang}
// {concrete code for the interface skeleton}
```

**Verify:** Project compiles. No tests yet.

---

### Step 2: Data Model

**Goal:** Implement data structures and storage layer.

**Files:**
- `{path/to/model/file}`

**Code:**
```{lang}
// {concrete code for data model}
```

**Verify:** Project compiles.

---

### Step 3: Core Logic

**Goal:** Implement the primary business logic.

**Files:**
- `{path/to/logic/file}`

**Code:**
```{lang}
// {concrete code for core logic}
```

**Verify:** Project compiles.

---

### Step 4: Unit Tests

**Goal:** Test internal logic and edge cases from the design spec.

**Files:**
- `{path/to/test/file}`

**Test cases:**
| Test | Input | Expected Output | Design Reference |
|------|-------|-----------------|-----------------|
| {test name} | {input} | {expected} | {which acceptance criterion or edge case} |

**Verify:** `{test command}` — all tests pass.

---

### Step N: {Additional steps as needed}

<!-- Add as many steps as needed. Common patterns:
  - Error handling
  - Configuration / dependency injection
  - CLI / API handler (if this module exposes an endpoint)
  - Internal helper functions
  Each step follows the same format: Goal, Files, Code, Verify
-->

## Integration Points

Interfaces this module exposes or consumes that other modules depend on:

| Direction | Module | Interface | Notes |
|-----------|--------|-----------|-------|
| Exposes → | M-{id} | `{function/method signature}` | {what the caller needs to know} |
| Consumes ← | M-{id} | `{function/method signature}` | {how this module calls it} |

Direction: `Exposes ->` means this module exposes an interface consumed by the listed module. `Consumes <-` means this module consumes an interface exposed by the listed module.

## Wiring & Registration

> Required section (delivery-discipline §B, §C). A module is **not done**
> until every persistence/transport/middleware piece it ships is wired
> into the running application. List every wire-up step — code that
> "exists" but is unregistered is the no-op-write-path failure mode.

| # | What to wire | Where | Verify signal |
|---|--------------|-------|---------------|
| 1 | Schema model `User` | `db/schema.go` AutoMigrate list | startup logs show table creation; integration test asserts row insert via the public API |
| 2 | HTTP route `POST /api/x` | `router.go` mount table | request returns non-404; test asserts behavior, not just status |
| 3 | Middleware `authz` | `app.use(...)` chain | test asserts a forbidden caller receives 403 — not just that authz file exists |
| 4 | Env flag / config key | deployment config (`docker-compose.yml` / `helm/values.yaml` / `.env.example`) | test that exercises the flag's "on" branch via integration |

**Write-path signal rule:** every write the module performs must be
observable to a caller — return the persisted entity / RowsAffected /
event published — so a test can assert "the write happened", not "the
function did not raise". Plans whose final step is a void-returning
write without a check are a discipline violation.

## Out-of-Scope / Deferred Work

> Required section (delivery-discipline §D). Anything intentionally
> deferred — partial AC, mock-only path, environment-conditional branch,
> follow-up refactor — is tracked here with a GitHub issue link. Plans
> that bury deferrals as `// TODO` comments in code are a discipline
> violation.

| # | Item | Reason | Issue |
|---|------|--------|-------|
| 1 | {what is deferred} | {why} | `owner/repo#NNN` |

## Acceptance Criteria Mapping

> Required (delivery-discipline §E, §F). Every AC the module owns must
> have a row. Each test step must use the AC reference in its name
> (`test_F001_AC3_*`) **and** assert the AC's exact behavior — not just
> "the call succeeded". The test column lists the strict assertion the
> step will make, not just the test name.

| Criterion (from design) | Journey Touchpoints | Implemented in Step | Test in Step | Strict Assertion |
|-------------------------|---------------------|---------------------|--------------|-------------------|
| {criterion description} | J-001 step 4 | Step 3 | Step 4: `test_F001_AC3_returns_403_when_caller_lacks_role` | `expect(response.status).toBe(403)` AND `expect(body.error).toBe("forbidden")` |
