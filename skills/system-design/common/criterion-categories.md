# Criterion Categories — system-design

This file is the **single source of truth** for criterion-to-category mapping for the
system-design skill. The `category:` field on every `checker_type: llm` entry in
`common/review-criteria.md` MUST match a category defined here.
`scripts/check-criteria-categories.sh` enforces this consistency.

Categories are the grouping dimension used by:

- `review/index.md` Step 2 — cross-reviewer fan-out (one cluster per category)
- `revise/index.md` Step 2 — per-issue-reviser grouping (one cluster per criterion;
  category is auxiliary metadata for prompt context)
- LLM sub-agent prompts — reviewer/reviser receive the category description so they
  can focus their attention on one conceptual surface at a time

---

## Categories

### `module-boundary`

Module cohesion, dependency direction rationale, boundary enforcement justification.
What belongs in which module and why; how modules depend on each other.

**Typical fix pattern:** move a responsibility to the correct module; justify a
direction-of-dependency arrow; specify boundary-enforcement mechanism (interface,
contract, ACL).

**Typical anti-pattern:** introducing a circular dependency to "make it work" without
addressing the design smell.

**Included CR-IDs:** `CR-SD-DESIGN01`, `CR-SD-DESIGN02`, `CR-SD-DESIGN03`.

### `data-model`

Data model normalization, schema integrity at the LLM tier (cross-module consistency
of types and relations).

**Typical fix pattern:** normalize a duplicated entity definition; promote a value-
typed field to a referenced entity; declare a foreign-key relation.

**Included CR-IDs:** `CR-SD-DESIGN04`.

### `api-contract`

API versioning strategy, contract evolution, breaking-change handling.

**Typical fix pattern:** add a versioning header convention; specify deprecation
window; declare a contract evolution policy.

**Included CR-IDs:** `CR-SD-DESIGN05`.

### `failure-modes`

Failure-mode coverage, error propagation paths, fallback behavior, partial-failure
modeling.

**Typical fix pattern:** add a failure-mode row to a module spec; specify retry/
timeout policy; declare a fallback path.

**Included CR-IDs:** `CR-SD-DESIGN06`.

### `observability`

Logging, metrics, tracing coverage at module boundaries and API surfaces.

**Typical fix pattern:** add a metric to a module's `## Observability` section;
declare a span name for a critical operation; specify a structured log shape.

**Included CR-IDs:** `CR-SD-DESIGN07`.

### `security`

Threat model coverage, secret handling, authentication/authorization at module
boundaries.

**Typical fix pattern:** add a threat-model row; specify a secret store; declare
an authz check at a module boundary.

**Included CR-IDs:** `CR-SD-DESIGN08`.

### `ui-promotion`

UI promotion action sets, hardening coverage, cross-journey-to-module coverage.

**Typical fix pattern:** add a promotion action set row; declare a hardening control;
trace a journey touchpoint to its supporting module.

**Included CR-IDs:** `CR-SD-DESIGN09`, `CR-SD-DESIGN10`, `CR-SD-DESIGN11`.

### `meta`

Reviewer-only categories for criteria-evolution feedback loop (guide §8). Findings
here are informational on `CR-META-mechanize`; the reviser handles the artifact fix on
`CR-META-adversarial`. A maintainer reviewing repeated findings under either should
consider promoting them into new formal/substantive criteria.

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
