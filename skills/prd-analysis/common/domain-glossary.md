# Domain Glossary — prd-analysis

This glossary drives automated disambiguation in `glossary-probe.sh`. The script greps each term and its aliases against `input.md`; on a hit it writes `trigger-flags.yml` with `glossary_hit: true`, which causes the orchestrator to invoke the domain-consultant before proceeding to the planner. New terms are added here as the skill matures and new ambiguity patterns are observed in production inputs.

All entries carry `disambiguation_required: true`. Terms are grouped by the ambiguity cluster — one H2 per cluster.

---

## `feature` vs `user story` vs `epic` vs `spec`

**Why disambiguate.** Users arrive with different vocabulary: "user story", "epic", "task", "spec", "ticket". In prd-analysis, a feature is specifically a `F-NNN-<slug>.md` leaf file — a self-contained spec for exactly one bounded product capability. Conflating a feature with a user story (which is finer-grained) or an epic (which is coarser) leads the planner to produce wrong granularity. A feature that is too coarse exceeds the 300-line leaf limit; one that is too fine produces redundant files that fragment the feature-to-journey mapping.

```yaml
- term: "feature"
  aliases: ["user story", "story", "spec", "feature spec", "feature file", "epic", "capability", "功能", "需求项", "feature ticket", "task spec", "product feature"]
  disambiguation_required: true
  definition: "A self-contained leaf file at features/F-NNN-<slug>.md that specifies exactly one bounded product capability. MUST inline all required context (data model fragments, coding conventions, journey back-references, acceptance criteria) so that a coding agent can implement the feature by reading only that one file. NOT a user story (too fine) or an epic (too coarse). Identified by a stable F-NNN zero-padded ID."
```

---

## `journey` vs `flow` vs `use case` vs `scenario`

**Why disambiguate.** "User flow", "use case", "scenario", and "walkthrough" are common alternatives for what prd-analysis calls a journey. A journey is specifically a `J-NNN-<slug>.md` file that pairs one persona with an ordered touchpoint sequence. Conflating a journey with a use case (which may be persona-agnostic) or a scenario (which may be a single edge-case) causes the feature-to-journey mapping matrix to be misaligned. Every feature MUST map to at least one journey touchpoint (CR-L01); if journeys are mis-scoped this invariant cannot be checked.

```yaml
- term: "journey"
  aliases: ["user journey", "user flow", "flow", "use case", "scenario", "walkthrough", "用户旅程", "用户流程", "customer journey", "end-to-end flow", "happy path"]
  disambiguation_required: true
  definition: "A leaf file at journeys/J-NNN-<slug>.md that pairs one named persona with an ordered sequence of touchpoints. Each touchpoint names a stage, screen/view, user action, interaction mode, system response, and optional pain point. Every feature must back-reference at least one touchpoint in a journey. Identified by a stable J-NNN zero-padded ID."
```

---

## `touchpoint` vs `step` vs `interaction` vs `screen`

**Why disambiguate.** Users often say "step", "screen", "interaction", or "moment" to mean a touchpoint. In prd-analysis terminology a touchpoint is the atomic unit within a journey — it is NOT the screen itself (a screen may contain multiple touchpoints) and NOT the full journey (which is an ordered sequence of touchpoints). Misidentifying the granularity makes journeys either too high-level (just screen names) or too low-level (every micro-interaction becomes its own touchpoint), both of which degrade feature derivation quality.

```yaml
- term: "touchpoint"
  aliases: ["step", "interaction step", "screen step", "moment", "interaction moment", "user step", "journey step", "action step", "接触点", "交互节点"]
  disambiguation_required: true
  definition: "The atomic unit within a journey: a single moment where a persona interacts with the system. Defined by six fields: stage name, screen/view, action, interaction mode (click/form/drag/keyboard/scroll/hover/swipe/voice/scan), system response, and optional pain point. Multiple touchpoints may occur on the same screen. Touchpoints drive feature derivation — every feature maps back to at least one touchpoint."
```

---

## `architecture topic file` vs `architecture.md` vs `design doc`

**Why disambiguate.** The prd-analysis artifact has two distinct architecture concepts that users frequently conflate: the `architecture.md` index (a 50-80 line table-of-contents that lists topic files) and the individual `architecture/<topic>.md` files (one per concern: tech-stack, data-model, coding-conventions, nfr). Treating the index as the full architecture document causes reviewers to miss topic-file drift (CR-S05). Treating a topic file as a general design document confuses the structured format requirement.

```yaml
- term: "architecture topic file"
  aliases: ["architecture file", "design doc", "architecture section", "tech doc", "architecture/<topic>.md", "topic file", "arch topic", "架构文档", "技术设计文档"]
  disambiguation_required: true
  definition: "A single markdown file at architecture/<topic>.md covering exactly one architectural concern (e.g., tech-stack, data-model, coding-conventions, nfr). Listed in the architecture.md index. Must NOT cross-reference other feature or architecture files inline — consumers read one topic file per concern. Distinct from architecture.md, which is only the 50-80 line index of topic files."

- term: "architecture index"
  aliases: ["architecture.md", "arch index", "architecture overview", "architecture summary", "架构索引"]
  disambiguation_required: true
  definition: "The architecture.md file at the artifact root — a 50-80 line index that lists all architecture/<topic>.md files. It is NOT a full design document; it contains only section headings and one-line summaries. Full content lives in the topic files."
```

---

## `wikilink` vs `hyperlink` vs `cross-reference`

**Why disambiguate.** Users may say "link", "reference", "cross-ref", or "hyperlink" when they mean a wikilink. In prd-analysis, a wikilink uses the `[[target]]` double-bracket syntax and is checked by the script-type criterion CR-S06 (wikilink-targets-exist). A standard Markdown hyperlink `[text](path)` is not a wikilink and is not subject to CR-S06 validation. Confusing the two causes either false-positive or false-negative link-validation results.

```yaml
- term: "wikilink"
  aliases: ["[[link]]", "wiki link", "double-bracket link", "internal link", "cross-reference", "cross-ref", "internal reference", "内部链接", "wiki链接"]
  disambiguation_required: true
  definition: "A cross-reference using the [[target]] double-bracket syntax. Validated by scripts/check-wikilink-targets.sh (CR-S06) — every [[target]] must resolve to an existing file within the artifact directory. Distinct from a standard Markdown hyperlink [text](path). Feature files may use wikilinks to reference journey files; wikilink targets must exist at validation time."
```

---

## `tombstone` vs `deleted feature` vs `deprecated feature`

**Why disambiguate.** In evolve mode a user may say "remove this feature", "deprecate it", or "mark it as gone". These all map to the tombstone pattern — a minimal marker file that records the deprecation rather than deleting the original. Actual file deletion would break the evolve-mode immutability constraint (R-007): the predecessor baseline MUST NOT be mutated. A tombstone in the new date-prefixed directory signals deprecation without touching the baseline.

```yaml
- term: "tombstone"
  aliases: ["deprecated feature", "removed feature", "deleted feature", "feature removal", "deprecate", "retire feature", "墓碑文件", "废弃标记", "下线标记"]
  disambiguation_required: true
  definition: "In evolve mode, a minimal markdown file that marks a feature or journey as deprecated. Placed in the new date-prefixed directory (never in the baseline). Contains: status: deprecated, deprecation reason, replacement reference if any, and a link to the original file in the predecessor baseline. The baseline file is NEVER deleted or mutated."
```

---

## `evolve baseline` vs `previous version` vs `v1 PRD`

**Why disambiguate.** Users say "update the PRD", "new version", "v2", or "revise based on v1". In prd-analysis there are two distinct update modes: `--revise` (in-place change management with REVISIONS.md log, for the same version) and `--evolve` (new date-prefixed directory, delta-only output, predecessor is the baseline). When a user says "new version" without specifying, the domain-consultant must clarify whether they mean revise (same artifact, tracked changes) or evolve (new artifact directory, baseline immutable).

```yaml
- term: "evolve baseline"
  aliases: ["previous PRD", "predecessor PRD", "v1 PRD", "old PRD", "baseline PRD", "original PRD", "source PRD", "上一版本 PRD", "基线 PRD", "前版本"]
  disambiguation_required: true
  definition: "The predecessor date-prefixed PRD directory that a new --evolve run extends. The baseline is treated as immutable: no file in it may be modified or deleted. The new PRD directory contains ONLY delta files — new journeys, modified features (as new files), and tombstones for deprecated ones. Unchanged features reference the baseline via a → baseline link rather than being copied."

- term: "evolve mode"
  aliases: ["--evolve", "evolve", "new PRD version", "new version", "v2", "next iteration", "演进模式", "迭代 PRD"]
  disambiguation_required: true
  definition: "The /prd-analysis --evolve <baseline-path> [notes.md] invocation mode. Produces a new date-prefixed directory with delta-only output. Predecessor baseline is immutable. Contrast with --revise, which applies tracked in-place changes to the same artifact directory and appends entries to REVISIONS.md."
```

---

## `self-contained file` vs `standalone file` vs `atomic file`

**Why disambiguate.** "Self-contained" is a specific design constraint in prd-analysis: a feature file MUST inline all context a coding agent needs — data model fragments, coding conventions, journey back-references — rather than pointing to those files by path. Users often think "standalone" means simply "no imports" or "no external dependencies", missing the inline-copying requirement. Violating this principle means a coding agent must open multiple files, defeating the one-file-per-feature implementation model.

```yaml
- term: "self-contained file"
  aliases: ["standalone file", "atomic file", "independent file", "self-sufficient file", "isolated spec", "自包含文件", "独立文件"]
  disambiguation_required: true
  definition: "A leaf file (feature or journey) that can be read and fully acted on without opening any other file. All referenced context — relevant data model fragments, coding conventions, journey back-references, acceptance criteria — is copied inline, not linked by path. A coding agent implementing a feature reads only that feature's file. Violating this principle (by adding cross-refs instead of inlining) triggers CR-S04."
```

---

## `product slug` vs `product name` vs `project name`

**Why disambiguate.** Users write product names in natural language ("My Task App", "Task Manager Pro"). A product slug is the kebab-case identifier derived from the name and used as the directory suffix: `YYYY-MM-DD-<product-slug>/`. Getting this wrong produces directories that shell scripts and glob patterns cannot match reliably. The domain-consultant confirms the slug explicitly at R-001 resolution time.

```yaml
- term: "product slug"
  aliases: ["slug", "product id", "project slug", "directory name", "folder name", "product identifier", "产品标识符", "产品代号"]
  disambiguation_required: true
  definition: "A kebab-case identifier (lowercase letters, digits, hyphens; no spaces or underscores) used as the suffix for the PRD output directory: docs/raw/prd/YYYY-MM-DD-<product-slug>/. Derived from the product name by lowercasing, replacing spaces with hyphens, and removing special characters. Confirmed explicitly during the domain-consultant clarification phase (R-001)."
```

---

## `revision log` vs `changelog` vs `REVISIONS.md`

**Why disambiguate.** Users say "changelog", "change log", "version history", or "audit trail" when referring to what prd-analysis calls the revision log. The revision log is the `REVISIONS.md` sibling file created after the first `--revise` run. It is distinct from a git commit log (which is not part of the artifact) and from a version bump (which is an evolve-mode operation). The CR-S07 (revisions-log-consistency) check validates that every --revise invocation appended a timestamped entry.

```yaml
- term: "revision log"
  aliases: ["changelog", "change log", "REVISIONS.md", "version history", "audit trail", "revision history", "修订日志", "变更记录", "变更日志"]
  disambiguation_required: true
  definition: "The REVISIONS.md file at the artifact root, created and appended to by --revise runs. Each entry records: timestamp, author, summary of changes, and list of modified files. Validated by CR-S07 (revisions-log-consistency). Only present after the first --revise run — not created by initial generation or --evolve. Distinct from git history and from tombstones (which are used in --evolve mode)."
```
