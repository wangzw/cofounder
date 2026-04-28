---
id: R7-V001-003
round: 8
file: common/parallel-dispatch.md
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V001-003 — RESOLVED (with related R8-001 follow-up)

## Original finding (round-7)

`common/parallel-dispatch.md` line 134 cross-referenced `revise/revise-mode.md` Step 5
for fix-subagent dispatch templates, perpetuating the dual-spec drift addressed by
R7-V001-002.

## Verification (round-8 state)

The cited reference at line 134 has been retargeted. `common/parallel-dispatch.md` now
ends with (line 134-135):

> See `review/index.md` Step 2 and `revise/index.md` Step 2 (Fan-out) for the full templates that bake
> these rules in.

Both halves of the cross-reference now point at canonical `index.md` files; neither
points at `revise/revise-mode.md` Step 5. The originally-flagged CR-L11 violation at
line 134 is no longer detectable.

## Class-based scan note (related new issue)

A class-based grep across all seven focus leaves found two additional legacy-revise-mode
references in `common/parallel-dispatch.md` lines 4-5 ("the clustering subagent (revise-mode
Pre-Answered Mode)" / "fix subagents (revise-mode Step 5)") that were not part of the
original R7-V001-003 scope (R7-V001-003 cited only line 134). These remain after the
round-7 revise pass and are filed as a new round-8 issue R8-001 — they perpetuate the
same dual-spec drift class but in the file's introductory paragraph, not in the cited
line. R7-V001-003 itself is resolved; R8-001 carries the follow-up scope.
