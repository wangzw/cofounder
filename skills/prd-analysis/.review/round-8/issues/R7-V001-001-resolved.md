---
id: R7-V001-001
round: 8
file: revise/index.md
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V001-001 — RESOLVED

## Original finding (round-7)

`revise/index.md` Step 1 declared `bash scripts/group-revise-issues.sh <target> <N>` and
"all of this is delegated to `scripts/group-revise-issues.sh`", but the script did not
exist on disk. Cross-reference contract failure (CR-L11).

## Verification (round-8 state)

The named-script reference has been removed. `revise/index.md` Step 1 now reads
(lines 11-17):

> ### Step 1 — Build Issue-Group Manifest (script)
>
> The orchestrator delegates issue grouping to a deterministic grouping script — no LLM-tier
> analysis permitted here (§5.1 pure-dispatch). The grouping script reads
> `<target>/.review/round-<N>/issues/` (frontmatter only), filters to open statuses ...

And lines 44-47:

> > **Infrastructure note**: the grouping script is a required infrastructure component. If it is
> > not yet present in `scripts/`, this step cannot execute and must be escalated as a HITL
> > blocker. The orchestrator MUST NOT fall back to inline grouping ...

And lines 95-97:

> The orchestrator MUST NOT evaluate issue status, group issues, or decide fan-out shape — all
> of this is delegated to the grouping script.

Class-based grep across all seven focus leaves for `group-revise-issues` returns zero
matches; the originally-cited specific filename has been replaced with a generic
"deterministic grouping script" contract plus an explicit HITL-escalation note when the
script is absent.

The original CR-L11 violation pattern (a stated contract referencing an implementation that
does not exist) is no longer detectable: the contract no longer names a specific path, and
the absence of the script is now declared as a known infrastructure gap with a defined
escalation path rather than a silent dangling reference.

## Notes

The grouping script itself is still missing on disk (`ls scripts/group-revise-issues.sh`
returns "No such file or directory"), but this is now an acknowledged infrastructure gap
rather than a cross-reference inconsistency. The acknowledgement plus HITL-escalation rail
is sufficient to clear the original CR-L11 issue. Whether to author the script is a
separate scaffolding-ownership decision outside the cross-reviewer scope.
