# Module Spec Template

Each file is **self-contained** — a coding agent implements the module by reading only this file.

## Template

The module file follows this structure. Omit any section that has no useful content.

### Header

```
# M-{001}: {Module Name}

> **Source Features:** F-001, F-003  **Complexity:** S | M | L | XL
```

### Change Scope

{Only for revised designs (via `--revise`) or incremental designs on existing codebases. Omit for initial designs.}

**Status:** New | Modified
**Previous version:** [{previous module file}]({relative path}) — {only for Modified}
**What changed:** {only for Modified — brief description of changes from the previous version}

{Unchanged modules are carried forward verbatim from the previous version — no Change Scope section needed.}

### Responsibility

{What this module does and does NOT do — 2-3 sentences}

### Architecture Position

{Where this module sits in the overall architecture, which modules it interacts with — Mermaid diagram}

### Interface Definition

{Public interfaces / exported functions exposed to other modules. Use the project's language for code examples:}

```go
type TaskSource interface {
    Parse(input string) ([]Task, error)
}
```

### API Surface

{**Required** for any module that exposes HTTP/gRPC/CLI endpoints. Omit only for pure internal library modules with no callable external surface. Each row below is one endpoint; every column must be filled (no blanks, no "see API-XXX" cross-references — the module file is self-contained).}

| Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints |
|--------------|-------------|---------|-------------|----------------|------------------|-------------|
| `POST /v1/tasks` | `x-api-key` + Developer | 201 | 400 invalid_request, 409 conflict, 429 rate_limit | see [API-001](../api/API-001-task.md#create-task) | see [API-001](../api/API-001-task.md#create-task) | idempotent on `Idempotency-Key`; body ≤ 1 MiB; 10 req/s/key |

Required columns (every row, no exceptions):
- **Method + Path** — full HTTP verb + path (include dual paths if the module serves `/v1/*` and `/api/v1/*`; do not rely on a file-level alias note)
- **Auth & Role** — required headers + role matrix (e.g. `x-api-key` + Developer/OrgAdmin/Admin), or `internal-only` for modules without external surface
- **Success** — HTTP status code for the happy path
- **Error Codes** — all triggerable status codes with error-type strings (e.g. `400 invalid_request_error`, `422 resource_error`)
- **Request Example / Response Example** — anchor links to populated JSON blocks in the owning API contract file (`api/API-XXX.md#...`); `{}` placeholder is not acceptable
- **Constraints** — rate limits, size caps, idempotency, concurrency caps (copy inline — do not say "see API contract")

If this module owns the API contract file itself, still fill all columns here (pointing to the API file's anchors) — a coding agent reading only this module file must be able to implement the handler without opening the API file.

### Relevant Conventions

{Copy applicable stack-specific implementation patterns from README's Implementation Conventions section. Use the translated patterns (language/framework idioms), not raw PRD policies. Also include applicable Shared Conventions from PRD architecture.md. Omit conventions this module doesn't touch.}

- **Error handling:** {e.g. `fmt.Errorf("doing X: %w", err)` — from Implementation Conventions error handling pattern}
- **Logging:** {e.g. `slog.Info("event", "key", val)` with JSON handler — from Implementation Conventions logging pattern}
- **Input validation:** {e.g. `validate` struct tags at handler layer — only if this module handles external input}
- **Concurrency:** {e.g. `context.Context` first parameter, `errgroup` for goroutine lifecycle — only if this module uses concurrency}
- **Test isolation:** {e.g. `t.TempDir()`, `net.Listen("tcp", ":0")` — from Implementation Conventions test isolation pattern}
- **API format:** {e.g. JSON, REST, pagination style — only if this module exposes or consumes APIs}
- **Error format:** {e.g. RFC 7807 Problem Details — only if this module produces error responses}
- **Testing:** {e.g. Jest for unit, Supertest for integration — framework mandates from PRD/README Test Strategy; see Testing section below for module-specific test strategy}

If this module requires a convention pattern not yet documented in README's Implementation Conventions, add the pattern to this module's Relevant Conventions section with a note: `[NEW — propose adding to README Implementation Conventions]`. The design review will surface these for promotion to project-wide conventions.

### Internal Design

{Core algorithms, state management, key flows — flowcharts or pseudocode. If source features define State Flow diagrams (stateDiagram), extract and refine the state machines here with implementation-level detail.}

### UI Architecture

{Only for frontend modules (Type = frontend). Omit for backend modules.}

**Views owned:** {list of views from README's View / Screen Index that this module implements}

**Prototype Reuse Guide:**

{Omit if no prototype exists for this module's source features, or if all mapped prototypes have Action = Rewrite.}

- **Source:** `{PRD path}/prototypes/src/{feature-slug}/` {web or TUI}
- **Action:** {Reuse / Refactor — from README Prototype-to-Production Mapping}
- **Files to copy/adapt:**

| Prototype File | Production Target | Action | Adaptation Notes |
|---------------|-------------------|--------|-----------------|
| {e.g. `sidebar.go`} | {e.g. `internal/tui/sidebar.go`} | Copy | {e.g. replace mock data with real agent state from M-003} |
| {e.g. `theme.go`} | {e.g. `internal/tui/theme.go`} | Copy | {e.g. no changes — token constants are production-ready} |
| {e.g. `TaskList.tsx`} | {e.g. `src/components/TaskList.tsx`} | Refactor | {e.g. extract API calls to service layer, add error boundary} |

- **Reusable patterns:** {list patterns the coding agent should preserve — e.g. "state machine in `Update()` method matches PRD spec; lipgloss styling approach; message routing pattern between models"}
- **What to discard:** {e.g. "hardcoded mock data in `testdata.go`; placeholder spinner — replace with real heartbeat from scheduler events"}

{**Rule:** When Action = Reuse, the coding agent MUST start by copying prototype files, then adapt. Do NOT rewrite from scratch. When Action = Refactor, start from prototype code and apply the documented adaptations.}

**Component Tree:**

{Show 2-3 levels of nesting. Leaf nodes are the smallest independently testable UI units (e.g., a form, a data table, a navigation bar) — not individual HTML elements.}

```
{ViewName}/
├── {ViewName}Layout          # top-level layout container
│   ├── {SectionA}            # major UI section
│   │   ├── {ChildComponent}
│   │   └── {ChildComponent}
│   └── {SectionB}
│       └── {ChildComponent}
```

**Routing:**

| Route | Component | Guard | Lazy Load | Data Prefetch |
|-------|-----------|-------|-----------|---------------|
| {route pattern from PRD} | {component name} | {e.g. authGuard / none} | {Yes / No} | {e.g. fetchData(id) / none} |

Guard: Name of the route guard function (e.g., `authGuard`, `roleGuard('admin')`). Use `—` if no guard is needed. Guards are referenced by name; implementation details belong in the module's Internal Design section.

**State Management:**

| State | Source | Scope | Implementation | Sync Strategy |
|-------|--------|-------|---------------|---------------|
| {e.g. taskList} | {API call / local / URL params} | {view / global / component} | {e.g. Zustand slice / useState / useSearchParams} | {e.g. React Query with 30s stale time / URL ↔ state sync on mount / —} |

**Key Interactions:**

| Interaction | Component | Triggers | Side Effects | Optimistic? |
|-------------|-----------|----------|-------------|-------------|
| {e.g. submit form} | {component name} | {e.g. POST /tasks via M-001} | {e.g. toast notification, invalidate query cache} | {Yes — add to list, rollback on error / No} |

**Frontend Performance (Web):**

| Metric | Target | Measurement | Optimization |
|--------|--------|-------------|-------------|
| LCP | {e.g. < 2.5s} | {e.g. Lighthouse CI} | {e.g. code split route, preload critical CSS} |
| INP | {e.g. < 200ms} | {e.g. Web Vitals lib} | {e.g. debounce search, virtualize long lists} |
| CLS | {e.g. < 0.1} | {e.g. Lighthouse CI} | {e.g. reserve space for async content} |
| Bundle (this module) | {e.g. < 150 KB gzipped} | {e.g. bundlesize CI check} | {e.g. tree-shake, lazy load heavy deps} |

**Frontend Performance (TUI):** {Use this table instead of Web Vitals for TUI modules.}

| Metric | Target | Measurement | Optimization |
|--------|--------|-------------|-------------|
| Render latency | {e.g. < 16ms per frame} | {e.g. teatest frame timing} | {e.g. avoid full re-render, update only changed regions} |
| Input-response time | {e.g. < 50ms} | {e.g. benchmark test} | {e.g. debounce rapid keystrokes} |
| Memory (RSS) | {e.g. < 150 MB with 500 messages} | {e.g. runtime.ReadMemStats} | {e.g. evict old messages, cap in-memory history} |

**Design System Usage:** {which patterns from README's Design System Conventions this module applies — e.g. "loading skeletons for async data, toast notifications for mutations, Sheet sidebar on mobile"}

**Accessibility Implementation:**
- Tab order: {describe the logical focus flow through this module's views}
- ARIA: {reference PRD feature spec's ARIA table; note implementation nuances}
- Testing: {e.g. "axe-core integration test for each view; manual screen reader test for {complex interaction}"}

**i18n Implementation (Frontend):**
- Namespace: {e.g. `dashboard`, `tasks` — maps to i18n key prefix from PRD feature specs}
- Lazy loading: {e.g. "load locale files per-route to reduce initial bundle"}
- Fallback: {e.g. "en as fallback; show key name if translation missing in dev"}

### Backend i18n Implementation

{Run through the trigger checklist below — if any answer is **yes**, this section is mandatory. Omit only when all answers are no (or the backend is single-language).}

**Trigger checklist** (answer each yes/no for this module):
- [ ] Returns HTTP error messages with human-readable `message` fields? (not just `error.type` codes)
- [ ] Returns validation errors with field-level human-readable text?
- [ ] Emits user-facing notifications (email, push, SMS, in-app)?
- [ ] Returns user-facing labels/enum values that must be localized (status names, reason strings shown in UI)?
- [ ] Handles timestamps that are serialized to user-local time (not pure UTC) at this module's boundary?

If **any** box is ticked, fill all four fields below:

- **Locale context:** {how this module receives the request locale — e.g. "from `i18n.FromContext(ctx)` set by M-006 LocaleMiddleware", "from `user.preferred_locale` field loaded by M-010 Auth"}
- **Message catalog access:** {concrete call site — e.g. "`i18n.Localize(ctx, 'backend.tasks.errors.not_found')` at `internal/tasks/service.go:142`"; name the catalog namespace (e.g. `backend.{module-slug}.errors.*`)}
- **Locale-dependent outputs:** {enumerate every interface method/response field that returns localized content — e.g. "Create() → 400 message, Validate() → field-level errors, NotifyUser() → email body"}
- **Timezone:** {e.g. "stores UTC; converts via `user.timezone` at `handler.serializeTask`", or "all timestamps UTC ISO 8601 — no conversion, client responsible"}

If all boxes are unticked, add a one-line note in **Relevant Conventions** instead: "Backend i18n: N/A — module returns only machine-readable error codes and UTC timestamps; localization responsibility is on caller." This single line is the explicit opt-out — omitting the section silently is not acceptable when the module is HTTP-facing.

### Data Model

{Complete schema for entities this module owns or mutates — fields, types, constraints, indexes}

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| ... | ... | ... | ... |

### Error Handling

| Error Scenario | Handling Strategy |
|----------------|-------------------|
| {case} | {handling} |

### Testing

{How this module is tested. Self-contained — a coding agent knows what tests to write from this section alone.}

**Test isolation:** {how this module is tested independently — which dependencies are replaced and with what. Reusable fakes live in the project's Shared Test Fakes Inventory (see README Test Strategy). When a dependency appears in that inventory, reference it by name rather than describing a new fake — this prevents the same fake being reinvented across modules.}

| Dependency | Test Double | Source | Rationale |
|------------|-------------|--------|-----------|
| {e.g. M-032 Audit sink} | `fakes.AuditSink` | Shared Test Fakes Inventory | {e.g. "records emits in memory; callers assert on count + payload"} |
| {e.g. M-002 Storage} | `fakes.Storage` | Shared Test Fakes Inventory | {e.g. "preserves query semantics without real DB"} |
| {e.g. External: Stripe API} | recorded responses | Module-local (`internal/{slug}/testdata/stripe/`) | {why module-local and not shared} |

If this module introduces a new fake that other modules will likely need (e.g. a service dependency reused by >1 caller), add it to the Shared Test Fakes Inventory in README instead of keeping it module-local.

**Key test scenarios:**

| Scenario | Type | What to Verify |
|----------|------|----------------|
| {e.g. Parse valid input} | Unit | {expected output, state change, or side effect} |
| {e.g. Handle storage failure} | Unit | {error propagation, retry behavior} |
| {e.g. Full ingestion pipeline} | Integration | {end-to-end data flow through real dependencies} |

**Contract tests:** {list interactions from Module Interaction Protocols that this module participates in and must verify — e.g. "as callee: M-001 calls Parse() — verify contract with shared test fixtures"}

**Coverage target:** {e.g. "line coverage > 80% for core logic (Internal Design); error paths must have explicit test cases"}

### Non-Functional Requirements

{Explicit per-module constraints derived from PRD NFRs. Each entry references the source NFR and states a concrete, measurable target for this module.}

| NFR Source | Category | Constraint |
|------------|----------|------------|
| {e.g. NFR-001} | Performance | P99 latency < 200ms for query operations |
| {e.g. NFR-003} | Security | All inputs sanitized; no raw SQL; auth token validated before processing |
| {e.g. NFR-002} | Scalability | Stateless design; supports horizontal scaling to 1000 QPS |

### Dependencies

**Internal (modules):**
- Depends on: [M-{XXX}](./M-{XXX}-{slug}.md) — {reason}
- Depended by: [M-{YYY}](./M-{YYY}-{slug}.md) — {reason}

**External (services):** {from PRD architecture.md External Dependencies — only services this module directly calls}

| Service | Purpose | API Style | Timeout | Failure Mode | Fallback |
|---------|---------|-----------|---------|-------------|----------|
| {name} | {what this module uses it for} | REST / gRPC / SDK | {ms} | {what happens when down} | {degraded behavior or retry strategy} |

### Source Features

- [F-001: {name}]({relative path from design dir to PRD feature file}) — {which part of the feature this module implements}

{**Path format:** Use relative paths from this module file to the PRD feature file. From `docs/raw/design/YYYY-MM-DD-{slug}/modules/M-001-{slug}.md`, the path to a PRD feature typically looks like `../../../prd/YYYY-MM-DD-{slug}/features/F-001-{slug}.md`. Verify the link resolves from the module file's location.}

### Implementation Constraints

- {Non-NFR technical constraints: language/runtime version requirements, platform compatibility, architectural prohibitions, required libraries or protocols}
- {Pitfalls to avoid: known anti-patterns, concurrency traps, common mistakes in this domain}

### Boundary Enforcement

{Lint rules, structural tests, or CI checks that mechanically guard this module's boundaries and conventions. An agent whose changes violate these will have its build rejected.}

| Constraint | Tool / Lint / Test | File Path | CI Job |
|------------|-------------------|-----------|--------|
| {e.g. No imports from Service layer} | `eslint-plugin-import/no-restricted-paths` rule `repo-no-service` | `.eslintrc.js` | `lint` in `.github/workflows/ci.yml` |
| {e.g. All exported functions have JSDoc} | `eslint-plugin-jsdoc/require-jsdoc` | `.eslintrc.js` | `lint` |
| {e.g. File size < 500 lines} | custom structural test | `internal/{slug}/file_size_test.go` | `test` |
| {e.g. `ConfigReader` must be injected — no global singleton} | `depguard` rule forbidding package-level vars in `internal/{slug}/` | `.golangci.yml` | `lint` |

**Column rules** (every row, no exceptions):
- **Constraint** — one concrete rule; descriptive English like "code should be clean" is rejected
- **Tool / Lint / Test** — named tool + rule identifier (e.g. `golangci-lint:errcheck`, `eslint:custom-rule-name`, `go test ./internal/{slug}/...`); not "custom lint"
- **File Path** — path to the config file or test file that encodes the rule — must `grep` to a real file in the repo
- **CI Job** — job name from the CI pipeline that runs the check (e.g. `lint`, `test-unit`, `structural-check`) — must match a job defined in the Development Infrastructure module

If you cannot fill all four columns, the constraint is not enforceable and should be moved to **Implementation Constraints** as advisory guidance, not Boundary Enforcement.

## Rules

- **Responsibility = minimal but sufficient**: only what this module owns. If you can't describe it in 2-3 sentences, the module is too big.
- **Interface Definition is the contract**: other modules and coding agents depend on this. Be precise — parameter types, return types, error types.
- **API Surface is the HTTP contract snapshot**: every HTTP-facing module must fill the API Surface table with all columns (Method+Path / Auth & Role / Success / Error Codes / Request Example / Response Example / Constraints). "See API-XXX" cross-references without inline content are not acceptable — a coding agent must be able to implement the handler from this file alone. Anchor links to populated examples in the API contract file count as inline content; `{}` placeholders or "TBD" do not.
- **Internal Design**: enough detail that a coding agent can implement without guessing, but not so much that it becomes pseudocode for every line.
- **Data Model**: copy inline, never say "see README.md" or "see architecture.md".
- **Relevant Conventions**: copy stack-specific implementation patterns from README's Implementation Conventions (translated from PRD architecture.md convention sections: Shared Conventions, Coding Conventions, Test Isolation, Security Coding Policy, Development Workflow, Git & Branch Strategy, Code Review Policy, Observability Requirements, Performance Testing, Backward Compatibility) — only the ones this module needs. Use the translated language/framework idioms, not raw PRD policies. Ensures coding agents follow consistent patterns without reading external files.
- **NFR = concrete numbers**: don't write "should be fast" — write "P99 < 200ms". Every NFR entry must reference the source NFR ID from the PRD (e.g. NFR-001).
- **External Dependencies**: copy from PRD architecture.md External Dependencies — only services this module directly calls. Include timeout, failure mode, and fallback inline so the module spec is self-contained.
- **Testing = actionable for coding agents**: test isolation must name specific test doubles; key test scenarios must state what to verify, not just "test this works"; contract tests must reference the specific interaction from Module Interaction Protocols. Derive test scenarios from Interface Definition (public contract), Error Handling (failure paths), and Internal Design (complex logic branches). Copy toolchain choices (framework, runner) inline from README's Test Strategy — don't reference, copy, so the module file is self-contained.
- **Omit whitelist** (only these sections may be omitted — all others are mandatory when the module has the corresponding surface):
    - *Change Scope* — omit for initial designs; required for revisions
    - *Data Model* — omit if the module owns no persistent data
    - *Error Handling* — omit only if errors are trivially propagated with no module-specific strategy
    - *Non-Functional Requirements* — omit only if the module carries no PRD NFR allocation
    - *External Dependencies* — omit if the module calls only internal modules
    - *Relevant Conventions* — omit if none of the project's Implementation Conventions rows apply
    - *UI Architecture* — omit for backend/shared modules (required for frontend)
    - *Backend i18n Implementation* — omit only when every trigger-checklist box is unticked; otherwise mandatory
    - *API Surface* — omit only for pure internal library modules with no HTTP/gRPC/CLI endpoint
    - *Testing* — omit only for S-complexity modules with no dependencies and no error paths
    - *Boundary Enforcement* — omit if the project has no linting/CI infrastructure, or for trivial S-complexity modules
  - Sections not on the whitelist (Responsibility, Architecture Position, Interface Definition, Internal Design, Source Features, Implementation Constraints) are always required. Silently dropping them is a review finding.
- **Frontend modules must include UI Architecture**: component tree, routing, state management, key interactions, frontend performance, design system usage, accessibility implementation, and i18n implementation (frontend). This section provides the **implementation architecture** — it references PRD feature specs for the interaction design (component contracts, state machines, a11y requirements) and specifies how to implement them technically.
- **Backend i18n = checklist-driven**: every HTTP-facing backend module must walk the Backend i18n Implementation trigger checklist. If any box is ticked, fill all four fields (Locale context / Message catalog / Locale-dependent outputs / Timezone). If all boxes are unticked, declare it explicitly with a one-line N/A note in Relevant Conventions — silent omission on an HTTP-facing module is a review finding.
- **Inline glossary terms**: if the module uses domain-specific terms from the PRD glossary, define them inline in Responsibility or the relevant section — don't assume the reader has access to the PRD architecture.md glossary.
- **Cross-document paths are relative**: Source Features links point from the module file to the PRD feature file using relative paths (typically `../../../prd/YYYY-MM-DD-{slug}/features/F-001-{slug}.md`). Every link must resolve from the module file's filesystem location so downstream tools (autoforge planners) can follow them.
- **Boundary Enforcement = mechanical, not advisory**: every row must fill all four columns (Constraint / Tool-Lint-Test / File Path / CI Job) with grep-able identifiers. "Should follow X" without an enforcement mechanism, or "custom lint" without a named rule, is not acceptable — move such items to Implementation Constraints as advisory. Derive constraints from the project's Dependency Layering rules and module-level Relevant Conventions.
- **Precise language**: "must", "returns", "rejects" — not "should consider", "might want to".
