# Review Criteria — prd-analysis

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks — the prose is for human readers only. All
`conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via
CR-L04 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**.
Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

---

## Structural Criteria (Script-Type)

---

## CR-S01 artifact-pyramid-shape

The PRD artifact root MUST contain `README.md` at the top level plus at least the subdirectories
`journeys/`, `features/`, and `architecture/`. Each of those subdirectories MUST contain at least
one `.md` leaf. A flat or empty artifact directory means the planner or writer failed to produce
the expected pyramid.

```yaml
- id: CR-S01
  name: "artifact-pyramid-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-artifact-pyramid.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

---

## CR-S02 leaf-size-cap

Every `.md` leaf under `journeys/`, `features/`, and `architecture/` MUST NOT exceed 300 lines.
`README.md` and `architecture.md` (both are indexes) have a 200-line soft cap (warning, not
error). Oversized leaves indicate missing decomposition — a feature bundling multiple concerns or
an architecture topic mixing policy and implementation detail.

```yaml
- id: CR-S02
  name: "leaf-size-cap"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-artifact-pyramid.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S03 id-format-and-uniqueness

Every feature filename MUST match `F-\d{3}-[a-z0-9-]+\.md`; every journey filename MUST match
`J-\d{3}-[a-z0-9-]+\.md`. IDs MUST be unique within their respective directories. In evolve
(new-version) mode, new IDs MUST start above the baseline `max(id)` so baseline IDs are never
reused. Duplicate or malformed IDs corrupt the feature-module mapping matrix and break
traceability chains.

```yaml
- id: CR-S03
  name: "id-format-and-uniqueness"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S04 index-consistency

`README.md` MUST list every file in `journeys/` and `features/` in its index tables, and MUST NOT
list entries without a corresponding file. `architecture.md` MUST list every file in
`architecture/` with no phantom entries. An index that diverges from the file system breaks the
self-contained pyramid and causes readers to follow dead links.

```yaml
- id: CR-S04
  name: "index-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-index-consistency.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-S05 self-contained-discipline-headers

Every feature leaf MUST contain the section headers `## Data Models`, `## Conventions`, and
`## Journey Context` (case-insensitive match). Presence of these headers is a structural proxy for
the self-contained discipline — a feature leaf missing any of these headers has almost certainly
not inlined the required context. Semantic completeness of the content is checked by CR-L04.

```yaml
- id: CR-S05
  name: "self-contained-discipline-headers"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S06 no-todo-markers

No leaf file MUST contain the tokens `TODO`, `TBD`, `FIXME`, `[placeholder]`, or `<fill in>`
(case-insensitive). These tokens indicate incomplete authoring and will cause downstream coding
agents to block on unresolved decisions.

```yaml
- id: CR-S06
  name: "no-todo-markers"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-S07 changelog-consistency

If `REVISIONS.md` exists, each entry MUST have a `delivery_id`, `change_summary`, and
`affected_leaves` field. `delivery_id` values MUST be monotonically increasing with no gaps.
An inconsistent revision history breaks the version chain and makes evolve-mode predecessor
linking unreliable.

```yaml
- id: CR-S07
  name: "changelog-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-changelog-consistency.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-S08 criteria-yaml-shape

Every criterion entry in `common/review-criteria.md` MUST have the fields: `id`, `name`,
`version`, `checker_type`, `severity`. `checker_type` MUST be one of `script`, `llm`, or
`hybrid`. Malformed criteria are silently skipped by `run-checkers.sh`, producing false-green
review rounds.

```yaml
- id: CR-S08
  name: "criteria-yaml-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-criteria-yaml.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-L01 scope-discipline

The PRD MUST capture product-level decisions only: user journeys, features, acceptance criteria,
data models at entity level, architecture policies. It MUST NOT contain implementation details that
belong in system-design: module decomposition, specific library choices, SQL DDL beyond field
types, API route paths, or deployment topology. A PRD with implementation leakage produces
system-design duplication and confused traceability.

```yaml
- id: CR-L01
  name: "scope-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L02 journey-feature-coverage

Every journey touchpoint listed in a `journeys/J-NNN-*.md` file MUST be addressed by at least one
feature in `features/`. Every feature MUST trace back to at least one touchpoint (no orphan
features). Cross-journey patterns declared in `README.md` MUST each be addressed by at least one
feature. Gaps in this bipartite mapping mean user pain points are unresolved or features exist
with no user motivation.

```yaml
- id: CR-L02
  name: "journey-feature-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-L03 cross-journey-pattern-resolution

Each cross-journey pattern documented in the `README.md` Cross-Journey Patterns section MUST be
explicitly addressed by at least one feature. The addressing feature MUST reference the pattern by
name in its Journey Context section. An unaddressed pattern signals a systemic product gap that
will surface as repeated system-design complications.

```yaml
- id: CR-L03
  name: "cross-journey-pattern-resolution"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-L04 self-contained-readability

A coding agent reading ONE feature leaf MUST be able to implement the feature without opening any
other file. The feature leaf MUST contain: relevant data models copied inline (not referenced),
applicable coding conventions copied from `architecture/*.md` inline (not "see conventions file"),
permission model, and the specific journey touchpoints the feature addresses. Saturation rule:
once all entity fields, constraints, and relevant conventions are present inline, do NOT demand
deeper inlining of entities already described at JSON-schema depth.

```yaml
- id: CR-L04
  name: "self-contained-readability"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L05 mvp-discipline

Features marked `must-have` or `P0` MUST genuinely belong on the critical path for a minimum
viable product. Features that are "nice to have" or can be deferred without breaking core user
journeys MUST be placed in the roadmap (P1 or later) and MUST NOT be silently scoped into Phase 1.
The `README.md` Scope section MUST explicitly list what is out of scope for the current version.
Scope creep under `must-have` labels overloads Phase 1 and defeats incremental delivery.

```yaml
- id: CR-L05
  name: "mvp-discipline"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L06 ambiguity-elimination

No acceptance criterion, requirement statement, or data-model constraint MUST be interpretable in
two or more ways. Forbidden vague verbs: "correctly handles", "properly displays", "works as
expected", "appropriately responds". Each acceptance criterion MUST be specific enough to write a
deterministic test assertion. Where intentional flexibility is desired, phrase it explicitly (e.g.,
"user may choose any of: A, B, C").

```yaml
- id: CR-L06
  name: "ambiguity-elimination"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L07 evidence-source-stated

Every major product decision — Goals, Feature priority, Target metrics — MUST trace to an evidence
source (user research, analytics data, competitive analysis, stakeholder feedback) OR MUST be
explicitly labeled `[Assumption]` with a stated confidence level. Assumption-heavy features MUST
be flagged as validation risks in the README Risks table. A PRD built entirely on unlabeled
assumptions creates invisible validation debt.

```yaml
- id: CR-L07
  name: "evidence-source-stated"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-L08 risk-mitigation-completeness

Every risk rated High-likelihood OR High-impact in the README Risks table MUST have a stated
mitigation strategy. Features affected by a high-rated risk MUST acknowledge the risk in their
Risks & Mitigations section. If the product handles personal data, at least one compliance or
privacy risk MUST be listed regardless of likelihood and impact ratings.

```yaml
- id: CR-L08
  name: "risk-mitigation-completeness"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-L09 priority-phase-alignment

Every P0 feature MUST serve a core journey happy-path touchpoint. Roadmap phases MUST align with
priority labels (P0 → Phase 1, P1 → Phase 2, P2 → Phase 3). Feature dependency graphs MUST NOT
contradict phase ordering — no P0 feature may depend on a P1 or later feature. Misaligned phase
ordering forces implementation teams to cherry-pick dependencies, destabilizing delivery planning.

```yaml
- id: CR-L09
  name: "priority-phase-alignment"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-L10 testability-ac-observable

Every Acceptance Criterion MUST be precise enough to write a test assertion with a deterministic
pass/fail outcome. Forbidden vague formulations: "should handle gracefully", "displays
appropriately", "works correctly". Every Edge Case MUST use Given/When/Then format and MUST map
to an automatable test specification. A criterion that cannot be turned into a test is not a
requirement — it is a wish.

```yaml
- id: CR-L10
  name: "testability-ac-observable"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L11 non-behavioral-criterion-present

Every feature with non-trivial state management or external integration MUST have at least one
non-behavioral (non-functional) acceptance criterion covering performance, concurrency, resource
limits, or security. Saturation rule: one non-behavioral criterion per distinct operational
characteristic (e.g., read path vs. write path) is sufficient — do NOT demand per-endpoint p95
targets. A feature with only behavioral criteria leaves operational readiness undefined.

```yaml
- id: CR-L11
  name: "non-behavioral-criterion-present"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L12 authorization-edge-case

Every feature that declares a `Permission:` line in its Context section MUST have at least one
Edge Case testing unauthorized access. Saturation rule: one unauthorized-access edge case per
permission boundary (role × scope) is sufficient — do NOT enumerate every role × workspace × org
combination. A feature with permissions but no unauthorized-access edge case leaves the access
control contract unverifiable.

```yaml
- id: CR-L12
  name: "authorization-edge-case"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L13 architecture-convention-completeness

The `architecture/` directory MUST contain leaves covering at minimum: `tech-stack.md`,
`data-model.md`, `coding-conventions.md`, and `security.md`. Each leaf MUST cover the topics
described in the domain glossary for that topic type. A PRD that references architecture topics
without defining them produces self-contained feature leaves that inline incomplete or contradictory
conventions.

```yaml
- id: CR-L13
  name: "architecture-convention-completeness"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-L14 metrics-have-verification

Every Goal declared in `README.md` MUST have a `baseline` and a `measurement method`. Every
Journey Metric in `journeys/J-NNN-*.md` MUST have a Verification entry stating whether the
measurement is manual, automated, or monitoring-based, plus explicit pass/fail criteria. Goals and
metrics without measurement methods are aspirations, not requirements.

```yaml
- id: CR-L14
  name: "metrics-have-verification"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L15 cross-feature-integration-coverage

Features that declare `Dependencies: depends-on <F-NNN>` MUST have at least one integration-level
Acceptance Criterion referencing the upstream feature's output by name (e.g., "Given F-003 has
produced X, when F-005 consumes it, then Y"). Journey Error & Recovery Paths MUST each map to at
least one feature Edge Case or Acceptance Criterion. Gaps in integration coverage produce
incomplete handoff contracts between feature implementors.

```yaml
- id: CR-L15
  name: "cross-feature-integration-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-L16 evolve-change-annotation

In evolve (new-version) mode: every modified or added leaf file MUST have a metadata header with
`Status`, `Baseline`, and `Change summary`. Every internal change point inside a modified leaf
MUST have an inline tag (`[ADDED]`, `[MODIFIED]`, or `[REMOVED]`). The Change summary MUST be
consistent with the inline tags. Deprecated features MUST use tombstone files rather than silent
deletion. Without annotations the delta is invisible to reviewers and breaks the version chain.
Skip this criterion during initial creation (FromScratch) review.

```yaml
- id: CR-L16
  name: "evolve-change-annotation"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
