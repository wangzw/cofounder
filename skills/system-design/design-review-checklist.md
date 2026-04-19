# Design Review Checklist

This checklist is shared by three flows:

- **Phase 1 Step 10 self-review** (generate mode) — apply during initial generation.
- **`--review` mode** — apply read-only against an existing design directory.
- **`--revise` Step 7** — apply against a freshly revised design.

The checklist itself is identical; the surrounding workflow differs (see `generate-mode.md`, `review-mode.md`, `revise-mode.md`).

## Execution Scope — Per-File vs Cross-File

When review is run via parallel subagents (see `review-mode.md` Steps 2–3), each subagent runs only **per-file** dimensions on its assigned files. **Cross-file** dimensions need a whole-design view (multiple modules, API index, README cross-references, or PRD traceability) and must be run once by the orchestrating (main) agent after subagents return.

| Scope | Dimensions |
|-------|-----------|
| **Per-file** | Self-containment · Implementability · API completeness · Frontend performance · Backend i18n coverage · Form implementation consistency · Risk awareness (per-module mitigations) · Enforcement coverage (per-module conventions) · Testability (per-module isolation + test double strategy) |
| **Cross-file** | Completeness · Consistency · Dependency sanity · PRD traceability · NFR coverage · Interaction completeness · UI coverage · Prototype coverage · PRD interaction design alignment · Analytics coverage · Frontend-backend contract alignment · Convention translation · Infrastructure module coverage · PRD-Design freshness · Version integrity · Bootstrap self-sufficiency · Task entry points · Testability (README Test Strategy) |

When review is run inline (Phase 1 Step 10 self-review during initial creation, or `--revise` Step 7 delta review), both scopes are checked together by the main agent — no split needed.

---

## Checklist — check each dimension, fix issues directly

| Dimension | Check |
|-----------|-------|
| Completeness | Every Feature has corresponding Module coverage; mapping matrix has no gaps |
| Consistency | Module interfaces match each other; data models match API contracts |
| Self-containment | Each module file can be read independently |
| Implementability | Interface definitions are specific enough for a coding agent; no TBD/TODO |
| Dependency sanity | No circular dependencies; dependency direction is reasonable; all module dependencies comply with README's Dependency Layering — no reverse-layer imports |
| PRD traceability | Every module traces back to at least one Feature; every cross-journey pattern from the PRD (shared infrastructure needs, repeated touchpoints) is addressed by at least one module (or section omitted in PRD for single-journey products) |
| NFR coverage | Every PRD NFR is decomposed to at least one module's NFR section with concrete, measurable constraints; README's NFR Allocation table is consistent with module-level NFR sections |
| Interaction completeness | **Bidirectional sync required.** Every `(caller, callee)` pair in any module's Module Index `Deps (direct)` cell must have a matching row in README's Module Interaction Protocols, and every Protocols row must map back to a declared Deps pair (or a documented cross-cutting note). Sync/async and error strategy are specified on every row. Missing rows in either direction are findings |
| UI coverage | (Skip if no user-facing interface) Every PRD journey Screen/View appears in README's View / Screen Index; every frontend module has a UI Architecture section with component tree, routing, state management, key interactions, frontend performance, a11y implementation, and i18n implementation; Design System Conventions references PRD design tokens and specifies token-to-code implementation, responsive approach (**web**: sidebar behavior, grid system, mobile considerations; **TUI**: terminal width detection, sidebar auto-hide, minimum terminal size), dark mode/theming strategy (if applicable), and component patterns (loading, error, empty, toast/notification, modal/overlay, form/input) |
| Prototype coverage | (Skip if PRD has no prototypes) Every PRD prototype component (web or TUI) is accounted for in Prototype-to-Production Mapping; each entry has an Action (Reuse/Refactor/Rewrite) and Gap Description for non-Reuse items; every frontend module with Action = Reuse or Refactor has a Prototype Reuse Guide in its UI Architecture section listing specific files to copy and adaptations needed; prototype visual records (browser screenshots or teatest golden files) have been reviewed against state machines |
| Frontend performance | (Skip if no user-facing interface) Every frontend module has performance targets (**web**: LCP, INP, CLS, bundle size; **TUI**: render latency, input-response time, memory); targets are consistent with PRD NFRs; optimization strategies are specified |
| PRD interaction design alignment | (Skip if no user-facing interface) System-design does not redefine what PRD owns (design tokens, component contracts, state machines, a11y specs, i18n specs); frontend modules reference PRD feature specs for interaction design and specify how to implement them |
| Backend i18n coverage | (Skip if single-language backend) Every backend module that returns locale-dependent text (API errors, validation messages, notifications) has a Backend i18n Implementation section specifying locale resolution, message catalog access, and timezone conversion; decisions are consistent with README Key Technical Decisions (backend i18n rows); module interfaces that return user-visible text include a locale parameter or document how locale context is propagated |
| Analytics coverage | (Skip if no features define analytics events) **Enumerate every event** in every PRD feature file's `## Analytics` block and verify each has a row (or a named sweep rule) in README's Analytics Coverage. Do NOT pass the dimension by confirming the section merely exists — count events and match against row count. Orphaned events or unnamed sweep rules ("all backend features emit audit events" without feature IDs or channel) are findings |
| API completeness | (Skip if no APIs) **Per-endpoint** completeness (not file-level): every endpoint in every `api/API-*.md` file carries its own Authentication & Permissions block, Request table, Request example (populated — `{}` is a finding), Response table, Response example (populated), and Constraints block. File-level summary blocks do NOT substitute. Additionally: every HTTP-facing module has an API Surface table with Method+Path, Auth & Role, Success, Error Codes, Request+Response example links, and Constraints filled on every row |
| Testability | Every module can be tested in isolation (dependencies are injectable or replaceable); README's Test Strategy section exists and is consistent with module-level Testing sections; every module with external dependencies specifies a test double strategy; every Module Interaction Protocol has a contract test approach; NFR verification methods are specified for runtime-verifiable NFRs |
| Risk awareness | Every high-likelihood or high-impact risk from the PRD has a corresponding design mitigation in the affected module's Error Handling, NFR, or Interaction Protocols |
| Version integrity | If `REVISIONS.md` exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry; README's References section links to `REVISIONS.md`. If sibling directories with the same product slug exist in the parent directory: this version's `REVISIONS.md` accounts for them (links to predecessor, or is itself the first version). Skip this dimension during the Phase 1 Step 10 self-review of initial creation — it only applies to `--review` mode and `--revise` Step 7 (post-change review) |
| Bootstrap self-sufficiency | README or module Implementation Constraints specifies all setup steps (install, configure, seed) — an agent can bootstrap the project without external knowledge or tribal context; no implicit "ask someone" steps |
| Task entry points | README's Test Strategy or a dedicated section lists concrete build / test / lint commands — an agent knows exactly how to validate its changes without guessing |
| Form implementation consistency | (Skip if no forms) Every frontend module with forms uses the same form library, validation framework, and error display pattern as specified in Design System Conventions; form implementation strategy is consistent across views |
| Frontend-backend contract alignment | (Skip if no user-facing interface) Every frontend module's state management (API call entries) corresponds to an API contract in API Index; endpoint signatures match, error handling covers contract error codes, response parsing matches schema |
| Convention translation | Every PRD architecture.md convention section (Coding Conventions, Test Isolation, Development Workflow, Security Coding Policy, Backward Compatibility, Git & Branch Strategy, Code Review Policy, Observability Requirements, Performance Testing, AI Agent Configuration) has corresponding stack-specific implementation patterns in README's Implementation Conventions; module-level Relevant Conventions reference implementation patterns, not raw PRD policies; no PRD convention section is silently ignored |
| Infrastructure module coverage | A "Development Infrastructure" module spec exists covering convention enforcement artifacts (linter config, CI pipeline, test helpers, pre-commit hooks, CLAUDE.md, security scanning, benchmark harness) from the PRD's Development Infrastructure feature; a "Deployment Infrastructure" module spec exists (if PRD has Deployment Infrastructure feature) covering deployment artifacts; Deployment Architecture sub-sections from PRD (environments, local dev setup, environment parity, config management, data migration, CD pipeline, environment isolation, IaC) have corresponding concrete tooling decisions in the design |
| PRD-Design freshness | If a source PRD exists: compare PRD directory's latest modification date (or latest entry date in the PRD's `REVISIONS.md`, if present) against this design's creation/revision date; if PRD is newer, flag as "PRD may have been revised since this design was created — consider running --revise to check for upstream changes" |
| Enforcement coverage | Every Dependency Layering rule and every convention in Key Technical Decisions or module-level Relevant Conventions specifies how it is enforced. In module Boundary Enforcement tables, **every row MUST fill all four columns with grep-able identifiers** — Constraint (concrete rule), Tool/Lint/Test (named rule id, not "custom lint"), File Path (resolves to a real config/test file), CI Job (matches a job in the CI pipeline). Descriptive English in any column ("custom structural check", "lint rule") is a finding. Unenforced conventions are moved to Implementation Constraints as advisory, not left in Boundary Enforcement |

### Severity Levels

Apply the level **by rule, not by intuition**. Recurring reviewer drift — same-class issues landing at Critical in one pass and Important in the next — destroys trust in the severity signal. Use the examples below as anchors; a finding that matches an example must take that example's severity.

| Severity | Definition | Action Required |
|----------|-----------|-----------------|
| **Critical** | Blocks implementation or causes incorrect behavior | Must fix before proceeding |
| **Important** | Degrades quality or creates maintenance risk | Should fix; document reason if deferred |
| **Suggestion** | Improves clarity or consistency but doesn't affect correctness | Fix if time permits; safe to defer |

**Critical examples** (memorize these — any finding matching one of these classes is Critical, not Important):
- A frontend module references an API endpoint that does not exist in any `api/API-*.md` (frontend-backend contract gap)
- Two files give contradictory values for the same field (e.g. `GET /system/version` listed as both Admin-only and Public; same endpoint with two different rate limits)
- A module's `Deps (direct)` imports a module in a higher layer than itself (reverse-layer import) with no documented cross-cutting exemption
- A module's Interface Definition references a type, function, or field that is not defined anywhere in the design (`WithTxRetry` called but not declared; `SetSinkForTest` referenced but no signature given)
- An API endpoint declared at method+path X in module M, not present at method+path X in the API contract file (or vice versa) — the implementation contract is ambiguous
- A PRD feature, journey touchpoint, or NFR with zero module allocation (feature orphaned) — not "under-specified", *missing*

**Important examples** (these are Important, not Critical — resist escalating):
- An endpoint's example uses `{}` placeholder instead of a populated JSON body
- A module's Boundary Enforcement row has vague Tool/File/CI columns ("custom lint")
- A backend module returning error messages has no Backend i18n Implementation section and no explicit N/A note
- Module Interaction Protocols table missing a row that Module Index Deps implies
- Analytics Coverage missing an event defined in a PRD feature's `## Analytics` block
- API endpoint missing its per-endpoint Authentication & Permissions or Constraints block (content exists at file level but not per endpoint)

**Suggestion examples** (keep these at Suggestion even if they feel annoying):
- A typo in documentation (e.g. `limit_event_id` should be `last_event_id`)
- Ellipsis (`"...": "all other fields unchanged"`) used as a filler in otherwise complete examples
- Missing one test scenario row in an otherwise covered endpoint
- Benchmark path unspecified for an NFR that has verification strategy documented elsewhere

**Anti-drift rule:** when reviewing a revised design, the severity of any finding carried over or re-discovered from a prior review MUST match the prior severity unless the finding's class has clearly changed. If uncertain, pick the lower severity (Important over Critical, Suggestion over Important). Inflation toward Critical is how review scope explodes and throughput collapses.

## Self-Review Flow (used by generate mode and revise mode)

1. **Self-review — scan all files against the checklist.** Read README.md, every `modules/*.md`, and every `api/*.md`. For each dimension in the checklist, determine whether the current files pass. Keep a running list of findings (file, dimension, issue).
2. **Fix issues directly in the files.** This step is autonomous — do not ask the user for input on each finding. Apply concrete edits: correct inconsistent interfaces, add missing sections, replace TBDs with derived answers from the PRD/features. If a finding requires a judgment call the skill cannot resolve (e.g. which of two plausible module boundaries is correct), record it as an Open Question instead of guessing, and surface it in step 3.
3. **Present change summary and open questions to the user.** Use the structured format below. User reviews in their editor and responds with one of:
   - **approve** — proceed to commit.
   - **request changes** — user describes what to change; return to step 2 to apply the changes, then re-present. Loop until the user approves.
   - **reject** — abandon the review output; skill reports no-op.

### Change summary example

| File | Dimension | Issue Found | Change Made |
|------|-----------|-------------|-------------|
| M-001-xxx.md | Consistency | Return type `string` doesn't match M-002's expected `TaskResult` | Updated return type to `TaskResult` |
| README.md | Interaction completeness | M-001 → M-003 interaction missing | Added entry to Module Interaction Protocols |

**Note:** Immutability rules for design modifications are defined in `revise-mode.md` (Step 1: Detect Downstream State). Consult that file when deciding whether to modify files in place or create a new version.
