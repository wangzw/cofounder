---
name: system-design
description: "Use when the user needs to create system design documents from a PRD or requirements, perform module decomposition, define interfaces and data models, or review existing designs. Triggers: /system-design, 'system design', 'module design', 'technical design', 'design review'."
---

# System Design — AI-Coding-Ready Technical Design

Generate system design documents as a **multi-file directory**. Each module spec is a self-contained file — coding agents read only the file they need. Includes a structured design review phase that directly improves the documents.

## Input Modes

```
/system-design                                    # interactive mode
/system-design path/to/prd/                       # PRD-based mode
/system-design path/to/draft.md                   # document-based mode
/system-design --output docs/raw/design/my-project    # custom output dir
/system-design path/to/prd/ --output ./design     # both
/system-design --review docs/raw/design/xxx/          # review existing design (read-only)
/system-design --revise docs/raw/design/xxx/          # change management for existing design
```

## Process

### Phase 1 — Design Generation

1. **Parse input & confirm scope** — read PRD directory (README.md + journeys/*.md + architecture.md + features/*.md), parse existing design draft/notes file, or gather info interactively. Extract and note: journey flows (end-to-end data paths), cross-journey patterns (shared pain points, repeated touchpoints, handoff points, shared infrastructure needs — from README.md's Cross-Journey Patterns section), external dependencies (services, timeouts, failure modes), deployment architecture, observability requirements, shared conventions, testing conventions (frameworks, coverage targets, test infrastructure), authorization model (roles, permission matrix), privacy & compliance requirements (personal data entities, user rights, retention), notification requirements (from feature Notifications sections), NFRs (with IDs), risks, glossary, and feature analytics events. Summarize understanding back to user, confirm scope before proceeding. **If the project has an existing codebase** (source files, package manifests, or architecture docs present), **enter Incremental Design Mode** (see below) to assess current architecture before continuing.
2. **Module decomposition** — propose module breakdown based on architecture, features, and cross-journey patterns (shared infrastructure needs like search, notification, progress tracking suggest shared/common modules), present to user for confirmation
3. **Interactive refinement** (one question at a time, prefer multiple choice). Cover these topics in order, skip any that are already clear from the input:
   - **Architecture:** key technical choices, infrastructure decisions, dependency layering (forward-only layer order for modules — see Architecture Refinement deep-dive), ambiguities with multiple implementation paths → present options
   - **Modules:** boundary definition, responsibility split, interface protocols between modules
   - **UI / Frontend implementation architecture:** (skip if no user-facing interface) prototype assessment, view-to-module mapping, routing implementation, state management implementation, form strategy, frontend performance budget, design token implementation, component structure, frontend-backend data flow (see Frontend Implementation Architecture deep-dive below)
   - **Data flow:** cross-module interactions, state management, error propagation
   - **NFR decomposition:** take PRD-level NFRs and decompose to module-level constraints — which modules bear the performance/security/scalability load?
   - **Testing:** test pyramid allocation, module test isolation strategy, external dependency test approach, test data management (see Testing Deep-Dive below)
4. **Key technical decisions** — summarize decisions made during interaction, user confirms
5. **Feature-Module mapping** — generate mapping matrix, user confirms
6. **Generate module designs** — generate each module spec, show summary per module
7. **Generate API contracts** — only if the project has APIs. Design API contracts are the refined, authoritative version of PRD feature-level API contracts — they add parameter types, error codes, examples, and constraints. If a PRD feature's API Contract conflicts with the design API contract, the design version takes precedence
8. **Generate README.md** — aggregate index with all sections
9. **Write files** — write all generated files to disk (not yet committed)
10. **Self-review** — read each written file against the review checklist (see Design Review below), fix issues directly in files
11. **User review** — user reviews files in their editor, confirms or requests changes
12. **Commit** — set `Design Input > Status` to `Finalized`

#### Design Status Lifecycle

The design tracks status at two levels: **design-level** (`Design Input > Status` in README.md) and **module-level** (`Impl` column in Module Index).

**Module-level status** (Module Index `Impl` column):

| Impl | Meaning | Set When |
|------|---------|----------|
| — | Not started | Initial generation |
| In progress | Module is being coded | Coding agent starts implementing this module |
| Done | Module implementation complete | Coding agent finishes this module |

**Design-level status** (derived from module-level):

| Status | Meaning | Derived From |
|--------|---------|-------------|
| Draft | Design in progress, not yet committed | Initial generation (steps 1-11) |
| Finalized | Design committed, ready for implementation | Step 12 (commit); all modules still `—` |
| Implementing | Implementation has started | At least one module is `In progress` or `Done`, but not all `Done` |
| Implemented | All modules implemented | All modules are `Done` |

**Maintenance rules:**
- Set `Draft` on initial file generation (step 8)
- Set `Finalized` on commit (step 12)
- Module `Impl` column is updated by coding agents or users when they start/finish implementing a module
- When any module's `Impl` changes, update design-level `Status` accordingly (Finalized → Implementing on first module start; Implementing → Implemented when all Done)
- `prd-analysis --revise` reads design-level `Status` to decide: `Finalized` → PRD can be modified in place with change record; `Implementing` or `Implemented` → PRD must create a new version
- `system-design --revise` reads module-level `Impl` to decide per-module mutability (see Revise Step 1)

#### Step Completion Conditions (interactive steps only)

- **Step 1 → 2:** Scope confirmed, input fully parsed, user agrees with understanding summary
- **Step 2 → 3:** Module breakdown proposed and confirmed — each module has a name, type (backend/frontend/shared), one-sentence responsibility, and rough complexity estimate
- **Step 3 → 4:** All architecture ambiguities resolved (no "TBD"), dependency layering defined and confirmed, module boundaries validated, critical data flows traced, NFR budget allocated to modules, frontend implementation architecture decided (if applicable — including prototype assessment, routing, state management, form implementation strategy, performance budget, design token implementation, component structure sketch, frontend-backend data flow mapping, a11y implementation strategy, i18n implementation strategy, Design System Conventions approach), test strategy decided (pyramid allocation, isolation approach, external dependency test method)
- **Step 4 → 5:** Key technical decisions summarized in table form, user confirms all choices
- **Step 5 → 6:** Feature-Module mapping complete, no orphan features, user confirms
- **Step 6 → 7:** All module specs generated; each module has interface definition, responsibility, data model (if applicable), Testing section (if applicable — skip for trivial S-complexity modules with no dependencies), and Boundary Enforcement section (if the project has linting/CI infrastructure — skip for trivial S-complexity modules); frontend modules have UI Architecture section complete (component tree, routing, state management, key interactions, performance, a11y implementation, i18n implementation); frontend modules with forms use consistent form patterns per Design System Conventions
- **Step 7 → 8:** All API contracts generated (if applicable); endpoint definitions match module interfaces; all endpoints include error codes, Authentication & Permissions, and Constraints sections; Test Scenarios included for non-trivial APIs

#### Module Complexity Guide

| Level | Criteria | Example |
|-------|----------|---------|
| **S** | Single responsibility, < 5 public interfaces, no external dependencies, straightforward CRUD or pass-through | Config loader, simple validator |
| **M** | 2-3 internal components, 5-10 public interfaces, 1-2 module dependencies, some business logic | REST API handler with validation |
| **L** | Complex algorithms or state management, > 10 interfaces, 3+ dependencies, requires careful error handling | Workflow engine, query optimizer |
| **XL** | Should be challenged — consider splitting. Only acceptable if splitting would force artificial seams | Full auth system (tokens + RBAC + SSO) |

#### Step 3 Deep-Dive: Architecture Refinement

**Start from PRD:** If the PRD's architecture.md already specifies deployment architecture, observability, or tech stack decisions, use those as the baseline — only ask about gaps or ambiguities, don't re-ask what's already decided.

For each ambiguous technical choice, evaluate along these dimensions:

1. **Technology selection** — for each choice point (database, message queue, framework, etc.):
   - **Maturity:** production-proven vs. bleeding-edge? Known failure modes?
   - **Team familiarity:** team has experience, or learning curve required?
   - **Ecosystem:** library support, community, tooling, observability integrations?
   - **Performance characteristics:** latency profile, throughput ceiling, resource cost?
   - Present as multiple-choice with trade-off summary for each option
2. **Infrastructure decisions** (inherit from PRD deployment architecture if present):
   - Deployment model (monolith / modular monolith / microservices / serverless)?
   - State management strategy (stateless services + external store / in-process state / hybrid)?
   - Communication patterns (sync REST/gRPC / async events / CQRS)?
3. **External dependency mapping** — using PRD's External Dependencies table, determine which module owns each external service integration. For each: which module calls it, how does the module handle the documented failure mode and fallback?
4. **Dependency layering** — define a forward-only layer order for modules (e.g. Types → Config → Repository → Service → Runtime → UI). Each layer is a group of modules with the same architectural role. Modules may only depend on modules in the same layer or layers to their left. Present the proposed layering as a table (layer → modules → allowed dependencies) and confirm with user. This layering populates the README's Dependency Layering section and constrains the Module Index Deps column.

#### Step 3 Deep-Dive: Module Refinement

Apply these rules to judge whether modules should be split or merged:

- **Split when:** a module has more than 2 distinct responsibilities; its interface surface is > 10 public functions; or it owns data models that serve unrelated use cases
- **Merge when:** two modules always change together; one module's only caller is the other; or splitting forces data duplication without benefit
- **Litmus test:** can you describe the module's responsibility in 2-3 sentences? If not, it's too big. Does the module have a reason to exist independently? If not, merge it.
- **Boundary validation:** for each proposed boundary, ask — "if two different developers implement these two modules with only the interface spec, will it work?" If the answer requires implicit knowledge, the interface is underspecified.

#### Step 3 Deep-Dive: Data Flow Refinement

For each critical data path (derived from PRD journey flows — use journey files (journeys/*.md) touchpoints as the source of end-to-end user flows, and cross-journey patterns as the source of shared data paths that span multiple journeys, then map to module boundaries):

1. **Trace the path** — which modules does data touch, in what order?
2. **Sync vs. async** — must the caller wait for a result, or can it fire-and-forget?
3. **Consistency requirements** — does this path need strong consistency (transaction), eventual consistency (events), or is best-effort acceptable?
4. **Error propagation** — when module B fails mid-flow, what does module A see? Does it retry, compensate, or fail fast?
5. **Volume & latency** — expected throughput on this path? Latency budget?

#### Step 3 Deep-Dive: NFR Decomposition

For each PRD-level NFR, decompose to module-level budgets:

1. **Identify the hot path** — which modules are on the critical path for this NFR?
2. **Allocate budget** — e.g., "PRD says P99 < 500ms for task creation — ingestion gets 100ms, validation gets 100ms, storage gets 300ms"
3. **Identify the bottleneck owner** — which module has the tightest constraint? That module's design gets extra scrutiny.
4. **Security NFRs** — which modules handle untrusted input? Those modules must define input validation and sanitization strategies.
5. **Scalability NFRs** — which modules are stateful? Those are scaling bottlenecks — design for statelessness or explicit sharding.

#### Step 3 Deep-Dive: Frontend Implementation Architecture

Skip this section entirely if the project has no user-facing interface (pure API, background service). For projects with a UI (web, mobile, desktop, TUI):

1. **Prototype assessment** — read the PRD's `prototypes/src/` directory (if it exists). For each prototype component, assess:
   - Can it be used directly in production? (code quality, structure, patterns)
   - Does it need refactoring? (what specifically — e.g. extract API calls to service layer, add error boundary)
   - Must it be rewritten? (why — e.g. prototype only mocked API, needs real integration)
   Record assessment in README's Prototype-to-Production Mapping section.
2. **View inventory & module mapping** — collect all Screen/View names from PRD journey touchpoints. Each unique view becomes an entry in the README's View / Screen Index. For each view, determine which frontend module owns it. Ask user to confirm.
3. **Routing implementation** — based on PRD's Navigation Architecture:
   - Route configuration approach (file-based routing / config-based / framework convention)
   - Route guards / middleware (auth checks, data prefetching)
   - Code splitting strategy (per-route lazy loading, shared chunks)
   - Error boundaries per route
4. **State management implementation** — based on PRD's chosen approach (from architecture.md Frontend Stack):
   - Store structure (flat vs. nested, normalized vs. denormalized)
   - Async state patterns (loading/error/success wrappers, optimistic updates)
   - State persistence (URL params, localStorage, session)
   - Server state vs. client state separation (e.g. React Query/SWR for server state)
5. **Form implementation strategy** — based on PRD's Form Specifications in features:
   - Form library configuration
   - Validation execution (client-side schema, server-side validation, hybrid)
   - Error display pattern (inline, summary, toast)
   - Multi-step form state management (if applicable)
6. **Frontend performance budget** — based on PRD NFRs plus frontend-specific metrics:
   - Core Web Vitals targets (LCP, INP, CLS)
   - Bundle size budget (total, per-route)
   - Image optimization strategy (formats, lazy loading, CDN)
   - Caching strategy (service worker, HTTP cache, state cache)
7. **Design token implementation** — how PRD's design tokens map to code:
   - CSS custom properties / Tailwind config / theme object
   - Dark mode / theme switching mechanism (if applicable)
   - Token-to-code generation pipeline (if using a tool like Style Dictionary)
8. **Component structure** — for each frontend module, sketch the component tree: top-level layout → sections → leaf components. Enough detail for a coding agent to create the file structure.
9. **Frontend-backend data flow** — for each view, trace which API endpoints or backend modules supply data. Identify: what data is fetched on load, what mutations trigger API calls, what state is purely local.

**Rules:**
- Frontend modules follow the same module-template.md, with the added UI Architecture section
- Module Index in README must include a Type column (`backend` | `frontend` | `shared`)
- **PRD owns the interaction design (what + behavior); system-design owns the implementation architecture (how)**
- Do NOT redefine design tokens, component contracts, state machines, a11y requirements, or i18n requirements — these are authoritative in the PRD. System-design references them and specifies how to implement them

#### Step 3 Deep-Dive: Testing

Establish the project-level test strategy that will be recorded in README's Test Strategy section and decomposed into per-module Testing sections. **Start from PRD:** if the PRD's architecture.md already specifies testing conventions (frameworks, coverage targets), use those as the baseline.

1. **Test pyramid allocation** — decide the ratio of unit : integration : E2E tests for this project:
   - **Unit-heavy** (e.g. 70/20/10): projects with complex business logic, algorithms, or data transformations — most value comes from fast, isolated tests
   - **Integration-heavy** (e.g. 30/50/20): projects with many module interactions, database-heavy operations, or external service integrations — boundary correctness is the main risk
   - **E2E-heavy** (e.g. 20/30/50): projects where user-facing workflows are the primary risk — forms, multi-step processes, UI state management
   - Present as multiple-choice with rationale for each option based on the project's characteristics
2. **Module test isolation strategy** — for each module, determine how it can be tested independently:
   - Which dependencies need to be replaced with test doubles (mocks, stubs, fakes)?
   - Which modules should use real dependencies (e.g. in-memory database instead of mock)?
   - **Litmus test:** can each module's tests run without starting any other module? If not, the module boundary or interface needs redesign.
3. **External dependency test approach** — for each external dependency from the PRD's External Dependencies table:
   - **Real service** (sandboxed): when the service provides a test/sandbox environment
   - **Contract test**: verify the external interface contract without calling the real service — capture expected request/response shapes and validate locally
   - **Fake/stub**: in-process replacement that mimics behavior (e.g. in-memory database, fake HTTP server)
   - **Record/replay**: capture real responses, replay in tests — good for stable third-party APIs
   - Present decision per dependency, not as a blanket policy
4. **Test data management** — decide how test data is created, isolated, and cleaned up:
   - **Factories/builders**: programmatic test data creation with sensible defaults
   - **Fixtures**: static test data files for stable reference data
   - **Seeding**: database seed scripts for integration test environments
   - **Isolation strategy**: each test gets fresh data (transaction rollback, test containers, unique prefixes) vs. shared test database with cleanup
5. **NFR verification methods** — for each NFR category that requires runtime verification:
   - **Performance**: tool (e.g. k6, Artillery, Benchmark.js), load model (concurrent users, request rate), environment requirements
   - **Security**: approach (SAST in CI, dependency scanning, input fuzzing), tools, scope per module
   - **Reliability**: chaos/fault injection approach, failure scenario coverage
   - Skip NFR categories where static analysis or code review is sufficient (no runtime test needed)
6. **CI test execution** — how tests run in the continuous integration pipeline:
   - **Stage ordering**: unit → integration → E2E (fail-fast: stop on first stage failure?)
   - **Parallelization**: which test suites can run in parallel?
   - **Environment requirements**: which stages need external services (database, message queue)?
   - Skip if the project has no CI pipeline or if CI is already fully specified in PRD architecture.md

### Design Review

Applied as step 10 of Phase 1 (self-review, after writing, before user review and commit), or triggered independently via `--review` on existing files.

**Checklist — check each dimension, fix issues directly:**

| Dimension | Check |
|-----------|-------|
| Completeness | Every Feature has corresponding Module coverage; mapping matrix has no gaps |
| Consistency | Module interfaces match each other; data models match API contracts |
| Self-containment | Each module file can be read independently |
| Implementability | Interface definitions are specific enough for a coding agent; no TBD/TODO |
| Dependency sanity | No circular dependencies; dependency direction is reasonable; all module dependencies comply with README's Dependency Layering — no reverse-layer imports |
| PRD traceability | Every module traces back to at least one Feature; every cross-journey pattern from the PRD (shared infrastructure needs, repeated touchpoints) is addressed by at least one module (or section omitted in PRD for single-journey products) |
| NFR coverage | Every PRD NFR is decomposed to at least one module's NFR section with concrete, measurable constraints; README's NFR Allocation table is consistent with module-level NFR sections |
| Interaction completeness | Every cross-module dependency in module files has a corresponding entry in README's Module Interaction Protocols; sync/async and error strategy are specified |
| UI coverage | (Skip if no user-facing interface) Every PRD journey Screen/View appears in README's View / Screen Index; every frontend module has a UI Architecture section with component tree, routing, state management, key interactions, frontend performance, a11y implementation, and i18n implementation; Design System Conventions references PRD design tokens and specifies token-to-code implementation, responsive approach (sidebar behavior, grid system, mobile considerations), dark mode/theming strategy (if applicable), and component patterns (loading, error, empty, toast, modal, form) |
| Prototype coverage | (Skip if PRD has no prototypes) Every PRD prototype component is accounted for in Prototype-to-Production Mapping; each entry has an Action (Reuse/Refactor/Rewrite) and Gap Description for non-Reuse items |
| Frontend performance | (Skip if no user-facing interface) Every frontend module has performance targets (LCP, INP, CLS, bundle size); targets are consistent with PRD NFRs; optimization strategies are specified |
| PRD interaction design alignment | (Skip if no user-facing interface) System-design does not redefine what PRD owns (design tokens, component contracts, state machines, a11y specs, i18n specs); frontend modules reference PRD feature specs for interaction design and specify how to implement them |
| Analytics coverage | (Skip if no features define analytics events) Every PRD feature analytics event is mapped to a responsible module in README's Analytics Coverage; no events are orphaned |
| API completeness | (Skip if no APIs) Every API contract has request/response examples, error codes, Authentication & Permissions (derived from PRD Authorization Model for external APIs), and Constraints (rate limiting, size limits, idempotency where applicable) |
| Testability | Every module can be tested in isolation (dependencies are injectable or replaceable); README's Test Strategy section exists and is consistent with module-level Testing sections; every module with external dependencies specifies a test double strategy; every Module Interaction Protocol has a contract test approach; NFR verification methods are specified for runtime-verifiable NFRs |
| Risk awareness | Every high-likelihood or high-impact risk from the PRD has a corresponding design mitigation in the affected module's Error Handling, NFR, or Interaction Protocols |
| Version integrity | If Revision History exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry. If sibling directories with the same product slug exist in the parent directory: this version's Revision History accounts for them (links to predecessor, or is itself the first version). Skip this dimension during the main process step 10 (self-review of initial creation) — it only applies to `--review` mode and `--revise` post-change review (Revise Step 7) |
| Bootstrap self-sufficiency | README or module Implementation Constraints specifies all setup steps (install, configure, seed) — an agent can bootstrap the project without external knowledge or tribal context; no implicit "ask someone" steps |
| Task entry points | README's Test Strategy or a dedicated section lists concrete build / test / lint commands — an agent knows exactly how to validate its changes without guessing |
| Form implementation consistency | (Skip if no forms) Every frontend module with forms uses the same form library, validation framework, and error display pattern as specified in Design System Conventions; form implementation strategy is consistent across views |
| Frontend-backend contract alignment | (Skip if no user-facing interface) Every frontend module's state management (API call entries) corresponds to an API contract in API Index; endpoint signatures match, error handling covers contract error codes, response parsing matches schema |
| Enforcement coverage | Every Dependency Layering rule and every convention in Key Technical Decisions or module-level Relevant Conventions specifies how it is enforced (lint rule, structural test, type system, CI check); unenforced conventions are flagged as findings |

**Review flow:**
1. Scan all files against the checklist
2. Fix issues directly
3. Present change summary to user in structured format (example below), user confirms

**Change summary example:**

| File | Dimension | Issue Found | Change Made |
|------|-----------|-------------|-------------|
| M-001-xxx.md | Consistency | Return type `string` doesn't match M-002's expected `TaskResult` | Updated return type to `TaskResult` |
| README.md | Interaction completeness | M-001 → M-003 interaction missing | Added entry to Module Interaction Protocols |

**Immutability rule:** whether design files can be modified in place depends on the **module-level implementation state** (tracked by the `Impl` column in Module Index):

| Scenario | Modify in Place? | Rationale |
|----------|-----------------|-----------|
| Design Status is Draft / Finalized | Yes | No modules have been implemented |
| Design Status is Implementing / Implemented, but all affected modules have Impl = `—` | Yes | Changed modules have no implementation code to invalidate |
| Any affected module has Impl = `In progress` or `Done` | No — create new version | Modifying in place would invalidate implemented code |

Steps 10-11 (self-review, user review) always occur before commit and are part of the creation process — modifying files during these steps is expected regardless of Status.

**Review-only mode (`--review`):**

Review an existing design directory for quality, completeness, and consistency. **This mode is read-only** — it reports findings but does not modify any files.

0. **Version discovery** — scan the parent directory for sibling design directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the Revision History in each version forms a consistent chain (each newer version links back to its predecessor). Record this context for subsequent steps.
1. **Read all files** — README.md, modules/*.md, api/*.md (if present)
2. **Run Design Review checklist** — check every dimension (including Version integrity), collect findings. If directory structure doesn't match template conventions, note this as a finding.
3. **Present findings** — if multiple versions were discovered in step 0, lead with a version context block before the findings table:
   ```
   Version context:
     Reviewing: {path of reviewed directory} ({position, e.g. v1 of 2})
     Latest:    {path of latest directory}
     Chain:     {whether Revision History links form a consistent chain}
     ⚠ You are reviewing an older version.       ← only if not latest
   ```
   Then present the structured table of issues with severity (Critical / Important / Suggestion).
4. **Recommend next step:**
   - If issues are minor (wording, missing cross-links): note them for the next revision
   - If issues are significant (missing modules, interface mismatches, coverage gaps): recommend `--revise` to address the issues
   - If reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version

**Revise mode (`--revise`):**

Interactively modify an existing design — whether it's still pre-implementation or already being coded. Auto-detects downstream state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

#### Revise Step 1: Detect Downstream State & Confirm Intent

Read `Design Input > Status` field for the design-level state:

| Detected Status | Implication |
|----------------|------------|
| Draft / Finalized | No modules implemented — all changes can be applied in place |
| Implementing / Implemented | Some or all modules have been implemented — mutability depends on which modules are affected |

If Status is `Implementing` or `Implemented`, read the Module Index `Impl` column to build a per-module implementation map:

| Module | Impl | Mutable? |
|--------|------|----------|
| M-001 | Done | No — changes require new version |
| M-002 | In progress | No — changes require new version |
| M-003 | — | Yes — can modify in place |

Present the detected state (design-level + module-level map) to user and ask them to confirm. The user may correct the detected state (e.g. a module shows `—` but has actually been implemented informally).

**Key rule:** the final mutability decision is made in Step 6 after impact analysis reveals which modules are actually affected by the changes.

#### Revise Step 2: Check for PRD Changes

If the design has a Source PRD, proactively detect upstream changes:

- **In-place edits:** read the source PRD's Revision History. If entries exist with dates after the design's Date, summarize the PRD changes and ask which ones affect the design.
- **New PRD version:** scan for newer dated PRD directories with the same product name (e.g. if Source points to `docs/raw/prd/2026-03-01-foo/`, check for `docs/raw/prd/2026-04-*/foo/` or later). If a newer version exists, alert the user: "A newer PRD version exists at {path}. Should this design be updated against the new version?" If yes, read the new PRD's Revision History for the change summary.

If PRD changes are detected, they feed into Step 4 as change inputs alongside user-initiated changes.

#### Revise Step 3: Present Design Overview

Show the current design state to orient the user before gathering changes:

- Module index (ID, name, type, complexity, dependencies, Impl status)
- Key technical decisions summary
- Feature-Module mapping matrix
- NFR allocation summary

This helps the user point to specific areas they want to change — and see which modules are already implemented (not mutable) vs. still open for in-place modification.

#### Revise Step 4: Gather Changes

Changes come from three sources: PRD changes (Step 2), review findings (`--review` output), or user-initiated improvements. For each change, classify by type and ask deep-dive questions:

| Change Type | Description | Deep-Dive Questions |
|-------------|-------------|-------------------|
| Module restructure | Split, merge, rename, or change module boundaries | Which modules? What's wrong with current boundaries? What responsibilities move where? |
| Interface change | Modify a module's public interfaces — parameters, return types, error types | Which interface? What's the current contract? What should it become? Who are the callers? |
| Technology decision change | Swap database, framework, library, or communication pattern | Which decision from Key Technical Decisions? Why reconsider? What are the new options and trade-offs? |
| NFR reallocation | Change performance budgets, security requirements, or scalability targets across modules | Which NFR? Current budget allocation? Why is it wrong? Proposed new allocation? |
| Add module | New module for new requirements or extracted from existing module | What responsibility? Which features does it serve? What type (backend/frontend/shared)? Dependencies? |
| Remove module | Module no longer needed — responsibilities absorbed elsewhere or feature deprecated | Which module? Where do its responsibilities go? What about its callers? |

For each change, ask one question at a time. Confirm each change before moving to the next.

#### Revise Step 5: Impact Analysis & Conflict Detection

**Impact propagation** — for each change, systematically trace through these dimensions:

| Dimension | What to Check | How |
|-----------|--------------|-----|
| Dependency chain | Modules that depend on the changed module | Read changed module's dependents from Module Index Deps column and Module Interaction Protocols caller/callee |
| Interaction protocols | Cross-module interactions that reference the changed module | Scan README's Module Interaction Protocols table for entries involving the changed module |
| API contracts | API specs that expose the changed module's functionality | Scan API Index for APIs that route to the changed module |
| Feature-Module mapping | Features mapped to the changed module | Read Feature-Module Mapping matrix column for the changed module |
| NFR budget | NFR allocations that include the changed module | Read NFR Allocation table for rows listing the changed module as Primary or Supporting |
| View/Screen mapping | Views owned by changed frontend modules | Read View / Screen Index for views with the changed module as Primary Module |
| Dependency Layering | Module restructure or new dependencies violate layer order | Verify changed module's dependencies still comply with README's Dependency Layering table; check if new module needs layer assignment |
| Prototype mapping | Does the change affect modules with Reuse/Refactor prototype components? | Read Prototype-to-Production Mapping for entries targeting changed modules; Action may need updating |
| Frontend performance | Does module restructuring affect bundle size budgets or code splitting boundaries? | Check changed frontend modules' performance targets and code splitting strategy |
| Design token mapping | Does the change affect how PRD design tokens are implemented in code? | Read module's Design System Usage section and README's Design System Conventions table; check if token implementation (CSS var file, Tailwind config path, theme object structure) is impacted |
| Routing & code splitting | Do routing or lazy-load boundaries change, affecting bundle size targets or prefetch strategy? | Check all frontend modules' Routing tables; verify code splitting targets still valid after restructuring |
| State management structure | Do store structure, selectors, or sync strategies change, affecting other modules' state consumption? | Read all State Management tables across frontend modules; trace if changed module's state exports are consumed elsewhere; verify sync strategies compatible |
| Form pattern changes | Does the change affect form library, validation strategy, or error display across views? | Scan all frontend modules for form-related Key Interactions entries; if form strategy in Design System Conventions changed, verify all consumers updated |
| Component structure | Does the change affect a module's component tree, requiring child components to move or be reorganized? | Read changed module's Component Tree section; check if child components are referenced by other modules or views |
| Frontend-backend contracts | Do API endpoint calls, payloads, or response parsing change in affected frontend modules? | Cross-reference changed frontend modules' State Management (source: API call entries) with API Index; verify endpoint signatures match and consumers are updated |
| Key interactions | Does the change affect UI interaction flows (triggers, side effects, optimistic updates)? | Read Key Interactions tables in affected frontend modules; check if interaction flows are still consistent with module interfaces and state management |
| Accessibility implementation | Does the change affect a11y implementation (tab order, ARIA, testing approach) in frontend modules? | Read Accessibility Implementation sections in affected frontend modules; verify tab order, ARIA roles, and testing approach still valid after changes |
| i18n implementation | Does the change affect i18n strategy (namespace, lazy loading, fallback) in frontend modules? | Read i18n Implementation sections in affected frontend modules; verify namespace mappings and lazy loading still align with routing and module structure |
| Analytics coverage | Does the change affect which module is responsible for analytics events? | Read README's Analytics Coverage table; verify events mapped to changed modules still have a responsible owner after restructuring |

**Module mutability check** — after tracing impact, collect all affected modules (directly changed + impacted). Cross-reference each with the module implementation map from Step 1:

| Affected Module | Impl | Mutable? |
|----------------|------|----------|
| M-001 (directly changed) | — | Yes |
| M-003 (impacted: dependency chain) | Done | No |

If ANY affected module is not mutable (`In progress` or `Done`), the entire change set must create a new version — a design directory must remain a coherent unit. Present this determination to the user before proceeding.

Present impact summary to user as a table:

| Changed Item | Impacted Item | Dimension | Impl | Required Action |
|-------------|--------------|-----------|------|----------------|
| M-001 interface change | M-003 (caller) | Dependency chain | Done | Update M-003's call to match new interface |
| M-001 interface change | API-002 | API contract | N/A | Update request/response schema |

`Impl` column: module items show their implementation status (`—` / `In progress` / `Done`); non-module items (API contracts, README sections) show `N/A`.

**Conflict detection** — check for these conflict types after tracing impact:

| Conflict Type | Detection Rule | Example |
|---------------|---------------|---------|
| Interface incompatibility | Changed module's interface no longer matches what callers expect | M-001 returns `TaskResult` but M-003 still expects `string` |
| Circular dependency | Restructuring introduces a dependency cycle | M-001 → M-002 → M-003 → M-001 |
| NFR budget overflow | Reallocated module budgets exceed the PRD-level NFR target | P99 modules sum to 600ms but PRD target is 500ms |
| Feature coverage gap | A feature loses module coverage after changes | F-003 mapped to removed M-004, no replacement assigned |
| Interaction protocol mismatch | Module Interaction Protocols inconsistent with updated module interfaces | Protocol says sync call but module now emits async event |
| View orphan | A view loses its primary module owner after frontend module changes | Dashboard view's primary module M-002 was merged into M-001 |

If conflicts are detected, present them and ask user how to resolve before proceeding. Each conflict must be resolved or explicitly accepted as a known trade-off.

#### Revise Step 6: Execute Changes

Based on the mutability determination from Step 5 (not just Step 1 — Step 5's module-level check is the final decision):

**Modify in place** (Design Status is Draft/Finalized, OR Status is Implementing/Implemented but all affected modules are `—`):
1. Apply all changes directly to existing files
2. Add Revision History entry to README.md with Change Type = "In-place edit"
3. Update all impacted files identified in Step 5

**New version** (any affected module has Impl `In progress` or `Done`):
1. Create new dated directory (e.g. `docs/raw/design/2026-04-10-{product-name}/`)
2. Copy all files from original directory
3. Apply changes to the new copy
4. Add Revision History entry with Change Type = "New version", linking back to previous version
5. Set `Design Input > Status` to `Finalized`; reset all module `Impl` to `—` (implementation restarts from new design)

#### Revise Step 7: Post-Change Review

Run the full Design Review checklist on the result, with extra attention to:
- **Consistency:** do updated module interfaces match their callers?
- **Completeness:** do all features still have module coverage?
- **NFR coverage:** are all NFR budgets still within PRD targets?
- **Interaction completeness:** are all cross-module interactions in sync with module interfaces?
- **Testability:** do changed modules remain independently testable? Are test double strategies still valid after interface changes?
- **Enforcement coverage:** do changed modules' Boundary Enforcement sections still reference valid constraints? Are new constraints needed for restructured boundaries?
- **Dependency Layering:** do module changes still comply with the layer order? Does the Dependency Layering table need updating?
- **Frontend consistency:** are form patterns, state management, and routing still consistent across changed frontend modules? Do Design System Conventions and component structures reflect the new boundaries?
- **Frontend-backend alignment:** do frontend modules' API call entries still match API contracts after changes?
- **Accessibility consistency:** are a11y implementation strategies (tab order, ARIA, testing approach) still consistent across changed frontend modules?
- **i18n consistency:** are i18n implementation strategies (namespace mapping, lazy loading, fallback behavior) still consistent across changed frontend modules?
- **Analytics coverage:** are all PRD feature analytics events still mapped to a responsible module after restructuring?

Fix any issues found. Present change summary to user.

#### Revise Step 8: User Review

User reviews the changed files, confirms or requests further changes.

#### Revise Step 9: Commit

Commit with a descriptive message (e.g. "Revise design: restructure M-001/M-002 boundary, update API-002 contract").

### Interactive Mode (no PRD input)

When invoked without a PRD path, gather context interactively:
- Product/project background and problem being solved
- Architecture constraints and tech stack
- Shared conventions (API format, error handling, testing strategy) — needed as data source for module specs' Relevant Conventions section
- Key features to design for

**Enter step 2 when:** problem is clear, tech stack decided, and at least 3 features identified with enough detail to decompose into modules. If the user's description is too vague, ask clarifying questions before proceeding.

### Document-Based Mode

When input is an existing design draft or notes file (not a PRD directory):

Read document → summarize understanding → check gaps against checklist below → ask targeted questions → generate

**Gap checklist for design documents** — scan for missing or vague coverage:

- [ ] Module boundaries clearly defined with distinct responsibilities?
- [ ] Interface definitions with parameter types, return types, error types?
- [ ] Data models with field types, constraints, and ownership?
- [ ] Cross-module interaction patterns (sync/async, error propagation)?
- [ ] Non-functional requirements with concrete, measurable targets?
- [ ] Dependency direction explicit and acyclic?
- [ ] Key technical decisions documented with rationale?
- [ ] Feature-to-module traceability present?
- [ ] Dependency layering defined? Forward-only layer order with modules assigned to layers?
- [ ] UI/frontend implementation architecture covered (if user-facing)? Views mapped, component structure defined, routing and state management implementation specified?
- [ ] Prototype-to-Production mapping present (if PRD has prototypes)?
- [ ] Frontend performance budgets defined (Core Web Vitals, bundle size)?
- [ ] Routing implementation strategy specified (guards, code splitting, error boundaries)?
- [ ] State management implementation detailed (store structure, async patterns, persistence)?
- [ ] Design token implementation approach defined (CSS vars, Tailwind config, theme object)?
- [ ] Accessibility and i18n implementation strategies specified for frontend modules?
- [ ] Form implementation strategy defined (library, validation approach, error display, multi-step pattern)?
- [ ] Frontend-backend data flow traced for each view (load fetches, mutations, local-only state)?
- [ ] Design System Conventions complete (responsive approach, dark mode/theming, component patterns)?
- [ ] Analytics events mapped to responsible modules (if PRD defines analytics events)?
- [ ] API contracts include error codes, Authentication & Permissions, and Constraints?
- [ ] Test strategy defined? Test pyramid allocation, module isolation approach, external dependency test method, test data management?

### Incremental Design Mode

When the project already has an existing codebase (detected by presence of source code files, package manifests, or existing architecture docs):

1. **Assess existing architecture** — read key files (entry points, package structure, existing docs) to understand the current system structure
2. **Identify change scope** — based on the PRD/requirements, determine which parts of the existing architecture are affected:
   - New modules to add
   - Existing modules to modify (document current state → proposed state)
   - Existing interfaces that must remain stable (backward compatibility constraints)
3. **Delta-focused design** — module specs should clearly distinguish:
   - **Existing:** current behavior that must be preserved
   - **Modified:** what changes and why
   - **New:** entirely new components
4. **Integration risk assessment** — for each modification to an existing module, identify:
   - What existing callers/dependents are affected?
   - What tests need to be updated? Are existing test isolation strategies (mocks, fakes) and contract tests impacted by the interface change?
   - Is the change backward-compatible or does it require a migration?

## Output Structure

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md              # Design overview + module index + mapping matrix
├── modules/
│   ├── M-001-{slug}.md    # Self-contained module design
│   └── ...
├── api/                   # Only generated when project has APIs
│   ├── API-001-{slug}.md  # Self-contained API contract
│   └── ...
```

Use templates: `design-template.md` (README), `module-template.md` (module specs),
`api-template.md` (API contracts).

**Agent consumption:** read README.md (overview + mapping matrix) → read one module file → implement. The module file alone is sufficient for a coding agent to start working.

## Output Path

- **Default:** `docs/raw/design/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing
- **Cross-document paths:** when referencing PRD files (Source Features, References, Analytics Coverage), use relative paths from the design directory to the PRD directory. Example: if PRD is at `docs/raw/prd/2026-04-09-foo/` and design is at `docs/raw/design/2026-04-09-foo/`, a module's Source Feature link would be `../../../prd/2026-04-09-foo/features/F-001-slug.md`

## Key Principles

- **Self-contained** — each module file can be independently consumed by a coding agent
- **Copy, don't reference** — relevant data models, interface definitions are copied inline
- **One question at a time** — don't overwhelm during interactive refinement
- **Design ≠ Plan** — this skill produces "how to build it" designs, not "who does what in what order" — task assignment is handled by writing-plans
- **Review = improvement** — review finds issues and fixes them directly, no reports
- **Omit empty sections** — if a section has nothing useful, skip it
- **Feature-Module mapping** — the mapping matrix is the bridge between requirements and implementation, serving as the key input for the planning phase

## Next Steps Hint

After committing, print the following guidance to the user:

```
System design complete: {output path}

Next steps:
  Interactive — /plan based on {output path}
  Automated  — claude -p "implement all modules based on {output path}" --auto
```
