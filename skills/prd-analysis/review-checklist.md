# PRD Review Checklist

## Execution Scope — Per-File vs Cross-File

When review is run via parallel subagents (see `review-mode.md` Steps 2–3), each subagent runs only **per-file** dimensions on its assigned files. **Cross-file** dimensions need a whole-PRD view and must be run once by the orchestrating (main) agent after subagents return.

| Scope | Dimensions |
|-------|-----------|
| **Per-file** | Evidence · Authorization · Self-containment · Testability (a, b, c, d, h) · Interaction Design coverage · Form specification completeness · Micro-interactions & motion · State machine integrity · Frontend stack consistency · Accessibility per-feature · i18n per-feature — frontend · i18n per-feature — backend · Page transition completeness · Prototype-spec alignment · Prototype feedback incorporation · Responsive coverage · Scope boundary · Notifications · Journey interaction mode coverage · No ambiguity |
| **Cross-file** | Traceability · Competitive context · Metrics · Risks · Priority · Privacy · Testability (e, f, g) · Design token completeness · Component contract consistency · Cross-feature event flow · Accessibility baseline completeness · i18n baseline completeness · Navigation consistency · Prototype archival completeness · Coding conventions completeness · Test isolation completeness · Development workflow completeness · Security coding policy completeness · Backward compatibility completeness · Git & Branch Strategy completeness · Code review policy completeness · Observability requirements completeness · Performance testing completeness · Development infrastructure feature · Deployment architecture completeness · AI agent configuration completeness · Version integrity |

When review is run inline (self-review during initial creation, step 6), both scopes are checked together by the main agent — no split needed.

---

## Convergence Rules

A review that keeps producing fresh findings round after round is churning on subjective dimensions, not improving quality. Apply these rules BEFORE flagging a finding, in both inline self-review and dispatched subagents.

### Pass-Count Severity Gate

Count prior review-driven revision passes from `REVISIONS.md` (version-controlled — the authoritative source). Use `Grep` with pattern `^## .*review-finding` on `REVISIONS.md`; the match count is the number of prior remediation passes. Do NOT rely on `.reviews/*.applied.md` counts — `.reviews/` is gitignored and absent on fresh clones or after cleanup.

| Prior applied passes | Severities to emit |
|----------------------|---------------------|
| 0–1 | Critical, Important, Suggestion |
| 2 | Critical, Important (drop Suggestion) |
| ≥3 | Critical only |

Rationale: after three passes, remaining non-Critical findings are overwhelmingly judgment drift on subjective dimensions (scope boundary, fixture detail, i18n table shape, per-endpoint NR). If real structural gaps remain, system-design will surface them; do not keep scrubbing the PRD.

### Dimension Saturation Rules

Do NOT flag a finding if the listed saturation condition already holds. These dimensions are the primary sources of infinite regress.

| Dimension | Stop flagging once this holds |
|-----------|-------------------------------|
| Testability (c) non-behavioral AC | Feature has ≥1 NR per distinct operational characteristic (e.g. read vs write, steady vs burst). Do NOT demand per-endpoint p95. |
| Testability (d) authorization EC | Feature has ≥1 unauthorized-access EC per permission boundary (role × scope). Do NOT enumerate every role × workspace × org combination. |
| Testability (h) test data | Test Data Requirements section exists and a reader can set up the test without reading implementation code. Do NOT prescribe fixture JSON shape, seed-file paths, or generator API signatures. |
| i18n per-feature — backend | Table covers one row per error category (validation, permission, conflict, not_found). Do NOT demand a row per EC or AC. |
| i18n per-feature — frontend | Key-naming convention is stated. Do NOT audit individual string keys. |
| Micro-interactions & motion | Animations reference motion/timing tokens by name. Do NOT demand frame-by-frame choreography or easing math. |
| Self-containment | Feature contains the capability, contract, and observable behavior needed to implement. Do NOT demand deeper inlining of entities already described at JSON-schema level. |
| Scope boundary | See partition table below — flag ONLY if content is clearly in the "defer" column. |

### Scope Boundary vs Self-Containment — Authoritative Partition

Self-containment ("inline the context") and scope boundary ("no implementation detail") pull opposite directions. Use this table to resolve. Content on the boundary (storage-hint nouns, capability statements) is the author's judgment — respected, not flagged.

| Inline in feature file (self-contained) | Defer to system-design (scope boundary) |
|------------------------------------------|------------------------------------------|
| Entity names, field semantics, types at JSON-schema level | Table names, column physical types, index strategy, SQL DDL blocks |
| API endpoint path, method, request/response schema | Handler names, middleware composition, framework idioms |
| State machine states + transitions + system feedback | Concurrency mechanism (goroutine / channel / lock / SELECT FOR UPDATE) |
| Required behavior under concurrency ("no lost writes under 100 concurrent PATCH") | Implementation mechanism for achieving it |
| i18n key naming convention + category coverage | i18n library choice, loader config |
| Error envelope shape + error-type enum | Exception class hierarchy, error-wrapping library |
| Timeout and retry values, heartbeat intervals | Retry library, circuit breaker config |
| Storage-hint nouns ("transactional store", "PostgreSQL-backed") | Schema migrations, physical deployment choice |

Flag ONLY when content is clearly in the right-hand column. Storage-hint or capability-level content is NOT a violation.

### Oscillation Detection

Primary source is `REVISIONS.md` — every review-driven pass records a `**Themes:**` summary of what was added or removed (e.g. "Removed SQL DDL blocks", "Added performance NRs", "Tightened authorization ECs"). This is version-controlled and always available.

Before flagging a finding, check the most recent 2–3 `REVISIONS.md` entries for a Theme whose wording is opposite to your Fix (prior pass added what you're removing, or removed what you're adding). If found, do NOT emit the per-dimension finding — emit a single `[Critical] Convergence conflict` citing the conflicting REVISIONS.md entry date and Theme line.

Local `.reviews/*.applied.md` files, if present, may be consulted as a finer-grained supplement — but never as the primary signal, since they are gitignored.

Oscillation is resolved by the main agent via user judgment, not by swinging content back and forth in fix subagents.

---

Applied as step 6 of the process (after writing, before commit). Check each dimension and fix issues directly in the written files:

| Dimension | Check |
|-----------|-------|
| Traceability | Goal → Journey → Touchpoint → User Story → Feature → Analytics chain is complete: every persona has journeys (happy + error + first-use); every touchpoint and pain point maps to a Feature; every Feature maps back to at least one touchpoint; no orphan features; cross-journey patterns are documented and each pattern is addressed by at least one Feature (or section omitted for single-journey products) |
| Evidence | Every major product decision traces to an evidence source (user research, data, feedback, or explicitly labeled as assumption); assumption-heavy features are flagged as validation risks |
| Competitive context | Competitive landscape section is present (or explicitly marked N/A for internal tools); differentiation is stated; table-stakes features are identified |
| Metrics | Every Goal has baseline + measurement method; every measurement maps to at least one Feature's Analytics event; every Journey Metric has a Verification entry (manual/automated/monitoring + pass/fail criteria) |
| Risks | Every high-likelihood or high-impact risk has a mitigation strategy; affected Features acknowledge the risk; compliance/privacy risks are covered if applicable |
| Priority | Every P0 serves a core journey happy-path touchpoint; Roadmap phases align with Priority (P0→Phase 1, P1→Phase 2); Feature dependencies don't contradict phase ordering |
| Authorization | Authorization model is defined (or N/A); every Feature with access restrictions has a Permission line in Context |
| Privacy | Privacy & Compliance section is present (or explicitly N/A); personal data entities are identified; user rights are stated if regulated |
| Self-containment | Each Feature file can be read and implemented independently — all needed context is inline |
| Testability | **(a)** Every Acceptance Criterion is precise enough to write a test assertion (no vague verbs like "correctly handles", "properly displays" — replace with observable behavior). **(b)** Every Edge Case has Given/When/Then that maps to an automated test. **(c)** Every Feature with non-trivial state or integration has at least one non-behavioral criterion (performance, concurrency, or resource limit). **(d)** Every Feature with a Permission line has at least one edge-case testing unauthorized access. **(e)** Every Journey's Error & Recovery Paths map to at least one Feature's Edge Case or Acceptance Criterion. **(f)** Cross-feature dependencies have at least one integration-level acceptance criterion in the downstream Feature (e.g. "Given F-003 has scheduled a task, when F-005 executes it, then …"). **(g)** Every multi-touchpoint Journey has an E2E Test Scenarios table covering happy, alternative, and error paths with features exercised and expected outcomes. **(h)** Every Feature with non-trivial test setup has a Test Data Requirements section (fixtures, boundary values, preconditions, external stubs) |
| Interaction Design coverage | Every user-facing Feature has an Interaction Design section with Screen & Layout, Component Contracts, Interaction State Machine, Accessibility, Internationalization, and Responsive Behavior (web breakpoints or TUI terminal size constraints) filled; Screen/View names are consistent between journey touchpoints and feature files; no user-facing feature has Interaction Design omitted |
| Form specification completeness | (Skip if no features with forms) Every feature with user input has a Form Specification sub-section with field definitions (name, type, validation rules, error messages, conditional visibility, dependencies); submission behavior is defined (success/error handling); multi-step forms have step sequencing |
| Micro-interactions & motion | (Skip if no user-facing interface) Every user-facing feature with key interactions has a Micro-Interactions & Motion sub-section; every animation references duration and easing tokens (no raw ms or cubic-bezier values); every animation has a stated purpose |
| Journey interaction mode coverage | Every journey touchpoint has an Interaction Mode specified (click, form, drag, swipe, keyboard, scroll, hover, voice, scan, etc.); interaction modes are consistent with the corresponding feature's component contracts and state machines |
| Design token completeness | (Skip if no user-facing interface) All applicable token categories are defined in architecture.md — **web**: colors, typography, spacing, breakpoints, motion, z-index; **TUI**: colors (terminal palette), typography (monospace), spacing (character units), borders — skip breakpoints, shadows, border-radius for TUI per Phase 3 TUI Handling. No raw values used in feature Interaction Design sections — all visual references use token semantic names |
| State machine integrity | Every Interaction State Machine has no dead states (every state has at least one exit); every transition specifies system feedback; loading states have both success and error exits |
| Frontend stack consistency | (Skip if no user-facing interface) Every user-facing feature's Interaction Design uses patterns compatible with Phase 3 Frontend Stack choices — state machines align with chosen state management library, form specifications use chosen form library conventions, component contracts use chosen framework conventions |
| Component contract consistency | Every component referenced in a feature's Interaction Design section has a Component Contract with props, events, and slots defined; event names follow a consistent convention across features; for features sharing a screen, component nesting and slot-filling rules are explicit |
| Cross-feature event flow | For features with Dependencies: event names in state machine side effects match event names consumed by dependent features' state machines; event payloads (from Component Contract Events) match consumer expectations; integration acceptance criteria (Testability f) reference exact event names |
| Accessibility baseline completeness | (Skip if no user-facing interface) architecture.md Accessibility Baseline section is present and complete (WCAG target level, keyboard navigation policy, screen reader support, focus management, color contrast, reduced motion, touch targets, error identification); per-feature Accessibility sub-sections reference or extend the baseline |
| Accessibility per-feature | Every user-facing feature has an Accessibility sub-section; keyboard navigation covers all interactive elements; ARIA roles are specified for dynamic content; focus management is defined for all modals, drawers, and overlays |
| i18n baseline completeness | (Skip if product is single-language AND has no user-facing interface) architecture.md Internationalization Baseline section is present and complete. **Frontend** (skip if no UI): text externalization convention, key naming convention, content direction, RTL support. **Backend** (skip if no multi-locale backend): API locale resolution strategy, error/validation message localization approach, notification content localization, timezone handling. **Shared**: supported languages, default language, date/time format, number format, pluralization rules. Per-feature i18n sub-sections reference or extend the baseline |
| i18n per-feature — frontend | (Skip if no user-facing interface; also skip for single-language TUI products where Phase 3 TUI Handling confirmed no i18n) Every user-facing feature has a frontend Internationalization sub-section; all user-visible text has an i18n key (no hardcoded strings in component contracts or form specs); format rules are defined for dates, numbers, and plurals |
| i18n per-feature — backend | (Skip if single-language backend) Every backend feature that returns user-visible text (API error messages, validation messages, notification content, email templates) has a Backend Internationalization sub-section specifying which messages are locale-dependent and how locale is determined (Accept-Language, user preference, default) |
| Navigation consistency | Every Screen/View in journey touchpoints has a route in architecture.md Navigation Architecture; route params match feature requirements; breadcrumb strategy is defined |
| Page transition completeness | Every journey with multi-step flows has a Page Transitions table with transition type (navigate push/replace, modal, drawer, back), data prefetch strategy, and notes; transition types are consistent with the corresponding feature's state machines |
| Prototype-spec alignment | (Skip if no prototypes) Every state in the feature's Interaction State Machine has a corresponding prototype screenshot/snapshot (web: browser screenshot; TUI: teatest golden file or terminal screenshot); no undocumented states visible in prototypes that aren't in the state machine |
| Prototype feedback incorporation | (Skip if no prototypes) Every prototype has evidence of user validation (confirmation date in Prototype Reference); feedback has been categorized (spec change / token change / prototype-only) and incorporated — spec changes reflected in feature files, token changes reflected in architecture.md |
| Prototype archival completeness | (Skip if no prototypes) Prototype source code exists in `{prd-dir}/prototypes/src/`; key state screenshots/snapshots exist in `{prd-dir}/prototypes/screenshots/` (browser screenshots for web, teatest golden files or terminal screenshots for TUI); every user-facing feature's Prototype Reference section has path and confirmation date filled |
| Responsive coverage | Every user-facing feature has a Responsive Behavior sub-section; **web**: layout changes described for at least mobile (< sm) and desktop (>= lg) breakpoints; **TUI**: terminal width/height constraints and layout adaptations described (e.g. sidebar collapse threshold, minimum terminal size) |
| Scope boundary | PRD does not contain implementation-level details that belong in system-design (no middleware implementations, no database schemas, no library configurations, no code-splitting strategies); PRD interaction design uses design token semantic names, not implementation-specific values (no CSS class names, no Tailwind utilities) |
| Notifications | Every feature that triggers user notifications has a Notifications section with channel, recipient, content summary, and user control; features without notifications correctly omit it |
| Coding conventions completeness | architecture.md Coding Conventions section is present and covers: code organization/layering policy, naming conventions, interface/abstraction design policy, dependency wiring policy, error handling & propagation policy, logging conventions (levels, structured format, sensitive data), configuration access policy, concurrency patterns (lifecycle, shared state rules). If UI exists: component structure, state management patterns, styling conventions. All conventions are technology-agnostic policies, not implementation-specific patterns |
| Test isolation completeness | architecture.md Test Isolation section is present and covers: resource isolation policy (temp dirs, random ports, isolated DBs), global mutable state prohibition, file system isolation, external process cleanup, race detection requirement in CI, test timeout defaults, worktree/directory independence, parallel test classification. Per-feature Test Data Requirements reference these policies where applicable |
| Development workflow completeness | architecture.md Development Workflow section is present and covers: prerequisites (language/tool versions), local setup instructions, CI pipeline gates (what checks run, what blocks merge), build matrix (supported platforms), release process (versioning scheme, changelog), dependency management policy |
| Security coding policy completeness | architecture.md Security Coding Policy section is present and covers: input validation strategy (boundary definition), secret handling rules, dependency vulnerability scanning policy, injection prevention policy, authentication/authorization enforcement policy, sensitive data protection. Per-feature edge cases include security-relevant scenarios where applicable |
| Backward compatibility completeness | architecture.md Backward Compatibility section is present (or explicitly N/A for v1 with no existing consumers) and covers: API versioning strategy, breaking change definition and process, data schema evolution strategy, configuration file evolution. If N/A: intended future versioning strategy is noted |
| Git & Branch Strategy completeness | architecture.md Git & Branch Strategy section is present and covers: branch naming convention, merge strategy (and enforcement mechanism), branch protection rules, PR conventions (size, description, one-per-feature), commit message format, stale branch cleanup |
| Code review policy completeness | architecture.md Code Review Policy section is present and covers: review dimensions (correctness, security, tests, performance, readability), approval requirements, review SLA, automated vs human review split, feedback severity levels. If AI agents are reviewers: self-review policy defined |
| Observability requirements completeness | architecture.md Observability Requirements section is present (distinct from tool-focused Observability) and covers: mandatory logging events and required fields, health check requirements, key metrics with SLO targets, alerting rules and escalation, trace context propagation (if multi-component), audit trail requirements (if applicable) |
| Performance testing completeness | architecture.md Performance Testing section is present and covers: regression detection policy (CI benchmarks, threshold), performance budgets per category, load testing requirements (scenarios, pass/fail criteria), resource consumption limits. Per-feature non-behavioral criteria reference these budgets where applicable |
| Development infrastructure feature | A "Development Infrastructure" feature exists (auto-derived from convention sections) that produces enforceable artifacts for each convention policy: linter config, CI pipeline, pre-commit hooks, test helpers, security scanning, AI agent instruction files, etc. Feature is P0, Phase 1, no journey dependency. Each convention section in architecture.md maps to at least one concrete deliverable in this feature's requirements |
| Deployment architecture completeness | architecture.md Deployment Architecture section covers: environments (purpose, users, infrastructure), local development setup (reproducibility, service dependencies, env vars, data seeding), environment parity policy, configuration management (source, secrets, validation, template), deployment pipeline/CD (triggers, strategy, rollback, smoke tests), environment isolation (multi-instance, ports, databases). Data migration and IaC sections present if applicable. A "Deployment Infrastructure" feature exists (auto-derived) with deliverables for each deployment aspect |
| AI agent configuration completeness | architecture.md AI Agent Configuration section is present and covers: which agent instruction files to maintain (CLAUDE.md, AGENTS.md, etc.), structure policy (concise index vs monolithic — must be index), convention reference strategy (reference not duplicate), content policy (what is direct vs referenced), maintenance policy (when to update, who is responsible), multi-agent coordination (if applicable), context budget prioritization |
| No ambiguity | No TBD/TODO/vague descriptions remaining |
| Version integrity | If `REVISIONS.md` exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry; README's References section links to `REVISIONS.md`. If Baseline section exists (evolve-mode PRD): Predecessor path resolves to valid directory; all `→ baseline` links in indexes resolve correctly; Change Summary matches actual files. If sibling directories with the same product slug exist in the parent directory: version chain is consistent (revise-mode links via `REVISIONS.md`, evolve-mode links via Baseline.Predecessor). **Skip during initial creation self-review (step 6)** — only applies to `--review`, `--revise` post-change review, and `--evolve` post-generation review |
