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
├── issues/
│   ├── summary.yml         ← cross-round issue history (cross-reviewer reads for fingerprint matching, guide §7.6)
│   └── archive.yml         ← pruned per-retention summary entries (older deliveries)
├── round-0/                ← bootstrap (input + glossary probe + clarification)
├── round-1/, round-2/ …    ← per-round work (issues | self-reviews | reviewer-output | index | verdict)
├── traces/round-<N>/       ← dispatch-log.jsonl for that round (one JSONL line per launched/completed event)
├── versions/<N>.md         ← on-converge delivery summaries (only written when verdict=converged)
├── metrics/                ← aggregated metrics (produced by metrics-aggregate in --diagnose mode)
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
| `current_round` | Monotonically incremented across rounds and deliveries. Read by run-checkers, the cross-reviewer (for trace_id assignment), and the phase-gate scripts. |
| `current_delivery` | Bumped when a verdict=converged triggers the delivery commit. |
| `mode` | One of `generate-from-scratch`, `generate-new-version`, `review`, `revise`. |
| `phase` (optional) | Set to `on-converge` just before the summarizer's on-converge phase is dispatched. |
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

| File / dir | Produced by | When |
|---|---|---|
| `plan.md` | `planner` (sub-agent) | First round of a delivery; after plan approval it drives writer fan-out. New-version deliveries include `delete`/`modify`/`add`/`keep` lists. |
| `self-reviews/R<N>-W-<NNN>.md` | `writer` (sub-agent) | One per writer dispatch. Substantive CR PASS/FAIL checklist + `self_review_status` + `fail_count`. Formal CRs are NOT recorded here — `scripts/run-checkers.sh` enforces them as a hard gate before the writer ACKs (guide §4 + §4.1). |
| `reviewer-output/<trace_id>.json` | `cross-reviewer` / `adversarial-reviewer` (sub-agent) | One JSON document per reviewer dispatch with the LLM raw-output schema (see `common/issue-schema.md`). The orchestrator pipes this into `scripts/create-issues.sh` to materialize per-issue files. |
| `issues/I-NNN.md` | `scripts/create-issues.sh` | One file per issue, YAML frontmatter conforming to `common/issue-schema.md`. Schema enforced by `scripts/check-issue-schema.sh` (guide §10 self-closure). |
| `clarification/<ts>.yml` | `domain-consultant` (sub-agent, new-version deliveries) | Present when a delivery-N start required fresh clarification on top of the previous baseline. |
| `index.md` | `summarizer` (sub-agent) | YAML frontmatter with aggregate counts by `state` (`new_count`, `fixed_count`, `false_positive_count`, `deferred_count`, `superseded_count`) and `severity` (`critical_count`, `error_count`, `warning_count`), plus ratio signals (`false_positive_ratio`, `deferred_ratio`, `recurrence_count`) + prose. Judge reads the frontmatter only. |
| `verdict.yml` | `judge` (sub-agent) | `verdict: converged\|progressing\|oscillating\|diverging\|stalled` + `next_action` + `evidence` block. Verdict computed per `formal_PASS ∧ substantive_PASS` (guide §5). |

### Issue state machine (guide §7.2)

Each issue is in exactly one of:

- **`new`** — just created by `scripts/create-issues.sh` (from a reviewer's
  raw-output JSON document).
- **`fixed`** — the per-issue-reviser modified the leaf and the formal-review
  re-run reported PASS for the affected criteria.
- **`false-positive`** — the reviser dismissed the finding; requires a
  `dismissed_reason` field in frontmatter.
- **`deferred`** — known to be a real issue but out of scope this round;
  requires `defer_until` (one of `round-N+M | delivery-N+M | never |
  input-arrived`) and `defer_reason`.
- **`superseded`** — covered by another issue; requires `superseded_by:
  <id>`.

Phase gates around state transitions (guide §7.3):

- `scripts/check-review-readiness.sh` — refuses to enter a new review round
  while any issue from prior rounds is still in `state: new`.
- `scripts/check-revise-completeness.sh` — refuses to close the revise pass
  while any issue this round is still in `state: new`.

### Issue-ID format

`I-NNN` where `<NNN>` is zero-padded 3 digits, monotonic across all rounds
of the artifact. `create-issues.sh` allocates the next free id by scanning
all existing issue files.

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
frozen snapshot of `quality_at_delivery` (final issue counts by state and severity,
ratio signals, recurrence count, writer fail count, justified regressions) — the
authoritative "what did we ship and how clean was it" record.

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
