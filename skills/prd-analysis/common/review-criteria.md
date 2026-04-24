# Review Criteria — prd-analysis

Each criterion is defined below as a human-readable description followed by a YAML code block. Checker scripts extract only the YAML blocks — the prose is for human readers only. All `conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via CR-L11 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**. Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

Domain code: `S` for script CRs (`CR-S##`), `L` for LLM CRs (`CR-L##`). The target artifact is a multi-file PRD pyramid under `docs/raw/prd/YYYY-MM-DD-{product-slug}/` — leaves include `README.md` (index), `journeys/J-NNN-{slug}.md`, `features/F-NNN-{slug}.md`, `architecture.md` (index), and `architecture/*.md` topic files.

---

## Structural Criteria (Script-Type)

---

## CR-S01 pyramid-shape

The PRD artifact MUST follow the multi-level pyramid index structure: a root `README.md` index plus `journeys/`, `features/`, and `architecture/` subdirectories. `architecture.md` at root acts as the architecture index. A flat single-file PRD defeats the self-contained file principle and the per-leaf budget that coding agents rely on.

```yaml
- id: CR-S01
  name: "pyramid-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-artifact-pyramid.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S02 leaf-size-budget-300

Every leaf file (journey, feature, architecture topic) MUST NOT exceed 300 lines. Index files (`README.md`, `architecture.md`) have a 200-line soft cap. Oversized leaves indicate missing decomposition (e.g. a feature file bundling three features) and blow the coding-agent context budget.

```yaml
- id: CR-S02
  name: "leaf-size-budget-300"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-leaf-size.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S03 feature-id-format

Every feature file MUST be named `F-NNN-{kebab-slug}.md` where `NNN` is a zero-padded 3-digit integer. Every `F-NNN:` heading inside the file MUST match the filename ID. IDs MUST be unique and sequential within the artifact. Malformed IDs break cross-reference resolution and index generation.

```yaml
- id: CR-S03
  name: "feature-id-format"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-id-format.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S04 journey-id-format

Every journey file MUST be named `J-NNN-{kebab-slug}.md` where `NNN` is a zero-padded 3-digit integer. Every `J-NNN:` heading inside the file MUST match the filename ID. IDs MUST be unique and sequential within the artifact. Malformed IDs break journey-to-feature traceability.

```yaml
- id: CR-S04
  name: "journey-id-format"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-id-format.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S05 module-id-ref-valid

Any `M-NNN` module reference appearing in a feature's Dependencies section or in `architecture/*.md` MUST be a valid forward reference (module IDs are owned by system-design, not prd-analysis). The PRD MUST NOT invent module IDs without explicitly labeling them as placeholders for downstream system-design to resolve. Invalid module references create silent broken links when the PRD feeds into system-design.

```yaml
- id: CR-S05
  name: "module-id-ref-valid"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-module-refs.sh"
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-S06 kebab-slug-naming

All file slugs (after the ID prefix) MUST be kebab-case: lowercase ASCII letters, digits, and hyphens only. No underscores, spaces, camelCase, or unicode. Inconsistent slug casing breaks case-sensitive filesystem link resolution and grep-based tooling.

```yaml
- id: CR-S06
  name: "kebab-slug-naming"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-slug-naming.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S07 template-sections-present

Every leaf MUST contain the required H2 sections defined by its corresponding template in `common/templates/artifact-template.md` — feature leaves need `## Context`, `## Acceptance Criteria`, `## Edge Cases`, `## Dependencies`, `## Priority`; journey leaves need `## Persona`, `## Touchpoints`, `## Mapped Features`, `## Error & Recovery`; architecture topics need the topic-specific required sections. Missing sections defeat the self-contained guarantee.

```yaml
- id: CR-S07
  name: "template-sections-present"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-template-sections.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S08 cross-ref-integrity

Every internal reference (feature → journey, journey → feature, cross-journey-pattern → addressing feature, feature → dependency feature, README index row → file) MUST resolve to an existing ID and file. Includes checking that every feature's `Mapped Journeys` list cites journeys that list the feature back. Broken cross-references are the #1 silent-corruption mode for PRD consumers.

```yaml
- id: CR-S08
  name: "cross-ref-integrity"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-cross-refs.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

## CR-S09 artifact-nudity-no-ipc-envelopes

PRD leaves MUST NOT contain IPC HTML-comment envelopes (`<!-- metrics-footer -->`, `<!-- self-review -->`, `<!-- trace-id -->`, etc.) — these are process metadata that belong exclusively under `.review/`. Any HTML comment matching the envelope patterns in an artifact leaf is a hard-constraint violation per guide §3.9.

```yaml
- id: CR-S09
  name: "artifact-nudity-no-ipc-envelopes"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-artifact-nudity.sh"
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-S10 readme-index-consistency

`README.md`'s Journey Index table MUST list every file in `journeys/` exactly once; Feature Index MUST list every file in `features/` exactly once; no index row MAY reference a non-existent file. Inconsistent index tables cause downstream tools to either miss content or chase dead links.

```yaml
- id: CR-S10
  name: "readme-index-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-index-consistency.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

## CR-S11 frontmatter-required-fields

Every leaf MUST have the header metadata required by its template — `README.md` inline fields (`**Product:**`, `**Date:**`, `**Baseline:**` when evolve); feature leaves need `**Priority:**`, `**Effort:**`, `**Mapped Journeys:**` under the `# F-NNN:` heading; journey leaves need `**Persona:**`, `**Stage:**`. Missing header metadata prevents the summarizer from generating pyramid indexes.

```yaml
- id: CR-S11
  name: "frontmatter-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S12 revisions-log-monotonic

If `REVISIONS.md` exists (created after first `--revise` round) its entries MUST have monotonic `delivery_id` values with no gaps, and each entry's `affected_leaves` list MUST reference only existing files. Non-monotonic or orphan entries break the version-diff audit trail.

```yaml
- id: CR-S12
  name: "revisions-log-monotonic"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-revisions-log.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

## CR-S13 architecture-index-size-budget

`architecture.md` at the artifact root MUST be a thin index (≤80 lines) pointing at topic files under `architecture/` — it MUST NOT contain topic-level content inline. A bloated architecture.md reintroduces the flat-file anti-pattern and violates the pyramid shape.

```yaml
- id: CR-S13
  name: "architecture-index-size-budget"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-leaf-size.sh"
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-S14 wikilinks-resolve

Every markdown link of the form `[...](./path)`, `[...](../path)`, `[...](journeys/J-*.md)`, `[...](features/F-*.md)`, `[...](architecture/*.md)` MUST resolve to an existing file in the artifact. Broken wikilinks destroy the self-contained property at consume time.

```yaml
- id: CR-S14
  name: "wikilinks-resolve"
  version: 1.0.0
  checker_type: llm
  script_pending: "scripts/check-wikilinks.sh"
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-L01 self-contained-file

Each feature/journey/architecture-topic leaf MUST contain all context a coding agent needs to act on it — applicable data models, conventions, journey context, permission model — copied inline, not referenced by path. Phrases like "see architecture.md", "per shared conventions", "refer to the README" are FORBIDDEN in leaf bodies. Cross-file hyperlinks for navigation (e.g., "Related: F-003") are permitted; context-shifting references are not. Violation forces consuming agents to open multiple files, defeating the principle that motivates the pyramid shape.

```yaml
- id: CR-L01
  name: "self-contained-file"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L02 scope-discipline-prd-vs-design

PRD leaves MUST capture product-level decisions only — what, for whom, why, priority, acceptance-level behavior. They MUST NOT drift into implementation detail: specific libraries, class names, SQL schemas, code signatures, concrete module boundaries. That territory belongs to system-design. Scope drift creates premature implementation lock-in and duplicates content that will diverge on the system-design pass.

```yaml
- id: CR-L02
  name: "scope-discipline-prd-vs-design"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L03 journey-to-feature-coverage

Every feature MUST map back to at least one touchpoint in at least one journey (no orphan features); every journey touchpoint SHOULD map to at least one feature; every cross-journey pattern listed in README MUST be addressed by at least one feature (row populated in the "Addressed by Feature" column). Coverage gaps indicate either missing features or speculative features that do not serve an identified user need.

```yaml
- id: CR-L03
  name: "journey-to-feature-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L04 touchpoint-completeness

Every journey touchpoint MUST specify: stage name, screen/view, action, interaction mode (click | form | drag | keyboard | scroll | hover | swipe | voice | scan), system response, and pain point (or explicit "none"). Partial touchpoints prevent feature derivation and hide interaction-design gaps until much later in the lifecycle.

```yaml
- id: CR-L04
  name: "touchpoint-completeness"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L05 design-token-semantic-naming

Visual references in feature Interaction Design sections (colors, spacing, typography, motion) MUST use semantic token names (e.g. `color.primary.500`, `spacing.md`, `motion.duration.normal`) — not raw values (`#3B82F6`, `12px`, `200ms`). Raw values in PRD leaves hard-code design decisions that belong in `architecture/design-tokens.md` and break theming downstream.

```yaml
- id: CR-L05
  name: "design-token-semantic-naming"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L06 acceptance-criteria-testable

Every Acceptance Criterion MUST be precise enough to write a test assertion. Forbidden vague verbs: "correctly handles", "properly displays", "works as expected", "appropriately responds", "is reasonable", "is performant". Vague ACs collapse to subjective review and prevent automated verification by downstream agents.

```yaml
- id: CR-L06
  name: "acceptance-criteria-testable"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L07 priority-rationale-present

Every feature's Priority field (P0/P1/P2) MUST be accompanied by a rationale stating WHY this priority — which journey / metric / risk drives the ranking. A bare `Priority: P0` with no rationale is an unauditable judgment call and blocks the roadmap review.

```yaml
- id: CR-L07
  name: "priority-rationale-present"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L08 persona-consistency

Persona names, descriptions, and key traits MUST be consistent across every journey that cites them and every feature that references a persona (goal, permission, notification audience). Divergent persona descriptions ("Sarah the PM" vs "Sarah — product lead for mid-market") across journeys create ghost-persona proliferation.

```yaml
- id: CR-L08
  name: "persona-consistency"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L09 nfr-applicability-coverage

Non-Functional Requirement topics — performance, security, accessibility, i18n, observability, deployment — MUST each have either an `architecture/<topic>.md` file with substantive content OR an explicit "N/A because ..." declaration in `architecture.md`. Silent omission leaves downstream agents guessing about what was intentionally skipped vs. forgotten.

```yaml
- id: CR-L09
  name: "nfr-applicability-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L10 cross-journey-pattern-addressed

Every Cross-Journey Pattern row in the README (shared pain point, repeated touchpoint, common infrastructure need, persona handoff) MUST be addressed by at least one feature listed in its "Addressed by Feature" column. Un-addressed patterns indicate recurring user needs with no owner and surface as late-stage regression risk.

```yaml
- id: CR-L10
  name: "cross-journey-pattern-addressed"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L11 criteria-internally-consistent

No two criteria in this file MUST create oscillation-prone review signals per guide §13.1. In v1 all `conflicts_with` fields are `[]`; this check guards future additions and flags semantic oscillation even when the array is empty (e.g., two criteria that would force mutually exclusive rewrites of the same span).

```yaml
- id: CR-L11
  name: "criteria-internally-consistent"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```
