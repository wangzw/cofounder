# generate/new-version.md — NewVersion Mode Entry

Loaded by the orchestrator when `--evolve <prd-dir>` is provided.
Defines the dispatch sequence for evolving a delivered PRD into a new
version. After Step 8b (writer fan-out) the orchestrator loads
`review/index.md` and runs the review pipeline — this file does not
duplicate the review-loop orchestration.

NewVersion is a **write phase** of the alternating write/read cycle
defined in `SKILL.md` "Phase Contract". Like FromScratch, only the
formal review PASS clause applies on first-round exit (state-machine
clause is vacuous because the prior delivery converged with no open
issues, and this delivery's first round has not yet produced any).
Each writer's self-audit (Step 8b) gates leaf-level formal PASS;
`review/index.md` Step 1 enforces the bundle-level boundary.

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

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

Same as FromScratch.

### Step 2 — MANDATORY: Phase Entry Verification (script-enforced)

**This MUST be the second action of generate-evolve. The orchestrator
MUST NOT proceed past this script on a non-zero exit.**

```bash
scripts/verify-phase-entry.sh generate-evolve <prd-dir>
```

Verifies the new-version entry precondition: a prior delivery's
`versions/<N-1>.md` exists. Refuses to evolve a PRD that has no
delivered baseline.

| Exit | Meaning | Next action |
|------|---------|-------------|
| 0    | Prior delivery found | continue to Step 3 |
| 1    | No `versions/*.md` files | refuse to start; surface "no baseline to evolve" — user should use `--no-evolve` or generate from scratch |
| 2    | Script-level error | HITL |

### Steps 3–4 — Same as FromScratch

- `scripts/prepare-input.sh "<change-description>" <prd-dir>/.review` (writes
  to `round-<K+1>/`, where K = last completed round of the prior delivery)
- `scripts/glossary-probe.sh <prd-dir>/.review/round-<K+1> common/domain-glossary.md`

### Step 5 — Domain Consultant (usually skipped)

**Trigger**: `glossary_hit: true` OR user explicitly passed
`--interactive`. Most NewVersion invocations skip.

When dispatched, also passes `<prd-dir>/README.md` so the consultant
can ground answers in the existing baseline.

### Step 6 — Planner (sub-agent dispatch)

- Dispatches: `generate/planner-subagent.md`
- Inputs: `round-<K+1>/input.md` (or `clarification/<ts>.yml` when Step 5 ran),
  plus `<prd-dir>/README.md`, `<prd-dir>/CHANGELOG.md`,
  `<prd-dir>/.review/versions/<N-1>.md`
- Outputs: `round-<K+1>/plan.md` with `mode: new-version` and four lists
  (`delete`, `modify`, `add`, `keep`).

### Step 7 — HITL: Plan Approval Gate

Same as FromScratch. Orchestrator reads `plan.md` only.

### Step 8a — Apply Deletes (orchestrator action)

For each path in `plan.delete`, orchestrator runs `git rm <prd-dir>/<path>`
directly (not via sub-agent). Records removed paths in `state.yml`.

### Step 8b — Writer Fan-out (parallel)

Fan-out writers for each entry in `plan.modify` + `plan.add`. Files in
`plan.keep` are skipped (the planner certified them unchanged; the
review pipeline will re-confirm).

- Dispatches: `generate/writer-subagent.md`
- Inputs for `modify`: existing `<prd-dir>/<file>` content as context
- Inputs for `add`: same as FromScratch Step 8
- Self-audit: each writer runs the per-artifact check-*.sh for its
  leaf type (per `generate/writer-subagent.md`); fixes failures on its
  own leaf in place; substantive CRs go into the self-review

### Step 9 — Enter Review Loop

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
