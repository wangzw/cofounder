# Plan: M-{id} — {module-name}

> {module responsibility from design spec, 1-2 sentences}

## Context

| Field | Value |
|-------|-------|
| Design Spec | `{path to module design spec}` |
| Source Features | {F-001, F-003, ...} |
| Phase | {n} |
| Dependencies | {M-xxx, M-yyy or "None"} |
| Complexity | {S / M / L / XL} |
| Worktree Branch | `autoforge/{plan-id}/p{n}/M-{id}-{slug}` |

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

## Acceptance Criteria Mapping

Trace from design spec acceptance criteria to implementation steps:

| Criterion (from design) | Implemented in Step | Test in Step |
|------------------------|---------------------|-------------|
| {criterion description} | Step 3 | Step 4: {test name} |
