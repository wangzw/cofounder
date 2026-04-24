# Domain Glossary — PRD Analysis

This glossary drives automated disambiguation in `glossary-probe.sh`. The script greps each term and its aliases against `input.md`; on a hit it writes `trigger-flags.yml` with `glossary_hit: true`, which causes the orchestrator to invoke the domain-consultant before proceeding to the planner.

The scope of this glossary is **PRD (product requirements) vocabulary only**. Terms are pinned to their PRD meaning — NOT their implementation or system-design meaning. When a term (e.g. "Module") has a different meaning in system-design, the entry calls out the distinction so writers do not drift into system-design territory (which is out of scope for this skill).

Every entry below carries `disambiguation_required: true`. Terms are grouped by ambiguity cluster — one H2 per cluster. Each entry follows the shape:

```
- term: "<canonical term>"
  aliases: [ ... ]
  disambiguation_required: true
  definition: "<one-sentence pinning of meaning in this skill>"
  see_also: [ ... ]
```

New terms are added here as the skill matures and new ambiguity patterns are observed in production inputs.

---

## `PRD` vs `spec` vs `requirements doc`

**Why disambiguate.** Users freely mix "PRD", "spec", "requirements doc", "product brief", and "PM doc". In this skill, PRD specifically means the artifact produced under `docs/raw/prd/YYYY-MM-DD-{product-slug}/` — a pyramid of `README.md` index + `journeys/` + `features/` + `architecture/` leaves. Any other shape (single-file spec, PM one-pager, Notion doc) is NOT a PRD in this system and must be coerced into the multi-file pyramid before review/revise operations apply.

```yaml
- term: "PRD"
  aliases: ["Product Requirements Document", "product requirements", "requirements doc", "product spec", "product brief", "PM doc", "产品需求文档", "需求文档"]
  disambiguation_required: true
  definition: "A multi-file markdown artifact under docs/raw/prd/YYYY-MM-DD-{product-slug}/ consisting of README.md (index), journeys/J-NNN-*.md, features/F-NNN-*.md, architecture.md + architecture/*.md topic files. Captures product-level decisions (what / for whom / why / priority) and NOT implementation detail. A single-file spec is NOT a PRD — it must be expanded to the pyramid shape first."
  see_also: ["Self-Contained Leaf", "Feature", "Journey"]
```

---

## `Journey` vs `user flow` vs `workflow`

**Why disambiguate.** "Workflow" is overloaded — in business-process tools it means an automation; in UX it means a user path; in this skill's skeleton system it could be confused with "workflow skill" (a non-generative skill type). In the PRD domain, "Journey" is the user-experience construct with persona, trigger, goal, touchpoints, and pain points — always stored as `journeys/J-NNN-{slug}.md`.

```yaml
- term: "Journey"
  aliases: ["user journey", "user flow", "customer journey", "journey map", "flow", "用户旅程", "用户路径"]
  disambiguation_required: true
  definition: "A persona-anchored sequence of touchpoints stored as journeys/J-NNN-{slug}.md. Contains: persona, trigger, goal, frequency, stage-by-stage touchpoint table, alternative paths, error & recovery paths, E2E test scenarios, and journey metrics. Journeys describe the user's experience, NOT the system's behavior. Distinct from 'workflow skill' in the meta-skill domain."
  see_also: ["Touchpoint", "Persona", "Cross-Journey Pattern"]
```

---

## `Touchpoint` vs `step` vs `interaction`

**Why disambiguate.** "Step" and "interaction" are too generic and get confused with both UI component events and business-process steps. A Touchpoint in the PRD domain is a specific row in a journey's Touchpoints table with a fixed six-column contract: Stage, User Action, System Response, Screen/View, Interaction Mode, Pain Point (plus Emotion and Mapped Feature). Missing any column makes the touchpoint incomplete and triggers a review blocker.

```yaml
- term: "Touchpoint"
  aliases: ["journey touchpoint", "journey step", "interaction point", "step", "moment", "接触点", "触点"]
  disambiguation_required: true
  definition: "A single row in a journey's Touchpoints table, defined by Stage + User Action + System Response + Screen/View + Interaction Mode + Pain Point (+ Emotion, Mapped Feature). Drives feature derivation — every feature must map back to at least one touchpoint, and every pain point must have feature coverage. Incomplete touchpoints (missing any of the six required columns) fail review."
  see_also: ["Journey", "Interaction Mode", "Feature"]
```

---

## `Interaction Mode` vs `interaction type` vs `input method`

**Why disambiguate.** "Input method" and "interaction type" are widely used but loosely defined. Interaction Mode is a **closed vocabulary** in this skill: one of `click`, `form`, `drag`, `keyboard`, `scroll`, `hover`, `swipe`, `voice`, `scan`. Free-form strings ("user clicks and then types") are NOT valid Interaction Modes — they fail the structural check and force the writer to pick the primary mode and defer details to the feature's state machine.

```yaml
- term: "Interaction Mode"
  aliases: ["interaction type", "interaction pattern", "input method", "input mode", "UI mode", "交互方式", "交互模式"]
  disambiguation_required: true
  definition: "The primary user interaction pattern at a journey touchpoint, drawn from the closed vocabulary: click, form, drag, keyboard, scroll, hover, swipe, voice, scan. If a touchpoint has multiple modes, record only the primary one; sub-mode details belong to the feature's Interaction State Machine. Free-form descriptions are invalid."
  see_also: ["Touchpoint", "Feature"]
```

---

## `Feature` vs `requirement` vs `story` vs `capability`

**Why disambiguate.** Users say "feature", "story", "requirement", "capability" interchangeably, but in this skill Feature has a very specific shape: `features/F-NNN-{slug}.md`, self-contained, with sections for Context, User Stories, Journey Context, Requirements, Acceptance Criteria, Interaction Design (when user-facing), Edge Cases, Dependencies, etc. A standalone user story or a one-line requirement is NOT a Feature — it is content that belongs INSIDE a Feature leaf.

```yaml
- term: "Feature"
  aliases: ["capability", "user story", "功能", "特性", "需求项"]
  disambiguation_required: true
  definition: "A self-contained product capability stored as features/F-NNN-{slug}.md. Contains Context, User Stories, Journey Context, Requirements, Acceptance Criteria (Given/When/Then), Interaction Design (user-facing only), Edge Cases, Dependencies, Analytics, and Implementation Notes. Must map back to at least one journey touchpoint. A single user story or a one-line requirement is NOT a Feature — it is content inside a Feature."
  see_also: ["Self-Contained Leaf", "Acceptance Criterion", "Touchpoint", "Priority (P0/P1/P2)"]
```

---

## `Module` (PRD reference) vs `Module` (system-design)

**Why disambiguate.** This is the single most dangerous cross-skill term. In **system-design** (downstream skill), Module means an implementation unit with its own `modules/M-NNN-{slug}.md` file. In the PRD domain, Module appears ONLY as a reference (e.g. mentioning a module by ID for traceability) and never as an authored artifact. Writers who treat Module as a PRD-owned concept produce implementation-level leakage (module interfaces, internal data structures, class contracts) — this is scope drift into system-design territory and fails review.

```yaml
- term: "Module"
  aliases: ["system module", "component", "service module", "module ref", "M-NNN", "模块"]
  disambiguation_required: true
  definition: "In the PRD domain, Module is a REFERENCE-ONLY concept — PRDs may cite module IDs (M-NNN) for downstream traceability but MUST NOT author module specs. Authoring M-NNN-*.md files is the exclusive job of the system-design skill. Writing module interfaces, internal data structures, or class contracts inside a PRD is scope drift and fails review."
  see_also: ["Feature", "PRD"]
```

---

## `Persona` vs `user` vs `role` vs `actor`

**Why disambiguate.** "User" and "role" are too generic — "role" also collides with the authorization-model concept (Admin/Member/Viewer). Persona in the PRD domain is a named archetype (e.g. "Solo Founder", "Ops Engineer") with demographics, goals, and frustrations, declared in `README.md` and referenced consistently across journeys. An authorization role (Admin) is NOT a persona; a raw "user" without a named archetype is NOT a persona.

```yaml
- term: "Persona"
  aliases: ["user persona", "target user", "user archetype", "customer persona", "actor", "用户画像", "目标用户"]
  disambiguation_required: true
  definition: "A named user archetype declared in README.md with demographics, goals, and frustrations. Referenced by name in every Journey's Persona header and in Feature user stories ('As a <persona>...'). Distinct from 'role' in the authorization-model sense (Admin/Member/Viewer) — those are access-control roles, not personas. Persona names must be consistent across all journeys and features."
  see_also: ["Journey", "Feature"]
```

---

## `Cross-Journey Pattern` vs `theme` vs `shared concern`

**Why disambiguate.** Users say "theme", "shared concern", "recurring issue", "common pattern" — these are imprecise. Cross-Journey Pattern in this skill is a **structural section in the README.md index** with a required "Addressed by Feature" column. Every pattern listed MUST be addressed by at least one feature; orphan patterns (no addressing feature) fail the journey-to-feature coverage check.

```yaml
- term: "Cross-Journey Pattern"
  aliases: ["cross journey pattern", "journey pattern", "shared concern", "recurring theme", "common pattern", "跨旅程模式", "共性问题"]
  disambiguation_required: true
  definition: "A recurring theme observed across multiple journeys — shared pain points, repeated touchpoints, common infrastructure needs, or persona handoffs. Documented in the README.md Cross-Journey Patterns section with a required 'Addressed by Feature' column. Every pattern MUST be addressed by at least one feature; orphan patterns fail journey-to-feature coverage review."
  see_also: ["Journey", "Feature"]
```

---

## `Design Token` vs `style variable` vs `CSS variable`

**Why disambiguate.** "Style variable" and "CSS variable" refer to the implementation; "design token" is the semantic-level construct. The PRD **defines token semantics and values** (names like `color.primary`, `spacing.md`); system-design defines the implementation mechanism (CSS custom properties, Tailwind config, terminal constants). PRDs that reference raw values (`#0066FF`, `16px`) instead of tokens fail the design-token semantic-naming check. Tokens MUST use semantic names, never raw values.

```yaml
- term: "Design Token"
  aliases: ["token", "design variable", "style token", "theme token", "UI token", "设计令牌", "设计变量"]
  disambiguation_required: true
  definition: "A named value (color, typography, spacing, motion, radius, shadow, breakpoint, z-index) representing a design decision. PRD defines token semantics and values (e.g. color.primary.500, spacing.md, motion.duration.fast); system-design defines the implementation mechanism. Features MUST reference tokens by semantic name — raw values (#0066FF, 16px) in feature specs fail review."
  see_also: ["Feature"]
```

---

## `Acceptance Criterion` vs `test case` vs `requirement`

**Why disambiguate.** "Test case" is a QA artifact written by QA engineers; "requirement" is too generic. Acceptance Criterion in the PRD domain is a Given/When/Then statement on a Feature leaf that is **testable and measurable**. Non-behavioral criteria (performance, resource, concurrency, security, degradation) are allowed but each MUST still be verifiable. Vague criteria ("should be fast") fail the testable-criteria LLM check.

```yaml
- term: "Acceptance Criterion"
  aliases: ["acceptance criteria", "AC", "acceptance test", "test criterion", "success criterion", "验收标准", "验收条件"]
  disambiguation_required: true
  definition: "A testable, measurable statement on a Feature leaf written in Given/When/Then form (behavioral) or as a specific numeric/boundary specification (non-behavioral: performance, resource, concurrency, security, degradation). Every acceptance criterion MUST map to at least one automated test. Vague wording ('should be fast', 'user-friendly', 'works well') fails review. Distinct from a QA test case, which is the downstream implementation."
  see_also: ["Feature", "Edge Cases"]
```

---

## `Priority (P0/P1/P2)` vs `severity` vs `importance`

**Why disambiguate.** "Severity" is a bug-tracking term (blocker/critical/major/minor); "importance" is informal. Priority in the PRD domain is a closed set — `P0` (must-have for MVP), `P1` (should-have, next iteration), `P2` (nice-to-have, future) — and every Feature MUST declare one with a rationale. Bare priority values without rationale fail the priority-rationale LLM check.

```yaml
- term: "Priority (P0/P1/P2)"
  aliases: ["priority", "P0", "P1", "P2", "must-have", "should-have", "nice-to-have", "MVP priority", "优先级"]
  disambiguation_required: true
  definition: "A closed-set priority tag on every Feature: P0 (must-have for MVP, release-blocking), P1 (should-have, next iteration), P2 (nice-to-have, future / stretch). Every Feature MUST declare priority in its header AND provide a one-line rationale (why this priority, what would change it). Bare priority values without rationale fail review. Distinct from bug severity (blocker/critical/major/minor) which is a defect-tracking concept."
  see_also: ["Feature"]
```

---

## `NFR` vs `non-functional requirement` vs `constraint`

**Why disambiguate.** "Constraint" and "quality attribute" are often used interchangeably with NFR but have subtly different scopes. NFR in the PRD domain means a cross-cutting quality requirement documented in `architecture/nfr.md` with an ID (`NFR-NNN`), category (Performance, Security, Scalability, Reliability, Observability, Accessibility, i18n, Deployment), and a measurable target. Features reference relevant NFRs in their non-behavioral acceptance criteria. Omitting applicable NFR categories (e.g. Performance for a real-time feature) fails the NFR-coverage LLM check.

```yaml
- term: "NFR"
  aliases: ["non-functional requirement", "non functional requirement", "quality attribute", "quality requirement", "constraint", "cross-cutting requirement", "非功能需求", "质量属性"]
  disambiguation_required: true
  definition: "A cross-cutting quality requirement stored in architecture/nfr.md with ID (NFR-NNN), category (Performance, Security, Scalability, Reliability, Observability, Accessibility, Internationalization, Deployment), and a measurable target. Features cite relevant NFRs in their non-behavioral acceptance criteria. Applicable NFR categories MUST be covered — omitting Performance for a real-time feature or Security for an auth feature fails review."
  see_also: ["Acceptance Criterion", "Feature"]
```

---

## `Tombstone` (evolve-mode only)

**Why disambiguate.** "Tombstone" is a borrowed database term and users often don't recognize it. In evolve-mode PRDs, a Tombstone is a minimal Feature or Journey leaf that marks the item as deprecated — it contains status, deprecation reason, optional replacement reference, and a link back to the original in the baseline PRD. Tombstones are ONLY produced by `--evolve` mode; never write a tombstone in FromScratch or `--revise` mode.

```yaml
- term: "Tombstone"
  aliases: ["deprecated marker", "deprecation stub", "deprecation tombstone", "deleted feature stub", "墓碑", "弃用标记"]
  disambiguation_required: true
  definition: "A minimal feature or journey leaf used in evolve-mode ONLY to mark the item as deprecated. Contains: status (deprecated / replaced / removed), deprecation reason, optional replacement reference (e.g. 'replaced by F-042'), and a link to the original in the baseline PRD. FORBIDDEN in FromScratch and --revise modes. Distinct from outright deletion — tombstones preserve the historical ID so downstream consumers can still resolve F-NNN references."
  see_also: ["Feature", "Journey", "PRD"]
```

---

## `Self-Contained Leaf` vs `single file` vs `standalone doc`

**Why disambiguate.** "Single file" and "standalone doc" are weaker than self-contained — a file can be single but still cross-reference external files for context. A Self-Contained Leaf in this skill means a leaf file where **all referenced context (data models, conventions, journey context, dependency descriptions) is COPIED INLINE** — a coding agent can read only that one file and implement correctly without opening any other file. Leaf files that use "see architecture.md" or "refer to J-003 for context" are NOT self-contained and fail the self-contained-file LLM check.

```yaml
- term: "Self-Contained Leaf"
  aliases: ["self contained leaf", "self-contained file", "standalone leaf", "atomic leaf", "leaf file", "叶子文件", "自包含文件"]
  disambiguation_required: true
  definition: "A leaf file (feature / journey / architecture topic) where ALL referenced context — data models, conventions, journey context, dependency descriptions — is COPIED INLINE rather than cross-referenced. A coding agent reading only that file can implement correctly without opening any other file. MUST stay under 300 lines. Phrases like 'see architecture.md', 'refer to J-003', 'follow conventions in coding-conventions.md' violate the self-contained principle and fail review."
  see_also: ["Feature", "Journey", "PRD"]
```

---

## Quality Bar — Entry Format (DO / DON'T)

This glossary is consumed by `glossary-probe.sh` and by the domain-consultant sub-agent. Each entry must follow the shape above so that (a) `grep` on `aliases` reliably fires the disambiguation path, and (b) the domain-consultant has a sharp one-sentence definition plus cross-references to pin the user's intent.

**DO — a complete, well-formed entry:**

```yaml
- term: "Feature"
  aliases: ["capability", "user story", "功能"]
  disambiguation_required: true
  definition: "A self-contained product capability stored as features/F-NNN-{slug}.md with Context, User Stories, Requirements, Acceptance Criteria, Interaction Design, Edge Cases, Dependencies. Must map back to at least one journey touchpoint."
  see_also: ["Self-Contained Leaf", "Touchpoint"]
```

**DON'T — an underspecified entry:**

```yaml
- term: "feature"
  definition: "A thing the product does."
```

Why the DON'T form fails: aliases missing (so `glossary-probe.sh` only matches the exact word "feature"), `disambiguation_required` flag omitted (so the probe cannot know whether to trigger the domain-consultant path), definition is too vague to pin PRD-specific meaning vs. implementation-level meaning, and `see_also` is missing (so related terms like Self-Contained Leaf and Touchpoint go unlinked).

**DO** also group terms into ambiguity clusters (one H2 per cluster) and open each cluster with a **"Why disambiguate."** paragraph that names the specific failure mode the disambiguation prevents — this is what turns the glossary from a list of definitions into an operational tool that improves clarification quality.
