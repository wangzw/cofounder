# Review Mode — Orchestration

Loaded by the orchestrator when `--review` is invoked. Defines the review
loop the orchestrator follows for round N. Implements
[~/Documents/mind/raw/guide/生成式skill的审查设计.md](../../../../Documents/mind/raw/guide/生成式skill的审查设计.md):

- §5 — convergence is `formal_PASS ∧ substantive_PASS`. Formal failure
  short-circuits LLM dispatch (no point reviewing content of a malformed
  artifact).
- §7 — review-revise iteration with phase gates around `state: new` issues.
- §10 — review artifacts are themselves artifacts and pass formal checks.

Review mode is the **read phase** of the alternating write/read cycle
defined in `SKILL.md` "Phase Contract". This file enforces both:

- **Read-phase entry gate** (Step 1): no `state: new` from
  prior rounds AND bundle passes formal review. If either fails, the
  read phase does not start — control returns to a write (revise) phase.
- **Read-phase exit**: judge verdict in Step 7. The read phase produces
  issues in `state: new`; dispositioning them is the next write
  (revise) phase's job, gated by `check-revise-completeness.sh`.

This file is **orchestration**, not a sub-agent prompt. It does not carry
the Snippet D fingerprint.

---

## Review Loop — Step by Step

### Step 1 — MANDATORY: Phase Entry Verification (script-enforced)

**This MUST be the first action of the read phase. The orchestrator
MUST NOT proceed past this script on a non-zero exit.**

```bash
scripts/verify-phase-entry.sh read <design-dir>
```

Consolidates both read-phase entry preconditions into a single gate:

- `check-review-readiness.sh` — no `state: new` issue from any prior
  round (i.e. the previous revise wrote completely; guide §7.3)
- `run-checkers.sh` — bundle is formally clean (i.e. the previous
  write phase produced a valid bundle; guide §6 fast-failure)

| Exit | Meaning | Next action |
|------|---------|-------------|
| 0    | Both preconditions PASS | continue to Step 2 (LLM substantive dispatch) |
| 1    | At least one precondition FAIL | **short-circuit to revise**: re-run `run-checkers.sh <design-dir>` to capture the JSON formal-failure document, pipe to `create-issues.sh <design-dir> <round>` to materialize per-issue files, then load `revise/index.md` |
| 2    | Script-level error in a sub-checker | HITL — do not modify the artifact (guide §9.1) |

Why this is the first step: the prose contract in `SKILL.md` "Phase
Contract" is enforcement-by-LLM, which is unreliable. This script is
enforcement-by-process: even if subsequent steps are skipped or
reordered, control cannot reach LLM dispatch without
`verify-phase-entry` having exited 0. Per guide §6, a formal problem
caught here costs zero LLM tokens and saves an entire LLM round.

### Step 2 — Cross-Reviewer Dispatch (substantive only)

Pre-conditions: Step 1 exit 0 (entry verification PASS) **and** there is meaningful
work for the reviewer (artifact changed since last delivery, or prior-round
issues are still open).

```
Dispatch: review/cross-reviewer-subagent.md
```

**Sub-agent inputs**:

- The design bundle leaves (`README.md`, every `modules/M-NNN-*.md`,
  every `api/API-NNN-*.md`)
- Writer self-review files at `<design-dir>/.review/round-<N>/self-reviews/` (if any)
- `<design-dir>/.review/issues/summary.yml` — for fingerprint matching against
  prior issues (guide §7.6). The reviewer MUST check each new finding
  against this list before emitting it; matched findings get
  `recurrence_of: <prior-id>` in the output.
- `common/review-criteria.md` — every entry whose `checker_type: llm`

**Sub-agent output (one disk write)**: writes a JSON document to
`<design-dir>/.review/round-<N>/reviewer-output/<trace_id>.json`, conforming
to the LLM raw-output schema in `common/issue-schema.md`. The reviewer
NEVER writes issue files directly (guide §7.1) — `create-issues.sh`
walks the `reviewer-output/` directory and materializes per-issue files
in a later step.

**Orchestrator action on ACK**: record the trace_id in `state.yml`. Do
not yet materialize issues; that happens after Step 3 (so cross +
adversarial reviewer outputs are merged in one create-issues pass).

### Step 3 — Adversarial-Reviewer Dispatch (conditional)

Fire only if cross-reviewer's output contained at least one
`severity: critical` finding (configurable via `config.yml
adversarial_review.triggered_by`).

```
Dispatch: review/adversarial-reviewer-subagent.md
```

Same input contract as cross-reviewer; writes a separate
`reviewer-output/<trace_id>.json` file.

### Step 4 — Materialize Issue Files

After both reviewer dispatches have ACKed:

```bash
scripts/create-issues.sh <design-dir> <round>
```

Default mode (no `--stdin`) walks every
`<design-dir>/.review/round-<N>/reviewer-output/*.json`, merges their
`issues` lists, and writes one schema-conformant `.md` file per accepted
finding to `<design-dir>/.review/round-<N>/issues/`. If `create-issues.sh`
exits 1, at least one reviewer's output violated the schema — surface
the specific error to the user; do NOT silently drop findings.

### Step 5 — Update Summary

```bash
scripts/update-summary.sh <design-dir>
```

Refreshes `<design-dir>/.review/issues/summary.yml` so the next round's
fingerprint matching sees this round's issues. Per guide §7.5, this is
where recurrence detection happens for the next iteration.

### Step 6 — Summarizer Dispatch

```
Dispatch: shared/summarizer-subagent.md (per-round phase)
```

Sub-agent writes `<design-dir>/.review/round-<N>/index.md` with issue counts
(by state and severity), `false_positive_ratio`, `deferred_ratio`, and
recurrence statistics (guide §7.7).

### Step 7 — Judge Dispatch

```
Dispatch: shared/judge-subagent.md
```

Sub-agent writes `<design-dir>/.review/round-<N>/verdict.yml`.

The verdict is computed against the rule from guide §5:

```
converged ⟺ formal_PASS ∧ substantive_PASS
formal_PASS    : Step 1 exited 0 in this round
substantive_PASS: 0 issues with severity ∈ {error, critical} and state ∈ {new}
```

Verdicts other than `converged` mean further work; specifically the judge
considers:

- `progressing`  — issues exist but were refined this round (count or
  severity decreased vs prior round)
- `oscillating`  — the same issues keep returning between fixed and new
  (guide §7.5.1 recurrence count ≥ 2 on the same issue id)
- `diverging`    — error/critical count rose vs prior round
- `stalled`      — `max_iterations` reached without convergence

### Step 8 — Verdict Routing

| Verdict        | Next Action |
|----------------|-------------|
| `converged`    | Delivery sequence (Step 9 below) |
| `progressing`  | Load `revise/index.md`, increment round number for the next review pass |
| `oscillating`  | HITL gate: surface oscillating-issue list with their `recurrence_count`; wait for `/continue`, `/override`, or `/abort` |
| `diverging`    | HITL gate: surface regression report; same options |
| `stalled`      | HITL gate: report stall; same options |

### Step 9 — Delivery Sequence (only on `converged`)

1. Set `state.yml phase: on-converge` and inject `git_sha: <HEAD sha>`.
2. Re-dispatch `shared/summarizer-subagent.md` with `phase: on-converge`. The
   summarizer writes:
   - `<design-dir>/.review/versions/<N>.md` — quality_at_delivery snapshot
   - `<design-dir>/CHANGELOG.md` — prepend a delivery entry
   - (conditional) `<design-dir>/README.md` — append a Revisions row
3. Run `scripts/commit-delivery.sh <design-dir> <delivery-id> <slug>` to create
   the annotated git tag `delivery-<N>-<slug>`.
4. Orchestrator exits cleanly.

Steps 1 and 3 are orchestrator-side (no LLM); Step 2 is the only Phase 2
sub-agent dispatch in the entire delivery sequence.

---

## Files in This Directory

- [cross-reviewer-subagent.md](cross-reviewer-subagent.md) — substantive
  reviewer (every `checker_type: llm` criterion)
- [adversarial-reviewer-subagent.md](adversarial-reviewer-subagent.md) —
  adversarial substantive reviewer (conditional, on critical findings)

---

## What Changed vs the Prior Design

The prior orchestration mixed three things into one pipeline: (a) Phase
A manifest + depgraph + skip-set machinery inherited from skill-forge,
(b) drift short-circuit, and (c) the actual review loop. Per the audit
guide, formal review and substantive review have asymmetric roles in
convergence (§5) — formal is a necessary gate, substantive is the
sufficient condition. Treating them as one continuous pipeline made the
formal gate too easy to skip. The new design enforces:

1. Formal hard gate **before** any LLM dispatch (§5, §6).
2. Issues are created by **script** from the reviewer's JSON output, not
   hand-written by the reviewer (§7.1, §10 self-closure).
3. Cross-round recurrence detection lives in `summary.yml` and is read
   by the reviewer on every dispatch (§7.6).
4. Phase gates around `state: new` issues prevent skipping a revise pass
   (§7.3).

Skill-forge-specific machinery (Phase A skip-set, scaffolder version
drift, force-full override) is removed — those were features of a
generator-driven skill, not the review-revise loop.
