# generate/from-scratch.md — FromScratch Mode Entry

Loaded by the orchestrator when mode = generate and no `--evolve` is
provided. Defines Round 0 + Round 1 setup. After Step 7 (writer fan-out)
the orchestrator loads `review/index.md` and runs the review pipeline —
this file does not duplicate the review-loop orchestration.

This file is **orchestration**, not a sub-agent prompt. It does not
carry the Snippet D fingerprint.

---

## Round 0 — Bootstrap

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

Exit non-zero → stop the skill; do not enter generate mode.

### Step 2 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<user-prompt>" <prd-dir>/.review
```

Outputs `<prd-dir>/.review/round-0/input.md` (normalized), `input-meta.yml`,
and (idempotently, on first bootstrap) `.review/README.md` from
`common/templates/review-readme-template.md`.

Orchestrator: read exit code only; never read the written files.

### Step 3 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <prd-dir>/.review common/domain-glossary.md
```

Outputs `<prd-dir>/.review/round-0/trigger-flags.yml` (`glossary_hit`,
`sparse_input`, `ambiguous_artifact_type`).

### Step 4 — Domain Consultant (conditional)

**Trigger**: `glossary_hit: true` OR `sparse_input: true` OR user passed
`--interactive`. Skip otherwise.

`--no-consultant` override: skip unconditionally. The orchestrator
delegates the clarification write to
`scripts/synthesize-clarification.sh <prd-dir> <skill-name>
<skill-version> <skill-description> <artifact-root>` (which marks
R-001..R-007 as `status: deferred`). This keeps the orchestrator
pure-dispatch — it does not write `clarification/<ts>.yml` directly.

- Dispatches: `generate/domain-consultant-subagent.md`
- Inputs: `round-0/input.md`, `input-meta.yml`, `trigger-flags.yml`,
  `common/domain-glossary.md`
- Outputs: `<prd-dir>/.review/round-0/clarification/<ISO-ts>.yml`

### Step 5 — Planner (sub-agent dispatch)

- Dispatches: `generate/planner-subagent.md`
- Inputs: `round-0/clarification/<ts>.yml` (or `round-0/input.md` directly
  when consultant skipped)
- Outputs: `<prd-dir>/.review/round-1/plan.md`

The planner produces an `add:` list of PRD leaves to author (typically
README.md, journeys/J-NNN-*.md, features/F-NNN-*.md, architecture.md,
architecture/*.md). PRDs have no skeleton — every leaf is an `add`.

### Step 6 — HITL: Plan Approval Gate

Orchestrator reads `round-1/plan.md` (the only artifact it is permitted
to read). Wait for user response:

- approve / `/approve` → continue to Step 7
- revise / `/revise <feedback>` → re-dispatch planner with feedback;
  loop Steps 5–6
- abort / `/abort` → exit the skill

---

## Round 1 — Writer fan-out

### Step 7 — Writer Fan-out (parallel)

Fan-out one writer per entry in `plan.add`. Each writer:

- Receives: `round-0/clarification/<ts>.yml` (most recent),
  `round-1/plan.md`, the relevant template from `common/templates/`
  (`feature-template.md` / `journey-template.md` /
  `architecture-template.md` / `prd-template.md`).
- Writes the leaf at `<prd-dir>/<relative-path>`.
- Runs the per-artifact check-*.sh script for its assigned leaf type
  (see `generate/writer-subagent.md` "Formal pre-check" table) as a
  self-audit hard gate (guide §4); fixes formal failures on its own
  leaf in place and re-runs until PASS. Findings on other leaves are
  ignored (other writers handle their own scope). Formal failures here
  do NOT create issue files (guide §4.1).
- Writes the self-review at
  `<prd-dir>/.review/round-1/self-reviews/<trace_id>.md` covering only
  **substantive** CRs (formal CRs are already enforced by run-checkers).
- Returns single-line ACK.

Orchestrator: collect `self_review_status` and `fail_count` from each
ACK. Proceed to Step 8.

### Step 8 — Enter Review Loop

Load `review/index.md` and execute the review-mode steps with
`round=1`. The review pipeline handles formal hard gate (re-runs
`scripts/run-checkers.sh` over the full bundle as a belt-and-suspenders
check on top of each writer's per-leaf self-audit), cross-reviewer
dispatch, summarizer, judge.

Verdict routing (per `review/index.md` Step 8):

| Verdict | Next |
|---------|------|
| `converged` | Delivery: `scripts/commit-delivery.sh <prd-dir> <delivery-id> <slug>` creates annotated tag `delivery-<N>-<slug>`; skill exits cleanly |
| `progressing` | Load `revise/index.md`; increment round; loop back to review |
| `oscillating` / `diverging` / `stalled` | HITL gate; surface to user |

---

## Notes

- Round numbers are cross-delivery monotonic. Round 1 in delivery 1 is
  round 1 globally; delivery 2 starts at round-(K+1) where K is the
  last delivery 1 round.
- The orchestrator MUST NOT read any artifact leaf except `plan.md`
  (Step 6). All other routing decisions ride on ACK fields and verdict
  files.
- PRD generation has no scaffold step — there is no skeleton to copy
  from. Each leaf is authored fresh by a writer based on the template.
