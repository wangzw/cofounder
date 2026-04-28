# Revise Mode — Orchestration

This file is loaded by the orchestrator when mode = `--revise` (or after a review phase that
produced critical/error issues). It defines the revise loop the orchestrator follows. It is
**not** a sub-agent prompt and does not carry the Snippet D fingerprint.

---

## Revise Loop — Step by Step

### Step 1 — Read Open Issue List

The orchestrator reads the issue manifest for the current round:
`<target>/.review/round-<N>/issues/`

- Read frontmatter only (status, severity, file, criterion_id). Do NOT read issue bodies.
- Collect all issues where `status` ∈ {`new`, `persistent`, `regressed`} — these are open.
- Issues with `status` ∈ {`resolved`, `dismissed`} are already closed; skip them.

The open set includes carry-forwards from prior rounds (run-checkers.sh writes them
unconditionally — see "Carry-forward" block in scripts/run-checkers.sh). When `--review`
exited via Step 1 short-circuit (script-tier errors → cross-reviewer skipped), those
carry-forwards are the *only* record of unresolved LLM-tier findings; the reviser must
explicitly transition each one (see Step 3 status-mutation contract).

### Step 2 — Group Issues by Target File

Group all open issues by their `file` field (the `<target-relative-path>` of the artifact leaf
they point at). Each group becomes one reviser dispatch — one reviser handles all issues
targeting the same leaf.

Example grouping:
```
generate/writer-subagent.md      → [issue-001, issue-005, issue-009]
review/cross-reviewer-subagent.md → [issue-002]
SKILL.md                          → [issue-003, issue-007]
```

If an issue points at a skeleton-owned path (e.g., `scripts/metrics-aggregate.sh`,
`scripts/lib/aggregate.py`, or any path matching skeleton manifest at
`common/skeleton/shared-scripts-manifest.yml`): do NOT dispatch a reviser for that file.
Instead, create a meta-issue with `criterion_id: CR-META-skeleton-protected` in
`round-<N>/issues/` and log it in `state.yml`.

### Step 3 — Fan-out Per-Issue-Reviser (parallel)

Fan-out one `per-issue-reviser-subagent.md` per file-group. All dispatches are parallel (guide
§14.1 — each reviser is scoped to one leaf and reads resolved-issues history as negative
constraints, so they do not conflict).

- **Dispatches**: `revise/per-issue-reviser-subagent.md` (N instances, one per file-group)
- **Inputs consumed by each sub-agent**:
  - All open issue files for that leaf group
  - The current content of the target leaf
  - Resolved-issues history injected up to `config.yml regression_gate.max_injected_resolved`
    (default: 20) — regression-protection rail
- **Outputs written by each sub-agent**:
  1. The revised artifact leaf at `<target>/<leaf-path>`
  2. Frontmatter `status:` mutation on EACH addressed issue file at
     `<target>/.review/round-<N>/issues/<issue-id>.md` — exactly one of
     `resolved` | `persistent` | `dismissed` per issue (with `defer_reason:` /
     `dismiss_reason:` companion field where applicable). See
     `per-issue-reviser-subagent.md` "Issue Status Mutation" for the full contract.
- **Orchestrator action on all ACKs**: collect `linked_issues` from each ACK; update
  `state.yml`; proceed to Step 4.

**Why the reviser owns status mutation** (and not the cross-reviewer in the next
review round): cross-reviewer can be skipped by Step 1 short-circuit when the round
has script-tier errors. Revise is the only phase guaranteed to run after a
non-converged round, so it is the single source of truth for issue state transitions.
The next `--review` round's carry-forward block reads the post-revise status to
decide what to inherit.

### Step 4 — Summarizer: Aggregate Post-Revise State

- **Dispatches**: `shared/summarizer-subagent.md` (update-status phase)
- The summarizer aggregates from `round-N/issues/*.md` frontmatter (status field on each issue,
  post-revise) and writes `round-N/index.md` with the issue-count summary. Status
  transitions (new/persistent → resolved | persistent | dismissed) are written by the
  per-issue-reviser in Step 3 — summarizer is a pure aggregator and does NOT mutate
  status. Summarizer does NOT read artifact leaves.
- Open count = `len(status ∈ {new, persistent, regressed})`. Closed count =
  `len(status ∈ {resolved, dismissed})`. Both `resolved` and `dismissed` exit the open
  set; the distinction is preserved in the index for audit but not for verdict gating.
- **Orchestrator action on ACK**: proceed to Step 5.

### Step 5 — Judge: Evaluate New Round Verdict

- **Dispatches**: `shared/judge-subagent.md`
- **Outputs written by sub-agent**: `<target>/.review/round-<N>/verdict.yml` with `phase: post-revise`
  (overwrites the same round's pre-revise verdict written in `review/index.md` Step 6 — the
  round number does NOT advance inside `--revise`; a fresh round starts when the operator
  next invokes `--review`).
- **Orchestrator action on ACK**: read verdict and route:

User-triggered `--revise` MUST exit at the verdict — it MUST NOT auto-loop back into a fresh review round. The round number advances only at the start of the next `--review` invocation, after the operator has had a chance to inspect the in-flight reviser writes. This boundary is what lets `--review`/`--revise` remain idempotent across re-invocations.

| Verdict | Next Action |
|---------|------------|
| `converged` | Delivery phase: summarizer writes CHANGELOG + version summary; `scripts/commit-delivery.sh` |
| `progressing` | Update `state.yml` `mode_phase: idle-awaiting-review-round-<N+1>` and exit cleanly. Operator runs `/cofounder:skill-forge --review --target <skill>` to verify the in-flight fixes — that invocation increments the round at the start of `review/index.md` Step 1 (Phase A). MUST NOT auto-load `review/index.md` in this invocation. |
| `oscillating` | HITL gate: surface oscillating-issue list; wait for user decision |
| `diverging` | HITL gate: surface regression report; wait for user decision |
| `stalled` | HITL gate: report stall; wait for user decision |

---

## Notes

- The orchestrator MUST NOT read the revised artifact leaf content — route on ACK fields and
  verdict only (§5.1 pure-dispatch principle).
- Round numbers are monotonically increasing. If the revise pass produces a clean round, the
  next review pass increments N before dispatching the cross-reviewer.
- Skeleton-protected files are never revised by the reviser. If a checker fires on a
  skeleton file, this indicates a skeleton defect — surface it as a HITL issue, not a
  reviser task.
- Reference `common/snippets.md` Snippet C (orchestrator dispatch contract) for `trace_id`
  format and `launched`/`completed` event schema.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) — Per-issue reviser sub-agent prompt (one dispatch per target leaf)
