# Review Criteria — prd-analysis

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks — the prose is for human readers only. All
`conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via
CR-PP22 (LLM check) rather than hard-coded exclusions.

Criteria are partitioned per the dual-criteria from
[~/Documents/mind/raw/guide/生成式skill的审查设计.md](../../../../Documents/mind/raw/guide/生成式skill的审查设计.md) §1.3:

- **Formal (script-type)** — mechanically expressible AND the result does not imply a correctness
  judgment. Enforced by `scripts/check-prd-formal.sh` (or another script in `scripts/`). Failure
  is a **necessary condition** preventing convergence (guide §5). LLM reviewers MUST NOT also
  apply these — they were already enforced before any LLM dispatch (guide §6 fast-failure).
- **Substantive (LLM-type)** — content correctness, semantic coherence, cross-leaf
  consistency. Applied by cross-reviewer / adversarial-reviewer. Convergence requires
  substantive PASS in addition to formal PASS.

Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

---

## Formal Criteria (Script-Type)

These criteria are evaluated mechanically by `scripts/check-prd-formal.sh`. The
script emits one issue per finding in the schema documented in
`common/issue-schema.md`.

---

## CR-PP01 prd-directory-structure

A generated PRD bundle MUST have the canonical directory structure: `README.md` at root,
`journeys/` sub-directory with at least one `J-NNN.md` file, `features/` sub-directory with at
least one `F-NNN-slug.md` file, and `architecture/` sub-directory. Missing any top-level component
means the PRD is incomplete and downstream system-design cannot consume it.

```yaml
- id: CR-PP01
  name: "prd-directory-structure"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: critical
  conflicts_with: []
  priority: 1
```

---

## CR-PP02 id-format-monotonic

All Feature IDs MUST follow the format `F-NNN` (zero-padded, starting at F-001, sequential with no
gaps). All Journey IDs MUST follow `J-NNN`. The README feature index and journey index MUST list
IDs in ascending order with no duplicates. Broken ID sequences break the stable-ID contract that
evolve-mode depends on for tombstone and diff-aware generation.

```yaml
- id: CR-PP02
  name: "id-format-monotonic"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-PP03 readme-index-complete

The PRD `README.md` MUST have a journey index and a feature index. Every `J-NNN.md` file in
`journeys/` MUST have a corresponding entry in the journey index, and every `F-NNN-slug.md` in
`features/` MUST have a corresponding entry in the feature index. Orphan leaves (files not listed
in README) or stale index entries (listed but no file) cause review-mode and system-design to
produce incomplete output.

```yaml
- id: CR-PP03
  name: "readme-index-complete"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-PP04 no-tbd-remaining

No leaf file or README MUST contain literal `TBD`, `TODO`, or `FIXME` markers. Vague placeholder
text in Acceptance Criteria or Edge Cases blocks downstream test authoring and makes the PRD
unsuitable for coding agents.

```yaml
- id: CR-PP04
  name: "no-tbd-remaining"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-PP05 version-chain-integrity

If `REVISIONS.md` exists in the PRD directory, every `Previous Version` path listed MUST resolve
to an actual directory on disk. The Summary of Changes MUST be present for each entry. If a
Baseline section exists (evolve-mode PRD), the Predecessor path MUST resolve and all `→ baseline`
links in the feature/journey indexes MUST point to valid files. Broken version chains cause
`--evolve` and `--revise` to silently skip prior context.

```yaml
- id: CR-PP05
  name: "version-chain-integrity"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-FM01 frontmatter-required-fields

Every leaf file (`features/F-NNN-*.md`, `journeys/J-NNN-*.md`) MUST carry a frontmatter block
with the required fields. For features: `id`, `title`, `status`. For journeys: `id`, `title`,
`persona`. The frontmatter is the machine-truth source for IDs and metadata; missing fields
break downstream consumption (system-design + autoforge both index features by frontmatter ID).

```yaml
- id: CR-FM01
  name: "frontmatter-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-IS01 issue-schema-conformance

Every issue file under `<artifact-root>/.review/round-<N>/issues/` MUST conform to the on-disk
schema defined in `common/issue-schema.md`. This is review-artifact self-closure (guide §10):
the audit pipeline produces artifacts (issue files) which are themselves audited by the same
formal-review machinery. Without this gate, schema drift in LLM-emitted issues would corrupt
state-machine transitions, ratio signals, and cross-round fingerprinting.

```yaml
- id: CR-IS01
  name: "issue-schema-conformance"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-issue.sh
  severity: error
  applies_to: [".review/round-*/issues/*.md"]
  conflicts_with: []
  priority: 2
```

---

## Audit-Artifact Schema Criteria (CR-CL / CR-PL / CR-SR / CR-RO / CR-RI / CR-VD / CR-VS)

These criteria audit LLM-produced artifacts of the review pipeline itself
(guide §10 self-closure). Each pairs with a per-artifact check script.

```yaml
- id: CR-CL01
  name: "clarification-required-keys-present"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-clarification.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-CL02
  name: "clarification-flat-keys-first"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-clarification.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-PL01
  name: "plan-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-plan.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-PL02
  name: "plan-add-modify-entry-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-plan.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR01
  name: "self-review-required-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR02
  name: "self-review-fail-blocker-scope"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR03
  name: "self-review-status-fail-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RO01
  name: "reviewer-output-json-valid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-reviewer-output.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RO02
  name: "reviewer-output-issue-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-reviewer-output.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RI01
  name: "round-index-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-round-index.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RI02
  name: "round-index-state-counts-sum-to-total"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-round-index.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VD01
  name: "verdict-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-verdict.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VD02
  name: "verdict-next-action-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-verdict.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VS01
  name: "version-required-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-version.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VS02
  name: "version-converged-only"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-version.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## Substantive Criteria (LLM-Type)

---

## CR-PP06 traceability-chain

The Goal → Journey → Touchpoint → User Story → Feature → Analytics traceability chain MUST be
complete. Every persona MUST have at least one journey (happy path). Every touchpoint and pain
point listed in a journey MUST map to at least one Feature. Every Feature MUST reference at least
one journey touchpoint. No orphan features are permitted. Cross-journey patterns MUST be
documented in the README and each pattern MUST be addressed by at least one Feature (or the
section explicitly omitted for single-journey products). Broken traceability means coding agents
cannot verify completeness of their implementation against requirements.

```yaml
- id: CR-PP06
  name: "traceability-chain"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

---

## CR-PP07 evidence-present

Every major product decision in a Feature file MUST trace to an evidence source: user research,
data, competitive analysis, or an explicit assumption label. Assumption-heavy features MUST be
flagged as validation risks. Features with no evidence attribution and no assumption label are
undiscoverable risks that block informed prioritization.

```yaml
- id: CR-PP07
  name: "evidence-present"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP08 competitive-context

The PRD README MUST contain a Competitive Landscape section (or explicitly mark it N/A for
internal tools). Differentiation MUST be stated. Table-stakes features MUST be identified.
Missing competitive context leaves the PRD unable to justify scope and roadmap phase decisions.

```yaml
- id: CR-PP08
  name: "competitive-context"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP09 metrics-complete

Every Goal in the README MUST have a baseline and a measurement method. Every measurement MUST map
to at least one Feature's Analytics event. Every Journey Metric MUST have a Verification entry
(manual/automated/monitoring with pass/fail criteria). Goals without measurable outcomes cannot be
evaluated at launch.

```yaml
- id: CR-PP09
  name: "metrics-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP10 risks-mitigated

Every high-likelihood or high-impact risk in the PRD MUST have a mitigation strategy. Affected
Features MUST acknowledge the risk. Compliance and privacy risks MUST be covered if applicable.
Unmitigated risks leave the product launch with unknown critical blockers.

```yaml
- id: CR-PP10
  name: "risks-mitigated"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP11 priority-roadmap-alignment

Every P0 Feature MUST serve a core journey happy-path touchpoint. Roadmap phases MUST align with
Priority ordering (P0→Phase 1, P1→Phase 2). Feature dependencies MUST not contradict phase
ordering (a P1 feature MUST NOT depend on a feature scheduled for Phase 2 or later without
explicit justification). Misaligned priorities cause sprint planning failures.

```yaml
- id: CR-PP11
  name: "priority-roadmap-alignment"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP12 authorization-model

The PRD MUST define an authorization model (or explicitly state N/A). Every Feature with access
restrictions MUST have a Permission line in its Context section. Missing authorization definitions
leave security holes that system-design cannot close without backtracking to requirements.

```yaml
- id: CR-PP12
  name: "authorization-model"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP13 privacy-compliance

The PRD README MUST have a Privacy & Compliance section (or explicitly N/A). Personal data
entities MUST be identified. User rights MUST be stated if a regulated market is targeted. Missing
privacy coverage creates legal exposure discovered only after implementation.

```yaml
- id: CR-PP13
  name: "privacy-compliance"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP14 self-containment

Each Feature file MUST be independently readable and actionable. All required context — data
models, applicable conventions, journey context — MUST be copied inline in the feature file. A
coding agent implementing a feature MUST NOT need to open a second file. Cross-references to
architecture.md or journey files are FORBIDDEN within feature leaves; inline-copy the relevant
excerpt instead.

```yaml
- id: CR-PP14
  name: "self-containment"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-PP15F acceptance-criteria-format (formal)

Every feature file MUST contain a `## Acceptance Criteria` section with at least one
Given/When/Then block (all three keywords present). This is the mechanical format check;
the substantive testability assessment is CR-PP15 (below).

```yaml
- id: CR-PP15F
  name: "acceptance-criteria-format"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-prd-formal.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-PP15 acceptance-criteria-testable (substantive)

In addition to the formal BDD format gate (CR-PP15F), every Acceptance Criterion in a Feature
file MUST be precise enough to write a test assertion. Vague verbs — "correctly handles",
"properly displays", "works as expected" — are FORBIDDEN. Every AC MUST express observable
behavior (what the system returns, emits, renders, or stores). Every Edge Case MUST have a
Given/When/Then form that maps to an automated test. Every Feature with non-trivial state or
integration MUST have at least one non-behavioral criterion (performance, concurrency, or
resource limit). Every Feature with a Permission line MUST have at least one edge case testing
unauthorized access.

```yaml
- id: CR-PP15
  name: "acceptance-criteria-testable"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-PP16 e2e-test-scenarios

Every multi-touchpoint Journey file MUST have an E2E Test Scenarios table covering happy,
alternative, and error paths with features exercised and expected outcomes. Every Journey's Error &
Recovery Paths MUST map to at least one Feature's Edge Case or Acceptance Criterion. Cross-feature
dependencies MUST have at least one integration-level acceptance criterion in the downstream
Feature. Missing E2E scenarios mean system-design cannot produce an integration test plan.

```yaml
- id: CR-PP16
  name: "e2e-test-scenarios"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP17 test-data-requirements

Every Feature with non-trivial test setup MUST have a Test Data Requirements section specifying
fixtures, boundary values, preconditions, and external stubs at a level sufficient for a reader to
set up the test without reading implementation code. Prescribing fixture JSON shape, seed-file
paths, or generator API signatures is FORBIDDEN (over-specification creates maintenance debt).

```yaml
- id: CR-PP17
  name: "test-data-requirements"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP18 interaction-design-complete

Every user-facing Feature MUST have an Interaction Design section with: Screen & Layout,
Component Contracts, Interaction State Machine, Accessibility, Internationalization, and Responsive
Behavior. Screen/View names MUST be consistent between journey touchpoints and feature files. No
user-facing feature MAY have Interaction Design omitted. Missing interaction design produces
inconsistent UI and blocks frontend implementation.

```yaml
- id: CR-PP18
  name: "interaction-design-complete"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-PP19 form-specification

Every Feature with user input MUST have a Form Specification sub-section with: field definitions
(name, type, validation rules, error messages, conditional visibility, dependencies), submission
behavior (success/error handling), and multi-step form step sequencing. Features without forms may
omit this section. Incomplete form specs generate inconsistent validation UX across implementations.

```yaml
- id: CR-PP19
  name: "form-specification"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP20 micro-interactions-motion

Every user-facing Feature with key interactions MUST have a Micro-Interactions & Motion
sub-section. Every animation MUST reference duration and easing tokens by name (raw millisecond
values and raw cubic-bezier expressions are FORBIDDEN). Every animation MUST have a stated purpose.
Features without animations may omit this section. Animation token references without meaning
cannot be validated by design review.

```yaml
- id: CR-PP20
  name: "micro-interactions-motion"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP21 journey-interaction-modes

Every journey touchpoint MUST have an Interaction Mode specified (click, form, drag, swipe,
keyboard, scroll, hover, voice, scan, or equivalent). Interaction modes MUST be consistent with
the corresponding feature's component contracts and state machines. Touchpoints without interaction
modes block interaction-design consistency checks.

```yaml
- id: CR-PP21
  name: "journey-interaction-modes"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP22 oscillation-detection

No review finding MUST contradict an applied revision recorded in `REVISIONS.md` for the same
dimension in the prior 2–3 passes. If a finding demands adding content that a prior REVISIONS.md
Theme line records as removed (or removing content that was added), a single `[Critical]
Convergence conflict` MUST be emitted citing the conflicting entry — NOT the per-dimension
finding. This criterion is the primary guard against oscillation-induced infinite loops.

```yaml
- id: CR-PP22
  name: "oscillation-detection"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-PP23 design-token-completeness

All applicable token categories MUST be defined in `architecture/design-tokens.md` (or equivalent
architecture topic file). For web products: colors, typography, spacing, breakpoints, motion,
z-index. For TUI products: terminal colors, monospace typography, character-unit spacing, borders.
No raw values (hex, rem, ms, px) MUST appear in Feature Interaction Design sections — all visual
references MUST use semantic token names. Missing token definitions cause inconsistent styling
across features.

```yaml
- id: CR-PP23
  name: "design-token-completeness"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP24 state-machine-integrity

Every Interaction State Machine in a Feature file MUST have no dead states (every state has at
least one exit transition). Every transition MUST specify the system feedback (e.g. toast, loader,
error message). Loading states MUST have both a success exit and an error exit. Dead states and
undefined feedback make front-end engineers guess at transition behavior.

```yaml
- id: CR-PP24
  name: "state-machine-integrity"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP25 frontend-stack-consistency

Every user-facing Feature's Interaction Design MUST use patterns compatible with the Phase 3
Frontend Stack choices recorded in architecture. State machines MUST align with the chosen state
management library. Form specifications MUST use chosen form library conventions. Component
contracts MUST use chosen framework conventions. Deviating from the stack without justification
forces refactoring during implementation.

```yaml
- id: CR-PP25
  name: "frontend-stack-consistency"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP26 component-contract-consistency

Every component referenced in a Feature's Interaction Design MUST have a Component Contract with
props, events, and slots defined. Event names MUST follow a consistent convention across all
features. For features sharing a screen, component nesting and slot-filling rules MUST be explicit.
Inconsistent component contracts produce broken composition at integration time.

```yaml
- id: CR-PP26
  name: "component-contract-consistency"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP27 cross-feature-event-flow

For Features with declared dependencies, event names in state machine side effects MUST match
event names consumed by dependent features' state machines. Event payloads in Component Contract
Events MUST match consumer expectations. Integration acceptance criteria (Testability f) MUST
reference exact event names. Mismatched event names cause silent integration failures invisible in
unit tests.

```yaml
- id: CR-PP27
  name: "cross-feature-event-flow"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP28 accessibility-baseline

The `architecture/accessibility.md` (or equivalent architecture topic file) MUST have an
Accessibility Baseline section that is complete: WCAG target level, keyboard navigation policy,
screen reader support, focus management, color contrast, reduced motion, touch targets, error
identification. Every user-facing Feature MUST have an Accessibility sub-section that references or
extends the baseline. Features without this section silently ship accessibility regressions.

```yaml
- id: CR-PP28
  name: "accessibility-baseline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP29 accessibility-per-feature

Every user-facing Feature MUST have an Accessibility sub-section. Keyboard navigation MUST cover
all interactive elements. ARIA roles MUST be specified for dynamic content. Focus management MUST
be defined for all modals, drawers, and overlays. Missing per-feature accessibility blocks
systematic WCAG auditing.

```yaml
- id: CR-PP29
  name: "accessibility-per-feature"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP30 i18n-baseline

The `architecture/i18n.md` (or equivalent architecture topic file) MUST be present and complete.
For products with a user interface: text externalization convention, key naming convention, content
direction, RTL support. For products with a multi-locale backend: API locale resolution strategy,
error/validation message localization approach, notification content localization, timezone
handling. Shared baseline: supported languages, default language, date/time format, number format,
pluralization rules. Missing baseline means each feature author independently guesses at i18n
conventions.

```yaml
- id: CR-PP30
  name: "i18n-baseline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP31 i18n-per-feature-frontend

Every user-facing Feature MUST have a frontend Internationalization sub-section. All user-visible
text MUST have an i18n key (hardcoded strings in component contracts or form specs are FORBIDDEN).
Format rules MUST be defined for dates, numbers, and plurals. The saturation condition: key naming
convention is stated — do NOT audit individual string keys.

```yaml
- id: CR-PP31
  name: "i18n-per-feature-frontend"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP32 i18n-per-feature-backend

Every backend Feature that returns user-visible text (API error messages, validation messages,
notification content, email templates) MUST have a Backend Internationalization sub-section
specifying which messages are locale-dependent and how locale is determined (Accept-Language, user
preference, default). Table coverage saturation: one row per error category (validation,
permission, conflict, not_found) is sufficient — do NOT require a row per individual AC or EC.

```yaml
- id: CR-PP32
  name: "i18n-per-feature-backend"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP33 navigation-consistency

Every Screen/View named in journey touchpoints MUST have a corresponding route entry in the
`architecture/navigation.md` (or equivalent architecture topic). Route params MUST match feature
requirements. A breadcrumb strategy MUST be defined. Screens without routes cause 404s and
back-navigation breakage.

```yaml
- id: CR-PP33
  name: "navigation-consistency"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP34 page-transitions-complete

Every Journey with multi-step flows MUST have a Page Transitions table with: transition type
(navigate push/replace, modal, drawer, back), data prefetch strategy, and notes. Transition types
MUST be consistent with the corresponding feature's state machines. Missing transition tables
produce janky UX and inconsistent loading state handling across features.

```yaml
- id: CR-PP34
  name: "page-transitions-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP35 prototype-spec-alignment

(Applies only when `prototypes/` directory exists.) Every state in a Feature's Interaction State
Machine MUST have a corresponding prototype screenshot or snapshot. No states visible in prototypes
MUST be absent from the state machine. Divergence between prototype states and state machine
indicates unimplemented or undocumented design decisions.

```yaml
- id: CR-PP35
  name: "prototype-spec-alignment"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP36 prototype-feedback-incorporated

(Applies only when `prototypes/` directory exists.) Every prototype MUST have evidence of user
validation (confirmation date in Prototype Reference). Feedback MUST be categorized (spec change /
token change / prototype-only) and incorporated — spec changes reflected in Feature files, token
changes reflected in architecture. Prototypes without confirmed user validation are design
hypotheses, not validated requirements.

```yaml
- id: CR-PP36
  name: "prototype-feedback-incorporated"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP37 prototype-archival-complete

(Applies only when `prototypes/` directory exists.) Prototype source code MUST exist in
`{prd-dir}/prototypes/src/`. Key state screenshots or snapshots MUST exist in
`{prd-dir}/prototypes/screenshots/`. Every user-facing Feature's Prototype Reference section MUST
have path and confirmation date filled. Missing archival means prototypes cannot be referenced
in future PRD iterations.

```yaml
- id: CR-PP37
  name: "prototype-archival-complete"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP38 responsive-coverage

Every user-facing Feature MUST have a Responsive Behavior sub-section. For web products: layout
changes MUST be described for at least mobile (< sm) and desktop (>= lg) breakpoints. For TUI
products: terminal width/height constraints and layout adaptations MUST be described (e.g. sidebar
collapse threshold, minimum terminal size). Missing responsive coverage produces broken layouts on
non-standard viewports.

```yaml
- id: CR-PP38
  name: "responsive-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PP39 notifications-defined

Every Feature that triggers user notifications MUST have a Notifications section specifying:
channel, recipient, content summary, and user control options. Features without notifications MUST
correctly omit the section (not leave it blank). Undefined notification behavior causes inconsistent
push/email delivery across features.

```yaml
- id: CR-PP39
  name: "notifications-defined"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PP40 coding-conventions-complete

The `architecture/coding-conventions.md` (or equivalent architecture topic) MUST be present and
complete. Required sections: code organization/layering policy, naming conventions,
interface/abstraction design policy, dependency wiring policy, error handling & propagation policy,
logging conventions (levels, structured format, sensitive data), configuration access policy,
concurrency patterns. If UI exists: component structure, state management patterns, styling
conventions. All conventions MUST be technology-agnostic policies — implementation-specific
patterns are FORBIDDEN in architecture.

```yaml
- id: CR-PP40
  name: "coding-conventions-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP41 test-isolation-complete

The `architecture/test-isolation.md` (or equivalent architecture topic) MUST be present and
complete: resource isolation policy (temp dirs, random ports, isolated DBs), global mutable state
prohibition, file system isolation, external process cleanup, race detection requirement in CI,
test timeout defaults, worktree/directory independence, parallel test classification. Per-feature
Test Data Requirements MUST reference these policies where applicable. Missing test isolation
policy causes flaky tests in CI.

```yaml
- id: CR-PP41
  name: "test-isolation-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP42 development-workflow-complete

The `architecture/development-workflow.md` (or equivalent architecture topic) MUST be present and
complete: prerequisites (language/tool versions), local setup instructions, CI pipeline gates (what
checks run, what blocks merge), build matrix (supported platforms), release process (versioning
scheme, changelog), dependency management policy. Incomplete workflow documentation causes
onboarding failures and CI/CD drift.

```yaml
- id: CR-PP42
  name: "development-workflow-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP43 security-policy-complete

The `architecture/security.md` (or equivalent architecture topic) MUST be present and complete:
input validation strategy (boundary definition), secret handling rules, dependency vulnerability
scanning policy, injection prevention policy, authentication/authorization enforcement policy,
sensitive data protection. Per-feature edge cases MUST include security-relevant scenarios where
applicable. Missing security policy leaves injection and secret-leak vectors unaddressed until
pentest.

```yaml
- id: CR-PP43
  name: "security-policy-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP44 backward-compatibility

The `architecture/backward-compatibility.md` (or equivalent architecture topic) MUST be present
(or explicitly N/A for v1 with no existing consumers). Required coverage: API versioning strategy,
breaking change definition and process, data schema evolution strategy, configuration file
evolution. If marked N/A: intended future versioning strategy MUST be noted. Missing
backward-compatibility policy causes unmanaged breaking changes in future iterations.

```yaml
- id: CR-PP44
  name: "backward-compatibility"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-PP45 git-branch-strategy

The `architecture/git-strategy.md` (or equivalent architecture topic) MUST be present and complete:
branch naming convention, merge strategy and enforcement mechanism, branch protection rules, PR
conventions (size, description, one-per-feature), commit message format, stale branch cleanup.
Missing git strategy causes inconsistent repository hygiene across the engineering team.

```yaml
- id: CR-PP45
  name: "git-branch-strategy"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-PP46 code-review-policy

The `architecture/code-review-policy.md` (or equivalent architecture topic) MUST be present and
complete: review dimensions (correctness, security, tests, performance, readability), approval
requirements, review SLA, automated vs human review split, feedback severity levels. If AI agents
are reviewers: self-review policy MUST be defined. Missing code review policy leaves review
quality non-deterministic.

```yaml
- id: CR-PP46
  name: "code-review-policy"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-PP47 observability-requirements

The `architecture/observability.md` (or equivalent architecture topic) MUST be present and
distinct from tool-focused observability. Required coverage: mandatory logging events and required
fields, health check requirements, key metrics with SLO targets, alerting rules and escalation,
trace context propagation (if multi-component), audit trail requirements (if applicable). Missing
observability requirements cause production incidents with no diagnosis path.

```yaml
- id: CR-PP47
  name: "observability-requirements"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP48 performance-testing-complete

The `architecture/performance-testing.md` (or equivalent architecture topic) MUST be present and
complete: regression detection policy (CI benchmarks, threshold), performance budgets per category,
load testing requirements (scenarios, pass/fail criteria), resource consumption limits. Per-feature
non-behavioral criteria MUST reference these budgets where applicable. Missing performance budgets
cause regressions discovered in production.

```yaml
- id: CR-PP48
  name: "performance-testing-complete"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP49 dev-infra-feature-exists

A "Development Infrastructure" feature (auto-derived from architecture convention sections) MUST
exist in the PRD feature set. It MUST be tagged P0, Phase 1, with no journey dependency. Each
convention section in architecture MUST map to at least one concrete deliverable in this feature's
requirements (linter config, CI pipeline, pre-commit hooks, test helpers, security scanning, AI
agent instruction files, etc.). Missing this feature means conventions are documented but never
enforced.

```yaml
- id: CR-PP49
  name: "dev-infra-feature-exists"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP50 deployment-architecture

The `architecture/deployment.md` (or equivalent architecture topic) MUST be present and complete:
environments (purpose, users, infrastructure), local development setup (reproducibility, service
dependencies, env vars, data seeding), environment parity policy, configuration management
(source, secrets, validation, template), deployment pipeline/CD (triggers, strategy, rollback,
smoke tests), environment isolation. Data migration and IaC sections MUST be present if applicable.
A "Deployment Infrastructure" feature MUST exist (auto-derived) with deliverables for each
deployment aspect. Missing deployment architecture leaves the launch plan incomplete.

```yaml
- id: CR-PP50
  name: "deployment-architecture"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PP51 ai-agent-configuration

The `architecture/ai-agent-config.md` (or equivalent architecture topic) MUST be present and
complete: which agent instruction files to maintain (CLAUDE.md, AGENTS.md, etc.), structure policy
(concise index vs monolithic — MUST be index), convention reference strategy (reference not
duplicate), content policy (what is direct vs referenced), maintenance policy (when to update,
who is responsible), multi-agent coordination (if applicable), context budget prioritization.
Missing AI agent configuration causes coding agents to operate with incomplete conventions.

```yaml
- id: CR-PP51
  name: "ai-agent-configuration"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```
