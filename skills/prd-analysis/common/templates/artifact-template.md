# Artifact Template Index — prd-analysis

This file is the canonical entry point for all artifact templates produced by prd-analysis. It
describes the template family, routes the writer to the correct template by file class, and states
the self-containment rules that every artifact must satisfy regardless of template used.

**Planner note**: When emitting a `plan.md` `add[]` entry for a prd-analysis artifact file, the
`template` field MUST point to the specific template below that matches the file's class — NOT to
this index file. This index is for navigation only; writers must read the leaf template directly.

---

## Template Family

| File Class | Template Path | When to Use |
|------------|--------------|-------------|
| PRD README (from-scratch) | `common/templates/prd-template.md` | The top-level `README.md` at the PRD output root. Authored in from-scratch and new-version generate modes. Contains product overview, persona table, journey index, feature index, cross-journey patterns, roadmap, and design token summary. |
| Journey spec | `common/templates/journey-template.md` | One file per user journey under `journeys/J-{NNN}-{slug}.md`. Documents persona, stage-by-stage touchpoints, pain points, and feature derivation table for that journey. |
| Feature spec | `common/templates/feature-template.md` | One file per feature under `features/F-{NNN}-{slug}.md`. Self-contained implementation spec: header, goal, actors, state machine, acceptance criteria, data model snapshot, design tokens, dependencies, and open questions. |
| Architecture index + topics | `common/templates/architecture-template.md` | Two-level structure: `architecture.md` (index, ~50–80 lines) + topic files under `architecture/` (tech-stack, design-tokens, navigation, accessibility, i18n, state, data-flow, error-handling, testing). Each topic file is self-contained. |
| Evolve-mode PRD README | `common/templates/evolve-readme-template.md` | The `README.md` for an incremental (evolved) PRD directory. References a predecessor PRD as baseline, annotates changed/added/removed/unchanged items, and provides a complete mixed index. |

---

## Self-Containment Rules (apply to every artifact)

Every output file produced from the templates above MUST satisfy all of the following:

1. **No cross-file references for implementation**: A coding agent reading a single feature spec
   must have everything it needs to implement that feature without opening a second file. If a
   convention, data model field, or architecture decision is needed by a feature, copy the
   relevant text inline — do not write "see `architecture/tech-stack.md`".

2. **Data model inline**: Any field or entity the feature reads or writes must be reproduced in
   the feature's "Data Model Snapshot" section — even if the same entity appears in another
   feature file. Duplication across files is correct; omission is not.

3. **Design tokens inline**: If the feature references a design token (color, spacing, motion),
   that token's name and value must appear inline in the feature file, not as a reference to
   `architecture/design-tokens.md`.

4. **No placeholder sections**: A file with empty sections or `<!-- TBD -->` content fails
   CR-PP14 (self-containment) and CR-PP04 (no-tbd-placeholders). Every section
   either has substantive content or is omitted entirely.

5. **IPC envelope prohibition**: Artifact files MUST NOT contain any HTML-comment IPC envelopes
   (`<!-- metrics-footer -->`, `<!-- self-review -->`, `<!-- DOMAIN_FILL -->`, `<!-- Writer: ... -->`).
   All process metadata goes to `.review/` archive files only.

---

## Anti-Patterns

**BAD — cross-reference instead of inline copy**:

```markdown
## Data Model
See `architecture/data-model.md` for the User entity schema.
```

**GOOD — inline copy**:

```markdown
## Data Model Snapshot
User: { id: uuid, email: string, role: enum(admin|member|viewer), created_at: timestamp }
```

---

**BAD — IPC envelope in artifact body**:

```markdown
<!-- DOMAIN_FILL: populated by writer-subagent during round 1 -->
<!-- Writer: describe the artifact's section layout -->
```

**GOOD — no HTML-comment metadata in artifact body at all**. Placeholders belong in templates
only; the written artifact must contain realized content.

---

**BAD — empty section retained**:

```markdown
## Open Questions

<!-- Writer: list open questions here -->
```

**GOOD — omit the section if empty, or populate it**:

```markdown
## Open Questions

- Q1: Should the bulk-import feature support XLS in addition to CSV? Owner: PM. Due: 2025-06-01.
```

---

## Routing Decision Tree

```
Is this the top-level README.md for a from-scratch or new-version PRD?
  YES → use common/templates/prd-template.md

Is this a journey file (journeys/J-*.md)?
  YES → use common/templates/journey-template.md

Is this a feature file (features/F-*.md)?
  YES → use common/templates/feature-template.md

Is this an architecture index or architecture topic file?
  YES → use common/templates/architecture-template.md

Is this the README.md for an evolve-mode PRD?
  YES → use common/templates/evolve-readme-template.md

None of the above?
  → set template: null in plan.md and derive structure from clarification.yml context
```

---

## ID Conventions (shared across templates)

- Features: `F-001`, `F-002`, ... (zero-padded, sequential, stable across iterations — never renumber)
- Journeys: `J-001`, `J-002`, ...
- Architecture topics: no ID prefix — named by topic (`tech-stack`, `design-tokens`, etc.)

These IDs appear in every cross-reference within the PRD (e.g., a journey's feature derivation
table references `F-001`). Writers MUST use the IDs assigned in the planner's `plan.md`; they
MUST NOT assign new IDs unilaterally.
