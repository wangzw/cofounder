# generate/new-version.md — NewVersion Mode Entry

Loaded by the orchestrator when `--evolve <prd-dir>` is provided.
Defines the dispatch sequence for evolving a delivered PRD into a new
version. After Step 7 (writer fan-out) the orchestrator loads
`review/index.md` and runs the review pipeline — this file does not
duplicate the review-loop orchestration.

This file is **orchestration**, not a sub-agent prompt.

---

## Key Differences from FromScratch

| Aspect | FromScratch | NewVersion |
|--------|-------------|------------|
| Bootstrap | Round 0 with input + clarification | Same Round 0; clarification typically minimal (user has a specific change) |
| Planner inputs | `clarification.yml` or `input.md` | Also reads existing `README.md`, `CHANGELOG.md`, `versions/<N-1>.md` |
| Plan shape | `add` only (all new) | `{delete, modify, add, keep}` |
| Writer fan-out | All `add` files | Only `modify` + `add` files |
| First-round review | Standard | All leaves reviewed (delete/modify/add operations may affect cross-leaf consistency that file-by-file review wouldn't catch) |
| Round numbering | Starts at 1 | Continues from last delivery (cross-delivery monotonic) |

There is no "scaffold drift" check — PRD generation does not scaffold;
the previous PRD's directory is the ground truth that the planner
reads. Drift detection here would be content-level, which is the
review pipeline's job.

---

## Round Sequence

### Steps 1–3 — Same as FromScratch

- `scripts/git-precheck.sh`
- `scripts/prepare-input.sh "<change-description>" <prd-dir>/.review` (writes
  to `round-<K+1>/`, where K = last completed round of the prior delivery)
- `scripts/glossary-probe.sh <prd-dir>/.review/round-<K+1> common/domain-glossary.md`

### Step 4 — Domain Consultant (usually skipped)

**Trigger**: `glossary_hit: true` OR user explicitly passed
`--interactive`. Most NewVersion invocations skip.

When dispatched, also passes `<prd-dir>/README.md` so the consultant
can ground answers in the existing baseline.

### Step 5 — Planner (sub-agent dispatch)

- Dispatches: `generate/planner-subagent.md`
- Inputs: `round-<K+1>/input.md` (or `clarification/<ts>.yml` when Step 4 ran),
  plus `<prd-dir>/README.md`, `<prd-dir>/CHANGELOG.md`,
  `<prd-dir>/.review/versions/<N-1>.md`
- Outputs: `round-<K+1>/plan.md` with `mode: new-version` and four lists
  (`delete`, `modify`, `add`, `keep`).

### Step 6 — HITL: Plan Approval Gate

Same as FromScratch. Orchestrator reads `plan.md` only.

### Step 7a — Apply Deletes (orchestrator action)

For each path in `plan.delete`, orchestrator runs `git rm <prd-dir>/<path>`
directly (not via sub-agent). Records removed paths in `state.yml`.

### Step 7b — Writer Fan-out (parallel)

Fan-out writers for each entry in `plan.modify` + `plan.add`. Files in
`plan.keep` are skipped (the planner certified them unchanged; the
review pipeline will re-confirm).

- Dispatches: `generate/writer-subagent.md`
- Inputs for `modify`: existing `<prd-dir>/<file>` content as context
- Inputs for `add`: same as FromScratch Step 7
- Self-audit: each writer runs `scripts/run-checkers.sh <prd-dir>` as a
  formal hard gate (guide §4); fixes failures in place; substantive
  CRs go into the self-review

### Step 8 — Enter Review Loop

Load `review/index.md` and execute the review-mode steps with
`round=K+1`. First-round-of-delivery effects (e.g. forced full review)
are computed inside `review/index.md` based on `state.yml`.

Verdict routing per `review/index.md` Step 8:

| Verdict | Next |
|---------|------|
| `converged` | Delivery: `scripts/commit-delivery.sh <prd-dir> <delivery-id> <slug>` creates tag `delivery-<N+1>-<slug>` |
| `progressing` | Load `revise/index.md`; loop |
| `oscillating` / `diverging` / `stalled` | HITL gate |

---

## Round Numbering Example

```
Delivery 1:  round-1 (plan), round-2, round-3 (converged) → tag delivery-1-foo
Delivery 2:  round-4 (plan), round-5 (converged)          → tag delivery-2-foo
```

Delivery 2's planner reads `versions/3.md` (the delivery 1 converged
summary). It writes `round-4/plan.md`. Writers write to round-4
self-reviews. All monotonic — round numbers never reuse.

---

## Notes

- The orchestrator MUST NOT read any artifact leaf when deciding which
  files need writers — rely on `plan.modify` + `plan.add` lists in
  `plan.md` only.
- `plan.delete` is honored by `git rm` BEFORE writer fan-out so the
  review pipeline never sees orphan-referenced paths.
