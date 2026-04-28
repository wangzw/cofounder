# Revise Mode — Orchestration

This file is loaded by the orchestrator when mode = `--revise` (or after a review phase that
produced critical/error issues). It defines the revise loop the orchestrator follows. It is
**not** a sub-agent prompt and does not carry the Snippet D fingerprint.

---

## Revise Loop — Step by Step

### Step 1 — Build Issue-Group Manifest (script)

The orchestrator delegates issue grouping to a deterministic grouping script — no LLM-tier
analysis permitted here (§5.1 pure-dispatch). The grouping script reads
`<target>/.review/round-<N>/issues/` (frontmatter only), filters to open statuses
(`new`, `persistent`, `regressed`), skips skeleton-owned paths, and emits a YAML manifest at:

```
<target>/.review/round-<N>/revise-plan.yml
```

Manifest format:

```yaml
groups:
  - leaf: generate/writer-subagent.md
    issues: [R6-V001-001, R6-V001-005]
  - leaf: review/cross-reviewer-subagent.md
    issues: [R6-V002-002]
skeleton_skipped:
  - leaf: scripts/metrics-aggregate.sh
    issues: [R6-V003-001]
    meta_issue: R6-META-001
```

For any skeleton-owned path the script finds, it writes a meta-issue with
`criterion_id: CR-META-skeleton-protected` into `round-<N>/issues/` and records it under
`skeleton_skipped` in the manifest. The orchestrator does **not** evaluate skeleton ownership —
the script handles it fully.

The orchestrator reads `revise-plan.yml` **verbatim** after the script exits. It does not
re-interpret, filter, or reorder the groups — the manifest is the dispatch plan.

> **Infrastructure note**: the grouping script is a required infrastructure component. If it is
> not yet present in `scripts/`, this step cannot execute and must be escalated as a HITL
> blocker. The orchestrator MUST NOT fall back to inline grouping (§5.1 pure-dispatch forbids
> the orchestrator from filtering issues by status or grouping by file field).

### Step 2 — Fan-out Per-Issue-Reviser (parallel)

Fan-out one `per-issue-reviser-subagent.md` per `groups` entry in `revise-plan.yml`. All
dispatches are parallel (guide §14.1 — each reviser is scoped to one leaf and reads
resolved-issues history as negative constraints, so they do not conflict).

- **Dispatches**: `revise/per-issue-reviser-subagent.md` (N instances, one per group in manifest)
- **Inputs consumed by each sub-agent**:
  - All open issue files for that leaf group (issue IDs taken verbatim from manifest)
  - The current content of the target leaf
  - Resolved-issues history injected up to `config.yml regression_gate.max_injected_resolved`
    (default: 20) — regression-protection rail
- **Outputs written by each sub-agent**: the revised artifact leaf at `<target>/<leaf-path>`
- **Orchestrator action on all ACKs**: collect `linked_issues` from each ACK; update
  `state.yml`; proceed to Step 3.

### Step 3 — Summarizer: Update Issue Status

- **Dispatches**: `shared/summarizer-subagent.md` (update-status phase)
- The summarizer aggregates from `round-N/issues/*.md` frontmatter (status field on each issue)
  and writes `round-N/index.md` with the issue-count summary. Status transitions
  (new → resolved, resolved → regressed, etc.) are set by the cross-reviewer in the next review
  round — NOT by summarizer. Summarizer does NOT read artifact leaves.
- **Orchestrator action on ACK**: proceed to Step 4.

### Step 4 — Judge: Evaluate New Round Verdict

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
- The orchestrator MUST NOT evaluate issue status, group issues, or decide fan-out shape — all
  of this is delegated to the grouping script. The orchestrator only invokes the script and
  consumes its YAML output verbatim (§5.1 pure-dispatch principle).
- Round numbers are monotonically increasing. If the revise pass produces a clean round, the
  next review pass increments N before dispatching the cross-reviewer.
- Skeleton-protected files are never revised by the reviser. The grouping script handles
  skeleton detection and meta-issue creation automatically. If a checker fires on a skeleton
  file, this indicates a skeleton defect — the script surfaces it under `skeleton_skipped`
  in the manifest so the orchestrator can escalate as a HITL issue.
- Reference `common/snippets.md` Snippet C (orchestrator dispatch contract) for `trace_id`
  format and `launched`/`completed` event schema.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) — Per-issue reviser sub-agent prompt (one dispatch per target leaf)
