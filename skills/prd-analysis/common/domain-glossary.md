# Domain Glossary — prd-analysis

This glossary serves two consumers:

1. **`glossary-probe.sh`** — The script greps each term and its aliases against `input.md`; on a hit it writes `trigger-flags.yml` with `glossary_hit: true` and the associated severity, which causes the orchestrator to invoke the domain-consultant sub-agent before proceeding to the planner. The `## Trigger-Mapping Table` section at the end of this file defines severity per term.

2. **Writers and reviewers** — Every term defined here is the canonical form. When a writer drafts a PRD artifact leaf, they MUST use these definitions verbatim. When a reviewer applies CR-L07 (terminology-consistency) or CR-L08 (glossary-coverage), they check against this file as the single source of truth. No cross-references to external files — every definition stands alone.

All entries carry `disambiguation_required: true`. Terms are organized into two groups: PRD-domain core (terms produced by or consumed by the prd-analysis skill) and skill-domain inherited (terms shared with skill-forge and the generative-skill runtime).

---

## PRD-Domain Core Terms

---

## `product requirements document (PRD)`

**Term**: product requirements document (PRD)

A PRD is a multi-file artifact that captures **product-level decisions**: what to build, for whom, why it matters, and at what priority. It is the canonical handoff from product thinking to implementation. The PRD is organized as a pyramid: a `README.md` navigation index at the root, plus subdirectories containing self-contained leaf files for individual journeys (`journeys/J-NNN-{slug}.md`), features (`features/F-NNN-{slug}.md`), and architecture topic files (`architecture/{topic}.md`).

A PRD is NOT a system design. It does not specify modules, APIs, database schemas, deployment topology, or code structure — those belong to the system-design skill. The boundary is strict: if a decision can only be made by an engineer looking at the codebase, it is outside PRD scope. If a decision can be made by a product manager or a user, it belongs in the PRD. Common boundary cases: data model field names (PRD scope — what data exists and why) vs. ORM table layout (system-design scope); design token names and values (PRD scope) vs. CSS custom property declaration (system-design scope).

When user says "write a spec", "write requirements", "product doc", or "user requirements document", treat as PRD.

```yaml
- term: "product requirements document"
  aliases: ["PRD", "product doc", "user requirements document", "spec", "requirements doc", "product spec", "需求文档", "产品需求文档"]
  disambiguation_required: true
  definition: "Multi-file artifact capturing product-level decisions: what, for whom, why, and at what priority. Organized as a pyramid: README.md root + journeys/, features/, architecture/ leaf directories. PRD scope ends at implementation boundaries — module design, API contracts, and database schemas belong to system-design."
```

---

## `user journey`

**Term**: user journey

A user journey is a **sequence of touchpoints** that one persona follows when pursuing one specific goal within the product. Each journey has a stable ID of the form `J-NNN` (zero-padded, sequential, stable across PRD iterations). The journey file captures: the persona pursuing the goal, the goal statement, pre-conditions (what must be true before the journey starts), an ordered touchpoint table, a list of features that satisfy the journey's touchpoints, and post-conditions (the outcome state after the journey succeeds).

Journeys are causal chains: each touchpoint must logically follow from the previous one. A journey is NOT a feature list and NOT a user story. It is a narrative arc that describes a lived experience — the sequence and causality matter. Multiple personas may share touchpoints with different emotional contexts; those differences must be captured in separate journeys or via persona-specific sub-paths within the touchpoint table.

When user says "user flow", "user scenario", "use case flow", "usage scenario", or "user path", treat as user journey.

```yaml
- term: "user journey"
  aliases: ["journey", "user flow", "user scenario", "use case flow", "usage scenario", "user path", "用户旅程", "用户路径"]
  disambiguation_required: true
  definition: "Sequence of touchpoints for one persona pursuing one goal. Identified by J-NNN. The journey file captures persona, goal, pre-conditions, touchpoint table, mapped features, and post-conditions. Causality between touchpoints is mandatory — not a list."
```

---

## `persona`

**Term**: persona

A persona is a **named, motivated user archetype** that represents a distinct class of user with a specific role, context, goals, and success metric. Each persona in a PRD has: a name (e.g., "Mia the Solo Founder"), a role label, a context description (what situation they are in), primary goals, a success metric (how they know they succeeded), and pain points relevant to the product.

A persona is NOT a demographic profile and NOT a user story subject. It is a behavioral archetype defined by motivation and context. Two users with the same demographic may be different personas if their goals and contexts diverge (e.g., a "Trial User" and a "Power User" within the same SaaS product are distinct personas even if both are individual contributors). Each journey is owned by exactly one persona; a persona may own multiple journeys.

When user says "user type", "user role", "actor", "stakeholder", or "target user", treat as persona.

```yaml
- term: "persona"
  aliases: ["user type", "user role", "actor", "stakeholder", "target user", "用户角色", "角色", "用户画像"]
  disambiguation_required: true
  definition: "Named, motivated user archetype with role, context, goals, and success metric. Each journey is owned by exactly one persona. Personas are behavioral archetypes (motivation + context), not demographic profiles."
```

---

## `touchpoint`

**Term**: touchpoint

A touchpoint is a **specific moment** in a user journey where the user interacts with the system. Each touchpoint is defined by six fields: stage name (the phase of the journey), screen/view (the surface the user is on), action (what the user does), interaction mode (one of the canonical values — see `interaction mode` entry in this glossary), system response (what the system does in reply), and pain point (optional — what friction exists for the user at this moment).

Touchpoints are the atomic units from which features are derived: every PRD feature MUST trace back to at least one touchpoint in a journey. A touchpoint is NOT the same as a feature — a touchpoint describes a user action and system response; a feature bundles the capabilities needed to make that exchange possible. A single touchpoint may be addressed by multiple features, and a single feature may address multiple touchpoints.

When user says "interaction point", "user step", "step in the flow", "UI moment", or "user action", treat as touchpoint.

```yaml
- term: "touchpoint"
  aliases: ["interaction point", "user step", "step in the flow", "UI moment", "user action", "触点", "交互点"]
  disambiguation_required: true
  definition: "Specific interaction moment in a user journey. Defined by: stage name, screen/view, action, interaction mode, system response, and pain point (if any). Every feature must trace to at least one touchpoint. Touchpoints drive feature derivation."
```

---

## `interaction mode`

**Term**: interaction mode

Interaction mode is the **primary user interaction pattern** at a single touchpoint. The canonical values are: `click` (mouse click on UI element), `form` (fill and submit form fields), `drag` (drag-and-drop), `keyboard` (keyboard input, shortcuts), `scroll` (scroll-triggered actions), `hover` (hover-triggered tooltips or menus), `swipe` (touch gesture), `voice` (voice command), `scan` (QR or barcode scan).

Each touchpoint records exactly one primary interaction mode. If a touchpoint involves multiple modes (e.g., both `keyboard` and `click`), record only the dominant mode in the touchpoint table; secondary modes belong in the corresponding feature's state machine. Interaction mode is a classification device, not a UI design specification — it signals to the system-design skill what kind of interaction infrastructure is needed.

When user says "input type", "how the user interacts", "gesture", or "input method", treat as interaction mode.

```yaml
- term: "interaction mode"
  aliases: ["input type", "gesture", "input method", "UI interaction", "交互方式", "输入模式"]
  disambiguation_required: true
  definition: "Primary user interaction pattern at a touchpoint. Canonical values: click | form | drag | keyboard | scroll | hover | swipe | voice | scan. One value per touchpoint; secondary modes belong in the feature state machine."
```

---

## `feature`

**Term**: feature

A feature is a **bundle of product capabilities** that satisfies one or more touchpoints in a user journey. Each feature has a stable ID of the form `F-NNN` (zero-padded, sequential, stable across PRD iterations). The feature file contains: an overview, a user story, acceptance criteria, a state machine (or interaction flow), the interaction mode, inline copies of relevant data model excerpts, inline copies of relevant journey context, inline copies of applicable conventions, dependencies on other features, and an explicit MVP boundary note.

A feature is NOT a task, NOT a user story alone, and NOT a module. Tasks are implementation work items; user stories are motivational summaries; modules are system-design constructs. A feature spans the product-requirement layer: it is defined by what the user can do and what the system must support to make it possible, not by how the system is implemented. Feature files are self-contained — a coding agent reads one feature file and has everything needed to implement it.

When user says "user story", "capability", "functionality", "requirement", "product feature", or "product function", treat as feature.

```yaml
- term: "feature"
  aliases: ["user story", "capability", "functionality", "requirement", "product feature", "product function", "功能", "特性", "需求项"]
  disambiguation_required: true
  definition: "Bundle of product capabilities tied to ≥1 touchpoint. Identified by F-NNN. Self-contained leaf file: overview, user story, acceptance criteria, state machine, interaction mode, inline data model, inline journey context, inline conventions, dependencies, MVP boundary note."
```

---

## `MVP boundary`

**Term**: MVP boundary

The MVP boundary is the **explicit, justified cutoff** between features that are in-scope for the minimum viable product and features that are deferred to post-MVP. The boundary is not implied by priority labels alone — it must be stated as a formal decision in the PRD README and as a note in each feature file. In-MVP features are those without which the product cannot be validated with real users; post-MVP features are those that enhance the product after initial validation.

The MVP boundary requires justification: for each deferred feature, the PRD must state why deferral is acceptable (e.g., "not on critical user journey", "available via workaround", "complexity exceeds validation value"). The boundary is a product-level decision, not an engineering estimate. Engineers may later renegotiate scope, but the PRD's MVP boundary is the authoritative input to that negotiation.

When user says "v1 scope", "must-have vs nice-to-have", "launch scope", "MVP features", or "phase 1", treat as MVP boundary.

```yaml
- term: "MVP boundary"
  aliases: ["v1 scope", "must-have vs nice-to-have", "launch scope", "MVP features", "phase 1", "最小可行产品边界", "MVP范围"]
  disambiguation_required: true
  definition: "Explicit, justified cutoff between in-MVP and post-MVP features. Stated in PRD README and in each feature file. Each deferral requires a justification. Product-level decision, not an engineering estimate."
```

---

## `cross-journey pattern`

**Term**: cross-journey pattern

A cross-journey pattern is a **recurring theme observed across two or more user journeys**. It may take the form of: a shared pain point (multiple personas experience the same friction), a repeated touchpoint (the same interaction appears in multiple journeys), common infrastructure needs (multiple journeys require the same underlying capability), or a handoff point between personas (one journey's end state triggers another journey's start). Cross-journey patterns are documented in the PRD README's "Cross-Journey Patterns" section.

Each identified pattern must be addressed by at least one feature. Patterns that lack a covering feature represent a gap in the feature set. Cross-journey patterns are a quality signal: a PRD with zero identified patterns in a product with three or more journeys likely has incomplete analysis. The pattern description must name the affected journeys (by J-NNN ID) and the addressing feature (by F-NNN ID).

When user says "shared behavior", "common flow", "repeated interaction", "cross-feature dependency", or "shared infrastructure need", treat as cross-journey pattern.

```yaml
- term: "cross-journey pattern"
  aliases: ["shared behavior", "common flow", "repeated interaction", "cross-feature dependency", "shared infrastructure need", "跨旅程模式", "共同模式"]
  disambiguation_required: true
  definition: "Recurring theme across ≥2 journeys: shared pain point, repeated touchpoint, common infrastructure need, or persona handoff. Documented in PRD README. Each pattern must be addressed by ≥1 feature (F-NNN). Zero patterns in a multi-journey PRD signals incomplete analysis."
```

---

## `feature-module mapping`

**Term**: feature-module mapping

The feature-module mapping is a **matrix linking PRD features (columns) to system-design modules (rows)**. It uses two symbols: `✦` means the module modifies data for that feature (write path); `△` means the module provides read-only support for that feature (read path). The mapping is the formal bridge between the requirements layer (PRD) and the implementation layer (system-design).

Within the PRD, features own the column definitions — the PRD defines what F-NNN is and what it must do. The system-design skill owns the row definitions — it defines what M-NNN is and how it is implemented. The PRD author does NOT assign module IDs. If a PRD references a module, that reference is forward-looking and non-authoritative; the system-design output is the authoritative source for module definitions and the completed matrix.

When user says "feature-to-module map", "which module handles which feature", "module-feature matrix", or "component coverage", treat as feature-module mapping.

```yaml
- term: "feature-module mapping"
  aliases: ["feature-to-module map", "module-feature matrix", "component coverage", "which module handles which feature", "功能模块映射"]
  disambiguation_required: true
  definition: "Matrix: PRD features (F-NNN columns) × system-design modules (M-NNN rows). Symbols: ✦ = module writes data for this feature; △ = module provides read-only support. PRD owns feature definitions; system-design owns module definitions. The completed matrix lives in the system-design README."
```

---

## `design token`

**Term**: design token

A design token is a **named semantic value** that represents a design decision. Token names use semantic notation, never raw values (e.g., `color.primary` not `#0066FF`; `spacing.md` not `16px`). The PRD defines two things for each token: the semantic name and the resolved value (the actual color, size, duration, etc.). The system-design skill defines a third thing: the implementation mechanism (CSS custom property declaration, Tailwind config entry, terminal constant, etc.).

Design tokens cover: colors (background, text, border, interactive states), spacing (margin, padding, gap scales), typography (font family, size scale, weight, line-height), motion (transition duration, easing curve), elevation (shadow levels), and border radius. A PRD that specifies raw hex values or pixel values without semantic names is out of scope discipline — those values belong in a design token with a semantic name. Tokens are defined in the `architecture/design-tokens.md` topic file.

When user says "color palette", "spacing scale", "brand colors", "design variables", "CSS variables", or "theme values", treat as design tokens.

```yaml
- term: "design token"
  aliases: ["color palette", "spacing scale", "brand colors", "design variables", "CSS variables", "theme values", "设计令牌", "设计变量"]
  disambiguation_required: true
  definition: "Named semantic value representing a design decision. Format: <category>.<semantic-name> (e.g., color.primary, spacing.md). PRD defines name + resolved value; system-design defines implementation mechanism. Raw hex/px values without semantic names are a scope violation."
```

---

## `success criteria`

**Term**: success criteria

Success criteria are **measurable assertions** that define when a feature or PRD objective is considered successfully achieved. Each criterion must be binary (pass/fail) or threshold-based (e.g., "≥ 80% of new users complete onboarding within 5 minutes"). Vague assertions ("users find it easy") are not valid success criteria — they must be operationalized into observable measurements.

Success criteria operate at two levels: feature-level (does this feature behave correctly?) and product-level (does the product achieve its business objectives?). Feature-level success criteria are close to acceptance criteria but focus on outcomes rather than behavior: "conversion rate from sign-up to first export ≥ 15%" rather than "the export button is present and clickable". Product-level success criteria appear in the PRD README and measure the overall value proposition.

When user says "KPIs", "metrics for success", "definition of success", "how we know it's working", or "launch metrics", treat as success criteria.

```yaml
- term: "success criteria"
  aliases: ["KPIs", "metrics for success", "definition of success", "how we know it's working", "launch metrics", "成功标准", "成功指标"]
  disambiguation_required: true
  definition: "Measurable assertions (binary or threshold) for accepting a feature or PRD objective. Must be operationalized: not 'users find it easy' but '≥ 80% of users complete X within Y minutes'. Feature-level criteria verify behavioral outcomes; product-level criteria verify business value."
```

---

## `acceptance criteria`

**Term**: acceptance criteria

Acceptance criteria are **behavioral assertions** that verify a feature works as specified. Each criterion takes one of two canonical forms: (1) Given/When/Then — a BDD-style scenario that describes a precondition, a triggering action, and an expected outcome; or (2) a state machine assertion — a named state transition that must occur (e.g., "state: draft → submitted when user clicks 'Submit' and all required fields are valid").

Acceptance criteria are the primary interface between the PRD and the test layer. A coding agent implementing a feature reads the acceptance criteria to understand what "done" means. Criteria must be specific enough that a developer can write a test for each one without further clarification. Vague criteria ("the feature works") are a CR-L failure — they will be flagged by the adversarial reviewer.

When user says "test criteria", "pass/fail conditions", "done criteria", "BDD scenarios", "Given/When/Then", or "feature tests", treat as acceptance criteria.

```yaml
- term: "acceptance criteria"
  aliases: ["test criteria", "pass/fail conditions", "done criteria", "BDD scenarios", "Given/When/Then", "feature tests", "验收标准", "验收条件"]
  disambiguation_required: true
  definition: "Behavioral assertions verifying feature behavior. Two canonical forms: (1) Given/When/Then BDD scenario; (2) state machine transition assertion. Each criterion must be testable by a developer without further clarification."
```

---

## `tombstone`

**Term**: tombstone

A tombstone is a **minimal file** produced in evolve-mode PRDs that marks a feature or journey as deprecated. It replaces the original feature or journey file in the new PRD version directory and contains: the deprecation status (`deprecated`), the deprecation reason (one or two sentences), a replacement reference (`→ F-NNN` or `→ J-NNN` if a successor exists, or `none` if the capability is removed entirely), and a link back to the original file in the baseline PRD.

A tombstone is NOT a full feature file with a deprecated flag — it is a deliberately minimal file. Its purpose is to signal to coding agents and downstream skills that the original feature/journey no longer applies, without repeating all of its content. A tombstone file MUST NOT contain the original feature's implementation details. The tombstone enables evolve-mode consumers to distinguish "this feature was changed" (local file present) from "this feature was removed" (tombstone present) from "this feature is unchanged" (baseline reference present, no local file).

When user says "mark as deprecated", "deprecated feature", "removed feature", "sunset", or "phased out", treat as tombstone.

```yaml
- term: "tombstone"
  aliases: ["deprecated feature", "removed feature", "sunset", "phased out", "mark as deprecated", "废弃标记", "弃用文件"]
  disambiguation_required: true
  definition: "Minimal file in evolve-mode PRDs marking a deprecated feature or journey. Contains: status (deprecated), reason, replacement reference (F-NNN or none), and baseline link. NOT a full feature file — intentionally minimal. Distinguishes 'removed' from 'changed' from 'unchanged'."
```

---

## Skill-Domain Inherited Terms

---

## `self-contained file`

**Term**: self-contained file

A self-contained file is a file that can be **read and acted on independently**. All context that a consuming agent needs to act on the file — data models, conventions, journey context, dependencies — is copied inline rather than referenced by path. A coding agent implementing a feature reads only that feature file and has everything it needs; it must never need to open a second file.

In practice: when a feature template says "copy applicable conventions from `architecture/coding-conventions.md`", it means copy the relevant text into the feature file's "Inline Conventions" section, not add a file path reference. The self-contained principle applies to all leaf files: journey files copy the relevant persona definition inline; feature files copy the relevant journey touchpoints and data model fields inline. The README index is NOT self-contained — it is a navigation aid, not a leaf.

When user says "standalone file", "self-sufficient file", "no external deps", or "copy inline", treat as self-contained file.

```yaml
- term: "self-contained file"
  aliases: ["standalone file", "self-sufficient file", "no external deps", "copy inline", "自包含文件", "独立文件"]
  disambiguation_required: true
  definition: "File that can be read and acted on independently. All referenced context (data models, conventions, journey context) is copied inline, not referenced by path. A coding agent reads only this file. Applies to all leaf files; the README index is exempt."
```

---

## `generative skill`

**Term**: generative skill

A generative skill is a **skill that produces artifacts from sparse user intent**. It uses the 8-role pattern: an orchestrator plus seven sub-agents (domain-consultant, planner, writer, cross-reviewer, adversarial-reviewer, reviser, summarizer, judge). The orchestrator dispatches sub-agents sequentially and in parallel across iterative review/revise rounds until the judge emits a convergence verdict. The prd-analysis skill is a generative skill.

A generative skill is NOT a workflow skill. Workflow skills orchestrate deterministic steps (lint, deploy, tag) without artifact generation or quality judgment. The distinction matters because generative skills require the review/revise round loop, the HITL gate, and the 8-role agent architecture — none of which apply to workflow skills.

When user says "skill that generates content", "AI-powered PRD writer", "artifact generator", or "multi-agent generator", treat as generative skill.

```yaml
- term: "generative skill"
  aliases: ["生成式 skill", "content-generating skill", "artifact skill", "AI-powered PRD writer", "artifact generator", "multi-agent generator", "生成式技能"]
  disambiguation_required: true
  definition: "Skill producing artifacts from sparse intent using the 8-role pattern (orchestrator + 7 sub-agents) with iterative review/revise rounds. prd-analysis is a generative skill. Contrast with workflow skills, which are deterministic and have no round loop."
```

---

## `artifact pyramid`

**Term**: artifact pyramid

The artifact pyramid is the **multi-file directory structure** produced by a generative skill run. It has a README.md hub at the root (navigation index with summaries) and leaf files in subdirectories (journeys/, features/, modules/, etc.). For prd-analysis, the pyramid root is `docs/raw/prd/YYYY-MM-DD-{product-slug}/` and the leaves are individual journey and feature files.

The pyramid has one invariant: a coding agent reads exactly one leaf and has everything it needs. The README is a stable navigation index — it is not load-bearing for any single implementation task. The pyramid is the unit of artifact delivery; a delivery counter increments when the judge confirms the pyramid has converged.

When user says "output directory", "PRD directory", "generated files", or "artifact tree", treat as artifact pyramid.

```yaml
- term: "artifact pyramid"
  aliases: ["output directory", "PRD directory", "generated files", "artifact tree", "制品金字塔", "输出目录"]
  disambiguation_required: true
  definition: "Multi-file directory structure from a generative skill run. README.md hub + leaf files in subdirectories. For prd-analysis: docs/raw/prd/YYYY-MM-DD-{slug}/. Coding agents read one leaf; README is navigation only. The unit of delivery."
```

---

## `delivery`

**Term**: delivery

A delivery is a **converged round group** identified by a monotonic integer counter (D001, D002, ...). A delivery increments each time the convergence judge emits `converged` and the artifact pyramid is committed. Round numbers are monotonically increasing across deliveries — round 4 in delivery 2 is globally round 4, not round 1 of delivery 2. The delivery counter is the authoritative versioning mechanism for a skill's output.

Delivery is NOT semantic versioning. Users who say "v1", "release", "version bump", or "major update" mean delivery in this system. Confusing delivery with semantic versioning causes incorrect tag generation and broken regression history.

When user says "v1", "release", "version bump", "major update", or "delivery", treat as delivery.

```yaml
- term: "delivery"
  aliases: ["v1", "release", "version bump", "major update", "semantic version", "semver", "版本", "发布", "交付物"]
  disambiguation_required: true
  definition: "Converged round group; monotonic integer counter (D001, D002, ...) incrementing on each judge convergence verdict. Round numbers are globally monotonic across deliveries. NOT semantic versioning — 'v1' and 'release' map to delivery in this system."
```

---

## `round`

**Term**: round

A round is **one full generate → review → revise pass** within a delivery. A round starts when the planner emits a plan.md and writers begin producing or revising artifact leaves. A round ends when the judge emits a verdict (converged, needs-revision, oscillating, or diverging). Round numbers are monotonically increasing and globally unique within a skill's run — they do not reset between deliveries.

Each round produces: writer artifacts, self-review archives, cross-reviewer issues, adversarial-reviewer issues, per-issue revisions, a summarizer round summary, and a judge verdict. The orchestrator advances to the next round if the verdict is `needs-revision`, halts if `converged`, and triggers a HITL gate if `oscillating` or `diverging`.

When user says "iteration", "review cycle", "pass", or "review round", treat as round.

```yaml
- term: "round"
  aliases: ["iteration", "review cycle", "pass", "review round", "轮次", "迭代"]
  disambiguation_required: true
  definition: "One full generate→review→revise pass within a delivery. Globally unique, monotonically increasing round number. Ends with a judge verdict (converged | needs-revision | oscillating | diverging). Round numbers do not reset between deliveries."
```

---

## `HITL gate`

**Term**: HITL gate

A HITL gate (human-in-the-loop approval pause) is a **mandatory orchestrator halt** that requires explicit human approval before execution continues. In prd-analysis, there are two HITL gates: (1) the plan approval gate after the planner emits `plan.md` — the human must approve before writers begin; (2) the force-continue gate triggered when the judge emits `oscillating` or `diverging` — the human must decide whether to continue, abort, or redirect.

A HITL gate is NOT an optional review step. It is enforced by the orchestrator's dispatch logic — no sub-agent is spawned and no artifact is written until the gate resolves. The HITL gate is the primary mechanism by which the human retains control over an autonomous agent run.

When user says "approval gate", "human review point", "pause for review", "waiting for approval", or "requires human decision", treat as HITL gate.

```yaml
- term: "HITL gate"
  aliases: ["approval gate", "human review point", "pause for review", "waiting for approval", "requires human decision", "人工审核门", "审核门控"]
  disambiguation_required: true
  definition: "Mandatory orchestrator halt requiring explicit human approval. Two gates in prd-analysis: (1) plan approval after planner emits plan.md; (2) force-continue gate on oscillating/diverging judge verdict. No sub-agent spawns until gate resolves."
```

---

## Trigger-Mapping Table

This table is consumed by `glossary-probe.sh` to set `glossary_hit` severity flags. High-severity terms always trigger the domain-consultant when found in sparse input. Medium-severity terms trigger the consultant when combined with low signal density (fewer than 3 other R-001..R-007 values confirmed). Low-severity terms resolve via the alias mapping in the term entry above — no consultant trigger.

| term | glossary_hit_severity |
|------|-----------------------|
| PRD | high |
| product requirements document | high |
| user journey | high |
| journey | high |
| persona | high |
| feature | high |
| user story | low |
| capability | low |
| requirement | low |
| touchpoint | high |
| interaction mode | medium |
| MVP boundary | medium |
| v1 scope | medium |
| launch scope | medium |
| cross-journey pattern | medium |
| shared behavior | low |
| common flow | low |
| feature-module mapping | medium |
| design token | medium |
| color palette | low |
| brand colors | low |
| success criteria | medium |
| KPIs | low |
| launch metrics | low |
| acceptance criteria | medium |
| BDD scenarios | low |
| Given/When/Then | low |
| tombstone | medium |
| deprecated feature | low |
| self-contained file | medium |
| standalone file | low |
| generative skill | medium |
| artifact pyramid | medium |
| output directory | low |
| delivery | medium |
| v1 | low |
| release | low |
| round | medium |
| iteration | low |
| review cycle | low |
| HITL gate | medium |
| approval gate | low |
