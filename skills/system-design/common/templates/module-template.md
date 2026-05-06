# M-{{NNN}}: {{Module Name}}

<!-- Header: Module ID (M-NNN) is stable across iterations. Name must match the README module index row exactly. -->

> **Doc Status:** Draft | Finalized | Implementing | Implemented  
> **Impl Status:** NotStarted | InProgress | Done  
> **Assignee:** {{assignee or "unassigned"}}  
> **Source Features:** {{F-001, F-003 — space-separated list of PRD feature IDs}}  
> **Complexity:** S | M | L | XL

<!-- Doc Status tracks the design document's lifecycle (Draft = in progress; Finalized = approved for
     implementation; Implementing = coding underway; Implemented = shipped and merged).
     Impl Status tracks code progress (NotStarted = not yet coded; InProgress = work underway;
     Done = merged to main). The two are independent — a module can be
     Doc Status: Finalized and Impl Status: NotStarted. -->

---

## Change Scope

<!-- Omit this section for initial designs (the first time this module file is created).
     Required for --revise mode and incremental designs on existing codebases. -->

**Status:** New | Modified  
**Previous version:** [{{previous module file}}]({{relative path}}) — *only for Modified*  
**What changed:** {{brief description of what differs from the prior version — only for Modified}}

---

## Responsibilities

<!-- 2–3 sentences. State what this module DOES and what it explicitly DOES NOT do.
     If you cannot describe the scope in 2–3 sentences the module is too large — split it.
     Also define any domain-specific terms used below rather than assuming the reader has the PRD. -->

{{What this module is solely responsible for, in precise imperative language.}}

**Out of scope:** {{explicit list of things a reader might expect this module to handle, but doesn't.}}

---

## Architecture Position

<!-- Mermaid diagram showing where this module sits in the overall system.
     Show at minimum: this module's box, every direct caller, and every direct dependency.
     Label each edge with the data or call type (e.g., REST, gRPC, event, in-process). -->

```mermaid
graph LR
    subgraph Callers
        {{M-NNN-caller}}["{{Caller Module}}"]
    end
    subgraph This
        {{M-NNN}}["{{This Module}}"]
    end
    subgraph Deps
        {{M-NNN-dep}}["{{Dependency Module}}"]
        {{ExtSvc}}["{{External Service}}"]
    end

    {{M-NNN-caller}} -- "{{call type}}" --> {{M-NNN}}
    {{M-NNN}} -- "{{call type}}" --> {{M-NNN-dep}}
    {{M-NNN}} -- "REST/SDK" --> {{ExtSvc}}
```

---

## Source Features

<!-- Relative paths from this module file to the PRD feature files.
     From docs/raw/design/YYYY-MM-DD-{slug}/modules/M-NNN-{slug}.md the typical form is:
     ../../../prd/YYYY-MM-DD-{slug}/features/F-NNN-{slug}.md
     Verify each link resolves from the module file's filesystem location. -->

- [F-{{NNN}}: {{Feature Name}}](../../../prd/{{YYYY-MM-DD-slug}}/features/F-{{NNN}}-{{slug}}.md) — {{which part of the feature this module implements}}
- [F-{{NNN}}: {{Feature Name}}](../../../prd/{{YYYY-MM-DD-slug}}/features/F-{{NNN}}-{{slug}}.md) — {{which part of the feature this module implements}}

<!-- X5 lint (check-feature-module-traceability.sh) verifies every F-NNN here resolves to a real
     PRD file and appears as ✦ in the README Feature-Module matrix for this module column. -->

---

## Data Models

<!-- Inline TypeScript or JSON-Schema definitions for every entity this module OWNS or MUTATES.
     Never say "see README.md" or "see architecture.md" — copy the definition here so a coding
     agent can implement without opening a second file.
     Omit this section only if this module owns no persistent data and mutates no shared state. -->

<!-- X7 lint (check-single-source-of-truth.sh) verifies that ID-prefix conventions (e.g. task_,
     usr_) and data-model definitions declared here are also declared as the source of truth in
     the module designated as canonical owner in the Architecture Overview.
     If THIS module IS the canonical owner, prefix each definition with a comment: "// source of truth". -->

```typescript
// REPLACE this entire block with your module's real types — do not keep the example.
// source of truth  ← include this comment only when THIS module is the designated owner

export interface Task {
  id: string;              // format: "task_" + ULID, e.g. "task_01ARZ3NDEKTSV4RRFFQ69G5FAV"
  title: string;           // max 255 characters; required
  description: string | null;  // optional — null when not provided
  status: TaskStatus;      // current lifecycle state
  assigneeId: string | null;   // optional — null when unassigned
  createdAt: string;       // ISO 8601 UTC
  updatedAt: string;       // ISO 8601 UTC
}

export type TaskStatus = "pending" | "in_progress" | "done" | "cancelled";
```

**Database schema (when applicable):**

| Field | Type | Constraints | Index | Description |
|-------|------|-------------|-------|-------------|
| `{{field_name}}` | `{{SQL type}}` | `NOT NULL` / `UNIQUE` / `DEFAULT {{val}}` | Primary / Unique / None | {{description}} |
| `{{field_name}}` | `{{SQL type}}` | `NOT NULL` | `idx_{{table}}_{{field}}` | {{description — why indexed}} |

<!-- Add migration notes here if this module modifies an existing schema:
     Migration: {{migration file or strategy, e.g. "add column non-nullable with DEFAULT ''; backfill; drop DEFAULT"}} -->

---

## Public Interfaces

<!-- TypeScript-style signatures for ALL public interfaces exposed by this module.
     Covers: outbound (what other modules call on this module) and inbound (what this module calls
     on its dependencies — import type from the dependency's Interface Definition, DO NOT redefine).

     Be precise: parameter types, return types, error types. Other modules and coding agents
     depend on this contract. "Returns data" is not a contract; "returns Promise<Task | null>" is.

     L5 lint (check-module-interface-types.sh) verifies every type referenced here resolves to
     a definition either inline in this file's Data Models section or in the named dependency
     module's Interface Definition / Data Models. -->

### Outbound (this module exposes)

```typescript
// REPLACE this entire block with your module's real interface — do not keep the example.
// Outbound interface — callers depend on this signature; changes here are breaking.

export interface TaskService {
  /**
   * Retrieve a task by its ID.
   * @param id task ULID (e.g. "task_01ARZ3NDEKTSV4RRFFQ69G5FAV")
   * @returns Task if found, null if not found
   * @throws AuthorizationError when caller lacks read permission
   */
  getById(id: string): Promise<Task | null>;

  /**
   * Create a new task and persist it.
   * @param input validated creation payload
   * @param actorId ID of the authenticated user performing the action
   * @returns newly created Task
   * @throws ValidationError when input fails schema check
   * @throws AuthorizationError when actor lacks create permission
   */
  create(input: CreateTaskInput, actorId: string): Promise<Task>;
}

// Supporting types — inline definitions so callers do not need to open a second file.
export interface CreateTaskInput {
  title: string;
  description?: string;
}

export interface TaskResult {
  task: Task;
  created: boolean;
}

export class AuthorizationError extends Error {
  constructor(public readonly code: "forbidden" | "unauthenticated", message: string) {
    super(message);
  }
}
```

### Inbound (this module calls on dependencies)

```typescript
// REPLACE this block with your module's real dependency imports — do not keep the example.

// Imported from M-006-auth — do NOT redefine, only import in implementation.
import type { AuthService } from "../m-006-auth";

// Constructor signature — dependency injection pattern used by this module.
// Callers use TaskService; the factory/DI container supplies concrete impls.
export function createTaskService(deps: {
  auth: AuthService;
  db: DatabaseService;
}): TaskService;
```

---

## API Surface

<!-- Required for ANY module that exposes HTTP / gRPC / CLI endpoints.
     Omit ONLY for pure internal library modules with no callable external surface.

     SELF-CONTAINED REQUIREMENT: every column MUST be filled inline — no "see API-NNN" prose
     without an anchor link. A coding agent implementing this handler must never need to open
     a second file. Anchor links to populated examples in the API contract file count as
     inline content; {} placeholders or "TBD" do not.

     L4 lint (check-api-surface-cols.sh) enforces EXACTLY 7 columns per row.
     Column order MUST be: Method+Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints

     For internal-only endpoints with no external caller, set Auth & Role = "internal-only" and
     omit anchor links — use inline descriptions instead. -->

| Method+Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints |
|-------------|-------------|---------|-------------|-----------------|-----------------|-------------|
| `{{METHOD}} {{/v1/resource/:id}}` | `{{scheme — e.g. "bearer JWT"; roles — e.g. "developer,org-admin" or "all"}}` | `{{200 + response shape, e.g. "200 Task"}}` | `{{400 invalid_request_error, 401 unauthenticated_error, 404 not_found_error}}` | [API-{{NNN}}](../api/API-{{NNN}}-{{slug}}.md#request-{{anchor}}) | [API-{{NNN}}](../api/API-{{NNN}}-{{slug}}.md#response-{{anchor}}) | `{{e.g. "body ≤ 1 MB; rate: 10 req/s/key; Idempotent on Idempotency-Key header"}}` |
| `{{METHOD}} {{/v1/resource}}` | `{{auth scheme; roles}}` | `{{201 + shape}}` | `{{400 validation_error, 409 conflict_error}}` | [API-{{NNN}}](../api/API-{{NNN}}-{{slug}}.md#request-{{anchor}}) | [API-{{NNN}}](../api/API-{{NNN}}-{{slug}}.md#response-{{anchor}}) | `{{constraints}}` |

<!-- Column definitions (copied inline per self-contained principle):
     Method+Path      — combined: full HTTP verb + full versioned path (e.g. "POST /v1/tasks/:id")
     Auth & Role      — auth scheme + eligible roles, combined
                        (e.g. "Authorization: Bearer JWT; roles: developer,org-admin")
                        use "none; roles: all" for unauthenticated public endpoints
                        use "internal-only" for endpoints with no external surface
     Success          — success HTTP status + brief response shape (e.g. "200 Task", "201 Task")
     Error Codes      — at least one status code + error-type string per distinct error path
                        (e.g. "400 invalid_request_error, 401 unauthenticated_error, 404 not_found_error")
     Request Example  — anchor link to the populated JSON request block in the owning api/API-NNN-slug.md
                        Format: [API-NNN](../api/API-NNN-slug.md#request-anchor)
                        FORBIDDEN: literal "{}", "TBD", "see API-NNN" without anchor
     Response Example — anchor link to the populated JSON response block in the owning api/API-NNN-slug.md
                        Format: [API-NNN](../api/API-NNN-slug.md#response-anchor)
                        FORBIDDEN: literal "{}", "TBD", "see API-NNN" without anchor
     Constraints      — rate limits, payload size, idempotency, and other per-endpoint constraints
                        (e.g. "body ≤ 1 MB; 10 req/s/key; Idempotent on Idempotency-Key header") -->

<!-- X2 lint (check-endpoint-literal-vs-api.sh) verifies every Method+Path literal here has a
     matching endpoint heading in the referenced api/API-NNN-slug.md file, and that no api/*.md
     endpoint is orphaned (not claimed by any module's API Surface). -->

---

## Boundary Enforcement

<!-- Lint rules, structural tests, or CI checks that mechanically guard this module’s boundaries.
     An agent whose changes violate these will have its build rejected.

     L3 lint (check-boundary-enforcement-cols.sh) enforces EXACTLY 4 columns per row.
     Column order MUST be: Constraint | Tool / Lint / Test | File Path | CI Job

     If you cannot fill all four columns with concrete named identifiers and repo-relative paths,
     the constraint is advisory — move it to Implementation Constraints instead. “custom lint”
     or “code review” without a named rule is NOT acceptable in this table.

     Omit this section only for trivial S-complexity modules with no CI infrastructure. -->

| Constraint | Tool / Lint / Test | File Path | CI Job |
|------------|-------------------|-----------|--------|
| `{{concrete boundary rule, e.g. "Only authenticated users may create resources"}}` | `{{named rule identifier, e.g. "middleware:auth-guard" or "eslint:no-restricted-paths" or "zod:CreateResourceSchema"}}` | `{{repo-relative path to the rule implementation, e.g. "src/middleware/auth-guard.ts"}}` | `{{CI job name that runs this check, e.g. "lint" or "test:integration"}}` |
| `{{concrete boundary rule}}` | `{{named rule identifier}}` | `{{repo-relative file path}}` | `{{CI job name}}` |

<!-- Column definitions (from structural-lint.md L3):
     Constraint       — one concrete boundary rule in precise language; “code should be clean” is
                        rejected; must be testable / machine-checkable
     Tool / Lint / Test — named rule identifier, NOT descriptive English
                        (e.g. middleware:auth-guard, golangci-lint:errcheck,
                        eslint:no-restricted-paths:repo-no-service, zod:CreateResourceSchema)
     File Path        — repo-relative path that resolves to the actual rule implementation file
                        (e.g. src/middleware/auth-guard.ts, scripts/check-boundary.sh)
     CI Job           — exact CI job name that executes this check; must match a job defined in
                        the Development Infrastructure module’s CI pipeline definition -->

---

## Dependencies

<!-- Direct outbound dependency module slugs (M-NNN format).
     X1 lint (check-module-deps-vs-protocols.sh) verifies every (caller, callee) pair listed here
     has a corresponding row in README.md's Module Interaction Protocols table — and vice versa.
     Orphan deps (declared here but absent from README protocols) and orphan protocol rows
     (in README but absent here) both fail X1.

     List only DIRECT dependencies — do not list transitive deps.
     For each dep, state the call direction and what data or service is exchanged. -->

**Depends on (outbound):**
- `{{M-NNN-slug}}` — {{why / what data this module calls on the dependency}}
- `{{M-NNN-slug}}` — {{why / what data}}

**Depended on by (inbound):**
- `{{M-NNN-slug}}` — {{why / what data the caller gets from this module}}

**External services** (from PRD architecture.md External Dependencies — copy inline):

<!-- Omit this sub-section if this module calls no external services. -->

| Service | Purpose | API Style | Timeout | Failure Mode | Fallback |
|---------|---------|-----------|---------|-------------|----------|
| `{{ServiceName}}` | {{what this module uses it for}} | REST / gRPC / SDK | `{{N}}ms` | {{what happens when the service is down or returns 5xx}} | {{degraded behavior, retry strategy, or circuit-breaker policy}} |

---

## Test Strategy

<!-- Self-contained: a coding agent must know exactly what tests to write from this section alone.
     Copy toolchain choices (framework, runner) inline from README's Test Strategy — do NOT cross-
     reference; copy, so the module file is self-contained.
     Derive test scenarios from: Interface Definition (public contract), Error Handling (failure
     paths), and Internal Design (complex logic branches).

     STACK SOURCE: test framework, runner, and coverage tooling MUST be taken from
     clarification.yml `stack.testing` key (if present) or from README Implementation Conventions.
     Do not invent a test stack ad-hoc — inconsistent choices across modules break shared
     test infrastructure.

     Omit this section only for S-complexity modules with no dependencies and no error paths. -->

**Test isolation** — how this module is tested independently:

| Dependency | Test Double | Source | Rationale |
|------------|-------------|--------|-----------|
| `{{M-NNN-dep}}` | `fakes.{{DepService}}` | Shared Test Fakes Inventory | {{e.g. "records calls in memory; callers assert on count + payload"}} |
| `{{M-NNN-dep}}` | `fakes.{{DepService}}` | Shared Test Fakes Inventory | {{rationale}} |
| `{{External: ServiceName}}` | recorded responses | Module-local (`{{internal/slug/testdata/service/}}`) | {{why module-local and not shared}} |

<!-- If this module introduces a new fake that >1 module will need, add it to the Shared Test
     Fakes Inventory in README.md instead of keeping it module-local. -->

**Test pyramid allocation:**

| Layer | Framework | Target Coverage | Focus |
|-------|-----------|----------------|-------|
| Unit | {{e.g. Jest / Vitest / go test}} | `{{≥ N%}}` line coverage on core logic | Interface contract, error paths, edge cases |
| Integration | {{e.g. Supertest / httptest}} | All API Surface endpoints | Real DB / service; verify status codes + body shape |
| Contract | {{e.g. Pact / shared fixtures}} | All Module Interaction Protocols rows | Callee verifies it meets caller's expectations |

**Key test scenarios:**

| Scenario | Type | What to Verify |
|----------|------|----------------|
| {{e.g. "{{methodName}} with valid input"}} | Unit | {{expected return value or state change}} |
| {{e.g. "{{methodName}} when dep returns error"}} | Unit | {{error propagated with correct type and message}} |
| {{e.g. "POST /v1/{{resource}} happy path"}} | Integration | {{201 response, entity persisted, event emitted}} |
| {{e.g. "POST /v1/{{resource}} missing required field"}} | Integration | {{400 validation_error, no entity created}} |
| {{e.g. "M-NNN calls {{methodName}} — contract"}} | Contract | {{shared fixture asserts response shape matches M-NNN expectations}} |

**Contract tests:** {{list every Module Interaction Protocols row this module participates in (as caller or callee) and must verify — e.g. "as callee: M-001 calls {{methodName}}() — verify contract with shared test fixture at testdata/contracts/M-001-{{slug}}.json"}}

**Coverage target:** {{e.g. "≥80% line coverage for core business logic (Internal Design section); every error path in Error Handling MUST have an explicit test case; uncovered lines in boundary/auth paths are P0 blockers."}}

---

## NFR Decomposition

<!-- This module's share of PRD NFRs. Every entry MUST reference the source NFR ID from the PRD
     and state a concrete, measurable target. "Should be fast" is rejected.
     Omit this section only if the module carries no PRD NFR allocation. -->

| NFR Source | Category | Constraint |
|------------|----------|------------|
| `{{NFR-NNN}}` | Performance | {{e.g. P99 latency < 200ms measured at handler entry; P50 < 50ms}} |
| `{{NFR-NNN}}` | Throughput | {{e.g. Sustain 500 req/s per instance at P99 < 200ms; horizontal scaling via stateless design}} |
| `{{NFR-NNN}}` | Error Budget | {{e.g. Error rate < 0.1% of requests; 99.9% availability per calendar month}} |
| `{{NFR-NNN}}` | Security | {{e.g. All inputs sanitized; no raw SQL; auth token validated before any data access}} |
| `{{NFR-NNN}}` | Data Retention | {{e.g. Hard-delete records after 90 days; anonymize PII fields within 30 days of account deletion}} |

---

## Observability

<!-- Structured event names, metric names, and trace span names for this module.
     These MUST match the PRD Analytics event names exactly — the Analytics Coverage section
     in README.md (checked by X4 lint) maps every PRD event to an owning module.
     Do NOT invent new event names here; derive from PRD features' Analytics tables. -->

**Structured logs** (emitted at significant state transitions):

| Event Name | Level | Fields | Trigger |
|------------|-------|--------|---------|
| `{{module.slug.event_name}}` | INFO | `{{field1, field2, field3}}` | {{when this log line is emitted}} |
| `{{module.slug.event_name}}` | ERROR | `{{field1, error_code, trace_id}}` | {{on which error condition}} |

**Metrics** (exported to Prometheus / StatsD / equivalent):

| Metric Name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `{{module_slug_operation_duration_seconds}}` | Histogram | `{{method, status_code, route}}` | {{latency of {{operation}}; P99 target from NFR above}} |
| `{{module_slug_errors_total}}` | Counter | `{{error_code, operation}}` | {{total error count by type}} |

**Distributed traces:**

| Span Name | Parent | Attributes | When Created |
|-----------|--------|------------|--------------|
| `{{module-slug.operation}}` | `{{parent-span or "root"}}` | `{{attr1, attr2}}` | {{entry point for {{operation}}}} |

---

## Internal Design

<!-- Core algorithms, state management, key flows — enough detail that a coding agent can implement
     without guessing. Not so much that it becomes pseudocode for every line.
     If source features define State Flow diagrams (stateDiagram), extract and refine the state
     machines here with implementation-level detail.

     Use Mermaid flowcharts or sequence diagrams for non-trivial flows. -->

### Key Flows

```mermaid
sequenceDiagram
    participant Caller as {{Caller (M-NNN or external)}}
    participant This as {{This Module}}
    participant Dep as {{Dependency (M-NNN or external service)}}

    Caller->>This: {{methodName}}({{params}})
    This->>Dep: {{depCall}}({{params}})
    Dep-->>This: {{response}}
    This-->>Caller: {{return value or error}}
```

### State Machine (when applicable)

```mermaid
stateDiagram-v2
    [*] --> {{InitialState}}
    {{InitialState}} --> {{NextState}}: {{trigger}}
    {{NextState}} --> {{FinalState}}: {{trigger}}
    {{FinalState}} --> [*]
```

### Algorithms and Invariants

- {{Describe key algorithms or invariants that a coding agent must preserve. E.g.: "The deduplication window is a sliding 5-minute TTL set; keys are SHA-256 of (user_id, idempotency_key)."}}
- {{Describe concurrency model: e.g. "All writes are serialized through a per-entity advisory lock; reads are non-locking."}}

---

## UI Architecture

<!-- Omit this section for backend and shared library modules.
     Required for frontend modules (Type = frontend).

     STACK SOURCE: component framework, state management library, routing, and i18n library MUST
     be taken from clarification.yml `stack.frontend` key (if present) or from README
     Implementation Conventions. Do not make ad-hoc framework choices — inconsistent choices
     across frontend modules produce conflicting stack signals for coding agents.

     SEMANTIC NOTE: PRD Phase 5 ("Frontend Draft") has already produced runnable code at the
     repo-relative path below. This section's role is NOT to design the UI from scratch — it
     is to (a) document the contracts the existing draft realises and (b) specify the
     hardening that autoforge must add on top of the draft to reach production. The Component
     Tree, Routing, State Management, Key Interactions sections below describe the contracts
     that the existing code SHOULD match (treat divergences as draft gaps to fix during
     promotion). The Promotion Requirements subsection lists the net-new production work that
     does NOT yet exist in the draft. -->

**Views owned:** {{list of views from README's View / Screen Index that this module implements}}

**Draft path:** `{{repo-relative path to the PRD Phase 5 draft for this module — same as Draft Path in README View/Screen Index; "—" if no draft produced (Action = Rewrite or net-new view)}}`

**Promotion action:** `{{Promote | Extend | Rewrite — must match the value in README's Production Promotion Plan and View/Screen Index for the views this module owns}}`

### Component Tree

<!-- Show 2–3 levels of nesting. Leaf nodes are the smallest independently testable UI units
     (e.g. a form, a data table, a navigation bar) — not individual HTML elements.
     For Action = Promote/Extend: this tree describes the expected structure of the existing
     draft code. Note any divergence as a Promotion Requirement under "Coding-standard
     alignment". For Action = Rewrite: this tree is the design autoforge will implement. -->

```
{{ViewName}}/
├── {{ViewName}}Layout          # top-level layout container
│   ├── {{SectionA}}            # major UI section
│   │   ├── {{ChildComponent}}
│   │   └── {{ChildComponent}}
│   └── {{SectionB}}
│       └── {{ChildComponent}}
```

### Routing

| Route | Component | Guard | Lazy Load | Data Prefetch |
|-------|-----------|-------|-----------|---------------|
| `{{route pattern}}` | `{{ComponentName}}` | `{{authGuard / roleGuard('admin') / —}}` | `{{Yes / No}}` | `{{fetchData(id) / none}}` |

<!-- Guard: name of the route guard function. Use "—" if no guard. Implementation belongs in
     Internal Design. -->

### State Management

| State | Source | Scope | Implementation | Sync Strategy |
|-------|--------|-------|---------------|---------------|
| `{{stateName}}` | `{{API call / local / URL params}}` | `{{view / global / component}}` | `{{e.g. Zustand slice / useState / useSearchParams}}` | `{{e.g. React Query 30s stale / URL ↔ state sync on mount / —}}` |

### Key Interactions

| Interaction | Component | Triggers | Side Effects | Optimistic? |
|-------------|-----------|----------|-------------|-------------|
| `{{e.g. submit form}}` | `{{ComponentName}}` | `{{e.g. POST /v1/resource via M-NNN}}` | `{{toast, invalidate query cache}}` | `{{Yes — add to list, rollback on error / No}}` |

### Frontend Performance

<!-- Use Web Vitals for web modules; use the TUI table below for terminal modules. -->

**Web:**

| Metric | Target | Measurement | Optimization |
|--------|--------|-------------|-------------|
| LCP | `{{< 2.5s}}` | `{{Lighthouse CI}}` | `{{code-split route, preload critical CSS}}` |
| INP | `{{< 200ms}}` | `{{Web Vitals lib}}` | `{{debounce search, virtualize long lists}}` |
| CLS | `{{< 0.1}}` | `{{Lighthouse CI}}` | `{{reserve space for async content}}` |
| Bundle (this module) | `{{< 150 KB gzipped}}` | `{{bundlesize CI check}}` | `{{tree-shake, lazy-load heavy deps}}` |

**TUI (use instead of Web Vitals for terminal modules):**

| Metric | Target | Measurement | Optimization |
|--------|--------|-------------|-------------|
| Render latency | `{{< 16ms per frame}}` | `{{teatest frame timing}}` | `{{avoid full re-render, update only changed regions}}` |
| Input-response time | `{{< 50ms}}` | `{{benchmark test}}` | `{{debounce rapid keystrokes}}` |
| Memory (RSS) | `{{< 150 MB with 500 messages}}` | `{{runtime.ReadMemStats}}` | `{{evict old messages, cap in-memory history}}` |

### Design System Usage

{{Which patterns from README's Design System Conventions this module applies — e.g. "loading skeletons for async data, toast notifications for mutations, Sheet sidebar on mobile."}}

### Accessibility Implementation

- **Tab order:** {{describe the logical focus flow through this module's views}}
- **ARIA:** {{reference PRD feature spec's ARIA table; note implementation nuances}}
- **Testing:** {{e.g. "axe-core integration test for each view; manual screen reader test for {{complex interaction}}"}}

### i18n Implementation (Frontend)

- **Namespace:** `{{e.g. dashboard, tasks — maps to i18n key prefix from PRD feature specs}}`
- **Lazy loading:** {{e.g. "load locale files per-route to reduce initial bundle"}}
- **Fallback:** {{e.g. "en as fallback; show key name if translation missing in dev"}}

### Promotion Requirements

<!-- REQUIRED for every frontend module with Promotion action = Promote or Extend.
     For Action = Rewrite this subsection MAY be omitted (autoforge implements from the
     contracts above, and the standard production conventions apply by default).

     Lists the net-new hardening work autoforge must do on top of the existing PRD draft.
     The PRD draft validated experience only — i18n / a11y / tests / lint / perf budgets
     were explicitly out of scope at PRD time. Specify each of the five categories below;
     if a category is genuinely N/A, say so with a one-line rationale rather than dropping
     the row. CR-SD-ui-hardening-coverage enforces full coverage. -->

| Category | Current Draft State | Hardening Required |
|----------|---------------------|--------------------|
| **i18n integration** | {{e.g. "draft uses inline strings under a single `strings.ts` table"}} | {{e.g. "wire react-i18next per architecture stack; extract into `{namespace}` keyspace; add locale negotiation; remove inline strings"}} |
| **Accessibility** | {{e.g. "draft uses semantic HTML and basic ARIA roles on top-level landmarks"}} | {{e.g. "full keyboard map per view; focus management on modals/dialogs; axe-core CI check; screen-reader pass on form flows"}} |
| **Performance** | {{e.g. "no budget enforced — bundle currently ~280 KB raw"}} | {{e.g. "code-split per route; meet LCP/INP/CLS targets above; bundlesize CI gate at 150 KB gzipped"}} |
| **Tests** | {{e.g. "no automated tests — manual walkthrough only at draft phase"}} | {{e.g. "unit tests on component contracts (> 80% lines); integration tests on state-machine transitions; Playwright E2E on each route"}} |
| **Coding-standard alignment** | {{e.g. "draft has 14 ESLint warnings; TypeScript `any` in 3 places; some inline styles"}} | {{e.g. "zero lint warnings; eliminate `any`; remove all inline styles; align file structure with framework convention"}} |

---

## Backend i18n Implementation

<!-- Run through the trigger checklist — if any answer is YES this section is mandatory.
     Omit only when ALL answers are NO (or backend is single-language with no user-facing text).

     STACK SOURCE: locale resolution middleware, message catalog library, and namespace
     conventions MUST be taken from clarification.yml `stack.i18n` key (if present) or from
     README Implementation Conventions. Do not invent an i18n strategy per-module. -->

**Trigger checklist** (answer YES/NO for this module):

- [ ] Returns HTTP error messages with human-readable `message` fields?
- [ ] Returns validation errors with field-level human-readable text?
- [ ] Emits user-facing notifications (email, push, SMS, in-app)?
- [ ] Returns user-facing labels or enum values that must be localized?
- [ ] Handles timestamps serialized to user-local time (not pure UTC) at this module's boundary?

<!-- If ANY box is ticked, fill all four fields below.
     If ALL boxes are unticked, delete the four fields and add a one-line note to Relevant
     Conventions instead: "Backend i18n: N/A — module returns only machine-readable error codes
     and UTC timestamps; localization responsibility is on caller." Silent omission on an
     HTTP-facing module is a review finding. -->

- **Locale context:** {{how this module receives the request locale — e.g. "from i18n.FromContext(ctx) set by M-006 LocaleMiddleware"}}
- **Message catalog access:** {{concrete call site — e.g. "i18n.Localize(ctx, 'backend.{{slug}}.errors.not_found') at internal/{{slug}}/service.go:142"; name the catalog namespace}}
- **Locale-dependent outputs:** {{enumerate every interface method/response field that returns localized content}}
- **Timezone:** {{e.g. "stores UTC; converts via user.timezone at handler.serialize{{Entity}}", or "all timestamps UTC ISO 8601 — no conversion, client responsible"}}

---

## Relevant Conventions

<!-- Copy applicable stack-specific implementation patterns from README's Implementation
     Conventions section. Use the translated language/framework idioms, not raw PRD policies.
     Also include applicable Shared Conventions from PRD architecture.md.
     Omit conventions this module does not touch.

     If this module requires a convention not yet in README's Implementation Conventions, add the
     pattern here with a note: "[NEW — propose adding to README Implementation Conventions]".
     The design review will surface these for promotion to project-wide conventions. -->

- **Error handling:** {{e.g. "fmt.Errorf("doing X: %w", err) — from Implementation Conventions error-handling pattern"}}
- **Logging:** {{e.g. "slog.Info("event", "key", val) with JSON handler — from Implementation Conventions logging pattern"}}
- **Input validation:** {{e.g. "zod schema at handler layer, never in service layer — only if this module handles external input"}}
- **Concurrency:** {{e.g. "context.Context as first parameter; errgroup for goroutine lifecycle — only if this module uses concurrency"}}
- **Test isolation:** {{e.g. "t.TempDir(), net.Listen("tcp", ":0") — from Implementation Conventions test-isolation pattern"}}
- **API format:** {{e.g. "JSON over REST; cursor-based pagination — only if this module exposes or consumes APIs"}}
- **Error format:** {{e.g. "RFC 7807 Problem Details with application/problem+json — only if this module produces error responses"}}
- **Backend i18n:** {{N/A note here if all trigger-checklist boxes are unticked — mandatory explicit opt-out for HTTP-facing modules}}
- **Stack context:** {{copy verbatim from clarification.yml `stack:` block — include `stack.frontend`, `stack.backend`, `stack.testing`, and `stack.i18n` keys applicable to this module; if clarification.yml has no `stack:` block, derive from README Implementation Conventions and note the source}}

---

## Implementation Constraints

<!-- Non-NFR technical constraints: language/runtime version requirements, platform compatibility,
     architectural prohibitions, required libraries or protocols.
     Pitfalls to avoid: known anti-patterns, concurrency traps, common mistakes in this domain.
     Items that cannot meet all four Boundary Enforcement columns belong here as advisory guidance. -->

- {{e.g. "Requires Node.js ≥ 20 LTS; do not use CommonJS require() — ESM only per project standard."}}
- {{e.g. "MUST NOT import from {{M-NNN-slug}} — that module is in a higher layer per Dependency Layering rules."}}
- {{e.g. "Avoid N+1 queries: batch-load related entities using DataLoader or equivalent."}}
- {{e.g. "Do not store secrets in process.env at module load time — read them inside the request handler from the secrets manager."}}

---

## Error Handling

<!-- How this module handles each significant error scenario.
     Omit only if errors are trivially propagated with no module-specific strategy.
     For each scenario: state what triggers it, how it is caught, what is returned, and whether
     it is retried, logged, or surfaced to the caller. -->

| Error Scenario | Trigger | Handling Strategy | Caller-Facing Response |
|----------------|---------|-------------------|----------------------|
| `{{dependency unavailable}}` | `{{M-NNN-dep throws NetworkError}}` | `{{Log + return service_unavailable}}` | `{{503 service_unavailable_error}}` |
| `{{validation failure}}` | `{{input fails schema check}}` | `{{Reject immediately, no DB write}}` | `{{400 validation_error with field-level detail}}` |
| `{{entity not found}}` | `{{DB returns null for given ID}}` | `{{Return null from service; handler maps to 404}}` | `{{404 not_found_error}}` |
| `{{concurrent modification}}` | `{{optimistic lock version mismatch}}` | `{{Retry up to 3× with exponential backoff; fail after}}` | `{{409 conflict_error}}` |

---

## Open Questions

<!-- Questions that must be resolved before or during implementation. Each question should
     reference the person or decision-making process that can resolve it.
     Remove resolved questions; do not leave stale items. -->

- [ ] `{{Q-NNN}}` {{Question text.}} — *Owner: {{name or role}}; Due: {{date or sprint}}*
- [ ] `{{Q-NNN}}` {{Question text.}} — *Owner: {{name or role}}; Due: {{date or sprint}}*
