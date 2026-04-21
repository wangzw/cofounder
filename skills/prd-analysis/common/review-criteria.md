# Review Criteria — PRD Analysis

Each criterion is one YAML block. Narrative text between blocks is for humans; the criteria-extractor script parses only the YAML code fences. Severities: `critical` > `error` > `warning` > `info`.

Checker types:
- `script` — deterministic check; runs via `scripts/<script_path>`; issues emitted as JSON
- `llm` — semantic judgment; runs in `cross-reviewer-subagent` / `adversarial-reviewer-subagent`
- `hybrid` — script extracts evidence (concept list, reference map, etc.) and LLM judges the output

`conflicts_with` declares known rule conflicts; `priority` arbitrates (lower wins).

---

## Layer 1 — Structural & Format (script-only)

### CR-001 header-metadata-complete

Every leaf (README.md, journey file, feature file, architecture topic) must have the minimum header metadata required by its template. For journey/feature files this is the filename pattern (`F-{NNN}-{slug}.md` / `J-{NNN}-{slug}.md` supplies `id` + `slug`) plus the inline bold header fields (e.g. feature files need `**Priority:** ... **Effort:** ...` under the `# F-NNN: ...` heading). These templates use inline header fields, not YAML frontmatter delimited by `---`.

```yaml
- id: CR-001
  name: "header-metadata-complete"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-002 leaf-size-limit

Single-leaf files must not exceed 600 lines. Oversized files indicate missing decomposition (e.g. a feature file bundling three features). README.md and architecture.md (both are indexes) have a 200-line soft cap.

```yaml
- id: CR-002
  name: "leaf-size-limit"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-003 wikilinks-resolve

Every internal markdown link (`[...](./path)`, `[...](../path)`, `[...](journeys/J-*.md)`, etc.) must resolve to an existing file in the artifact. Broken cross-references destroy the self-contained property.

```yaml
- id: CR-003
  name: "wikilinks-resolve"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-wikilinks.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-004 index-consistency

`README.md` and `architecture.md` index tables must list every file in `journeys/`, `features/`, and `architecture/` respectively, and list no entries that lack a corresponding file.

```yaml
- id: CR-004
  name: "index-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-index-consistency.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-005 changelog-consistency

`CHANGELOG.md` entries and `.review/versions/<N>.md` files must be 1:1 with matching `delivery_id`, `change_summary`, and `affected_leaves`. `delivery_id` must be monotonic with no gaps.

```yaml
- id: CR-005
  name: "changelog-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-changelog-consistency.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-006 id-uniqueness

Journey IDs (`J-001`, `J-002`, ...), feature IDs (`F-001`, ...) must be unique and monotonic within the artifact. In evolve-mode new files must start above baseline `max(id)`.

```yaml
- id: CR-006
  name: "id-uniqueness"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-007 no-todo-markers

No `TODO`, `TBD`, `FIXME`, `[placeholder]`, or `<fill in>` tokens in committed files — these indicate incomplete authoring.

```yaml
- id: CR-007
  name: "no-todo-markers"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 2
```

---

## Layer 2 — Traceability (hybrid)

### CR-010 traceability-goal-to-feature

Chain `Goal → Journey → Touchpoint → User Story → Feature → Analytics` must be unbroken. Every persona has at least one journey; every touchpoint maps to ≥1 feature; every feature maps back to ≥1 touchpoint (no orphan features); cross-journey patterns each have an addressing feature.

```yaml
- id: CR-010
  name: "traceability-goal-to-feature"
  version: 1.0.0
  checker_type: hybrid
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-011 metrics-have-verification

Every README `Goal` metric has a `baseline` and `measurement method`; every journey metric has a Verification entry stating manual/automated/monitoring plus pass/fail criteria.

```yaml
- id: CR-011
  name: "metrics-have-verification"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-012 evidence-source-stated

Every major product decision (Goals, Feature priority, Target metric) traces to an evidence source (user research, analytics, feedback) OR is labeled `Assumption` with confidence level. Assumption-heavy decisions are echoed in the Risks table as validation risks.

```yaml
- id: CR-012
  name: "evidence-source-stated"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-013 risk-mitigation-completeness

Every High-likelihood OR High-impact risk has a mitigation; affected features list the risk in their Risks & Mitigations section; compliance/privacy risks are covered if personal data is handled.

```yaml
- id: CR-013
  name: "risk-mitigation-completeness"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-014 priority-phase-alignment

Every P0 feature serves a core-happy-path touchpoint; Roadmap phases align (P0→Phase 1, P1→Phase 2, P2→Phase 3); dependency graph does not contradict phase ordering (no P0 depending on P1 feature).

```yaml
- id: CR-014
  name: "priority-phase-alignment"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-015 competitive-context-present

A Competitive Landscape section exists with ≥1 alternative (or is explicitly marked N/A for internal tools). Differentiation statement is present. Table-stakes features are identified.

```yaml
- id: CR-015
  name: "competitive-context-present"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 3 — Self-Containment (llm)

### CR-020 feature-self-contained

Each feature file contains all context needed for a coding agent: relevant data models (copied inline, not referenced), applicable conventions (copied from `architecture/*.md`), permission model, journey context. A reader of one feature file alone can implement the feature.

```yaml
- id: CR-020
  name: "feature-self-contained"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-021 no-external-file-references-in-feature

Feature files must not say "see architecture.md" or "per shared conventions" — the text must be copied inline. Cross-file hyperlinks to journeys and other features are allowed (they are navigational, not context-shifting).

```yaml
- id: CR-021
  name: "no-external-file-references-in-feature"
  version: 1.0.0
  checker_type: hybrid
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 2
```

---

## Layer 4 — Testability (llm)

### CR-030 ac-observable

Every Acceptance Criterion is precise enough to write a test assertion. Forbidden vague verbs: "correctly handles", "properly displays", "works as expected", "appropriately responds".

```yaml
- id: CR-030
  name: "ac-observable"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-031 edge-case-given-when-then

Every Edge Case uses Given/When/Then and maps to an automated-test specification.

```yaml
- id: CR-031
  name: "edge-case-given-when-then"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-032 non-behavioral-criterion-present

Every feature with non-trivial state or integration has ≥1 non-behavioral criterion (performance, concurrency, resource limit, security). Saturation rule: one NR per distinct operational characteristic is sufficient — do NOT demand per-endpoint p95.

```yaml
- id: CR-032
  name: "non-behavioral-criterion-present"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-033 authorization-edge-case

Every feature with a `Permission` line has ≥1 edge case testing unauthorized access. Saturation rule: one unauthorized-access EC per permission boundary (role × scope) is sufficient — do NOT enumerate every role × workspace × org combination.

```yaml
- id: CR-033
  name: "authorization-edge-case"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-034 journey-error-path-covered

Every journey's Error & Recovery Paths row maps to ≥1 feature's Edge Case or Acceptance Criterion.

```yaml
- id: CR-034
  name: "journey-error-path-covered"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-035 cross-feature-integration-ac

Features with `Dependencies: depends-on` must have ≥1 integration-level AC referencing the upstream feature's output (e.g. "Given F-003 has produced X, when F-005 consumes it, then ...").

```yaml
- id: CR-035
  name: "cross-feature-integration-ac"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-036 journey-e2e-scenarios

Every multi-touchpoint journey has an E2E Test Scenarios table covering happy / alternative / error paths with features exercised + expected outcomes. Single-touchpoint journeys are exempt.

```yaml
- id: CR-036
  name: "journey-e2e-scenarios"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-037 test-data-requirements

Every feature with non-trivial test setup has a Test Data Requirements section (fixtures, boundary values, preconditions, external stubs). Saturation rule: reader can set up the test without reading implementation code — do NOT prescribe fixture JSON shape or generator API signatures.

```yaml
- id: CR-037
  name: "test-data-requirements"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 5 — Interaction Design (llm, skip if no UI)

### CR-040 interaction-design-coverage

Every user-facing feature has an Interaction Design section containing Screen & Layout, Component Contracts, Interaction State Machine, Accessibility, Internationalization (frontend), Responsive Behavior. Skip for backend-only features.

```yaml
- id: CR-040
  name: "interaction-design-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-041 screen-name-consistency

Screen/View names are identical across every journey touchpoint and every feature's `Screen & Layout` section referencing the same screen. Divergent names ("Dashboard" vs. "Home") break the de-facto screen inventory.

```yaml
- id: CR-041
  name: "screen-name-consistency"
  version: 1.0.0
  checker_type: hybrid
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-042 state-machine-integrity

Every Interaction State Machine has no dead states (every state has ≥1 exit); every transition specifies system feedback; loading states have both Success AND Error exits.

```yaml
- id: CR-042
  name: "state-machine-integrity"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-043 design-token-usage

No raw values (hex colors, ms, px values) in feature Interaction Design sections — all visual references use token semantic names (e.g. `color.primary.500`, `motion.duration.normal`). All applicable token categories are declared in `architecture/design-tokens.md`.

```yaml
- id: CR-043
  name: "design-token-usage"
  version: 1.0.0
  checker_type: hybrid
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-044 component-contract-consistency

Every component referenced in a feature's Interaction Design has a Component Contract (props, events, slots). Event names follow a consistent convention across features. Features sharing a screen have explicit component nesting rules.

```yaml
- id: CR-044
  name: "component-contract-consistency"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-045 cross-feature-event-flow

For features with Dependencies: event names in state-machine side effects match event names consumed by dependent features; payloads match; integration ACs (CR-035) reference the exact event names.

```yaml
- id: CR-045
  name: "cross-feature-event-flow"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-046 frontend-stack-consistency

Feature Interaction Designs use patterns compatible with the Frontend Stack chosen in `architecture/tech-stack.md` (state mgmt library, form library, UI framework conventions).

```yaml
- id: CR-046
  name: "frontend-stack-consistency"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```

### CR-047 form-specification-complete

Every feature with user input has a Form Specification sub-section (fields: type, validation, error messages, conditional visibility, dependencies; submission: success/error handling; multi-step: step sequencing).

```yaml
- id: CR-047
  name: "form-specification-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-048 micro-interactions-use-tokens

Every animation references motion duration and easing tokens by name. Saturation: once tokens are referenced, do NOT demand frame-by-frame choreography.

```yaml
- id: CR-048
  name: "micro-interactions-use-tokens"
  version: 1.0.0
  checker_type: llm
  severity: info
  conflicts_with: []
  priority: 3
```

### CR-049 journey-interaction-mode-set

Every journey touchpoint has an Interaction Mode specified (click / form / drag / swipe / keyboard / scroll / hover / voice / scan). Mode is consistent with the corresponding feature's component contracts and state machines.

```yaml
- id: CR-049
  name: "journey-interaction-mode-set"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 6 — Accessibility, i18n, Responsive (llm, skip branches where N/A)

### CR-050 accessibility-baseline-complete

`architecture/accessibility.md` is present (skip if no UI) and covers WCAG level, keyboard navigation, screen reader support, focus management, contrast, reduced motion, touch targets, error identification.

```yaml
- id: CR-050
  name: "accessibility-baseline-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-051 accessibility-per-feature

Every user-facing feature has an Accessibility sub-section referencing or extending the baseline. Keyboard navigation covers all interactive elements; ARIA roles specified for dynamic content; focus management defined for modals/drawers/overlays.

```yaml
- id: CR-051
  name: "accessibility-per-feature"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-052 i18n-baseline-complete

`architecture/i18n.md` present unless product is single-language AND no UI. Covers: supported languages, default, RTL, date/time/number/plural rules (shared); text externalization + key convention + content direction (frontend, if UI); locale resolution + message localization + timezone (backend, if multi-locale backend).

```yaml
- id: CR-052
  name: "i18n-baseline-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-053 i18n-per-feature-frontend

Every user-facing feature has frontend i18n sub-section. All user-visible text has an i18n key (no hardcoded strings in component contracts or form specs). Saturation: key-naming convention stated once → do NOT audit individual keys.

```yaml
- id: CR-053
  name: "i18n-per-feature-frontend"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-054 i18n-per-feature-backend

Every backend feature returning user-visible text (API errors, validation messages, notification content, emails) has a Backend Internationalization sub-section stating which messages are locale-dependent and how locale is determined. Saturation: one row per error category (validation / permission / conflict / not_found) — do NOT demand per-EC row.

```yaml
- id: CR-054
  name: "i18n-per-feature-backend"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-055 responsive-coverage

Every user-facing feature has a Responsive Behavior sub-section. Web: layout changes for ≥ mobile + desktop breakpoints. TUI: terminal width/height constraints and layout adaptations.

```yaml
- id: CR-055
  name: "responsive-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-056 navigation-consistency

Every screen/view in journey touchpoints has a route in `architecture/navigation.md`. Route params match feature requirements. Breadcrumb strategy is defined.

```yaml
- id: CR-056
  name: "navigation-consistency"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-057 page-transition-complete

Every multi-step journey has a Page Transitions table (transition type, data prefetch, notes). Transition types are consistent with feature state machines.

```yaml
- id: CR-057
  name: "page-transition-complete"
  version: 1.0.0
  checker_type: llm
  severity: info
  conflicts_with: []
  priority: 4
```

---

## Layer 7 — Architecture Convention Completeness (llm)

### CR-060 coding-conventions-complete

`architecture/coding-conventions.md` covers: code organization / layering, naming, interface / abstraction design, dependency wiring, error handling & propagation, logging (levels, structured format, sensitive data), config access, concurrency patterns. Conventions are technology-agnostic policies, not implementation-specific patterns.

```yaml
- id: CR-060
  name: "coding-conventions-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-061 test-isolation-complete

`architecture/test-isolation.md` covers: resource isolation policy, global mutable state prohibition, file system isolation, external process cleanup, race detection requirement, test timeout defaults, worktree/directory independence, parallel test classification.

```yaml
- id: CR-061
  name: "test-isolation-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-062 dev-workflow-complete

`architecture/dev-workflow.md` covers: prerequisites (tool versions), local setup, CI pipeline gates, build matrix, release process (versioning, changelog), dependency management policy.

```yaml
- id: CR-062
  name: "dev-workflow-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-063 security-policy-complete

`architecture/security.md` covers: input validation strategy (boundary definition), secret handling, dependency vulnerability scanning, injection prevention, authn/authz enforcement, sensitive data protection.

```yaml
- id: CR-063
  name: "security-policy-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-064 backward-compat-present

`architecture/backward-compat.md` is present (or explicitly N/A for v1 with no consumers). Covers: API versioning, breaking change process, data schema evolution, configuration evolution.

```yaml
- id: CR-064
  name: "backward-compat-present"
  version: 1.0.0
  checker_type: llm
  severity: info
  conflicts_with: []
  priority: 4
```

### CR-065 git-strategy-complete

`architecture/git-strategy.md` covers: branch naming, merge strategy + enforcement, branch protection, PR conventions (size, description), commit message format, stale branch cleanup.

```yaml
- id: CR-065
  name: "git-strategy-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-066 code-review-policy-complete

`architecture/code-review.md` covers: review dimensions, approval requirements, SLA, automated vs human split, feedback severity levels. If AI agents review: self-review policy defined.

```yaml
- id: CR-066
  name: "code-review-policy-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-067 observability-requirements-complete

`architecture/observability.md` covers: mandatory logging events + required fields, health check requirements, key metrics + SLO targets, alerting rules + escalation, trace context propagation (multi-component), audit trail (if applicable).

```yaml
- id: CR-067
  name: "observability-requirements-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-068 performance-testing-complete

`architecture/performance.md` covers: regression detection policy (CI benchmarks + threshold), performance budgets per category, load testing requirements, resource consumption limits.

```yaml
- id: CR-068
  name: "performance-testing-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-069 deployment-architecture-complete

`architecture/deployment.md` covers environments, local dev setup (single-command bootstrap), environment parity, configuration management (source, secrets, validation), deployment pipeline (triggers, strategy, rollback, smoke tests), environment isolation (ports, DBs), data migration (if applicable), IaC requirements (if applicable).

```yaml
- id: CR-069
  name: "deployment-architecture-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-070 ai-agent-config-complete

`architecture/ai-agent-config.md` covers: which agent instruction files to maintain (CLAUDE.md, AGENTS.md), structure policy (concise index vs monolithic — must be index), convention reference strategy (reference not duplicate), content policy, maintenance policy, multi-agent coordination (if applicable), context budget prioritization.

```yaml
- id: CR-070
  name: "ai-agent-config-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-071 dev-infrastructure-feature

A Development Infrastructure feature exists (F-### with P0, Phase 1, no journey dependency). Its deliverables map to each convention section in `architecture/` (linter config, CI pipeline, pre-commit hooks, test helpers, security scanning, AI agent instruction files). Technology-agnostic at PRD level — concrete tool choices belong to system-design.

```yaml
- id: CR-071
  name: "dev-infrastructure-feature"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-072 deployment-infrastructure-feature

If `architecture/deployment.md` defines environments, a Deployment Infrastructure feature exists with deliverables for each deployment aspect (env setup, config templates, migration tooling, CD pipeline, isolation config). P0, Phase 1.

```yaml
- id: CR-072
  name: "deployment-infrastructure-feature"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 8 — Prototypes (llm, skip if no prototypes)

### CR-080 prototype-spec-alignment

Every state in a feature's Interaction State Machine corresponds to a prototype screenshot/snapshot under `prototypes/screenshots/F-*/`. No undocumented states visible in prototypes that aren't in the state machine.

```yaml
- id: CR-080
  name: "prototype-spec-alignment"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-081 prototype-feedback-incorporated

Every prototype has evidence of user validation (confirmation date in Prototype Reference). Feedback is categorized (spec change / token change / prototype-only) and incorporated — spec changes reflected in feature files, token changes reflected in `architecture/design-tokens.md`.

```yaml
- id: CR-081
  name: "prototype-feedback-incorporated"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-082 prototype-archival

Prototype source code exists under `prototypes/src/F-*/`; key state screenshots / snapshots exist under `prototypes/screenshots/F-*/`; every user-facing feature's Prototype Reference section has path and confirmation date populated.

```yaml
- id: CR-082
  name: "prototype-archival"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 9 — Notifications & Privacy (llm, skip when N/A)

### CR-090 notification-spec

Every feature triggering user notifications has a Notifications section (channel, recipient, content summary, user control). Features without notifications correctly omit the section.

```yaml
- id: CR-090
  name: "notification-spec"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-091 privacy-section-present

Privacy & Compliance section is present in README (or explicitly N/A). Personal data entities identified in `architecture/data-model.md`. User rights stated if regulated (GDPR / CCPA / etc.).

```yaml
- id: CR-091
  name: "privacy-section-present"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

### CR-092 authorization-model-defined

`architecture/auth-model.md` is present (or explicitly N/A for single-role products). Every feature with access restrictions has a Permission line in Context. Authorization model lists roles, scopes, defaults.

```yaml
- id: CR-092
  name: "authorization-model-defined"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

---

## Layer 10 — Ambiguity (llm)

### CR-100 no-ambiguity

No TBD / TODO / vague descriptions remain. No sentences that could be interpreted two ways. Where ambiguity is intentional (phrased as "user preference"), phrase explicitly.

```yaml
- id: CR-100
  name: "no-ambiguity"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-101 mvp-discipline

README Scope section lists out-of-scope items explicitly. Features listed as P0 serve the core happy path only — tangential polish is P1 or later.

```yaml
- id: CR-101
  name: "mvp-discipline"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## Layer 11 — Evolve Mode (llm, only run in new-version review)

### CR-110 evolve-change-annotation

In evolve (new-version) delta files, every modified/added file has a metadata header (Status, Baseline, Change summary). Every file's internal change points have inline tags (`[ADDED]` / `[MODIFIED]` / `[REMOVED]`). Change summary is consistent with inline tags.

```yaml
- id: CR-110
  name: "evolve-change-annotation"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

### CR-111 evolve-reference-validity

README Baseline.Predecessor path resolves to a valid old PRD directory; all `→ baseline` links in Journey / Feature / Architecture indexes resolve; Baseline field links in changed files resolve; tombstone Original links are valid.

```yaml
- id: CR-111
  name: "evolve-reference-validity"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-wikilinks.sh
  severity: error
  conflicts_with: []
  priority: 1
```

### CR-112 evolve-flatten-integrity

Running the flatten algorithm (evolve-mode doc) produces a combined view that passes the full review-criteria. New features' journey mappings exist in the flattened journey set; new features' dependencies exist in the flattened feature set; no references to deprecated items.

```yaml
- id: CR-112
  name: "evolve-flatten-integrity"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
```

---

## Layer 12 — Convergence Governance (llm, used by judge indirectly)

These criteria are NOT run against the artifact body; they are referenced by `shared/judge-subagent.md` when interpreting oscillation signals.

### CR-900 non-saturation-guard

When a finding is emitted, the reviewer has checked the saturation rules declared in the matching criterion's narrative. Persistent findings on saturation-hit dimensions are downgraded to `info` automatically by the reviewer.

```yaml
- id: CR-900
  name: "non-saturation-guard"
  version: 1.0.0
  checker_type: llm
  severity: info
  conflicts_with: []
  priority: 4
```

### CR-901 anti-oscillation

Before flagging, the reviewer consults the last two rounds' resolved issues and does NOT re-flag an issue whose resolution would reverse a previously resolved issue. If such a conflict is detected, emit a single `criterion-thrash` issue instead of a regular dimension finding; flag for HITL.

```yaml
- id: CR-901
  name: "anti-oscillation"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 2
```
