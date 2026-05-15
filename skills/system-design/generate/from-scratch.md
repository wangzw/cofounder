# generate/from-scratch.md — FromScratch Mode Entry

Loaded by the orchestrator when mode = generate and no `--evolve` is
provided. Defines Round 0 + Round 1 setup. After Step 8 (writer fan-out)
the orchestrator loads `review/index.md` and runs the review pipeline —
this file does not duplicate the review-loop orchestration.

FromScratch is a **write phase** of the alternating write/read cycle
defined in `SKILL.md` "Phase Contract". The first write phase has no
inbound issues, so the state-machine clause is vacuous; only the
**formal review PASS** clause applies as exit gate. Each writer's
self-audit (Step 8) loops on the per-artifact check script for its
leaf type until formal PASS for that leaf; review mode's Step 1
(`verify-phase-entry read`) re-runs `run-checkers.sh` over the full
bundle as the cross-leaf boundary check before any LLM dispatch.

This file is **orchestration**, not a sub-agent prompt. It does not
carry the Snippet D fingerprint.

---

## Round 0 — Bootstrap

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

Exit non-zero → stop the skill; do not enter generate mode.

### Step 2 — MANDATORY: Phase Entry Verification (script-enforced)

**This MUST be the second action of generate-from-scratch (after the
git precheck). The orchestrator MUST NOT proceed past this script on
a non-zero exit.**

```bash
scripts/verify-phase-entry.sh generate-fresh <design-dir>
```

Verifies the from-scratch entry precondition: the target design bundle
does not yet exist (no `README.md`, no `modules/*`, no `api/*`).
Refuses to overwrite an existing design; the user should use `--evolve`
instead.

| Exit | Meaning | Next action |
|------|---------|-------------|
| 0    | Bundle is empty/absent — safe to generate | continue to Step 3 |
| 1    | Existing design content found | refuse to start; surface the diagnostic and tell the user to use `--evolve` |
| 2    | Script-level error | HITL |

### Step 3 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<user-prompt-or-prd-path>" <design-dir>/.review
```

Outputs `<design-dir>/.review/round-0/input.md` (raw user prompt, written
verbatim — no `@path` or URL expansion) and `input-meta.yml`
(`word_count`, `char_count`, `has_code_block`, `has_structured_lists` for
the sparse-input probe). On first bootstrap it also drops
`.review/README.md` idempotently from `common/templates/review-readme-template.md`.

Sub-agents downstream (domain-consultant, planner, writer) have Read /
WebFetch tools and pull any `@path` / `http(s)://` references on demand
— the orchestrator no longer inlines them at bootstrap time. When the
user-prompt itself names a PRD bundle path (e.g.
`docs/raw/prd/<date>-<slug>/`), the planner reads the source PRD's
`README.md`, every `features/F-NNN-*.md`, and every
`journeys/J-NNN-*.md` directly via its Read tool.

Orchestrator: read exit code only; never read the written files.

### Step 4 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <design-dir>/.review common/domain-glossary.md
```

Outputs `<design-dir>/.review/round-0/trigger-flags.yml` (`glossary_hit`,
`sparse_input`, `ambiguous_artifact_type`).

### Step 5 — Domain Consultant (conditional)

**Trigger**: `glossary_hit: true` OR `sparse_input: true` OR user passed
`--interactive`. Skip otherwise.

`--no-consultant` override: skip unconditionally. The orchestrator
delegates the clarification write to
`scripts/synthesize-clarification.sh <design-dir> <skill-name>
<skill-version> <skill-description> <artifact-root>` (which marks
R-001..R-007 as `status: deferred`). This keeps the orchestrator
pure-dispatch — it does not write `clarification/<ts>.yml` directly.

- Dispatches: `generate/domain-consultant-subagent.md`
- Inputs: `round-0/input.md`, `input-meta.yml`, `trigger-flags.yml`,
  `common/domain-glossary.md`, plus the source PRD bundle (when
  `input.md` names a PRD path — the consultant Reads it directly)
- Outputs: `<design-dir>/.review/round-0/clarification/<ISO-ts>.yml`

### Step 6 — Planner (sub-agent dispatch)

- Dispatches: `generate/planner-subagent.md`
- Inputs: `round-0/clarification/<ts>.yml` (or `round-0/input.md` directly
  when consultant skipped), plus the source PRD bundle when present
- Outputs: `<design-dir>/.review/round-1/plan.md`

The planner produces an `add:` list of design leaves to author —
exactly: `README.md`, one `modules/M-NNN-<slug>.md` per module, and one
`api/API-NNN-<slug>.md` per externally exposed API surface. Designs
have no skeleton — every leaf is an `add`.

### Step 7 — HITL: Plan Approval Gate

Orchestrator reads `round-1/plan.md` (the only artifact it is permitted
to read). Wait for user response:

- approve / `/approve` → continue to Step 8
- revise / `/revise <feedback>` → re-dispatch planner with feedback;
  loop Steps 6–7
- abort / `/abort` → exit the skill

---

## Round 1 — Writer fan-out

### Step 8 — Writer Fan-out (parallel)

Fan-out one writer per entry in `plan.add`. Each writer:

- Receives: `round-0/clarification/<ts>.yml` (most recent),
  `round-1/plan.md`, the relevant template from `common/templates/`
  (`design-readme-template.md` / `module-template.md` /
  `api-template.md`), and the source PRD bundle (read-only).
- Writes the leaf at `<design-dir>/<relative-path>`.
- Runs the per-artifact check-*.sh script for its assigned leaf type
  (see `generate/writer-subagent.md` "Formal pre-check" table) as a
  self-audit hard gate (guide §4); fixes formal failures on its own
  leaf in place and re-runs until PASS. Findings on other leaves are
  ignored (other writers handle their own scope). Formal failures here
  do NOT create issue files (guide §4.1).
- Writes the self-review at
  `<design-dir>/.review/round-1/self-reviews/<trace_id>.md` covering only
  **substantive** CRs (formal CRs are already enforced by run-checkers).
- Returns single-line ACK.

Orchestrator: collect `self_review_status` and `fail_count` from each
ACK. Proceed to Step 9.

### Step 9 — Enter Review Loop

Load `review/index.md` and execute the review-mode steps with
`round=1`. The review pipeline handles formal hard gate (re-runs
`scripts/run-checkers.sh` over the full bundle as a belt-and-suspenders
check on top of each writer's per-leaf self-audit), cross-reviewer
dispatch, summarizer, judge.

Verdict routing (per `review/index.md` Step 8):

| Verdict | Next |
|---------|------|
| `converged` | Delivery: `scripts/commit-delivery.sh <design-dir> <delivery-id> <slug>` creates annotated tag `system-design-delivery-<N>-<slug>`; skill exits cleanly |
| `progressing` | Load `revise/index.md`; increment round; loop back to review |
| `oscillating` / `diverging` / `stalled` | HITL gate; surface to user |

---

## Notes

- Round numbers are cross-delivery monotonic. Round 1 in delivery 1 is
  round 1 globally; delivery 2 starts at round-(K+1) where K is the
  last delivery 1 round.
- The orchestrator MUST NOT read any artifact leaf except `plan.md`
  (during Step 7 HITL approval). All other routing decisions ride on
  ACK fields and verdict files.
- System-design generation has no scaffold step — there is no skeleton
  to copy from. Each leaf is authored fresh by a writer based on the
  template.
