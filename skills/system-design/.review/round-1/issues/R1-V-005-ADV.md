---
issue_id: R1-V-005-ADV
round: 1
file: shared/judge-subagent.md
criterion_id: CR-L11
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Judge convergence gate is unreachable: requires `error_count == 0` but generate-mode has no reviser pass

## Attack angle

Convergence cliff. The hard-converged conditions (judge-subagent.md lines 117-124) require six counters all zero; combined with from-scratch's missing reviser-fan-out step (R1-V-003-ADV), this skill cannot emit `verdict: converged` on any non-trivial design. Round 1 issues are filed by reviewers, never closed by revisers, so round 1's `error_count` stays > 0 forever, judge keeps emitting `progressing`, then `stalled` at round 5. Every generate-mode run terminates as `hitl`.

## Evidence

`shared/judge-subagent.md` lines 117-124 (hard converged):
- `sum(fail_count where role=writer, this round)` == 0
- `coverage_percent` == 100
- `critical_count` == 0
- `error_count` == 0
- `regressed_count` == 0
- `open_issues` == 0

The summarizer's frontmatter (`shared/summarizer-subagent.md` lines 134-138) defines `critical_count`, `error_count` as "open count where severity=critical/error" — i.e. status ∈ {new, persistent, regressed}.

For `error_count == 0` to hold, every error-severity issue raised in round 1 (or earlier) must reach status `resolved`. That requires the reviser to consume the issue, fix the artifact, and re-classify the issue's status. But:

- `from-scratch.md` Step 8 → 9 → 10 → 11 → 12 has NO reviser dispatch step.
- Step 9 (lint pre-pass) text DOES mention `→ spawn reviser sub-agents` for blocker lint issues only.
- Step 10's cross-reviewer + adversarial-reviewer file `error`-severity issues. No subsequent step fixes them.
- Step 12 judge sees `error_count > 0` → emits `progressing` → orchestrator "loops from Step 8".
- Step 8 re-runs the writer fan-out, which produces NEW artifact bodies (writers don't read prior issue files — verified at writer-subagent.md lines 99-107). The writers may even regress the very issues round 1 closed.

Without an explicit Reviser-fan-out-fix-issues step inside the round loop, the judge condition `error_count == 0` is unreachable for any design with ≥ 1 CR-D* finding.

## Severity reasoning

`important` (could-break-prod) rather than `blocker`: a user can manually invoke `--revise` to break the cycle, BUT the FromScratch pipeline as documented promises an automatic delivery commit on convergence. That promise is unfulfillable.

## Fix

Insert a dedicated reviser step in `from-scratch.md` between Step 10 (cross + adversarial review) and Step 11 (summarizer). It MUST:

1. Read all `round-N/issues/*.md` with `status ∈ {new, persistent, regressed}`.
2. Group by `file:` field (one reviser per affected leaf).
3. Dispatch `revise/per-issue-reviser-subagent.md` for each group with model: balanced.
4. Wait for all reviser ACKs.
5. Re-run `scripts/run-checkers.sh` (re-validate lint after revisions).
6. Re-run cross + adversarial reviewer in "delta mode" against modified files only. Reviewers MUST update issue `status` to `resolved` for issues no longer detectable.
7. Loop steps 1-6 until iteration cap or zero open issues.

Equivalently: align the from-scratch sequence with the legacy review→revise→re-review pattern that `revise/index.md` already specifies for `--revise` mode.

Also: clarify what `regressed` issue detection looks like inside generate-mode round-N when no `round-(N-1)` exists. Currently the cross-reviewer prompt (lines 162-174) describes "compare against round N-1 issues" but in round 1 there is no N-1. Fine — but spell out the bootstrapping rule explicitly so a sub-agent does not silently drop the persistence check.
