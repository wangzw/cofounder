# `.review/` — Generation, Review & Delivery Archive

Everything under `.review/` is **meta** about how the surrounding skill was produced.
The surrounding skill itself lives at the parent level (`SKILL.md`, `common/`,
`generate/`, `review/`, `revise/`, `scripts/`, `shared/`). Nothing in this directory is
loaded at runtime by the skill — it exists purely for audit, debugging, metrics, and
future-round context.

> **Ownership note.** The files here were written by **the generator that produced
> this skill** (the tool that was invoked when this skill's `.review/` was first
> populated), NOT by this skill's own scripts. A generated skill's archive describes
> the audit trail of *being produced*, not of producing its own downstream artifacts.
> If this skill is later self-hosted — i.e. it generates a new version of itself —
> subsequent rounds will be written by this skill's own `scripts/` under the same
> schema, because every generative skill follows the same 8-role spec.

---

## Top-level shape

```
.review/
├── README.md               ← this file
├── state.yml               ← orchestrator bookkeeping (current_round, current_delivery, phase, git_sha)
├── round-0/                ← bootstrap (input + glossary probe + clarification)
├── round-1/, round-2/ …    ← per-round work (plan | issues | self-reviews | skip-set | index | verdict)
├── traces/round-<N>/       ← dispatch-log.jsonl for that round (one JSONL line per launched/completed event)
├── versions/<N>.md         ← on-converge delivery summaries (only written when verdict=converged)
├── metrics/                ← aggregated metrics (produced by metrics-aggregate in --diagnose mode)
├── dismissed-fails/        ← writer self-review FAIL rows the cross-reviewer explicitly dismissed
└── hitl/                   ← human-in-the-loop override records (force-continue, regression justification, etc.)
```

Rounds are **cross-delivery monotonic**: delivery-1 uses round-1..k, delivery-2 starts
at round-k+1. Round-0 is the **one-off bootstrap** scoped to input and clarification —
it does not recur per delivery (it is re-used as the bootstrap subdir for new-version
deliveries via the generator's `prepare-input --bootstrap-subdir <round>` flag).

## `state.yml`

Single source of truth for the orchestrator's own bookkeeping. Keys:

| Key | Purpose |
|---|---|
| `current_round` | Monotonically incremented; read by run-checkers / skip-set / cross-reviewer. |
| `current_delivery` | Bumped when a verdict=converged triggers the delivery commit. |
| `mode` | One of `generate-from-scratch`, `generate-new-version`, `review`, `revise`. |
| `phase` (optional) | Set to `on-converge` just before the summarizer's on-converge phase is dispatched. |
| `forced_full_cross_review` (optional) | `true` during the first `--review` dispatch of a delivery. |
| `git_sha` (optional) | Current HEAD sha, injected by orchestrator before on-converge summarizer dispatch. |

Orchestrator is the **only** writer to this file. Sub-agents read it but never modify
it.

## `round-0/` — Bootstrap

Produced during the generator's Round-0 bootstrap steps (input preparation, glossary
probe, optional clarification dialogue). Contents:

| File | Produced by role | Purpose |
|---|---|---|
| `input.md` | `prepare-input` (script) | Normalized user prompt + any `@path` / `http://` references expanded inline. Directory refs are walked and inlined under a per-directory size budget. |
| `input-meta.yml` | `prepare-input` (script) | `word_count`, `has_code_block`, `has_structured_lists`, `expanded_references`, `fetch_errors`. |
| `trigger-flags.yml` | `glossary-probe` (script) | `glossary_hit`, `sparse_input`, `hit_terms[]`. Orchestrator routes the clarification step off this file. |
| `clarification/<ISO-ts>.yml` | `domain-consultant` (sub-agent) | Flat `SKILL_NAME`/`SKILL_VERSION`/`SKILL_DESCRIPTION`/`ARTIFACT_ROOT` keys + `normalized_requirements` R-001..R-007. Planner + writers read this. |

If multiple clarification files exist (e.g., user revised mid-dialogue), the
**lexicographic max by filename** is the authoritative one (ISO-8601 timestamps sort
correctly).

## `round-<N>/` — Per-round work

The canonical working directory for round N. Not every file is written every round —
presence depends on what step of the round executed.

| File / dir | Produced by role | When |
|---|---|---|
| `plan.md` | `planner` (sub-agent) | First round of a delivery; after plan approval it drives writer fan-out. New-version deliveries include `delete`/`modify`/`add`/`keep` lists. |
| `self-reviews/R<N>-W-<NNN>.md` | `writer` (sub-agent) | One per writer dispatch. CR-by-CR PASS/FAIL checklist + `self_review_status` + `fail_count`. Summarizer reads `fail_count` for `writer_fail_count_sum`. |
| `manifest.yml` | `run-checkers` (script) Phase A | Leaf inventory for the round (hash + last-mod). |
| `depgraph.yml` | `run-checkers` (script) Phase A | Leaf dependency graph used by skip-set propagation. |
| `skip-set.yml` | `run-checkers` (script) Phase A | `cross_reviewer_focus` + `cross_reviewer_skip` lists. `forced_full: true` when invoked via `--full`. |
| `issues/round-checker-output.json` | `run-checkers` (script) Phase B | Raw JSON array of all issues produced by script-type checkers. Machine-readable source of truth. |
| `issues/R<N>-<NNN>.md` | `run-checkers` (script source **or** carry-forward from skipped-leaf open issues) **and** `cross-reviewer` / `adversarial-reviewer` (llm source) | One file per issue, YAML frontmatter: `id`, `status`, `severity`, `criterion_id`, `file`, `round`, `source` (`script` \| `carry-forward` \| `cross-reviewer` \| `adversarial-reviewer` \| `self-review-escalation`), optional `missing_script_path` (script source), `resolved_script_path` (when marked resolved), `resolves: R<M>-<NNN>` (cross-reviewer when closing a prior-round issue), `carries_from: R<M>-<NNN>` (carry-forward when inheriting a prior-round open issue whose file is in this round's `cross_reviewer_skip`). Summarizer and judge read **frontmatter only**; they never open issue bodies. |
| `clarification/<ts>.yml` | `domain-consultant` (sub-agent, new-version deliveries) | Present when a delivery-N start required fresh clarification on top of the previous baseline. |
| `dismissed-fails/<trace_id>-<cr-id>.md` | `cross-reviewer` (sub-agent) | Written when a writer self-review FAIL row is explicitly dismissed (instead of escalated to an issue). |
| `index.md` | `summarizer` (sub-agent) | YAML frontmatter with aggregate counts (`open_issues`, `resolved_this_round`, `critical_count`, `error_count`, `warning_count`, `coverage_percent`, `skip_set_utilization`, `writer_fail_count_sum`) + prose. Judge reads the frontmatter only. Severity counts are scoped to OPEN issues (status ∈ {new, persistent, regressed}) so resolved issues never block convergence. |
| `verdict.yml` | `judge` (sub-agent) | `verdict: converged\|progressing\|oscillating\|diverging\|stalled` + `next_action` + `evidence` block. Routes the next round. |

### Issue-status vocabulary

Statuses must be drawn from this set (vocabulary consistent across round-N/issues/,
summarizer, and judge):

- `new` — first-round detection
- `persistent` — same `criterion_id + file` was `new`/`persistent` in round N-1
- `resolved` — existed in round N-1 but no longer detectable this round
- `regressed` — was `resolved` in round N-1 but detected again this round

Transition rules (who sets what, per round N):

- **`new`** — emitted by `run-checkers` (script source) or by a reviewer (llm source) on
  first detection.
- **`persistent`** — set two ways. (a) the cross-reviewer re-evaluates a leaf in its focus
  list and finds the same `criterion_id + file` still detectable — writes a new record
  with `source: cross-reviewer`. (b) `run-checkers` Phase A carries the prior-round issue
  forward because its `file` is in the **current** round's `cross_reviewer_skip` and no
  one re-evaluated it — writes a new record with `source: carry-forward` and
  `carries_from: R<N-1>-<NNN>`. Carry-forward guarantees open issues never vanish from the
  summarizer's `open_issues` count just because cross-reviewer didn't re-look at them
  (incremental-review correctness).
- **`resolved`** — set by the cross-reviewer when a prior-round issue is no longer
  detectable. Writes a new record with `status: resolved`, `resolves: R<N-1>-<NNN>`.
- **`regressed`** — set by the cross-reviewer when an issue that was `resolved` in
  round N-1 is detected again.

The summarizer and the judge never set status — they only read it.

### Issue-ID format

`R<N>-<NNN>` where `<NNN>` is zero-padded 3 digits. Script-tier issues come first in a
round (NNN=001, 002, …). When the cross-reviewer runs later in the same round, it
starts at `max(existing_NNN) + 1` so IDs never collide.

## `traces/round-<N>/dispatch-log.jsonl`

JSONL — one line per **launched**/**completed** event. Written **only** by the
orchestrator (pure-dispatch principle — sub-agents never touch this file). Schema:

```jsonl
{"event": "launched", "trace_id": "R3-W-007", "role": "writer", "reviewer_variant": null, "tier": "balanced", "model": "<model>", "delivery_id": 3, "dispatched_at": "<ISO-ts>", "prompt_hash": "sha256:…", "linked_issues": [...]}
{"event": "completed", "trace_id": "R3-W-007", "role": "writer", "ack_status": "OK", "linked_issues": [...], "returned_at": "<ISO-ts>", "self_review_status": "FULL_PASS", "fail_count": 0}
```

Role letters (the single letter after the round number in `trace_id`): `C`
domain-Consultant · `P` Planner · `W` Writer · `V` reViewer (cross or adversarial —
distinguished by `reviewer_variant`) · `R` Reviser · `S` Summarizer · `J` Judge.

The `metrics-aggregate` tool in `--diagnose` mode reads this file plus the harness
transcripts to produce `metrics/<scope>.metrics.yml`.

## `versions/<N>.md`

Written by the summarizer's on-converge phase when the judge verdict is `converged`.
Sits alongside the annotated git tag produced by the delivery commit. Each file is a
frozen snapshot of `quality_at_delivery` (final issue counts, coverage, regressed
count, writer fail count) — the authoritative "what did we ship and how clean was it"
record.

## `metrics/`

Output of the generator's `metrics-aggregate --diagnose` invocations. Pure-script,
never LLM-written. Scope is either a round (`round-<N>.metrics.yml`) or a delivery
(`delivery-<N>.metrics.yml`). Contents: latency, cost, tier distribution, coverage-gap
warnings. `README.md` under this subdir is a rolling trend table appended by the
summarizer's on-converge phase.

## `hitl/`

One file per human-in-the-loop override. Examples: `--force-continue`
acknowledgments, regression justifications, stalled-release approvals. Format is
free-form YAML with at minimum `decided_at`, `decision`, and `rationale`.

---

## How to review this run

1. **What was asked for?** — `round-0/input.md` + the `clarification/` YAML.
2. **How was it planned?** — `round-<first>/plan.md` add/modify/delete/keep lists.
3. **What did each writer produce?** — `self-reviews/` tell you which CRs each writer
   passed/failed; the artifact leaves are at the parent level (one directory up from
   `.review/`).
4. **What did the checks find?** — `round-<N>/issues/*.md` frontmatter. Start from
   `round-<N>/index.md` for the aggregate view.
5. **What did the judge decide, and why?** — `round-<N>/verdict.yml` evidence block.
6. **How expensive was it?** — `metrics/` (re-run the generator's `--diagnose` if the
   files aren't already written).
7. **Did anyone override the judge?** — `hitl/`.

The rule of thumb: every routing decision the orchestrator made should be
reconstructable from these files **without reading any artifact leaf**. If you find
yourself opening an artifact leaf to answer "why did X happen?", that's a signal the
archive is missing an expected record — file it as a generator-internal bug.

---

## Run history for this skill

Keep this section append-only. Each delivery entry below is a summary of the
corresponding `versions/<N>.md` + the round sequence that produced it.

### Delivery 1 — rounds 1–2 — FromScratch generation
- **Trigger**: generator invoked with a sparse 29-word prompt describing "a skill
  that converts sparse product ideas into self-contained multi-file PRDs for AI
  coding agents", with `@skills/prd-analysis.backup` as a reference.
- **Round 1**: planner emitted a 10-leaf `add:` plan (SKILL.md, review-criteria,
  domain-glossary, artifact-template, 5 sub-agent prompts + 1 reviser prompt).
  Writer fan-out of 10 produced the leaves; all 10 self-reviews FULL_PASS.
  Script-tier `run-checkers` filed 11 `CR-META-missing-checker` issues (the
  writer-authored criteria declared `script_path`s for scripts not shipped in
  this delivery).
- **Round 2**: reviser rewrote `common/review-criteria.md` to convert the 11
  affected CRs from `checker_type: script` → `checker_type: llm` with
  `script_pending:` pointers. Cross-reviewer verified → 11 × status=resolved.
- **Verdict**: `converged` (round-2). Tag: `delivery-1-first-delivery-of-prd-analysis-generativ`.
- **Authoritative record**: `versions/1.md`.

### Delivery 2 — rounds 3–8 — Post-generation `--review` cycle
- **Trigger**: generator invoked in `--review --full` mode on the already-delivered
  skill to audit semantic-tier conformance.
- **Round 3** (`--review --full`): `run-checkers` 0 issues; full cross-reviewer
  over all 48 leaves found 6 issues (5 error + 1 warning), all against
  writer-authored leaves — CR-L01 self-contained violations (artifact-template
  referenced the external backup; planner referenced non-existent templates)
  and CR-L11 criteria-internally-consistent violations (stale / invented /
  misnamed CR IDs across the sub-agent prompts).
- **Round 4** (incremental `--review`): no files changed, skip-set put all 48
  leaves in `cross_reviewer_skip` → no cross-reviewer dispatch; `run-checkers`
  Phase A carry-forward inherited R3's 6 open issues as status=persistent.
  Verdict=progressing (correctly blocked from converged by coverage=0 safeguard
  AND by the now-propagated persistent count of 6).
- **Round 5** (revise): 5 parallel reviser dispatches, one per file-group, fixed
  all 6 issues in place.
- **Round 6** (`--review`): cross-reviewer verified 6 × status=resolved; its
  class-based scan surfaced 1 new finding (R6-007: adversarial-reviewer and
  per-issue-reviser hadn't been updated in R5 when cross-reviewer's schema was
  unified — same CR-L11 class). Verdict=progressing.
- **Round 7** (revise): 2 parallel reviser dispatches completed the schema
  alignment across the two sibling prompts.
- **Round 8** (`--review`): cross-reviewer verified R8-001 × status=resolved
  (closes R6-007). All 6 hard convergence conditions satisfied:
  `open_issues=0`, `coverage_percent=100`, `critical_count=0`, `error_count=0`,
  `regressed_count=0`, `writer_fail_count_sum=0`.
- **Verdict**: `converged` (round-8). Tag: `delivery-2-post-generation-review-cycle-7-issues-c`.
- **Authoritative record**: `versions/2.md`.

### Aggregate totals
- Deliveries committed: 2. Total rounds executed: 8 (round-0 bootstrap + rounds 1–8).
- Sub-agent dispatches recorded in `traces/round-*/dispatch-log.jsonl`: ~30 traces
  (1 consultant, 1 planner, 10 writers, 3 cross-reviewers, 6 summarizers, 2 judges, 7 revisers).
- See `metrics/delivery-1.metrics.yml` and `metrics/delivery-2.metrics.yml` for
  per-role cost + latency breakdowns. **Caveat (2026-04-24)**: the generator's
  `aggregate.py` strict-model JOIN fix (Bug #13) causes under-attribution for
  some primary-JOIN events (the event's `model` string in the harness JSONL
  doesn't always match the dispatch-log's `model` string verbatim). Treat the
  cost numbers in these files as a lower bound until the JOIN path is
  re-validated; the open-issue trajectory, round sequence, and verdict
  progression above are authoritative.
