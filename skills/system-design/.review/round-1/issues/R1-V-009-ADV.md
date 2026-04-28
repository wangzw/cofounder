---
issue_id: R1-V-009-ADV
round: 1
file: revise/per-issue-reviser-subagent.md
criterion_id: CR-L07
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Reviser scope-discipline broken: global-conflict path FORBIDDEN by skill-forge but ENCOURAGED in two places

## Attack angle

Reviser force-fix of global conflicts (skill-forge attack pattern 6). Prompts contradict each other on whether to attempt fixes for `blocker_scope: global-conflict` issues.

## Evidence

`revise/per-issue-reviser-subagent.md` lines 134-142 (correctly hedge):
> For issues with `blocker_scope: global-conflict` escalated to the reviser by the cross-reviewer: **do NOT apply a fix in this dispatch**. The per-leaf reviser scope is structurally incapable of resolving cross-artifact conflicts. Instead:
> 1. Emit a meta-issue at `<design-dir>/.reviews/issues/<new-issue-id>.md` with `criterion_id: CR-META-skip-violation` ...
> 2. Return `FAIL trace_id=R3-R-002 reason=global-conflict-requires-cross-artifact-pass`.

This is correct. But three conflicts:

1. **The output path is wrong.** `<design-dir>/.reviews/issues/...` — `.reviews/` is the user-facing directory; `--review` and `--revise` write directly to `.reviews/REVIEW-<NNN>.md` (no `issues/` subdirectory per `review/index.md` Step 4a, line 99). The path the prompt prescribes does not exist anywhere else in the skill. Revise-mode meta-issues will be lost.

2. **Returning `FAIL` for a global-conflict contradicts the IPC contract.** The Snippet D contract (writer-subagent.md lines 53-72, repeated in this file lines 53-72) explicitly says:
   > `FAIL` ACK covers technical failures only:
   > - Write tool call denied by sandbox
   > - Prompt parse error / input so corrupted no leaf could be produced
   > - Timeout with zero writes completed

   And:
   > Self-review FAIL rows do NOT trigger `FAIL` ACK. ... Mixing `FAIL` ACK with self-review FAIL rows is the §11.2 core anti-pattern.

   A "global-conflict requires cross-artifact pass" is NOT a technical failure — it is a scope-external blocker that the skill-forge contract says MUST return `OK ... self_review_status=PARTIAL`. The reviser's instruction to return `FAIL trace_id=... reason=global-conflict-requires-cross-artifact-pass` is exactly the §11.2 anti-pattern.

3. **The reviser is told it has only `reviser` role's IPC mapping**. The role table (lines 27-34) shows reviser has 1 write: `<artifact-path>` (updated artifact leaf). Writing a meta-issue file is OUT of the reviser's permitted write surface. The orchestrator-side validation should reject the write — but if it doesn't, the reviser silently exceeds its role.

## Severity reasoning

`important`: when a global-conflict actually fires, the reviser will hit a path that doesn't exist and return a `FAIL` ACK that the orchestrator interprets as a technical failure. §16 retry policy will re-dispatch up to 3× with exponential backoff before giving up. The user sees three failed retries and an unhelpful `FAIL` ACK — they have no concrete recovery path because the meta-issue never got written.

## Fix

1. Replace the global-conflict instruction (lines 134-142) with the canonical pattern:

   ```
   For issues with `blocker_scope: global-conflict`:
   - Do NOT apply a fix.
   - Append a row to your dispatch's reviser self-review (write to
     `<design-dir>/.review/round-<N>/self-reviews/<trace_id>.md`) with:
     `- CR-<id>: FAIL — blocker_scope: global-conflict — note: <one-line>`
   - Return `OK trace_id=<id> role=reviser linked_issues=<original-issue-id> self_review_status=PARTIAL fail_count=1`
   - The orchestrator will surface the unresolved global-conflict issue to HITL.
   ```

2. Remove the `<design-dir>/.reviews/issues/` path from the prompt — that directory does not exist by convention and the meta-issue file is unnecessary if the self-review FAIL row carries the same information.

3. Update the role-mapping table (lines 27-34) to reflect 2 writes for reviser: the artifact + the self-review (if applicable to revise mode). OR keep 1 write but rely on REVISIONS.md as the audit trail and document explicitly that the reviser has no self-review archive.
