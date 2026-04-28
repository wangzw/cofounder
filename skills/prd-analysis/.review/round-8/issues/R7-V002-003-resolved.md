---
id: R7-V002-003
round: 8
file: revise/per-issue-reviser-subagent.md
criterion_id: CR-L11
severity: error
source: adversarial-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V002-003 — RESOLVED

## Original finding (round-7)

`revise/per-issue-reviser-subagent.md` lines 184-186 cited a `revise/index.md` Step 5
"batch-by-file" procedure as binding orchestration context, but `revise/index.md` only
defines Steps 1–4. The actual "Step 5" content lived in `revise/revise-mode.md` (the
legacy interactive document), so the reference was either dangling or silently routing
the reviser to the wrong orchestration model. CR-L11 cross-reference inconsistency.

## Verification (round-8 state)

A class-based grep across all seven focus leaves for `revise/index.md.*Step 5` and
`Step 5 batch-by-file` returns zero matches. The reviser-subagent's Revision Discipline
section now contains:

- Lines 180-183: General fix-scope discipline ("Fix ONLY what the issue text describes …
  Read every issue body before applying any fix … Preserve unrelated content exactly").
- Lines 184-194: The global-conflict refusal protocol (R7-V002-002 fix), citing
  CR-L07 reviser-scope-discipline.

The line 184-186 dangling "Step 5" reference has been removed entirely; no replacement
"Step 5" reference is needed because the canonical orchestration context (per-leaf scope,
all open issues for that leaf, single write) is already stated in the file's Role line
45-47 ("Scoped to ONE artifact leaf per dispatch. Reads all open issues for that leaf,
applies fixes, and writes the revised leaf") — exactly the redundancy R7-V002-003
suggested as the cleanest fix path.

The CR-L11 dangling-step reference is no longer detectable.

## Cross-link with R7-V001-002 / R7-V001-003

R7-V001-002 (SKILL.md → revise-mode.md) and R7-V001-003 (parallel-dispatch.md line 134 →
revise-mode.md Step 5) were both resolved by retargeting the references to
`revise/index.md`. R7-V002-003 (this issue) was on the asymmetric reviser-side cross-
reference; it was resolved by deleting the legacy reference outright rather than
retargeting, which is the cleaner outcome (no cross-reference is needed when the binding
orchestration context is already in the same file's Role section).
