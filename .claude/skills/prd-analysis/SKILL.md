---
name: prd-analysis
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, prepare requirements for AI coding agents, or evolve an existing PRD for a new iteration. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis', 'evolve PRD', 'new iteration'."
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
/prd-analysis --evolve docs/raw/prd/xxx/        # incremental PRD for new iteration
/prd-analysis --evolve docs/raw/prd/xxx/ notes.md  # evolve with document input
```

## Mode Routing

After detecting the invocation mode, read the corresponding files before proceeding:

| Mode | Read These Files |
|------|-----------------|
| Initial analysis (no flags) | `questioning-phases.md` |
| Initial analysis + document input | `questioning-phases.md` + `document-mode.md` |
| `--review` | `review-mode.md` |
| `--revise` | `revise-mode.md` |
| `--evolve` | `evolve-mode.md` + `questioning-phases.md` |

Do NOT read files not listed for the current mode — they are not needed and waste context.

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
| Version integrity | If Revision History exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry. If Baseline section exists (evolve-mode PRD): Predecessor path resolves to valid directory; all `→ baseline` links in indexes resolve correctly; Change Summary matches actual files. If sibling directories with the same product slug exist in the parent directory: version chain is consistent (revise-mode links via Revision History, evolve-mode links via Baseline.Predecessor). Skip this dimension during the main process step 6 (self-review of initial creation) — it only applies to `--review`, `--revise` post-change review, and `--evolve` post-generation review |

### Immutability Rule

Whether PRD files can be modified in place depends on their **downstream consumption state** — what has been built on top of them:

| Downstream State | Modify in Place? | Rationale |
|-----------------|-----------------|-----------|
| No design exists | Yes | No downstream consumers to break |
| Design exists, not implemented | Yes + add Revision History entry | Design team needs the change record to update design accordingly |
| Implementation exists | No — create new version | Modifying in place would invalidate implemented code |

Steps 6-7 (self-review, user review) always occur before commit and are part of the creation process — modifying files during these steps is expected regardless of downstream state.

**Evolve mode note:** `--evolve` always creates a new directory (new date) — it never modifies the predecessor PRD. The predecessor is read-only input.

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

Use templates: `prd-template.md` (README), `journey-template.md` (individual journeys), `architecture-template.md` (architecture index + topic files), and `feature-template.md` (feature specs). Evolve mode uses `evolve-readme-template.md` instead of `prd-template.md` for the README; all other templates are reused with the addition of the Change Annotation Convention (defined in `evolve-mode.md`).

**Agent consumption:** read README.md (~concise overview) → read one feature file → implement. Each feature file copies all needed context inline (data models, conventions, journey context), so the feature file alone is sufficient for implementation. Agents do NOT need to read architecture.md or architecture/ files — those are source-of-truth for the PRD author, not for coding agents. The feature file is the coding agent's only input.

**Evolve mode output** — only delta files present:

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md                # Incremental README (baseline ref + change summary + full indexes)
├── journeys/
│   ├── J-{NNN}-{slug}.md   # Only new or modified journeys
│   └── ...
├── architecture.md          # Incremental index (changed → local, unchanged → baseline ref)
├── architecture/
│   ├── {changed-topic}.md   # Only changed topic files
│   └── ...
├── features/
│   ├── F-{NNN}-{slug}.md   # New features, modified features, or tombstones (deprecated)
│   └── ...
├── prototypes/              # Only new/modified feature prototypes
│   ├── src/
│   └── screenshots/
```

**Agent consumption (evolve mode):** read incremental README.md → for a new/modified feature, read the local feature file (self-contained). For an unchanged feature, follow the `→ baseline` link to the predecessor PRD's feature file.

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

**Initial creation and revise mode:**
```
PRD complete: {output path}

Next steps:
  Interactive — /system-design {output path}
  Automated  — claude -p "generate system design based on {output path}" --auto
```

**Evolve mode** — use the cascade notification from Evolve Step 5 instead.
