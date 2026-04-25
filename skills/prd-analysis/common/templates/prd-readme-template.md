## Template Usage Notes

This template is the structural scaffold for every `<prd-pyramid-root>/README.md` file produced by prd-analysis writers. Read all four notes before filling placeholders.

1. **Every table heading is REQUIRED even if the table body is empty.** If no rows exist yet, add a single `(none yet)` row spanning all columns so the heading is never orphaned. Omit entire sections only if they are genuinely inapplicable to this product (e.g., no cross-journey patterns when only one journey exists).

2. **Every Cross-Journey Pattern MUST list at least one `Addressed by` feature (CR-L11).** A pattern with no addressing feature is a known shared pain point that will produce duplicate work during implementation. If no feature addresses it yet, add a placeholder feature entry before finalizing the README.

3. **The `## MVP Boundary` section is REQUIRED (CR-L04).** It MUST contain explicit impact-vs-effort reasoning — "User impact: ..." not "Engineering convenience: ...". Any feature marked `conditional` in the MVP column of the Feature Index MUST have an "MVP Boundary Note" block inside its leaf file.

4. **Personas, Journey Index, and Feature Index are the canonical index (CR-S11 index-consistency).** Every file under `journeys/` MUST appear in the Journey Index. Every file under `features/` MUST appear in the Feature Index. The reverse also holds: every row in either index table MUST have a corresponding file on disk. The script `scripts/check-index-consistency.sh` enforces this — writers MUST NOT add a leaf file without updating the relevant index row.

---

---
title: {Product Name} PRD
slug: {product-slug}
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
status: draft | accepted | iterating
delivery: {N}
---

# {Product Name} — Product Requirements Document

{1-paragraph product summary: what it is, who uses it, primary value proposition. Write from the user's perspective — what problem does it solve and for whom — not from an engineering perspective.}

## Personas

| Name | Role | Motivation | Success Metric | Journeys |
|------|------|------------|----------------|----------|
| {Persona 1} | {role} | {motivation — why this person needs the product} | {metric — how they measure success, e.g. "completes invoice in < 2 min"} | J-001, J-003 |
| {Persona 2} | {role} | {motivation} | {metric} | J-002 |

(Each persona row maps to the persona's full definition inside the journey files it is listed in. Persona names MUST be consistent with `common/domain-glossary.md` entries — CR-L07.)

## Journey Index

| ID | Title | Persona | Goal | Priority | Feature Count | Status |
|----|-------|---------|------|----------|---------------|--------|
| J-001 | {title} | {persona name} | {goal — what the persona achieves by the end of this journey} | P0 | 5 | accepted |
| J-002 | {title} | {persona name} | {goal} | P1 | 3 | draft |

(Each row links to `journeys/J-NNN-{slug}.md`. Priority uses the same P0/P1/P2 scale as features. Feature Count is the count of features whose `Journeys` cell includes this journey ID. Status ∈ {draft, accepted, iterating, deprecated}. CR-S11: every file in `journeys/` MUST appear here — no orphans, no missing entries.)

## Feature Index

| ID | Name | Priority | MVP | Journeys | Status |
|----|------|----------|-----|----------|--------|
| F-001 | {name} | P0 | in | J-001 | accepted |
| F-002 | {name} | P1 | conditional | J-001, J-002 | draft |
| F-003 | {name} | P2 | out | J-002 | draft |

(Each row links to `features/F-NNN-{slug}.md`. MVP column values: `in` | `out` | `conditional`. A `conditional` entry REQUIRES the feature leaf to have an "MVP Boundary Note" section explaining the condition. CR-S11: every file in `features/` MUST appear here — no orphans, no missing entries.)

## Cross-Journey Patterns

(Each pattern is observed across ≥2 journeys. Per CR-L11, every pattern MUST be addressed by ≥1 feature. If only one journey exists, omit this section with the note "(single journey — no cross-journey patterns apply)".)

### Pattern 1: {Pattern Name}
- **Observed in**: J-001, J-003
- **Description**: {what the pattern is — shared pain point, repeated touchpoint, common infrastructure need, or hand-off between personas}
- **Addressed by**: F-007, F-012

### Pattern 2: {Pattern Name}
- **Observed in**: J-002, J-004
- **Description**: {description}
- **Addressed by**: F-005

## Architecture Topics

| Topic | File | Summary |
|-------|------|---------|
| Tech Stack | architecture/tech-stack.md | {1 sentence describing what is documented} |
| Data Model | architecture/data-model.md | {1 sentence} |
| Design Tokens | architecture/design-tokens.md | {1 sentence} |
| Non-Functional Requirements | architecture/nfrs.md | {1 sentence} |

(Full architecture index lives at `architecture.md`; this table is a navigation shortcut from the README. Every file under `architecture/` MUST appear here — same index-consistency rule as journeys and features.)

## Roadmap

| Delivery | Date | Verdict | Highlights |
|----------|------|---------|------------|
| 1 | YYYY-MM-DD | converged | {brief bullets — features added, journeys added, key decisions made} |
| 2 | YYYY-MM-DD | progressing | {in-progress description} |

(Verdict values match the judge's vocabulary: `converged` | `progressing` | `oscillating` | `diverging` | `stalled`. Leave future deliveries with a `—` verdict until their round is complete.)

## MVP Boundary

{Required section — CR-L04. 1-2 paragraphs. State clearly which features are in the MVP (status: `in`), which are deferred (status: `out`), and which have conditional inclusion criteria (status: `conditional`).}

{Reasoning MUST be grounded in user impact on the core happy-path journeys, NOT engineering convenience. Example: "F-001 through F-004 form the minimal set a user needs to complete J-001 end-to-end. F-005 (bulk export) is deferred because fewer than 10% of target users have inventories large enough to need it in the first 90 days — confirmed by competitor usage data. F-006 (SSO) is conditional: included if the first enterprise pilot customer requires it before GA, otherwise deferred to delivery 3."}

## Glossary

(Domain-specific terms used across leaves of THIS product's PRD pyramid. These are product-domain terms, not skill-internal terms. The skill-level glossary for prd-analysis internal vocabulary lives at `common/domain-glossary.md` — do not duplicate entries from there here unless the product overrides or specializes the meaning.)

| Term | Definition |
|------|------------|
| {term} | {1-2 sentence definition scoped to this product's domain} |

(Use `(none yet)` row if no product-specific terms have been identified yet.)

## Open Questions

- {Question blocking convergence — state what decision is needed and who owns it.}

(Remove this section when all questions are resolved. If questions are resolved mid-delivery, move them to the Change Log with their resolution.)

## Change Log

- YYYY-MM-DD: delivery 1 — initial PRD draft; {N} journeys, {M} features
- YYYY-MM-DD: delivery 2 — {brief description of changes}
