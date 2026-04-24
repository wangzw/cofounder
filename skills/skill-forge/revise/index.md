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
- Issues with `status: resolved` are already closed; skip them.

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
- **Outputs written by each sub-agent**: the revised artifact leaf at `<target>/<leaf-path>`
- **Orchestrator action on all ACKs**: collect `linked_issues` from each ACK; update
  `state.yml`; proceed to Step 4.

### Step 4 — Summarizer: Update Issue Status

- **Dispatches**: `shared/summarizer-subagent.md` (update-status phase)
- The summarizer re-reads all issue files and the freshly revised leaves, then updates issue
  status fields (new → persistent | resolved; resolved → regressed if re-introduced).
- It also updates `<target>/.review/round-<N>/index.md` with revised coverage percentage.
- **Orchestrator action on ACK**: proceed to Step 5.

### Step 5 — Judge: Evaluate New Round Verdict

- **Dispatches**: `shared/judge-subagent.md`
- **Outputs written by sub-agent**: `<target>/.review/round-<N>/verdict.yml` (overwrites
  previous verdict for this round, or uses incremented round number if orchestrator bumps N).
- **Orchestrator action on ACK**: read verdict and route:

| Verdict | Next Action |
|---------|------------|
| `converged` | Delivery phase: summarizer writes CHANGELOG + version summary; `scripts/commit-delivery.sh` |
| `progressing` | Increment round N; loop back to `review/index.md` Step 3 (cross-reviewer) |
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
