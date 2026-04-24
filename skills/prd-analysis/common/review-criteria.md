# Review Criteria — prd-analysis

## About

This file lists the domain-specific review criteria for prd-analysis artifacts. Each criterion is defined below as a human-readable description paragraph followed by a YAML code block. Checker scripts extract only the YAML blocks — the prose is for human readers only. All `conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via CR-L04 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**. Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

**Domain code**: `PRD` — CR IDs take the form `CR-PRD-S<NN>` (script-type) or `CR-PRD-L<NN>` (LLM-type).

**Reclassification note — PRD-S04**: The original R-005 list places `feature-files-self-contained` among structural criteria. However, mechanical pattern matching (absence of file-path cross-references) is insufficient: a feature file can satisfy every regex check yet reference data-model concepts whose definitions live exclusively in another file. Judging true self-containment requires reading and understanding content. Therefore PRD-S04 is classified as `checker_type: llm` and listed in the Semantic section as `CR-PRD-L01`. The IDs of the remaining structural criteria are unchanged (PRD-S01..S03, PRD-S05..S08); the semantic section begins at `CR-PRD-L01` (PRD-S04 reclassified), with the original R-006 entries renumbered CR-PRD-L02..CR-PRD-L06.

---

## Structural Criteria (Script-Type)

---

## CR-PRD-S01 readme-frontmatter-complete

The PRD README.md MUST contain frontmatter with at minimum the keys `title`, `product_name`, `date`, and `stakeholders`. Missing any of these keys prevents the summarizer from indexing the PRD and breaks downstream skills that rely on product-name lookup.

```yaml
- id: CR-PRD-S01
  name: "readme-frontmatter-complete"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-S02 features-have-ids

Every feature file under `features/` MUST be named with the `F-NNN-<slug>.md` pattern and MUST declare a matching `id: F-NNN` key in its frontmatter. Features without stable IDs cannot be cross-referenced in journey files or tracked across PRD versions.

```yaml
- id: CR-PRD-S02
  name: "features-have-ids"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-feature-ids.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-S03 journeys-have-ids

Every journey file under `journeys/` MUST be named with the `J-NNN-<slug>.md` pattern and MUST declare a matching `id: J-NNN` key in its frontmatter. Journeys without stable IDs cannot be back-referenced from feature specs or compared across evolve iterations.

```yaml
- id: CR-PRD-S03
  name: "journeys-have-ids"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-journey-ids.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-S05 architecture-index-matches-topic-files

The `architecture.md` index file MUST list every topic file that exists under `architecture/`, and no entry in the index MAY reference a topic file that does not exist on disk. Orphaned index entries or unlisted topic files signal a drift between the index and the actual content tree, causing confusion for downstream agents navigating the architecture section.

```yaml
- id: CR-PRD-S05
  name: "architecture-index-matches-topic-files"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-architecture-index.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PRD-S06 wikilink-targets-exist

Every `[[wikilink]]` in any PRD artifact file MUST resolve to an existing file in the same PRD directory tree. Broken wikilinks silently omit referenced content from agent context windows, producing incomplete implementations.

```yaml
- id: CR-PRD-S06
  name: "wikilink-targets-exist"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-wikilinks.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-S07 revisions-log-consistency

If `REVISIONS.md` is present, every revision entry MUST reference a valid feature or journey ID that exists in the current PRD tree, and every `--revise` session MUST have added a corresponding entry. An absent or incomplete revisions log breaks change-management auditability and makes `--evolve` baseline diffing unreliable.

```yaml
- id: CR-PRD-S07
  name: "revisions-log-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-revisions-log.sh
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-PRD-S08 leaf-size-within-limit

No single artifact leaf file MAY exceed 300 lines. Files larger than 300 lines force coding agents to load excessive context when reading a single spec, defeating the pyramid's purpose of keeping each leaf focused and independently consumable.

```yaml
- id: CR-PRD-S08
  name: "leaf-size-within-limit"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-leaf-size.sh
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-PRD-L01 feature-files-self-contained

Every feature file (`features/F-NNN-<slug>.md`) MUST be independently readable by a coding agent without opening any other file. All data-model definitions, relevant coding conventions, and journey context that the feature relies on MUST be copied inline into the feature file — not referenced by path or wikilink. A file can pass all structural checks (no file-path cross-references) yet still fail this criterion if it uses domain concepts whose definitions live exclusively in another file.

Note: This criterion was originally listed as PRD-S04 (structural/script) in R-005 but is reclassified as LLM-type because true self-containment cannot be verified mechanically — an LLM must read and comprehend the file's content to determine whether all necessary context is present.

```yaml
- id: CR-PRD-L01
  name: "feature-files-self-contained"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-L02 feature-to-journey-mapping

Every feature in `features/` MUST map to at least one journey touchpoint in `journeys/`. A feature that cannot be traced back to a user journey touchpoint has no user need justification and should not exist in the PRD. The reviewer must walk the full feature list and confirm each has a back-reference to at least one J-NNN touchpoint.

```yaml
- id: CR-PRD-L02
  name: "feature-to-journey-mapping"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-L03 mvp-discipline

The PRD MUST NOT include speculative or out-of-scope features that were not grounded in the stated problem and user personas. Features tagged as "v2", "future", or "nice-to-have" that are embedded within MVP feature files violate scope discipline and inflate implementation scope. The reviewer must identify any features that cannot be tied to a confirmed user need or that clearly belong to a future iteration.

```yaml
- id: CR-PRD-L03
  name: "mvp-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-L04 feature-boundaries-clear

No two features in `features/` MAY overlap in responsibility. Each feature MUST have a distinct, non-overlapping set of behaviors. Overlapping feature boundaries cause coding agents to implement the same logic in two separate modules, producing duplication and divergence. The reviewer must diff feature scopes pairwise for any ambiguous boundary.

```yaml
- id: CR-PRD-L04
  name: "feature-boundaries-clear"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-PRD-L05 non-functional-requirements-present

The `architecture/` section MUST contain at least one topic file that explicitly addresses non-functional requirements: performance targets, security posture, and accessibility (a11y) requirements. A PRD that specifies features without NFRs leaves implementation teams free to make arbitrary quality decisions, producing inconsistent and potentially unsafe systems.

```yaml
- id: CR-PRD-L05
  name: "non-functional-requirements-present"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-PRD-L06 cross-journey-patterns-identified

The PRD README.md MUST include a "Cross-Journey Patterns" section that names recurring themes observed across multiple user journeys — shared pain points, common touchpoints, repeated infrastructure needs, or persona handoff points. Failing to surface cross-journey patterns means shared infrastructure is not recognized as such and gets built redundantly per feature.

```yaml
- id: CR-PRD-L06
  name: "cross-journey-patterns-identified"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```
