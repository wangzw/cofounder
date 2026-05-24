# Criterion Categories — prd-analysis

This file is the **single source of truth** for criterion-to-category mapping. The
`category:` field on every `checker_type: llm` entry in `common/review-criteria.md`
MUST match a category defined here. `scripts/check-criteria-categories.sh` enforces
this consistency.

Categories are the grouping dimension used by:

- `review/index.md` Step 2 — cross-reviewer fan-out (one cluster per category)
- `revise/index.md` Step 2 — per-issue-reviser grouping (one cluster per criterion;
  category is auxiliary metadata for prompt context)
- LLM sub-agent prompts — reviewer/reviser receive the category description so they
  can focus their attention on one conceptual surface at a time

---

## Categories

### `traceability`

Goal → Journey → Touchpoint → User Story → Feature → Analytics chain integrity.
Includes orphan-feature detection, dangling-id references, persona-journey coverage.

**Typical fix pattern:** add a missing reference; relocate a feature under the correct
journey; insert an analytics event row.

**Typical anti-pattern:** rewriting feature copy to mention a journey without actually
updating the journey-to-feature index.

**Included CR-IDs:** `CR-PP06`.

### `evidence`

Each requirement is grounded in research, competitive context, or explicit assumption.
Metrics are present and tied to features.

**Typical fix pattern:** cite a source for a claim; convert an implicit assumption to an
explicit `## Assumptions` entry; add a competitive comparison row.

**Included CR-IDs:** `CR-PP07`, `CR-PP08`, `CR-PP09`.

### `coherence`

Cross-leaf logical consistency: authorization, state-machine integrity, oscillation
detection, design-token completeness, frontend stack consistency, component contracts,
cross-feature event flow.

**Typical fix pattern:** add a missing state transition; align two leaves that disagree
on a contract; reconcile a duplicated definition; specify a missing component contract.

**Included CR-IDs:** `CR-PP12`, `CR-PP22`, `CR-PP24`, `CR-PP25`, `CR-PP26`, `CR-PP27`.

### `accessibility-i18n`

WCAG baseline, accessibility per feature, i18n baseline, i18n per feature (frontend +
backend).

**Typical fix pattern:** add an `accessibility:` block to a feature; declare i18n keys;
specify locale fallback behavior.

**Included CR-IDs:** `CR-PP28`, `CR-PP29`, `CR-PP30`, `CR-PP31`, `CR-PP32`.

### `interaction-design`

Acceptance criteria testability, e2e scenarios, test data, interaction completeness,
form specification, micro-interactions, journey interaction modes, design tokens,
navigation consistency, page transitions, responsive coverage, notifications.

**Typical fix pattern:** add a Given/When/Then block; specify form validation rules;
list responsive breakpoints; declare a transition's trigger and duration.

**Included CR-IDs:** `CR-PP15`, `CR-PP16`, `CR-PP17`, `CR-PP18`, `CR-PP19`, `CR-PP20`,
`CR-PP21`, `CR-PP23`, `CR-PP33`, `CR-PP34`, `CR-PP38`, `CR-PP39`.

### `privacy-security`

Privacy compliance hooks, security policy, git branch strategy (security-relevant
defaults).

**Typical fix pattern:** add a `## Privacy` section; specify a security control; declare
a branch protection rule.

**Included CR-IDs:** `CR-PP13`, `CR-PP43`, `CR-PP45`.

### `risk-governance`

Risks + mitigation, priority/roadmap alignment, self-containment, coding conventions,
test isolation, development workflow, backward compatibility, code review policy,
observability, performance testing, dev infrastructure, deployment architecture, AI
agent configuration.

**Typical fix pattern:** add a `## Risks` row; align roadmap with feature priority;
document a convention inline; specify an observability requirement; declare a code
review policy.

**Included CR-IDs:** `CR-PP10`, `CR-PP11`, `CR-PP14`, `CR-PP40`, `CR-PP41`, `CR-PP42`,
`CR-PP44`, `CR-PP46`, `CR-PP47`, `CR-PP48`, `CR-PP49`, `CR-PP50`, `CR-PP51`.

### `meta`

Reviewer-only categories for criteria-evolution feedback loop (guide §8). Findings here
are informational; the reviser handles the artifact fix on `CR-META-adversarial`, and a
maintainer reviewing repeated findings under either should consider promoting them into
new formal/substantive criteria.

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.

---

## Notes

- Formal (`checker_type: script`) CR-IDs do NOT carry a category. They are enforced by
  `run-checkers.sh` before any LLM dispatch and never enter a reviewer/reviser cluster.
- A CR that conceptually fits multiple categories takes its **dominant** category.
  Borderline cases should be documented in `common/review-criteria.md` with a comment
  explaining the choice.
- New LLM-type CRs added to `review-criteria.md` MUST also be added to one of the
  categories above. `scripts/check-criteria-categories.sh` will fail otherwise.
