---
name: prd-analysis
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, or prepare requirements for AI coding agents. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis'."
---

# PRD Analysis — AI-Coding-Ready Requirements

Generate PRDs as a **multi-file directory**. Each feature spec is a self-contained file — coding agents read only the file they need, minimizing context consumption.

## Scope

PRD captures **product-level decisions**: what to build, for whom, why, and at what priority. It does NOT specify implementation-level details — those belong to system-design:

| Belongs in PRD | Belongs in System Design |
|----------------|------------------------|
| "Admin can manage users, Viewer can only read" (permission rules) | Permission middleware implementation, RBAC table schema |
| "User data must comply with GDPR" (compliance requirement) | PII field annotations, data retention cron design |
| "Support English and Chinese" (frontend i18n requirement) | i18n library config, translation lazy loading, fallback strategy |
| "API errors and emails in user's locale" (backend i18n requirement) | Accept-Language middleware, message catalog implementation, locale resolution chain |
| "Notify user when task fails" (notification requirement) | Notification queue architecture, delivery retry logic |
| Design token definitions (colors, typography, spacing, motion, breakpoints) | Token-to-code implementation (CSS custom properties, Tailwind config) |
| Component contracts (props, events, slots) | Component file structure, composition patterns |
| Interaction state machines (states, transitions, user feedback) | State store implementation, async patterns, caching |
| Navigation architecture (site map, routes, breadcrumbs) | Route guards, lazy loading, code splitting |
| Form specifications (fields, validation rules, i18n keys) | Form library config, validation execution, server integration |
| Accessibility requirements (WCAG level, ARIA, keyboard, focus management) | a11y testing tools (axe-core), implementation patterns |
| Responsive layout changes per breakpoint | CSS grid implementation, breakpoint utilities |
| Interactive prototypes (seed-quality code for validation) | Prototype-to-Production mapping, refactoring plan |
| Coding conventions — error propagation policy, logging level rules, global state prohibition, naming rules | Concrete patterns (specific error types, logger library config, DI container setup) |
| Test isolation policy — tests must use temporary resources, no shared mutable state, parallel-safe | Test helper implementations, fixture libraries, CI runner configuration |
| Development workflow requirements — prerequisite versions, CI gate policies, release versioning scheme | CI pipeline YAML, Makefile/Taskfile, release automation scripts |
| Security coding policy — input validation at boundaries, secret handling rules, dependency vulnerability scanning | WAF rules, secret manager integration, SAST tool config |
| Backward compatibility policy — API versioning rules, breaking change process, data migration strategy | Version negotiation middleware, migration script framework |
| Git & Branch Strategy — branch naming, merge strategy, protection rules, PR conventions, commit message format | Branch protection API config, git hooks, PR template files |
| Code review policy — review dimensions, approval requirements, automated vs human review split | Review bot config, CODEOWNERS file, CI reviewer assignment |
| Observability requirements (policy) — which events must be logged, health check requirements, SLO definitions, alerting rules | Log pipeline config, health check endpoint, Grafana dashboards, PagerDuty rules |
| Performance testing policy — regression detection thresholds, performance budgets, load testing requirements | Benchmark harness config, CI perf gate scripts, load test scenarios |
| AI agent configuration — instruction file strategy, structure policy (index vs monolithic), convention references, maintenance policy | Concrete instruction file content (CLAUDE.md body text), file scaffolding scripts |
| Deployment & environment policy — environments, local dev setup, environment parity, config management, data migration strategy, CD pipeline triggers/rollback, environment isolation, IaC requirements | Concrete deployment tooling (Dockerfile, docker-compose, Terraform, K8s manifests, CD workflow files, migration scripts) |

## Input Modes

```
/prd-analysis                          # interactive mode
/prd-analysis path/to/notes.md         # document-based mode
/prd-analysis --output docs/raw/prd/my-project  # custom output dir
/prd-analysis notes.md --output ./prd  # both
/prd-analysis --review docs/raw/prd/xxx/        # review existing PRD
/prd-analysis --revise docs/raw/prd/xxx/        # change management for existing PRD
```

## Process

1. **Gather requirements** — interactive questioning or parse provided document
2. **Fill gaps** — ask targeted follow-up questions for missing info
3. **Generate PRD files** — using templates in this skill directory
4. **Cross-link** — backfill cross-references that couldn't exist during initial generation: journey Mapped Feature columns, feature Deps, feature Journey Context links, Cross-Journey Patterns "Addressed by Feature" column
5. **Write files** — write all generated files to disk (not yet committed)
6. **Self-review** — read each written file against the review checklist (see Review Checklist below), fix issues directly in files
7. **User review** — user reviews files in their editor, confirms or requests changes
8. **Commit** — commit all files to git

### Review Checklist

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
| Version integrity | If Revision History exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry. If sibling directories with the same product slug exist in the parent directory: this version's Revision History accounts for them (links to predecessor, or is itself the first version). Skip this dimension during the main process step 6 (self-review of initial creation) — it only applies to `--review` mode and `--revise` post-change review (Revise Step 6) |

### Questioning (one at a time, prefer multiple choice)

**Phase 1 — Vision & Context:** problem, vision, success metrics (with baseline + how to measure), competitive landscape (see below), evidence base (see below)
**Phase 2 — Users & Journeys:** personas, then deep-dive each persona's journeys (see below), then identify cross-journey patterns (see below)
**Phase 3 — Frontend Foundation:** (skip if no user-facing interface) frontend tech stack confirmation, design token system, navigation architecture (see below)
**Phase 4 — Features & Interaction Design:** extract user stories from journey touchpoints (see below), derive features from stories, MVP boundary, inputs/outputs, edge cases (see granularity guide below), interaction design for user-facing features (see Interaction Design guide below)
**Phase 5 — Interactive Prototype:** (skip if no user-facing features) generate runnable prototypes per feature (web: browser-based via `frontend-design` skill; TUI: terminal-based via TUI framework), user validates, feedback loops, archive (see below)
**Phase 6 — Technical:** platform, backend tech stack, integrations, data/auth requirements, shared conventions (see below), coding conventions (see below), test isolation (see below), development workflow (see below), security coding policy (see below), backward compatibility (see below), git/branch strategy (see below), code review policy (see below), observability requirements (see below), performance testing (see below), AI agent configuration (see below), deployment & environment strategy (see below)
**Phase 7 — NFRs & Priority:** performance (including frontend Core Web Vitals), security, scalability, then prioritize using framework below
**Phase 8 — Risks:** technical risks, dependency risks, data/security risks, mitigation strategies

#### Phase 1 Deep-Dive: Competitive Landscape

Understand the market context before defining features. For each major competitor or alternative (including "do nothing"):

1. **Identify alternatives** — what do users currently use to solve this problem? (competitors, manual workarounds, internal tools)
2. **For each alternative:**
   - How does it solve the problem?
   - What does it do well? What are its weaknesses?
   - What's the switching cost for users?
3. **Our differentiation** — what will we do differently or better? Why will users choose us?
4. **Table stakes** — which features are baseline expectations (users won't adopt without them)?

Omit for purely internal tools with no external alternatives. Keep it brief — 1 paragraph per competitor, not a full market research report.

#### Phase 1 Deep-Dive: Evidence Base

Capture the evidence behind product decisions. For each major claim or priority:

1. **What evidence do we have?** Ask the user:
   - User interviews or usability studies?
   - Analytics data (funnel metrics, usage patterns, error rates)?
   - Customer feedback (support tickets, NPS comments, feature requests)?
   - Market research or industry trends?
   - Founder/team intuition (legitimate, but label it explicitly)?
2. **Record the source** — each major decision should trace to an evidence type. This isn't bureaucracy — it lets future team members understand why decisions were made and know when to revisit them.
3. **Flag assumption-heavy areas** — if a major feature is based primarily on intuition without user data, note it as a validation risk in Phase 6.

#### Phase 2 Deep-Dive: User Journeys

User journeys are the bridge between "who the users are" and "what features to build". Spend adequate time here — rushing past journeys leads to orphan features and missed scenarios.

For **each persona**, explore:

1. **Journey inventory** — what are the key journeys this persona takes? (use the checklist in `journey-template.md`: first-time use, core happy path, core unhappy path, return visit, power user, admin, migration)
2. **For each journey:**
   - **Trigger** — what event or need initiates this journey?
   - **Goal** — what is the user trying to accomplish?
   - **Steps** — walk through the journey step by step: what does the user do, what does the system respond?
   - **Alternative paths** — where might the user diverge from the happy path? Why?
   - **Error & recovery paths** — what can go wrong? How does the user recover?
   - **Pain points** — where is there friction, confusion, or frustration?
   - **Emotional arc** — where is the user confident vs. anxious vs. delighted?
3. **Cross-journey patterns** — after all persona journeys are mapped, identify patterns across journeys:
   - **Shared pain points** — the same frustration appears in multiple journeys (implies a high-value feature)
   - **Repeated touchpoints** — different journeys pass through the same screen/action (implies a shared component or hub)
   - **Handoff points** — where one persona's journey output becomes another persona's input (implies integration needs)
   - **Shared infrastructure needs** — multiple journeys require the same system capability (e.g. search, notification, progress tracking)
   - Record these in README.md's Cross-Journey Patterns section — they directly inform feature derivation in Phase 3
4. **Journey metrics** — how do we measure journey success? (completion rate, time to complete, drop-off points)

#### Phase 3: Frontend Foundation

Skip this phase entirely if the product has no user-facing interface (pure API, background service, CLI without TUI). Products with Terminal UI (TUI) enter this phase with reduced scope (see TUI Handling below).

**Step 3.1 — Frontend Tech Stack Confirmation**

Ask the user to confirm (one question at a time, multiple choice):

1. **UI framework:** React / Vue / Svelte / Solid / Angular / Other (specify)
2. **CSS approach:** Tailwind CSS / UnoCSS / CSS Modules / Styled Components / Vanilla CSS / Other
3. **Component library:** Shadcn/ui / Radix UI / Ant Design / Material UI / PrimeVue / Headless UI / None (custom) / Other
4. **State management:** React Context / Redux / Zustand / Pinia / Jotai / Signals / None (component-local) / Other
5. **Build tool:** Vite / Next.js / Nuxt / SvelteKit / Webpack / Other
6. **Form management:** React Hook Form / Formik / VeeValidate / Native / Other
7. **i18n library:** react-i18next / vue-i18n / Paraglide / Custom / Other

Record selections in architecture.md's Frontend Stack section.

**Step 3.2 — Design Token System**

Define the visual design foundation. Present sensible defaults based on the selected component library (e.g. if Shadcn is chosen, propose its default token values), let user adjust.

- If using an existing component library (Shadcn, Ant Design, etc.), extract its default tokens as the baseline; user confirms or overrides
- If building custom, propose a sensible default set (inspired by Tailwind defaults) and iterate
- Tokens must be expressed in the structured format defined in architecture-template.md (tables with Token / Value / Usage columns) that AI agents can parse into code
- Every token must have a semantic name — AI agents reference `color.primary.500`, not `#3b82f6`

Record in architecture.md's Design Token System section.

**Step 3.3 — Navigation Architecture & Information Architecture**

Define the product's navigation structure based on journey touchpoints:

1. **Site map** — Mermaid diagram showing page hierarchy derived from journey Screen/View names
2. **Navigation layers** — Global (always visible), Section (within a section), Contextual (inline)
3. **Route structure** — URL pattern definitions for each Screen/View (view, route pattern, params, query params, auth, layout)
4. **Breadcrumb strategy** — auto-generated from route hierarchy / manual / none
5. **Deep linking** — which views support direct URL access with state restoration

Record in architecture.md's Navigation Architecture section.

**Step 3.4 — Accessibility Baseline**

Confirm the WCAG target level and baseline requirements. Record in architecture.md's Accessibility Baseline section.

**Step 3.5 — Internationalization Baseline (Frontend)**

Confirm supported languages, default language, RTL requirements, text externalization convention. Record in architecture.md's Internationalization Baseline (Shared + Frontend sub-sections). Backend i18n is covered separately in Phase 6.

**TUI Handling:** Products with Terminal UI (TUI) enter Phase 3 with reduced scope:
- **Tech stack:** TUI framework (e.g. Ink, Bubbletea, blessed) replaces web framework. Skip CSS approach, web component library, i18n library (unless TUI is multilingual)
- **Design tokens:** Reduced set — colors (terminal palette: 16/256/truecolor), typography (monospace only, no font size scale), spacing (character-based). Skip breakpoints, shadows, border-radius
- **Navigation:** Command structure / screen flow replaces URL routing. Skip breadcrumbs and deep linking
- **Accessibility:** Keyboard navigation is primary. Skip WCAG color contrast (terminal dependent), touch targets, focus indicators (terminal handles this)

#### Phase 4 Step 1: User Story Extraction & Feature Derivation

Before defining features, explicitly derive them from journey touchpoints. This step bridges "what users experience" (journeys) to "what the system provides" (features).

**Step 1 — Extract User Stories from Touchpoints:**

For each journey's Touchpoints table, extract stories in the format: "As a {persona}, I want to {action at this touchpoint}, so that {goal}." One touchpoint may yield multiple stories (e.g. a "Dashboard" touchpoint may need both "view summary" and "filter by date"). Walk through ALL touchpoints across ALL journeys.

**Step 2 — Consolidate & Deduplicate:**

Collect all extracted stories into a flat list. Merge duplicates — different journeys often share the same touchpoint (e.g. both "first-time use" and "return visit" journeys pass through the login screen). Also incorporate stories implied by cross-journey patterns from Phase 2 (shared pain points, repeated touchpoints, handoff points).

**Step 3 — Group Stories into Features:**

Group related stories by shared data model + API + UI surface. Each group becomes a candidate Feature. A Feature may serve multiple stories across different journeys and personas — this M:N mapping is expected and desirable.

**Step 4 — Verify Coverage:**

- Every journey touchpoint has at least one story → at least one Feature
- Every journey pain point has at least one story addressing it → at least one Feature
- No Feature exists without a story tracing back to a touchpoint (no orphan features)
- Cross-journey patterns are covered by at least one Feature each

Only proceed to feature detailing after this derivation is complete. The extracted User Stories become the User Stories section in each feature file.

**Step 5 — Auto-Derive Development Infrastructure Feature:**

After feature derivation from user stories, automatically generate a **Development Infrastructure** feature that materializes the convention policies from architecture.md into enforceable artifacts. This feature is not derived from user journeys — it is derived from the developer convention sections and is always P0 (blocks all other features from having consistent quality enforcement).

The feature's deliverables are derived from whichever convention sections exist in architecture.md:

| Convention Section | Required Deliverable(s) |
|-------------------|------------------------|
| Coding Conventions | Linter configuration file (e.g. `.golangci-lint.yml`, `.eslintrc`), formatter configuration (e.g. `.editorconfig`, `prettier.config.js`) |
| Test Isolation | Test helper utilities enforcing isolation patterns (temp dir helpers, random port helpers, cleanup registration); test configuration enabling parallel execution and race detection |
| Development Workflow | CI/CD pipeline configuration (e.g. `.github/workflows/ci.yml`), local setup script (e.g. `Makefile`, `scripts/setup.sh`), prerequisite version validation |
| Security Coding Policy | Security scanning CI step (e.g. `gosec`, `CodeQL`), secret scanning configuration, dependency vulnerability scanning (e.g. `dependabot.yml`, `govulncheck`) |
| Git & Branch Strategy | Pre-commit hook configuration (e.g. `.pre-commit-config.yaml`), commit message lint (e.g. `commitlint`), branch protection documentation/script |
| Code Review Policy | `CODEOWNERS` file, PR template (`.github/pull_request_template.md`), automated review checklist in CI |
| Observability Requirements | Logging library initialization boilerplate, structured logger configuration |
| Performance Testing | Benchmark harness setup, CI benchmark comparison step |
| Backward Compatibility | (Only for non-v1) API versioning middleware/router configuration |
| AI Agent Configuration | Agent instruction file (`CLAUDE.md` and/or `AGENTS.md`) structured as concise index with references to convention files; role-specific agent instructions if multi-agent workflow is used |

**Rules for this auto-derived feature:**
- Always assigned P0 priority and Phase 1 — it must be implemented before other features to establish the quality baseline
- No dependencies on other features; other features may depend on it (e.g. features with tests depend on test helpers being available)
- Feature ID convention: use the next available F-number in the feature index
- Feature title: "Development Infrastructure" (or localized equivalent)
- This feature has no Journey Context (it serves developers, not end users) — skip that section
- The specific deliverables are technology-agnostic at PRD level (e.g. "linter configuration file"); the system-design phase specifies the concrete tool choices
- If architecture.md has no developer convention sections (unlikely after Phase 6), this feature can be omitted

**Step 6 — Auto-Derive Deployment Infrastructure Feature:**

If architecture.md has a Deployment Architecture section with defined environments, automatically generate a **Deployment Infrastructure** feature that produces the deployment artifacts needed for each environment. Like the Development Infrastructure feature, this is not derived from user journeys — it is derived from the Deployment Architecture section.

The feature's deliverables are derived from which environments and deployment policies exist in architecture.md. All deliverables are described as technology-agnostic requirements — the system-design phase specifies concrete tools:

| Deployment Aspect | Required Deliverable(s) |
|-------------------|------------------------|
| Local development environment | Reproducible local environment setup (single-command bootstrap); local service dependencies configuration; environment variable template with documented defaults |
| Environment-specific configuration | Configuration template per environment with validation; secret reference placeholders (not actual secrets); configuration documentation |
| Data seeding & migration | Seed data script for local/test environments; database schema migration setup (versioned, reversible migrations); test data generation if specified |
| CI/CD pipeline (deployment) | Deployment pipeline configuration per target environment (staging, production); deployment trigger rules (on merge, on tag, manual approval); rollback procedure or script |
| Environment isolation | Multi-instance isolation configuration (if required by Deployment Architecture); port/namespace/database separation strategy for parallel development |
| Container/infrastructure definitions | (Only if Deployment Architecture specifies containerization or IaC) Container build definitions; orchestration configuration; infrastructure declarations |
| Health & readiness checks | Application health check endpoint or command (referenced by Observability Requirements); readiness/liveness probe configuration if applicable |

**Rules for this auto-derived feature:**
- Priority P0 if the product requires deployment beyond local development (has staging/production); P1 if local-only (CLI tools, libraries)
- Phase 1 if P0 — deployment infrastructure must be established early so other features can be tested in realistic environments
- Depends on Development Infrastructure (CI pipeline must exist before CD pipeline extends it)
- Feature title: "Deployment Infrastructure" (or localized equivalent)
- This feature has no Journey Context — skip that section
- Deliverables are technology-agnostic at PRD level (e.g. "reproducible local environment setup", not "docker-compose.yml"); the system-design phase specifies whether that means Docker, Nix, devcontainer, Vagrant, or a shell script
- If architecture.md has no Deployment Architecture section or only a trivial one (single-developer local CLI tool), this feature can be omitted or reduced to just the local setup deliverable

#### Phase 4 Deep-Dive: Feature Granularity

A feature file should be **one unit of work a coding agent can implement in a single session**. Use these rules:

- **Split when:** a feature has multiple independent user stories for different personas, or involves both a complex backend + complex frontend that could be built separately, or exceeds ~XL effort
- **Merge when:** two features share the same data model, API, and UI — splitting would force the agent to context-switch between tightly coupled files
- **Rule of thumb:** if the Acceptance Criteria section has more than 8-10 items, the feature is likely too big. If it has fewer than 3, it may be too small (consider merging with a related feature)

#### Phase Completion Conditions

Move to the next phase when:

- **Phase 1 → 2:** Problem statement is clear, at least 2 measurable goals defined, scope boundary stated, competitive context captured (or explicitly N/A), evidence base documented
- **Phase 2 → 3:** Every persona has at least one journey with happy path + one error path fully walked through; every touchpoint has Interaction Mode specified; multi-step journeys have Page Transitions defined; cross-journey patterns documented in README (or explicitly N/A for single-journey products); multi-touchpoint journeys have E2E Test Scenarios covering happy, alternative, and error paths; Journey Metrics have Verification entries
- **Phase 3 → 4:** (Skip if no user-facing interface) Frontend tech stack confirmed; design tokens defined (all applicable categories — web: colors, typography, spacing, breakpoints, motion, z-index; TUI: colors, typography, spacing per TUI Handling); navigation architecture established (web: site map, routes, breadcrumbs; TUI: command structure, screen flow); accessibility baseline set; i18n baseline set; all recorded in architecture.md
- **Phase 4 → 5:** Feature list covers all journey touchpoints, MVP boundary agreed, no feature exceeds XL effort without a split plan; all user-facing features have full Interaction Design section filled (component contracts, state machines, form specifications, micro-interactions & motion, a11y, i18n, responsive); edge cases use Given/When/Then format; features with dependencies have at least one cross-feature integration AC; features with non-trivial test setup have Test Data Requirements
- **Phase 5 → 6:** (Skip if no user-facing features) All user-facing features have confirmed prototypes; prototype source code archived in `prototypes/src/{feature-slug}/`; visual records archived in `prototypes/screenshots/{feature-slug}/` (web: browser screenshots via playwright-cli; TUI: teatest `.golden` files preferred, terminal screenshots via `script`/`asciinema` as fallback); feedback incorporated into feature specs and design tokens; every user-facing feature's Prototype Reference section populated with path and confirmation date
- **Phase 6 → 7:** Backend tech stack decided, all external integrations identified, data model entities drafted, shared conventions (API, error handling, testing) defined, coding conventions defined (code organization, naming, error handling, logging, concurrency, dependency wiring — technology-agnostic policies), test isolation policies defined (resource isolation, parallel safety, race detection, timeouts), development workflow defined (prerequisites, CI gates, release process), security coding policy defined (input validation, secret handling, dependency scanning, injection prevention, auth enforcement), backward compatibility policy defined (or N/A for v1), git/branch strategy defined (naming, merge strategy, protection, PR conventions, commit format), code review policy defined (review dimensions, approvals, SLA, automated vs human), observability requirements defined (mandatory events, health checks, metrics, alerting, audit trail), performance testing policy defined (regression detection, budgets, load testing), AI agent configuration defined (instruction file strategy, structure policy, convention references, maintenance policy), authorization model captured (or N/A), privacy requirements captured (or N/A), backend i18n requirements captured (or N/A for single-language backend)
- **Phase 7 → 8:** Every feature has Impact/Effort rating and P0/P1/P2 assigned, Roadmap phases mapped, frontend performance metrics included (Core Web Vitals targets for user-facing products)
- **Phase 8 → Generate:** All high-impact risks have mitigation strategies, no open questions remain

#### Phase 4 Deep-Dive: Interaction Design for User-Facing Features

For each user-facing feature (not backend-only), explore:

1. **Screen mapping** — which screen/view does this feature live on? Use the Screen/View names from journey touchpoints. The route must match Navigation Architecture
2. **Component inventory** — identify the UI components needed. For each component, define its contract: Props (inputs), Events (outputs), Slots/Children (composition points). Express as a TypeScript-style interface or structured table
3. **Interaction state machine** — for each component with non-trivial state, define states and transitions using Mermaid stateDiagram. Every state must have at least one exit. States must include: idle, loading, success, error, and any domain-specific states
4. **Form specification** — for features with forms: field definitions (name, type, validation rules, error messages, conditional visibility, dependencies between fields)
5. **Micro-interactions & motion** — for key interactions, specify: trigger, animation type, duration token, easing token, purpose
6. **Accessibility requirements** — WCAG level (or "baseline per architecture.md"), keyboard navigation flow (tab order, shortcuts), ARIA roles and labels, focus management (modal open/close, form submit, inline errors), screen reader announcements for dynamic content
7. **Internationalization requirements** — supported languages (from architecture.md), text externalization keys with prefix `{feature-slug}.`, RTL support, date/time/number format rules, pluralization
8. **Responsive behavior** — reference breakpoint tokens, describe layout changes per breakpoint with specific details (not just "responsive")

**Rules:**
- Define interaction design at the **design token level** — describe structure, behavior, state machines, component contracts, and visual semantics using design token references. Raw visual values (hex colors, px sizes) belong in architecture.md's Design Token System; feature specs reference tokens by semantic name
- **Component contracts are the frontend equivalent of API contracts** — they define the interface that AI agents code against
- State machines must be complete: every user-perceivable state is listed, every transition is explicit
- Accessibility and i18n are NOT optional sections — they are mandatory for every user-facing feature. If a feature has no special a11y needs beyond baseline, state "follows baseline WCAG 2.1 AA from architecture.md"
- Design tokens are referenced by semantic name (e.g. `color.error.500`, `spacing.4`, `motion.duration.fast`), never by raw value
- The Screen/View name in the feature file must match the journey touchpoint's Screen/View column exactly
- If multiple features share the same screen, note which area/section each feature controls

#### Phase 4 Deep-Dive: Notification & Communication

For features that notify users (email, push, in-app, SMS), capture at the product level:

1. **Notification inventory** — which features trigger notifications? What events cause them?
2. **Channel** — how is the user notified? (email / push / in-app / SMS / multiple)
3. **Content summary** — what does the notification say? (not exact copy, but purpose and key info)
4. **User control** — can the user opt out or configure frequency?

Record these in the feature's Notifications section. Omit if the product has no notifications.

#### Phase 5: Interactive Prototype

Skip if the product has no user-facing features. After feature interaction design (Phase 4) is complete, generate interactive prototypes for user validation. **This phase generates actual running code — not more markdown.**

**IMPORTANT — Execution guidance:**
- For web/desktop UI: use the `frontend-design` skill to generate prototype code, use the `playwright-cli` skill to open it in a browser and take screenshots
- For TUI: write prototype code directly using the TUI framework (e.g. bubbletea + lipgloss for Go, Ink for JS). No specialized skill needed — TUI frameworks produce straightforward application code. Use the framework's snapshot tools (e.g. bubbletea teatest) for visual verification
- Write all prototype code into `{prd-dir}/prototypes/src/`. Organize by feature: `prototypes/src/{feature-slug}/`. This is a real coding step — create files, install dependencies, ensure the prototype runs

**Step 5.1 — Prototype Generation**

For each user-facing feature (or group of related features sharing a screen/view):

**Web/Desktop UI:**

1. Use the `frontend-design` skill to generate a runnable prototype using the confirmed tech stack (Phase 3)
2. Prototype requirements:
   - Implement the component contracts from the feature's Interaction Design section
   - Apply design tokens (real CSS custom properties / theme values)
   - Implement state machines (all states must be reachable)
   - Include semantic HTML and ARIA attributes (from a11y requirements)
   - Externalize text strings (from i18n requirements) — at minimum, use a key-value structure even if only one language
   - Follow the navigation architecture (routes, breadcrumbs)
   - Be self-contained and runnable (single `npm install && npm run dev` or equivalent)
3. Prototype code quality requirements (prototype is seed code for production):
   - Components match the component tree defined in the feature spec
   - State management follows the chosen approach from Phase 3
   - File structure follows framework conventions
   - No inline styles — use design tokens through the CSS approach chosen
   - No hardcoded strings — use i18n keys

**TUI:**

1. Generate a runnable TUI prototype using the confirmed TUI framework (e.g. bubbletea, Ink, blessed)
2. Prototype requirements:
   - Implement the component contracts from the feature's Interaction Design section (bubbletea Models, Messages, Views)
   - Apply design tokens (terminal colors via lipgloss/equivalent, spacing in character units)
   - Implement state machines (all states must be reachable via keyboard input)
   - Implement key interactions from the feature spec (Tab navigation, input handling, Command Center if applicable)
   - Be self-contained and runnable (single `go run ./cmd/prototype/` or equivalent)
3. Prototype code quality requirements (prototype is seed code for production):
   - TUI models match the component tree defined in the feature spec
   - State management follows the framework's architecture (e.g. bubbletea Elm architecture)
   - File structure follows framework conventions
   - No hardcoded colors — use design token constants

**Step 5.2 — User Validation**

Present the prototype to the user for feedback.

**Web/Desktop UI:**
1. Use the `playwright-cli` skill to open the prototype in a browser, navigate through states, and take screenshots
2. Walk through each feature's state machine — user verifies each state looks and behaves as expected
3. Collect feedback per category:
   - **Spec change** — the feature's Interaction Design section needs updating (update the feature file)
   - **Token change** — design tokens need adjustment (update architecture.md design tokens)
   - **Prototype-only fix** — implementation detail, doesn't affect spec (fix in prototype code only)

**TUI:**
1. Run the TUI prototype in the terminal. If the TUI framework supports snapshot testing (e.g. bubbletea teatest), generate golden snapshots for each state
2. Walk through each feature's state machine via keyboard — user verifies layout, colors, and interactions
3. Collect feedback per same categories as web (spec change / token change / prototype-only fix)
4. Save terminal snapshots (teatest `.golden` files or terminal screenshots via `script`/`asciinema`) as the visual record

**Step 5.3 — Archive**

After user confirms the prototype:

1. Take screenshots/snapshots of key states:
   - Web: save browser screenshots to `{prd-dir}/prototypes/screenshots/` (via `playwright-cli` skill)
   - TUI: save teatest `.golden` files or terminal screenshots to `{prd-dir}/prototypes/screenshots/`
2. Store prototype source code in `{prd-dir}/prototypes/src/`
3. Record prototype metadata in each feature file's Prototype Reference section

#### Phase 6 Deep-Dive: Authorization & Permissions

After personas are defined, explicitly ask about access control:

1. **Role inventory** — what distinct roles exist? (often maps 1:1 to personas, but not always — e.g. "Admin" persona may have super-admin and org-admin sub-roles)
2. **Permission matrix** — for each feature, which roles can access it? (full access / read-only / no access)
3. **Data visibility** — can all roles see all data, or is data scoped? (e.g. "users see only their own tasks, admins see all")
4. **Escalation** — who can grant/revoke roles?

Record in architecture.md's Authorization Model section. Omit for single-role products.

#### Phase 6 Deep-Dive: Privacy & Compliance

Ask about data handling obligations:

1. **Regulatory requirements** — GDPR, CCPA, HIPAA, SOC 2, or other? If none, note "no specific regulatory requirements"
2. **Personal data inventory** — which data model entities contain personal or sensitive data?
3. **User rights** — must users be able to export, delete, or correct their data?
4. **Data retention** — how long is data kept? Is there an automatic deletion policy?
5. **Consent** — does the product collect data that requires explicit user consent?

Record in architecture.md's Privacy & Compliance section. Omit for internal tools with no personal data.

#### Phase 6 Deep-Dive: Backend Internationalization

Ask about backend locale handling. Skip if the product is single-language AND has no user-facing interface (pure internal tool with no external consumers). Otherwise, even a backend-only API serving multiple locales needs these decisions:

1. **Supported locales** — which locales does the backend serve? (may differ from frontend — e.g. API supports 10 languages, frontend supports 3)
2. **Locale resolution** — how is the user's locale determined? (Accept-Language header / user profile preference / URL path prefix / query parameter / default only)
3. **API error & validation messages** — are error messages returned in the user's locale, or always in a fixed language? If localized: how are message catalogs structured?
4. **Notification & email content** — are notification/email templates localized? How is the recipient's locale determined?
5. **Timezone handling** — are timestamps stored in UTC? How are they presented to the user? (UTC always / user's timezone / configurable per request)
6. **Locale-aware data formatting** — do API responses format dates, numbers, or currencies in the user's locale, or return raw values for the client to format?

Record in architecture.md's Internationalization Baseline section (Backend sub-section). For single-language products with no multi-locale backend, note "N/A — single-language backend" and skip.

#### Phase 6 Deep-Dive: Shared Conventions

After tech stack is decided, explicitly ask about conventions that will be shared across all features. These feed directly into architecture.md's Shared Conventions section:

1. **API conventions** — response format (JSON?), authentication method, pagination style, versioning, rate limiting
2. **Error handling** — error response format, error code taxonomy, how to handle 4xx vs 5xx, validation error structure
3. **Testing strategy** — testing frameworks per layer (unit/integration/E2E), coverage targets, what must be tested

These are critical for AI coding agent consistency. Without them, each feature will be implemented with different conventions.

#### Phase 6 Deep-Dive: Coding Conventions

Ask about coding standards that ensure consistency when multiple agents (or developers) implement features in parallel. These are technology-agnostic policies — the system-design phase translates them into concrete patterns for the chosen stack.

1. **Code organization** — what layering strategy? (e.g. domain/service/infrastructure separation, feature-based grouping, flat structure) How are modules/packages named? How are files within a module organized?
2. **Naming conventions** — rules for files, modules, types/classes, functions, variables, constants. Are there project-specific prefixes or suffixes? (e.g. `*Service`, `*Handler`, `*Store`)
3. **Interface/abstraction design** — when to define abstractions vs use concrete types? Where do interfaces live — with the consumer (caller) or provider (implementer)? Are there rules about interface size (e.g. prefer small interfaces)?
4. **Dependency wiring** — how do components receive their dependencies? (constructor injection / parameter passing / service locator / framework-managed) Is global mutable state allowed? (typically: no — state must be passed explicitly)
5. **Error handling & propagation** — must errors include context (wrapping with "what was being done when this failed")? Are there custom error categories (e.g. validation errors vs system errors vs transient errors)? How do errors cross layer boundaries (e.g. domain errors → API errors)?
6. **Logging conventions** — what log levels are used and when? (e.g. ERROR = requires human action, WARN = degraded but functional, INFO = key business events, DEBUG = troubleshooting) Must logging be structured (key-value pairs, not free-form strings)? What must never be logged (secrets, PII, tokens)?
7. **Configuration access** — how do components get configuration? (injected at construction / read from a config object / environment variables) Must config be validated at startup (fail fast on invalid config)? Are there rules about config defaults?
8. **Concurrency patterns** — how are concurrent tasks managed? (context/cancellation propagation, lifecycle management) What are the rules for shared state? (e.g. no shared mutable state without synchronization; prefer message-passing over locks) Must long-running tasks support graceful cancellation?

Record in architecture.md's Coding Conventions section. These remain technology-agnostic — the system-design phase maps them to specific language/framework idioms.

**Frontend-specific conventions (if UI exists):**

9. **Component structure** — how is a UI component organized? (single file / multi-file per component) What is the naming convention for components? How is component hierarchy structured (container vs presentational, smart vs dumb)?
10. **State management patterns** — when is local state acceptable vs when must state be lifted/shared? Are there rules about state shape or immutability?
11. **Styling conventions** — how are design tokens consumed in code? Are inline styles allowed, or must styling be centralized? How are component-specific vs global styles organized?

#### Phase 6 Deep-Dive: Test Isolation & Concurrent Safety

This section ensures tests are reliable when run in parallel, across multiple worktrees, or in CI environments. These policies are especially critical for multi-agent development where multiple coding agents may run tests simultaneously.

Ask about (and establish) these policies:

1. **Resource isolation** — tests must use temporary/isolated resources, never shared global state. What resources need isolation? (file system directories, network ports, databases, message queues, caches) Policy: tests must create their own temporary resources and clean them up after completion
2. **No shared mutable state in tests** — tests must not rely on or modify package-level / module-level mutable state. All state must be passed as parameters or created within the test scope. This is a strict requirement, not a recommendation
3. **Port binding** — tests that start servers or listeners must use random available ports (e.g. binding to port 0), never hardcoded ports. This prevents conflicts when tests run in parallel or across worktrees
4. **File system isolation** — tests that create files or directories must use the test framework's temporary directory facility. Tests must never write to the working directory, project root, or any shared path
5. **External process isolation** — tests that spawn child processes must ensure processes are terminated on test completion (even on test failure or timeout). Orphan processes must not persist after tests
6. **Race condition detection** — if the language/runtime supports data race detection (e.g. Go race detector, ThreadSanitizer), it must be enabled in CI. This is a CI gate, not optional
7. **Test timeouts** — all tests must have bounded execution time. No test may run indefinitely. Timeout defaults should be specified (e.g. unit: 30s, integration: 5m)
8. **Worktree/directory independence** — tests must not assume any specific working directory or absolute path. Tests must work correctly when run from any worktree or checkout location
9. **Parallel test classification** — which tests can safely run in parallel? Which must run serially? (e.g. tests that acquire exclusive locks on shared resources must be serialized) How is this classification marked/enforced?

Record in architecture.md's Test Isolation section.

#### Phase 6 Deep-Dive: Development Workflow

Ask about the development workflow that all contributors (human or AI agent) must follow. This is especially important when AI coding agents implement features in parallel worktrees.

1. **Prerequisites** — what must be installed? (language runtime version, build tools, external CLIs) Are version constraints strict (exact) or minimum?
2. **Local setup** — is there a one-command setup? (e.g. `make setup`, `./scripts/bootstrap.sh`) What does first-time setup involve?
3. **CI pipeline gates** — what checks run on every PR/push? (typical: lint → build → test with race detection → benchmark regression). What must pass before merge? Are there checks that run but don't block?
4. **Build matrix** — which platforms/OS are supported? Is CI tested on all of them?
5. **Release process** — what versioning scheme? (semver / calver / other) How is the changelog generated? (manual / conventional commits / automated) What testing occurs before release?
6. **Dependency management** — what is the policy for adding new dependencies? (review required? license check?) How are dependency updates managed? (automated PRs? manual review?)

Record in architecture.md's Development Workflow section.

#### Phase 6 Deep-Dive: Security Coding Policy

Ask about security coding standards that every feature must follow. These are technology-agnostic policies — not security tool configurations.

1. **Input validation** — all external input (user input, API parameters, file content, environment variables) must be validated at system boundaries. What counts as a "boundary"? (e.g. API handlers, CLI argument parsers, file readers, message consumers) Internal layers trust validated data — no redundant validation deep in the stack
2. **Secret handling** — secrets, tokens, credentials, and API keys must never appear in: source code, logs, error messages, stack traces, version control history, client-side responses. How are secrets provided to the application? (environment variables / secret manager / config file excluded from VCS)
3. **Dependency vulnerability scanning** — third-party dependencies must pass vulnerability scanning. What is the policy? (block merge on critical/high CVEs? fix within N days? allow exceptions with documented justification?)
4. **Injection prevention** — for any scenario where user-controlled input is incorporated into commands, queries, or templates: what is the policy? (e.g. never concatenate — use parameterized queries, shell escaping, template sandboxing)
5. **Auth enforcement** — every entry point that requires authentication/authorization must independently verify permissions. Internal service-to-service calls must not bypass permission checks. How is this enforced? (middleware? decorator? manual check per handler?)
6. **Sensitive data in transit and at rest** — must connections to external services use TLS? Must sensitive data at rest be encrypted? What data is considered sensitive?

Record in architecture.md's Security Coding Policy section.

#### Phase 6 Deep-Dive: Backward Compatibility & API Evolution

Ask about how the product will evolve without breaking existing consumers. Skip for v1/MVP-only products where no consumers exist yet — but note the skip decision.

1. **API versioning strategy** — how are API versions managed? (URL prefix `/v1/` / header-based / query parameter / no versioning) When is a new version created? How long are old versions maintained?
2. **Breaking change definition** — what constitutes a breaking change? (removing a field, changing a type, renaming an endpoint, changing default behavior) Is there a formal list?
3. **Breaking change process** — when a breaking change is unavoidable, what is the process? (deprecation notice period? migration guide? version bump?)
4. **Data schema evolution** — how are persistent data format changes handled? (additive-only changes? migration scripts? backward-compatible readers?) Must old data remain readable after schema changes?
5. **Configuration file evolution** — when config format changes, what is the upgrade path for existing users? (automatic migration? manual migration with clear instructions? backward-compatible parsing?)

Record in architecture.md's Backward Compatibility section. For v1/MVP: note "N/A — first version, no existing consumers" and document the intended versioning strategy for future reference.

#### Phase 6 Deep-Dive: Git & Branch Strategy

Ask about version control workflow. Especially critical when multiple agents or developers work in parallel.

1. **Branch naming** — what is the naming convention? (e.g. `feature/{task-id}-{slug}`, `fix/{issue-id}`, `agent/{task-id}`) Are prefixes enforced?
2. **Merge strategy** — rebase + fast-forward only? Squash merge? Merge commits? Is this enforced (branch protection) or convention?
3. **Branch protection** — is the main/trunk branch protected? What checks must pass? How many approvals are required?
4. **PR conventions** — one PR per feature/task? Size limits or guidelines? Required sections in PR description? (summary, test plan, screenshots)
5. **Commit message format** — free-form? Conventional Commits (`feat:`, `fix:`, `chore:`)? Must reference task/issue ID?
6. **Stale branch cleanup** — how are merged/abandoned branches cleaned up? Automatic or manual?

Record in architecture.md's Git & Branch Strategy section.

#### Phase 6 Deep-Dive: Code Review Policy

Ask about code review standards that reviewers (human or AI agent) must follow. These define the quality bar for merged code.

1. **Review dimensions** — what must every review check? (correctness, security implications, test coverage, performance impact, readability, convention compliance) Are there dimension-specific checklists?
2. **Approval requirements** — how many approvals before merge? Are there different requirements by change type? (e.g. security-sensitive changes need security reviewer)
3. **Review SLA** — expected turnaround time for reviews? (e.g. within 1 business day) What happens if a review is blocked?
4. **Automated vs human review** — which checks are automated (lint, type check, test pass, coverage threshold) and which require human judgment (architecture fit, business logic correctness, UX quality)?
5. **Review feedback severity** — are review comments categorized by severity? (e.g. blocker = must fix before merge, suggestion = optional improvement, nit = style preference) How are disagreements resolved?
6. **Self-review for AI agents** — if AI coding agents submit code, do they self-review before requesting human/AI review? What does self-review cover?

Record in architecture.md's Code Review Policy section.

#### Phase 6 Deep-Dive: Observability Requirements

The existing Observability section in architecture.md is tool-focused (what tools to use). This deep-dive captures the **policy layer** — what must be observable, regardless of tooling.

1. **Mandatory logging events** — which categories of events must always be logged? (e.g. every state transition, every external API call, every authentication attempt, every error) What fields must every log entry include? (timestamp, component, severity, correlation ID)
2. **Health check requirements** — must every long-running component expose a health status? What does "healthy" mean for each component? (e.g. can accept requests, dependencies reachable, no stuck processes)
3. **Key metrics** — what metrics must be exposed? (e.g. request count/latency per endpoint, queue depth, error rate, active agent count, task completion rate) Are there SLO targets for key metrics?
4. **Alerting rules** — what conditions trigger alerts? (e.g. error rate > 5% for 5 minutes, agent unresponsive > timeout, disk usage > 90%) Who receives alerts? What is the escalation path?
5. **Trace context** — for distributed or multi-component systems: must a correlation/trace ID propagate across component boundaries? How? (header, context parameter, log field)
6. **Audit trail** — are there operations that must have an immutable audit log? (e.g. configuration changes, permission changes, data deletion)

Record in architecture.md's Observability Requirements section (distinct from the tool-focused Observability section).

#### Phase 6 Deep-Dive: Performance Testing & Budget

Ask about performance requirements beyond what's captured in per-feature NFRs. These are project-wide policies for preventing performance regression.

1. **Performance regression detection** — are benchmarks run in CI? What is the regression threshold that blocks merge? (e.g. > 10% degradation in p95 latency) How are false positives handled?
2. **Performance budgets** — are there per-category budgets? (e.g. API endpoint: p95 < 200ms; TUI render: < 16ms per frame; startup time: < 3s) How are budgets enforced?
3. **Load testing** — is load testing required before release? What scenarios? (e.g. N concurrent agents, M tasks, P simultaneous merges) What are the pass/fail criteria?
4. **Profiling requirements** — when must profiling be done? (e.g. before any P0 feature is merged, or only when a performance budget is exceeded) What profiling data must be captured?
5. **Resource consumption limits** — are there hard limits on memory, CPU, disk, or network usage? (e.g. total memory for N agents < 2GB, per-worktree disk < 110% of repo size)

Record in architecture.md's Performance Testing section.

#### Phase 6 Deep-Dive: AI Agent Configuration

AI coding agents (Claude Code, Copilot, Cursor, Codex, etc.) need project-specific context to work effectively. This deep-dive establishes policies for how AI agents discover and follow project conventions. These decisions affect every feature's implementation quality.

1. **Agent instruction files** — which AI agent instruction files does the project maintain? (e.g. `CLAUDE.md` for Claude Code, `AGENTS.md` for multi-agent, `GEMINI.md` for Gemini, `COPILOT.md` for Copilot) Is there a primary file that others extend, or are they independent?
2. **Structure policy** — agent instruction files must be **concise indexes**, not monolithic documents. Policy: the instruction file provides project overview + references to convention files, not a copy of all conventions. This prevents staleness and duplication. Maximum recommended size: ~200 lines for the main file
3. **Convention references** — the agent instruction file must reference (not duplicate) these sources:
   - Coding conventions file (linter config, formatter config)
   - Test isolation rules (test helper docs or conventions.md)
   - CI pipeline configuration (what gates run)
   - Security policies (what to validate, what never to log)
   - Git workflow (branch naming, commit format, merge strategy)
   - Architecture documentation (for understanding project structure)
4. **Content policy** — what belongs directly in the agent instruction file vs what should be referenced? (Direct: project overview, directory structure summary, key commands like build/test/lint. Referenced: detailed conventions, full API docs, architecture deep-dives)
5. **Maintenance policy** — when must the agent instruction file be updated? (e.g. when conventions change, when project structure changes, when new tooling is adopted) Who is responsible? Is it part of the PR checklist?
6. **Multi-agent coordination** — if multiple AI agents work in parallel (e.g. via autoforge or multi-worktree): do they share the same instruction file? Are there agent-role-specific instructions? (e.g. reviewer agent gets stricter security guidelines)
7. **Context budget** — AI agents have limited context windows. The instruction file must prioritize information by impact: what causes the most errors if missing? (typically: build/test commands, naming conventions, file structure, import patterns)

Record in architecture.md's AI Agent Configuration section.

#### Phase 6 Deep-Dive: Deployment & Environment Strategy

Ask about how the product is deployed across environments and what deployment artifacts are needed. These are technology-agnostic policies — the system-design phase maps them to concrete tooling (Docker, K8s, Terraform, etc.).

1. **Environments** — which environments exist? (local development, testing/CI, staging, production) For each environment: what is its purpose, who uses it, how is it provisioned?
2. **Local development setup** — how does a developer (human or AI agent) get a working local environment? Must it be reproducible from a single command? What services are needed locally? (database, cache, message queue, external API stubs) Is containerization required for local dev, or is native runtime sufficient?
3. **Environment parity** — how similar must non-production environments be to production? (identical infrastructure at smaller scale? same services with mock data? minimal subset?) What differences are acceptable? (e.g. staging uses smaller instances, dev uses local file storage instead of cloud)
4. **Configuration management** — how are environment-specific settings managed? (environment variables, config files per environment, secret manager, feature flags) Must there be a configuration template (e.g. `.env.example`) for each environment? Must configuration be validated at application startup?
5. **Data management per environment** — does local dev need seed data? How is it generated? Does staging use anonymized production data, synthetic data, or a seed script? Are there data migration requirements? (schema migration tool, rollback capability)
6. **Deployment pipeline (CD)** — how is code deployed to each non-local environment? (manual, automated on merge, automated on tag, approval gate) What is the rollback strategy? (redeploy previous version, database rollback, feature flag toggle) Must deployments be zero-downtime?
7. **Environment isolation** — can multiple developers/agents run independent environments simultaneously without conflict? (port allocation, database isolation, namespace separation) This is critical for multi-agent parallel development
8. **Infrastructure as Code** — must infrastructure be defined declaratively? (IaC configs, container definitions, orchestration manifests) Or is manual provisioning acceptable for MVP?

Record in architecture.md's Deployment Architecture section (which should be expanded to capture these policies alongside the existing environment table).

#### Phase 7 Deep-Dive: Priority Framework

Don't just ask "what's P0?" — guide the user through structured evaluation:

1. **Impact/Effort matrix** — for each feature, ask:
   - **Impact:** How many users affected? How severe is the pain without it? (High/Medium/Low)
   - **Effort:** Engineering complexity + calendar time (S/M/L/XL)
2. **Assign priority:**
   - **P0** = High impact, blocks core journey happy path — must ship in MVP
   - **P1** = High impact but has workaround, or medium impact with low effort
   - **P2** = Nice-to-have, low impact, or high effort with uncertain payoff
3. **Validate against journeys** — every P0 feature must serve a touchpoint on a core journey happy path. If a P0 feature only appears in alternative/edge paths, challenge the priority.

#### Phase 8 Deep-Dive: Risk Identification

For each risk, capture: what can go wrong, likelihood, impact, and mitigation. Focus on risks that affect **implementation decisions**:

- **Technical risks** — new/unproven tech, performance unknowns, complex integrations
- **Dependency risks** — third-party API reliability, team/skill availability, upstream deliverables
- **Data & compliance risks** — migration complexity, consistency guarantees, privacy regulation violations, data breach scenarios, consent gaps
- **Scope risks** — ambiguous requirements that could balloon during implementation
- **Validation risks** — features based primarily on assumptions without user data (flagged during Phase 1 Evidence Base)

### Document-Based Mode

Read document → summarize understanding → check gaps against list below → ask targeted questions → generate

**Gap checklist for documents** — scan for missing or vague coverage in these areas:

- [ ] Personas defined with clear goals?
- [ ] User journeys (happy path + error/alternative paths) described or inferrable?
- [ ] Cross-journey patterns identified (shared pain points, repeated touchpoints, handoff points)?
- [ ] Success metrics with measurable targets?
- [ ] Competitive context or alternatives acknowledged?
- [ ] Evidence base for key decisions (data, research, or labeled assumptions)?
- [ ] Feature boundaries clear (what's in/out of MVP)?
- [ ] Edge cases and error handling addressed?
- [ ] Interaction design described for user-facing features (component contracts, state machines, a11y, i18n)?
- [ ] Frontend tech stack specified (framework, CSS, component library, state management)?
- [ ] Design tokens defined (colors, typography, spacing, breakpoints, motion)?
- [ ] Navigation architecture described (site map, routes, breadcrumbs)?
- [ ] Component contracts defined for user-facing features (props, events, slots)?
- [ ] Interaction state machines defined for stateful UI components?
- [ ] Form specifications defined for form-having features (fields, validation, error messages, conditional logic, submission behavior)?
- [ ] Micro-interactions & motion defined for key interactions (trigger, animation, duration token, easing token, purpose)?
- [ ] Interaction Mode specified per journey touchpoint (click, form, drag, swipe, keyboard, etc.)?
- [ ] Page transitions defined for multi-step journeys (transition type, data prefetch, notes)?
- [ ] Architecture-level accessibility baseline defined (WCAG level, keyboard, focus, contrast, motion, touch targets)?
- [ ] Accessibility requirements stated per feature (WCAG level, keyboard, ARIA, focus)?
- [ ] Architecture-level i18n baseline defined — frontend (languages, default language, RTL, key convention, format rules) and/or backend (locale resolution, error message localization, timezone handling)?
- [ ] Frontend internationalization requirements stated per user-facing feature (languages, keys, format rules)?
- [ ] Backend internationalization requirements stated per feature returning user-visible text (locale-dependent messages, locale resolution strategy)?
- [ ] Responsive behavior described per breakpoint for user-facing features?
- [ ] Prototype feedback documented and incorporated into specs and design tokens?
- [ ] Prototype source code archived (prototypes/src/{feature-slug}/) and visual records archived (prototypes/screenshots/{feature-slug}/ — browser screenshots for web, teatest golden files for TUI)?
- [ ] Authorization / permission model described (if multi-role)?
- [ ] Privacy / compliance requirements stated (if handling personal data)?
- [ ] Notification requirements captured (if the product notifies users)?
- [ ] Technical stack and integration points specified?
- [ ] Non-functional requirements (performance, security, i18n) stated?
- [ ] Shared conventions (API format, error handling, testing strategy) defined or inferrable?
- [ ] Coding conventions defined (code organization, naming, interface design, dependency wiring, error propagation, logging, config access, concurrency)?
- [ ] Test isolation policies defined (resource isolation, no global mutable state, random ports, temp dirs, process cleanup, race detection, timeouts, directory independence)?
- [ ] Development workflow defined (prerequisites, local setup, CI gates, build matrix, release process, dependency management)?
- [ ] Security coding policy defined (input validation, secret handling, dependency scanning, injection prevention, auth enforcement)?
- [ ] Backward compatibility policy defined (API versioning, breaking changes, data schema evolution — or N/A for v1)?
- [ ] Git & Branch Strategy defined (naming, merge strategy, protection rules, PR conventions, commit format)?
- [ ] Code review policy defined (dimensions, approvals, SLA, automated vs human, severity levels)?
- [ ] Observability requirements defined at policy level (mandatory events, health checks, metrics/SLOs, alerting, audit trail)?
- [ ] Performance testing policy defined (regression detection, budgets, load testing, resource limits)?
- [ ] Development Infrastructure feature present (auto-derived from convention sections) with concrete deliverables (linter config, CI pipeline, pre-commit hooks, test helpers, security scanning, AI agent instruction files, etc.)?
- [ ] AI agent configuration defined (instruction files, structure policy, convention references, maintenance policy, context budget)?
- [ ] Deployment architecture defined (environments, local dev setup, environment parity, config management, data migration, CD pipeline, environment isolation, IaC)?
- [ ] Deployment Infrastructure feature present (auto-derived from Deployment Architecture) with concrete deliverables (env setup, config templates, migration tooling, CD pipeline, isolation config)?
- [ ] Risks or open questions acknowledged?
- [ ] Priority rationale (not just labels) provided?
- [ ] Edge cases testable (Given/When/Then, not vague descriptions)?
- [ ] Non-functional requirements stated per feature (not just globally)?
- [ ] Test data requirements inferrable for non-trivial features?
- [ ] E2E test scenarios inferrable from journey flows (happy + error paths)?

### Immutability Rule

Whether PRD files can be modified in place depends on their **downstream consumption state** — what has been built on top of them:

| Downstream State | Modify in Place? | Rationale |
|-----------------|-----------------|-----------|
| No design exists | Yes | No downstream consumers to break |
| Design exists, not implemented | Yes + add Revision History entry | Design team needs the change record to update design accordingly |
| Implementation exists | No — create new version | Modifying in place would invalidate implemented code |

Steps 6-7 (self-review, user review) always occur before commit and are part of the creation process — modifying files during these steps is expected regardless of downstream state.

### PRD Review Mode (`--review`)

Review an existing PRD directory for quality, completeness, and consistency. **This mode is read-only** — it reports findings but does not modify any files.

0. **Version discovery** — scan the parent directory for sibling PRD directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the Revision History in each version forms a consistent chain (each newer version links back to its predecessor). Record this context for subsequent steps.
1. **Read all files** — README.md, journeys/*.md, architecture.md, features/*.md
2. **Run Review Checklist** — check every dimension (including Version integrity), collect findings
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
   - If issues are significant (missing journeys, orphan features, gaps): recommend `--revise` to address the issues
   - If reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version

### PRD Revise Mode (`--revise`)

Interactively modify an existing PRD — whether it's still a draft or already finalized. Auto-detects PRD state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

#### Revise Step 1 — Detect Downstream State & Confirm Intent

Auto-detect what has been built on top of this PRD, then confirm with the user.

**Auto-detection:**

1. **Check for design:** scan for a system-design directory whose `Design Input > Source` references this PRD path
2. **Check for implementation:** if a design exists, read its `Design Input > Status` field — `Implementing` or `Implemented` means code exists

**Ask user to confirm detected state:**

> I detected the following downstream state for this PRD:
> - Design: {found at path / not found}
> - Implementation: {Status field value / N/A}
>
> Is this correct? If not, what's the actual state?

**Resolve action based on confirmed state:**

| Downstream State | Action |
|-----------------|--------|
| No design exists | Modify PRD files directly |
| Design exists, not implemented | Modify PRD files directly + add Revision History entry describing what changed (so design can be updated accordingly) |
| Implementation exists (Status = Implementing or Implemented) | Create new PRD version (new dated directory); original untouched |

If the user disagrees with the auto-detection (e.g. "the design exists but is outdated and will be regenerated"), defer to user judgment.

#### Revise Step 2 — Present PRD Overview

Read and summarize the current PRD so the user has context before describing changes:

- Product name and vision
- Personas and journey count
- Feature count by priority (P0/P1/P2) and roadmap phase
- Key risks and open items (if any)

#### Revise Step 3 — Gather Changes (interactive, one at a time)

Ask the user to select change types (multiple allowed):

1. **Add requirement** — new feature, new journey, or new persona
2. **Modify requirement** — change existing feature behavior, scope, priority, or acceptance criteria
3. **Deprecate requirement** — remove a feature or journey that's no longer needed
4. **Environment change** — external shift (tech stack, competitor, regulation, user feedback) that affects existing requirements
5. **Convention/policy change** — change to developer conventions, test isolation, security policy, git strategy, code review, observability, performance testing, or other architecture-level policies

Then deep-dive each selected type:

**Add requirement:**
- What persona does this serve? (existing or new?)
- What journey does it belong to? (existing or new?)
- What touchpoint / pain point does it address?
- What's the expected priority (P0/P1/P2)?
- Does it depend on any existing features?
- Does any existing feature need to change to accommodate this?

**Modify requirement:**
- Which feature(s) / journey(s)?
- What specifically changes? (behavior, scope, priority, acceptance criteria, interaction design)
- Why the change? (new evidence, user feedback, technical constraint, scope adjustment)
- Is the change additive (extending behavior) or breaking (changing existing behavior)?

**Deprecate requirement:**
- Which feature(s) / journey(s)?
- Why? (no longer needed, superseded by another feature, too expensive, invalidated by evidence)
- What replaces it, if anything?

**Environment change:**
- What changed externally? (tech stack shift, new competitor, regulatory change, user research findings)
- Which existing features / journeys are affected?
- Does this change priorities?
- Are new features needed in response?

**Convention/policy change:**
- Which section(s) in architecture.md? (Coding Conventions / Test Isolation / Security Coding Policy / Git & Branch Strategy / Code Review Policy / Observability Requirements / Performance Testing / Development Workflow / Backward Compatibility / Shared Conventions / AI Agent Configuration / Deployment Architecture)
- What specifically changes? (new policy, relaxed policy, stricter policy, removed policy)
- Why the change? (incident, new team member onboarding friction, CI flakiness, security audit finding, performance regression, workflow bottleneck)
- Is this additive (new policy alongside existing ones) or breaking (changes behavior that existing features already follow)?
- Which features are most affected? (features that copy this convention into "Relevant conventions", or features whose tests/edge cases depend on this policy)

#### Revise Step 4 — Impact Analysis & Conflict Detection

After gathering all changes, systematically trace their impact through the PRD.

**Impact propagation** — for each changed/added/deprecated item (feature, journey, or persona):

| Check | How |
|-------|-----|
| Journey impact | Which journeys reference the affected feature(s)? Do touchpoints need updating? If a journey itself changed, which features map to its touchpoints? |
| Dependency chain | Which features depend on the affected item? Which features does it depend on? |
| Cross-journey patterns | Does this change affect any documented cross-journey pattern? If a journey is added/removed, do patterns need re-evaluation? |
| Metrics impact | Does the affected item feed a Goal metric? Will removing/changing it leave a metric unmeasured? |
| Roadmap impact | Does this change affect phase ordering? Do dependencies still respect phase boundaries? |
| Risk impact | Does this change introduce new risks or invalidate existing mitigations? |
| Test impact | Which Acceptance Criteria, Edge Cases, and E2E Test Scenarios are invalidated or need updating? Which dependent Features' test cases need regression re-verification? List affected items by Feature/Journey ID |
| Design token impact | Does the change affect design tokens in architecture.md? If so, ALL features referencing those tokens are impacted — check every user-facing feature's Interaction Design section |
| Navigation impact | Does the change add/remove/rename screens? If so, architecture.md Navigation Architecture (site map, routes) and all affected features' Screen & Layout sub-sections need updating |
| Component contract impact | Does the change modify a shared component's contract? If so, check which features use that component and whether their state machines and interactions are still valid |
| Accessibility baseline impact | Does the change affect architecture.md's Accessibility Baseline? If so, every user-facing feature's Accessibility sub-section that references the baseline may need updating |
| i18n baseline impact | Does the change affect architecture.md's Internationalization Baseline (frontend or backend)? If frontend baseline changed, every user-facing feature's i18n sub-section and i18n key prefixes may need updating. If backend baseline changed (locale resolution, timezone handling), every backend feature returning user-visible text may need updating |
| Form specification impact | Does the change affect a feature's Form Specification (fields, validation, dependencies)? If so, check if the feature's state machine, acceptance criteria, and E2E Test Scenarios still cover the updated form behavior |
| Micro-interaction & motion impact | Does the change introduce, remove, or modify UI interactions? If so, check affected features' Micro-Interactions & Motion sub-sections for consistency with updated state machines and component contracts |
| Interaction mode impact | Does the change modify a journey's touchpoints or interaction patterns? If so, check that the Interaction Mode column is updated and that corresponding feature component contracts support the changed interaction mode |
| Prototype impact | Does the change invalidate existing prototypes? Mark affected prototypes as needing regeneration in the feature's Prototype Reference section (set Confirmed date to empty); after regeneration, overwrite old source in `prototypes/src/{feature-slug}/` and old screenshots in `prototypes/screenshots/{feature-slug}/`, then update Confirmed date |
| Coding conventions impact | Does the change affect architecture.md's Coding Conventions (e.g. new concurrency requirement, changed error handling policy)? If so, every feature's "Relevant conventions" section that copies those policies may need updating |
| Test isolation impact | Does the change affect architecture.md's Test Isolation policies (e.g. new resource isolation requirement, changed timeout defaults)? If so, affected features' Test Data Requirements sections may need updating |
| Development workflow impact | Does the change affect architecture.md's Development Workflow (e.g. new CI gate, changed prerequisites)? If so, check all features' Implementation Notes for consistency |
| Security policy impact | Does the change affect architecture.md's Security Coding Policy (e.g. new validation requirement, changed secret handling rules)? If so, every feature's edge cases and acceptance criteria should be checked for security-relevant scenarios |
| Backward compatibility impact | Does the change affect architecture.md's Backward Compatibility policy (e.g. new API version, changed migration strategy)? If so, affected features' API contracts and data model sections may need versioning annotations |
| Git & Branch Strategy impact | Does the change affect architecture.md's Git & Branch Strategy (e.g. changed merge strategy, new branch protection)? If so, features' Implementation Notes and Development Workflow CI gates may need updating |
| Code review policy impact | Does the change affect architecture.md's Code Review Policy (e.g. new review dimension, changed approval requirements)? If so, check if any feature's quality or testing criteria need alignment |
| Observability requirements impact | Does the change affect architecture.md's Observability Requirements (e.g. new mandatory event, changed alerting rules)? If so, affected features' Analytics & Tracking sections may need new events added |
| Performance testing impact | Does the change affect architecture.md's Performance Testing policy (e.g. new budget, changed regression threshold)? If so, affected features' non-behavioral acceptance criteria may need updating |
| AI agent configuration impact | Does the change affect architecture.md's AI Agent Configuration (e.g. new instruction file, changed structure policy, updated convention references)? If so, the Development Infrastructure feature's CLAUDE.md deliverable may need updating; check if instruction file references still point to valid convention files |
| Deployment architecture impact | Does the change affect architecture.md's Deployment Architecture (e.g. new environment, changed CD pipeline policy, updated rollback strategy, modified environment isolation)? If so, the Deployment Infrastructure feature's deliverables may need updating; check environment-specific configs, CD pipeline definitions, and isolation configurations |

**Conflict detection** — check for these types:

| Conflict Type | What to Check |
|---------------|---------------|
| Dependency conflict | New feature depends on a deprecated feature; modifying a feature breaks a dependent feature's assumptions |
| Priority conflict | A P0 depends on a P1/P2 (phase ordering violation); a new P0 isn't on any core journey happy path |
| Behavior conflict | New requirement contradicts an existing requirement (e.g. "data is public by default" vs. "data is private by default") |
| Scope conflict | Changes push total effort beyond stated MVP boundary without re-scoping |
| Coverage gap | Deprecating a feature leaves a journey touchpoint or pain point with no feature coverage |
| Metric orphan | Removing a feature that was the sole measurement point for a Goal metric |

Present findings to the user before proceeding:
- **Conflicts** — must be resolved before continuing (ask user how to resolve each one)
- **Impacts** — changes that propagate to other files, user confirms awareness
- **Warnings** — potential issues that don't block but should be acknowledged

#### Revise Step 5 — Execute Changes

Based on the downstream state confirmed in Step 1:

**Modify directly (no design, or design exists but not implemented):**
- Update affected files in place
- If design exists: add Revision History entry in README.md summarizing what changed and why — this record helps the design update process (`/system-design --revise`) identify what PRD changes need to propagate

**Create new version (implementation exists):**
- Create new dated directory (e.g. `docs/raw/prd/YYYY-MM-DD-{product-name}/`)
- Copy forward unchanged files
- Apply changes to affected files
- Add Revision History entry linking back to previous version

In both cases:
- Update all cross-references (journey Mapped Feature columns, feature Dependencies, Cross-Journey Patterns "Addressed by Feature" column)
- Mark deprecated features clearly — remove the feature file and remove it from Feature Index, Roadmap, and any Mapped Feature references
- Re-derive affected User Stories if journey touchpoints changed (re-run Phase 3 Step 1 extraction for affected journeys only)

#### Revise Step 6 — Post-Change Review

Run the full Review Checklist on the modified/new PRD, with special attention to:
- Traceability chain integrity after changes
- No orphan features (especially after deprecation)
- No uncovered touchpoints or pain points (especially after deprecation)
- Dependency ordering still valid after priority changes
- Cross-journey patterns still accurate
- All conflicts from Step 4 resolved
- Interaction Design sections consistent with any changed journeys (interaction modes, page transitions, state machines)
- Architecture-level baselines (a11y, i18n, design tokens) still consistent with per-feature sections after changes
- Prototype archival up to date (no stale screenshots or source for changed features)
- Developer convention sections (Coding Conventions, Test Isolation, Security Coding Policy, Git & Branch Strategy, Code Review Policy, Observability Requirements, Performance Testing, Development Workflow, Backward Compatibility) still consistent with per-feature "Relevant conventions" sections after changes
- Security Coding Policy changes reflected in affected features' edge cases (e.g. new input validation boundary → new edge case testing unauthorized input)
- Performance Testing budget changes reflected in affected features' non-behavioral acceptance criteria
- Code Review Policy changes aligned with features that have Reviewer-related user stories or acceptance criteria
- Observability Requirements changes reflected in affected features' Analytics & Tracking events
- Test Isolation policy changes reflected in affected features' Test Data Requirements sections
- Development Workflow changes (CI gates, prerequisites) reflected in affected features' Implementation Notes
- Backward Compatibility policy changes reflected in affected features' API Contracts and data model versioning annotations
- Git & Branch Strategy changes reflected in affected features' Implementation Notes and Development Workflow CI gates
- AI Agent Configuration consistency: instruction file structure policy still valid, convention references still point to existing files, maintenance triggers still aligned with changed conventions

Then proceed to user review → commit (same as initial creation flow steps 7-8).

**Commit message format:** describe the revision, e.g. "Revise PRD: add F-014 SSO, deprecate F-005, reprioritize F-008 to P0"

**Post-revise cascade notification:**

After committing the revision, check for downstream consumers and print applicable next steps:

1. **If a system-design exists for this PRD** (detected in Revise Step 1): print:
   ```
   ⚠ Downstream design exists: {design path}
   The following PRD sections changed: {list of changed sections}
   
   Next step: run system-design --revise {design path} to propagate these changes
     - Implementation Conventions may need re-translation
     - Module specs referencing changed conventions may need updating
   ```

2. **If no downstream design exists**: print only the standard next steps hint (same as initial creation).

## Output Structure

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md                # Product overview + journey index + feature index + roadmap
├── journeys/
│   ├── J-001-{slug}.md      # Individual journey spec
│   └── ...
├── architecture.md          # INDEX ONLY (~50-80 lines) — diagram + links to topic files
├── architecture/            # Topic files — each standalone, independently readable
│   ├── tech-stack.md
│   ├── design-tokens.md     # (omit if no UI)
│   ├── navigation.md        # (omit if no UI)
│   ├── accessibility.md     # (omit if no UI)
│   ├── i18n.md
│   ├── data-model.md
│   ├── external-deps.md
│   ├── coding-conventions.md
│   ├── test-isolation.md
│   ├── security.md
│   ├── dev-workflow.md
│   ├── git-strategy.md
│   ├── code-review.md
│   ├── observability.md
│   ├── performance.md
│   ├── backward-compat.md   # (omit for v1)
│   ├── ai-agent-config.md
│   ├── deployment.md
│   ├── shared-conventions.md
│   ├── auth-model.md        # (omit if single-role)
│   ├── privacy.md           # (omit if no personal data)
│   └── nfr.md
├── features/
│   ├── F-001-{slug}.md      # Self-contained feature spec
│   └── ...
├── prototypes/              # Interactive prototypes (seed code for production)
│   ├── src/                 # Runnable prototype source
│   └── screenshots/         # Key state screenshots per feature
```

Use templates: `prd-template.md` (README), `journey-template.md` (individual journeys), `architecture-template.md` (architecture index + topic files), and `feature-template.md` (feature specs).

**Agent consumption:** read README.md (~concise overview) → read one feature file → implement. Each feature file copies all needed context inline (data models, conventions, journey context), so the feature file alone is sufficient for implementation. Agents do NOT need to read architecture.md or architecture/ files — those are source-of-truth for the PRD author, not for coding agents. The feature file is the coding agent's only input.

## Output Path

- **Default:** `docs/raw/prd/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing

## Key Principles

- **One question at a time** — don't overwhelm
- **MVP ruthlessly** — push back on scope creep
- **Minimal context** — agents read one small file, not a giant document
- **Copy, don't reference** — feature files include relevant data models, conventions, and journey context inline
- **No ambiguity** — if a requirement can be interpreted two ways, clarify now
- **Omit empty sections** — if a section has nothing useful, skip it

## Next Steps Hint

After committing, print the following guidance to the user:

```
PRD complete: {output path}

Next steps:
  Interactive — /system-design {output path}
  Automated  — claude -p "generate system design based on {output path}" --auto
```
