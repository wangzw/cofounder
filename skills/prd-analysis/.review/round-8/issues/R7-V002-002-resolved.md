---
id: R7-V002-002
round: 8
file: revise/per-issue-reviser-subagent.md
criterion_id: CR-L07
severity: error
source: adversarial-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V002-002 — RESOLVED

## Original finding (round-7)

`revise/per-issue-reviser-subagent.md` "Revision Discipline" lines 187-190 instructed
the reviser to apply a fix in-place for `blocker_scope: global-conflict` issues
("apply the fix scoped to this leaf only … create a companion issue for that leaf"),
contradicting the writer-subagent's §11.2 contract that global-conflict is
scope-external to single-leaf scope. The reviser had no more cross-artifact authority
than the writer that produced the FAIL row, so the prior language assigned the reviser
an unfulfillable contract — the role-boundary inversion CR-L07 catches.

## Verification (round-8 state)

`revise/per-issue-reviser-subagent.md` Revision Discipline section now reads
(lines 184-194):

> - For issues with `blocker_scope: global-conflict` escalated by the cross-reviewer: **do NOT
>   apply a fix in this dispatch**. The per-leaf reviser scope is structurally incapable of
>   resolving cross-artifact conflicts — the reviser has the same single-leaf scope as the
>   writer that originally punted with `blocker_scope: global-conflict`. Instead:
>     1. Emit a meta-issue at `<target>/.review/round-<N>/issues/<new-issue-id>.md` with
>        `criterion_id: CR-META-skip-violation`, `severity: critical`, and a body that
>        references the original global-conflict issue ID.
>     2. Return `FAIL trace_id=<id> reason=global-conflict-requires-cross-artifact-pass`.
>   Global conflicts are resolved only via HITL escalation or a dedicated cross-artifact
>   resolution pass. Adversarial-reviewer attack angle #6 (CR-L07 reviser-scope-discipline)
>   flags any reviser language that encourages "fixing it anyway" in single-leaf scope.

This matches the suggested-fix shape in R7-V002-002 nearly verbatim:
- "do NOT apply a fix in this dispatch" instead of "apply the fix scoped to this leaf only".
- Emit `CR-META-skip-violation` (not a companion issue with the same criterion_id).
- Return `FAIL` ACK rather than `OK` with a side-issue.
- Explicit citation of CR-L07 reviser-scope-discipline as the governing rule.

The CR-L07 role-boundary-inversion anti-pattern is no longer present in the file. The
posture (refuse + meta-issue + FAIL ACK) now mirrors the existing Skeleton-Protection
Protocol pattern (lines 156-174), as suggested in R7-V002-002.
