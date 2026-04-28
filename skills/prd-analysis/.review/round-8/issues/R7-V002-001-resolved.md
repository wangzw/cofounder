---
id: R7-V002-001
round: 8
file: generate/writer-subagent.md
criterion_id: CR-L11
severity: error
source: adversarial-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V002-001 — RESOLVED

## Original finding (round-7)

`generate/writer-subagent.md` line 252-253 instructed writers that Interaction Mode
MUST be one of a 10-value list including `long-press`, but the project glossary,
journey-template, and per-issue-reviser-subagent.md all declared a fixed 9-value
vocabulary that did NOT include `long-press`. Writers obeying the writer prompt
would emit `long-press` touchpoints that the reviser was forbidden from preserving.
Cross-reference inconsistency (CR-L11) — vocabulary drift across four artifacts.

## Verification (round-8 state)

`generate/writer-subagent.md` lines 252-253 now read:

> Interaction Mode MUST be one of: `click`, `form`, `drag`, `swipe`, `keyboard`,
> `scroll`, `hover`, `voice`, `scan`.

That is exactly the 9-value glossary set: `click`, `form`, `drag`, `keyboard`,
`scroll`, `hover`, `swipe`, `voice`, `scan`. `long-press` has been removed.

A class-based grep across all seven focus leaves for `long-press` (and `long_press`)
returns zero matches. The vocabulary now agrees with the
`revise/per-issue-reviser-subagent.md` lines 96-99 invariant ("Interaction mode
values MUST be drawn exclusively from the project Glossary vocabulary: click, form,
drag, keyboard, scroll, hover, swipe, voice, scan") which is also in the focus set.

The other two references cited in R7-V002-001 (`common/domain-glossary.md` and
`common/templates/journey-template.md`) are in `cross_reviewer_skip`; per skip-set
discipline they were not opened. Both are scaffold-pure (per scaffold-provenance.yml
sha-match), so they retain the 9-value vocabulary that aligned with the original
finding.

The CR-L11 vocabulary-drift violation is no longer detectable.
