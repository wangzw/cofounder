# Review Mode — Orchestration

This file is loaded by the orchestrator when mode = `--review`. It defines the review loop the
orchestrator follows for the current round N. It is **not** a sub-agent prompt and does not carry
the Snippet D fingerprint.

---

## Review Loop — Step by Step

### Step 1 — Phase A + B Script Checks

```bash
scripts/run-checkers.sh <target>/ <round-N>
```

- **Phase A**: manifest validation + depgraph consistency + skip-set computation for round N.
  Outputs `<target>/.review/round-<N>/skip-set.yml` (lists `cross_reviewer_focus` and
  `cross_reviewer_skip` leaves) and manifest/depgraph issue files.
- **Phase B**: runs all 12 script-type checkers (CR-S01..CR-S12) against the target tree;
  aggregates all script-detected issues to
  `<target>/.review/round-<N>/issues/round-checker-output.json`.

**Exit 1 with critical or error issues** → skip Steps 2–4; jump directly to Revise Phase
(load `revise/index.md`). Do not dispatch cross-reviewer until script-type errors are resolved.

**Exit 0 OR only warnings** → continue to Step 2.

### Step 2 — Forced-Full Override Check

If `--review` was user-triggered (not part of an in-generate loop):

- Apply **forced-full cross-review** (guide §8.6): ignore `cross_reviewer_skip` entries for the
  **first** cross-reviewer dispatch of this delivery. Set a flag in `state.yml`:
  `forced_full_cross_review: true`.
- Subsequent rounds within the same delivery use the skip-set normally.

### Step 3 — Cross-Reviewer Dispatch

- **Dispatches**: `review/cross-reviewer-subagent.md`
- **Sub-agent inputs**: leaves listed in `skip-set.yml cross_reviewer_focus`, previous-round issue
  frontmatter from `round-<N-1>/issues/`, writer self-review files at
  `<target>/.review/round-<N>/self-reviews/`, and `common/review-criteria.md` (CR-L01..CR-L10).
- **Sub-agent outputs**: one issue file per issue found at
  `<target>/.review/round-<N>/issues/<issue-id>.md`.
- **Orchestrator action on ACK**: record `trace_id` in `state.yml`. If ACK is `FAIL` → apply §16
  retry policy.

### Step 4 — Adversarial-Reviewer Dispatch (Conditional)

**Condition**: check `config.yml adversarial_review.triggered_by`. Fire ADDITIONALLY to
cross-reviewer if any cross-reviewer issue from Step 3 meets or exceeds the configured trigger
severity (default: `critical`).

- **Dispatches**: `review/adversarial-reviewer-subagent.md`
- **Sub-agent inputs**: same as cross-reviewer, plus the in-generate writer self-review files.
- **Sub-agent outputs**: issue files with `source: adversarial-reviewer` at
  `<target>/.review/round-<N>/issues/<issue-id>.md`.
- **Orchestrator action on ACK**: record `trace_id` in `state.yml`.

### Step 5 — Summarizer Dispatch

- **Dispatches**: `shared/summarizer-subagent.md` (per-round phase)
- **Sub-agent outputs**: `<target>/.review/round-<N>/index.md` (issue aggregations, coverage
  percent, skip-set utilization); updates any leaf-index pages (e.g.
  `<target>/common/index.md`).
- **Orchestrator action on ACK**: proceed to Step 6.

### Step 6 — Judge Dispatch

- **Dispatches**: `shared/judge-subagent.md`
- **Sub-agent outputs**: `<target>/.review/round-<N>/verdict.yml`
- **Orchestrator action on ACK**: read verdict (see routing below).

### Step 7 — Verdict Routing

| Verdict | Next Action |
|---------|------------|
| `converged` | Delivery phase: run `scripts/commit-delivery.sh <target> <delivery-id> <slug>`, summarizer writes `<target>/CHANGELOG.md` + `.review/versions/<N>.md`, skill-forge exits cleanly |
| `progressing` | Revise phase: load `revise/index.md`, increment round |
| `oscillating` | HITL gate: surface to user with oscillating-issue list; wait for `/continue`, `/override`, or `/abort` |
| `diverging` | HITL gate: surface to user with regression report; same options |
| `stalled` | HITL gate: report stall (max iterations reached without convergence); same options |

---

## References

- **Snippet C** (orchestrator dispatch contract): `common/snippets.md` — defines `trace_id`
  format, `launched`/`completed` event schema, and the orchestrator FORBIDDEN list.
- **config.yml fields used here**: `adversarial_review.triggered_by`,
  `convergence.max_iterations`, `regression_gate.diverging_threshold`.
- **Skip-set semantics**: guide §8.5 — `cross_reviewer_focus` = leaves reviewer MUST read;
  `cross_reviewer_skip` = leaves reviewer MUST NOT read (unchanged and not implicated by open
  issues). Forced-full override clears the skip list for one dispatch (guide §8.6).

---

## Files in This Directory

- [cross-reviewer-subagent.md](cross-reviewer-subagent.md) — Cross-reviewer sub-agent prompt (LLM-type criteria CR-L01..CR-L10)
- [adversarial-reviewer-subagent.md](adversarial-reviewer-subagent.md) — Adversarial-reviewer sub-agent prompt (skill-forge–specific attack angles)
