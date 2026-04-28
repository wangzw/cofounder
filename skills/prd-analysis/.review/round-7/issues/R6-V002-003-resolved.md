---
id: R6-V002-003
round: 7
file: review/adversarial-reviewer-subagent.md
criterion_id: CR-L04
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V002-003 — RESOLVED

Original round-6 issue: adversarial-reviewer Issue File Schema used stale `issue_id:` key inconsistent with cross-reviewer's `id:`.

Round-7 verification: Issue File Schema now uses `id: R<N>-<seq>` (line 148) — consistent with cross-reviewer's frontmatter shape. The seq-numbering instruction also matches: "MUST check the highest existing `<seq>` in `round-<N>/issues/` and increment from there — adversarial-reviewer IDs MUST NOT collide with cross-reviewer or script-tier IDs." Cross-reference between the two reviewer prompts is now consistent.
