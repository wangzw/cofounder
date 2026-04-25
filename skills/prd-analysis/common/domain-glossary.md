# Domain Glossary — prd-analysis

This glossary provides PRD-domain term definitions for the domain-consultant sub-agent's
clarification phase and for all writer sub-agents producing prd-analysis artifact leaves.
Terms are grouped by ambiguity cluster. Each entry uses YAML blocks so `glossary-probe.sh`
can parse them automatically.

All entries carry `disambiguation_required: true`. Terms are grouped by the ambiguity cluster —
one H2 per cluster.

---

## `PRD` vs `spec` vs `design doc`

**Why disambiguate.** Users say "write a spec" or "write a design doc" interchangeably. In
this skill system "PRD" is a bounded artifact: product-level decisions (what/for whom/why/priority)
stored as a dated multi-file pyramid under `docs/raw/prd/`. "Spec" and "design doc" are ambiguous
— they could refer to the PRD, a system-design artifact, or an ad-hoc document. Using the wrong
term causes the domain-consultant to capture the wrong scope and the planner to generate the
wrong leaf set.

```yaml
- term: "PRD"
  aliases: ["product requirements document", "requirements doc", "requirements document",
            "spec", "product spec", "design doc", "needs doc", "feature doc",
            "需求文档", "产品需求", "PRD文档"]
  disambiguation_required: true
  definition: "The concrete multi-file directory tree produced by prd-analysis. Captures product-level decisions — what to build, for whom, why, and at what priority. Does NOT include implementation decisions (tech stack, module decomposition) — those belong to system-design. Stored as docs/raw/prd/YYYY-MM-DD-{product-slug}/."
  see_also: ["artifact", "leaf"]
```

---

## `Journey` vs `user story` vs `use case` vs `scenario`

**Why disambiguate.** "User story", "use case", and "journey" overlap heavily in common usage.
In this skill, a "Journey" (J-NNN) is a structured multi-touchpoint narrative with persona,
trigger, goal, touchpoint table, and error paths. A "user story" is a one-sentence requirement
in the form "As a X, I want Y, so that Z" — it appears INSIDE a feature file, not as a journey.
Conflating them causes the planner to either duplicate artifacts or omit entire journey files.

```yaml
- term: "Journey"
  aliases: ["user journey", "user flow", "customer journey", "use case", "user scenario",
            "scenario", "epic", "story map", "用户旅程", "用户流程", "使用场景"]
  disambiguation_required: true
  definition: "A structured multi-touchpoint narrative (file J-NNN-{slug}.md) describing one persona's end-to-end interaction with the product: trigger, goal, touchpoint table, alternative paths, error paths, and E2E test scenarios. Identified by J-NNN ID. Distinct from a 'user story', which is a one-sentence requirement inside a feature file."
  see_also: ["Touchpoint", "Persona", "Feature"]

- term: "user story"
  aliases: ["story", "As a user", "用户故事"]
  disambiguation_required: true
  definition: "A one-sentence requirement in the form 'As a {persona}, I want {action}, so that {outcome}'. Appears inside a Feature file's User Stories section, NOT as a standalone artifact. Distinct from a Journey, which is a full multi-touchpoint file."
  see_also: ["Journey", "Feature"]
```

---

## `Touchpoint` vs `step` vs `interaction`

**Why disambiguate.** Users casually say "step" or "interaction" when describing journey flows.
In this skill, "touchpoint" is a specific table row with seven mandatory columns (Stage, User Action,
System Response, Screen/View, Interaction Mode, Emotion, Pain Point). Calling it a "step" risks
producing a journey table that omits system-response or emotion columns, which breaks
feature-derivation downstream.

```yaml
- term: "Touchpoint"
  aliases: ["step", "interaction", "touch point", "contact point", "interaction step",
            "journey step", "流程步骤", "接触点", "触点"]
  disambiguation_required: true
  definition: "A specific row in a Journey's touchpoint table. Defined by seven fields: Stage, User Action, System Response, Screen/View, Interaction Mode, Emotion, and Pain Point. Every feature maps back to at least one touchpoint — features with no touchpoint reference are orphaned."
  see_also: ["Journey", "Interaction Mode", "Feature"]
```

---

## `Interaction Mode` vs `UI component` vs `action`

**Why disambiguate.** "Interaction Mode" in this skill has a fixed enumeration (click / form /
drag / keyboard / scroll / hover / swipe / voice / scan). Users often confuse it with a
UI component name ("button", "dropdown") or a generic verb ("click", "submit"). Using the wrong
value populates the touchpoint table with non-standard strings that break downstream feature
generation and accessibility requirements.

```yaml
- term: "Interaction Mode"
  aliases: ["interaction type", "UI interaction", "action type", "input method",
            "interaction pattern", "UX mode", "交互模式", "操作方式"]
  disambiguation_required: true
  definition: "The primary user interaction pattern at a journey touchpoint. Fixed enumeration: click (mouse click), form (fill+submit form fields), drag (drag-and-drop), keyboard (keyboard input/shortcuts), scroll (scroll-triggered), hover (hover-triggered tooltip/menu), swipe (touch gesture), voice (voice command), scan (QR/barcode). List the primary mode only; multi-mode details belong in the feature's state machine."
  see_also: ["Touchpoint", "Feature"]
```

---

## `Feature` (F-NNN) vs `requirement` vs `Epic` vs `task`

**Why disambiguate.** "Feature", "requirement", "Epic", and "task" are used interchangeably in
product discussions. In this skill system, "Feature" is a bounded leaf file (F-NNN-{slug}.md)
with a fixed structure (Context, User Stories, Journey Context, Requirements, Acceptance Criteria,
etc.) and a P0/P1/P2 priority tag. An "Epic" is not a first-class artifact — if a user says
"Epic", the domain-consultant must clarify whether they mean a Feature or a Journey.

```yaml
- term: "Feature"
  aliases: ["requirement", "feature requirement", "user requirement", "product requirement",
            "Epic", "epic story", "capability", "functionality", "功能", "需求", "特性"]
  disambiguation_required: true
  definition: "A bounded leaf file (F-NNN-{slug}.md) under features/ that captures one implementable capability: context, user stories, journey context, requirements, acceptance criteria, interaction design (if UI), and implementation notes. Identified by F-NNN ID. Priority is P0/P1/P2. This is NOT an implementation task — implementation tasks live in system-design modules."
  see_also: ["Journey", "Touchpoint", "Priority", "Acceptance Criterion", "Module"]
```

---

## `Module` (M-NNN) — reference only

**Why disambiguate.** PRD authors sometimes ask the domain-consultant to include module
decomposition. Modules (M-NNN) belong strictly to system-design, not to prd-analysis. The
PRD may reference module IDs in the Feature-Module mapping context but MUST NOT define or
decompose modules — that crosses the PRD/system-design scope boundary.

```yaml
- term: "Module"
  aliases: ["M-NNN", "system module", "implementation module", "component",
            "service", "microservice", "backend module", "模块", "服务模块"]
  disambiguation_required: true
  definition: "An implementation-level decomposition unit (M-NNN) defined by system-design, NOT by prd-analysis. The PRD may reference module IDs in a Feature-Module mapping but MUST NOT define module internals. If a user asks for modules in the PRD, the domain-consultant must clarify that module decomposition belongs to /cofounder:system-design."
  see_also: ["Feature"]
```

---

## `Persona` vs `user role` vs `actor`

**Why disambiguate.** Users often conflate "persona" (a named archetype describing goals,
frustrations, and behavior) with "user role" (an access-control concept like Admin/Member/Viewer)
or "actor" (UML term). In this skill, Personas drive journey derivation; Roles drive permission
matrices in feature specs. Conflating them causes the planner to omit journey diversity or the
writer to use access-control language in journey narratives.

```yaml
- term: "Persona"
  aliases: ["user type", "actor", "target user", "customer segment", "user persona",
            "user profile", "用户画像", "角色", "目标用户"]
  disambiguation_required: true
  definition: "A named fictional archetype representing a distinct user segment: name, goal, frustrations, behavior patterns, and technical sophistication. Personas drive journey derivation — each journey is scoped to one persona. Distinct from 'user role' (access-control) and 'actor' (UML). Defined in the PRD README."
  see_also: ["Journey", "Feature"]
```

---

## `Cross-Journey Pattern` vs `feature` vs `shared component`

**Why disambiguate.** Users sometimes describe a cross-cutting concern ("all journeys need
authentication") as a feature. In this skill, "Cross-Journey Pattern" is a thematic observation
documented in the PRD README's Cross-Journey Patterns section; it is NOT a feature file. The
pattern entry identifies recurring pain points or shared infrastructure needs and points to the
Feature(s) that address them. Creating a feature from a pattern name (e.g. "F-001-authentication-pattern")
is incorrect — the feature should be named for its behavior, not the pattern.

```yaml
- term: "Cross-Journey Pattern"
  aliases: ["cross-cutting concern", "shared pattern", "common theme", "recurring theme",
            "horizontal requirement", "cross-functional requirement", "横切关注点", "跨旅程模式"]
  disambiguation_required: true
  definition: "A recurring theme observed across multiple user journeys — shared pain points, repeated touchpoints, common infrastructure needs, or handoff points between personas. Documented in the PRD README's Cross-Journey Patterns section (NOT as a standalone file). Each pattern must be addressed by at least one Feature. Distinct from a Feature: the pattern names the theme; the Feature provides the implementation spec."
  see_also: ["Journey", "Feature", "Persona"]
```

---

## `Design Token` vs `CSS variable` vs `style constant`

**Why disambiguate.** Users say "design token", "CSS variable", and "style constant"
interchangeably. In this skill, "Design Token" is a PRD-level semantic name (e.g.
`color.primary`, `spacing.md`) that represents a design decision. CSS custom properties
(`--color-primary`), Tailwind config values, and terminal constants are the
implementation-level forms — they belong in system-design, not the PRD. Mixing them
causes the PRD to specify implementation details and the system-design to duplicate
semantic intent.

```yaml
- term: "Design Token"
  aliases: ["CSS variable", "CSS custom property", "style constant", "theme variable",
            "design variable", "style token", "design system token",
            "设计令牌", "设计变量", "样式变量"]
  disambiguation_required: true
  definition: "A named semantic value (color, spacing, typography, motion, etc.) that represents a design decision at the PRD level. Uses semantic names such as color.primary, spacing.md, motion.duration.normal — NOT raw values (#336699, 16px, 300ms) and NOT implementation forms (--color-primary, Tailwind class names). System-design defines the implementation mechanism."
  see_also: ["Feature"]
```

---

## `Acceptance Criterion` vs `requirement` vs `test case`

**Why disambiguate.** "Acceptance criterion", "requirement", and "test case" are often confused.
In this skill, Acceptance Criteria use Given/When/Then format and are the behavioral contract
that an automated test can directly verify. A "requirement" is a declarative statement ("must
support X") in the Requirements list. A "test case" is an implementation-level construct.
Mixing these causes feature files to have untestable criteria or duplicate requirement text.

```yaml
- term: "Acceptance Criterion"
  aliases: ["acceptance test", "test criterion", "test case", "AC", "done criterion",
            "definition of done", "success criterion", "验收标准", "验收条件", "完成标准"]
  disambiguation_required: true
  definition: "A behavioral contract in Given/When/Then format inside a Feature file's Acceptance Criteria section. Directly maps to one automated test. Distinct from a 'Requirement' (declarative statement in the Requirements list) and a 'test case' (implementation artifact). Every acceptance criterion must be verifiable by an automated test."
  see_also: ["Feature", "NFR"]
```

---

## `Priority` (P0/P1/P2) vs `severity` vs `MoSCoW`

**Why disambiguate.** Priority in prd-analysis uses the three-tier P0/P1/P2 scale (P0 = must-have
for launch, P1 = important next, P2 = nice-to-have). Users often use MoSCoW ("must", "should",
"could", "won't") or severity language. Converting priority values incorrectly causes the planner
to include P2 features in the MVP scope or omit P0 features.

```yaml
- term: "Priority"
  aliases: ["P0", "P1", "P2", "must have", "should have", "could have", "won't have",
            "MoSCoW", "critical", "high priority", "low priority", "nice to have",
            "优先级", "重要性", "紧急程度"]
  disambiguation_required: true
  definition: "The three-tier priority scale used in feature headers: P0 = must-have for launch (product does not ship without it), P1 = important but not blocking launch, P2 = nice-to-have for a future iteration. P0 maps to MoSCoW 'must'; P1 maps to 'should'; P2 maps to 'could/won't'. Distinct from 'severity', which measures impact of a defect, not importance of a feature."
  see_also: ["Feature", "Acceptance Criterion"]
```

---

## `NFR` vs `non-functional requirement` vs `quality attribute`

**Why disambiguate.** "NFR", "non-functional requirement", and "quality attribute" are
synonymous in intent but treated differently in prd-analysis output. NFRs (performance,
security, scalability, reliability, accessibility) appear in two places: (1) the PRD
`architecture/nfr.md` topic file for system-wide targets, and (2) the feature's
Acceptance Criteria non-behavioral section for feature-scoped budgets. Writing an NFR only
in one place and not the other creates coverage gaps that system-design cannot close.

```yaml
- term: "NFR"
  aliases: ["non-functional requirement", "quality attribute", "quality requirement",
            "system quality", "ility", "-ility requirement", "cross-cutting quality",
            "性能需求", "非功能性需求", "质量属性"]
  disambiguation_required: true
  definition: "A non-functional requirement that defines system quality attributes (performance, security, scalability, reliability, accessibility, i18n). In prd-analysis: system-wide NFR targets live in architecture/nfr.md; feature-scoped NFR budgets appear in the feature's Acceptance Criteria non-behavioral section. Both locations are required for complete PRD coverage."
  see_also: ["Feature", "Acceptance Criterion"]
```

---

## `Tombstone` vs `deleted feature` vs `deprecated`

**Why disambiguate.** In --evolve mode, removing a feature must produce a Tombstone file —
a minimal leaf that marks the feature as deprecated and links to the original. Simply deleting
the feature file from the evolve directory is incorrect: downstream skills (system-design,
autoforge) use the PRD to determine what to build and what to deprecate. A missing file
cannot signal deprecation; a tombstone can.

```yaml
- term: "Tombstone"
  aliases: ["deprecated feature", "deleted feature", "removed feature", "sunset feature",
            "deprecated journey", "墓碑", "废弃功能", "已删除功能"]
  disambiguation_required: true
  definition: "In evolve-mode PRDs (--evolve), a minimal leaf file that marks a feature or journey as deprecated. Contains: status=deprecated, deprecation reason, replacement feature reference (if any), and a link to the original file in the baseline PRD. Tombstones are NOT deleted files — they must be explicitly present so downstream skills know a deprecation occurred."
  see_also: ["Feature", "Journey"]
```

---

## `Self-Contained Leaf` vs `referenced file` vs `linked file`

**Why disambiguate.** The self-contained principle is frequently violated by writers who add
cross-references like "see architecture.md for data models" or "refer to journey J-001 for
context". In this skill, every leaf MUST copy the context it needs inline. A file that points
to another file for essential context is NOT self-contained and fails CR-L04. This
disambiguation is critical because the failure mode (a cross-reference in a feature file) looks
valid to a human reviewer but breaks coding-agent workflows.

```yaml
- term: "Self-Contained Leaf"
  aliases: ["self-contained file", "standalone file", "independent file", "self-sufficient file",
            "standalone spec", "独立文件", "自包含文件"]
  disambiguation_required: true
  definition: "A PRD leaf file (feature, journey, or architecture topic) that can be read and acted on independently. All referenced context — data models, coding conventions, journey narrative, design tokens — is copied inline, never referenced by path. A coding agent must never need to open a second file to implement the feature. Cross-references like 'see architecture.md' or 'refer to J-001' are FORBIDDEN in self-contained leaves."
  see_also: ["Feature", "Journey", "leaf"]
```
