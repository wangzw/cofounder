---
name: prd-analysis
version: 1.1.0
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, prepare requirements for AI coding agents, or evolve an existing PRD for a new iteration. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis', 'evolve PRD', 'new iteration'."
---

# prd-analysis — AI-Coding-Ready Product Requirements Documents

## Artifact Variant: Document

prd-analysis generates PRDs as a **multi-file directory** — a pyramid-indexed bundle of README, journey leaves, feature leaves, and architecture topic files. It operates as a **multi-stage interactive pipeline** (questioning → document parsing → review → revise → evolve), not a generative-skill subagent triad. The orchestrator drives the user dialogue directly via sequential mode-routing to topic files. This maps to guide §7.2 (Document variant): the primary artifact is a structured Markdown document set consumed by human reviewers and downstream AI coding agents alike.

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:prd-analysis` or `/cofounder:prd-analysis path/to/notes.md` | `generate/questioning-phases.md`, `common/output-discipline.md` (+ `generate/document-mode.md` if document arg present; the writer subagent's self-audit follows `generate/in-generate-review.md`, not loaded into orchestrator context) | Interactive questioning (or document parsing) → PRD file generation → self-review → user review → commit |
| generate (new version) | `/cofounder:prd-analysis --evolve <prd-dir> [notes.md]` | `generate/evolve-mode.md`, `generate/questioning-phases.md`, `common/output-discipline.md` (+ `common/scope-reference.md` + `common/templates/review-checklist.md` on demand when running the evolve review checklist) | Diff-aware iteration on baseline PRD; ID-stable new/modified features + tombstones for deprecated items |
| review | `/cofounder:prd-analysis --review <prd-dir>` | `review/index.md`, `common/parallel-dispatch.md`, `common/output-discipline.md` | Formal hard gate (scripts) → substantive LLM review → script-driven issue creation; issues filed under `.review/round-N/issues/` per `common/issue-schema.md` (read at runtime by `create-issues.sh` and `check-issue.sh`, not loaded into the orchestrator's prompt context). |
| revise | `/cofounder:prd-analysis --revise <prd-dir>` | `revise/index.md`, `common/parallel-dispatch.md`, `common/output-discipline.md` | Per-issue revise loop with state-machine transitions (new → fixed/false-positive/deferred/superseded); phase gate via `check-revise-completeness.sh`. Schema reference `common/issue-schema.md` is read at runtime by reviser subagent, not loaded by orchestrator. |
| compact | `/cofounder:prd-analysis --compact <prd-dir>` | `compact/index.md`, `common/output-discipline.md` | Pure-script mode (no sub-agent dispatch). Aggregates intermediate review rounds of the current delivery into a single `.review/round-<final>/compacted-history.md` and deletes the intermediate `round-N/` and `traces/round-N/` directories. Gated on `verdict: converged` for the current delivery's final round. |
| `--diagnose` | `[--round N \| --delivery N \| --since <iso>]` | Only `scripts/metrics-aggregate.sh` (pure script; no sub-agent prompt loaded, no artifact leaves read) | Aggregate harness JSONL + dispatch-log; output `.review/metrics/<scope>.metrics.yml` |

Do NOT load files not listed for the current mode — unused files waste context.

## Phase Contract

The skill operates as an alternating **write → read → write → read …**
sequence, with hard gates at every phase boundary. A phase MUST NOT
end until its exit gate passes; the next phase MUST NOT start until
the prior phase has ended.

### Write phase

- **Modes**: initial `generate` (writers author leaves from a plan) and
  `revise` (per-issue revisers fix leaves to address issues).
- **Goal**: produce a PRD bundle that is structurally well-formed and,
  in the revise case, has no open issues.
- **Exit gate** (necessary before write phase ends):
  1. **Formal review PASS** — `scripts/run-checkers.sh <prd-dir>`
     exits 0. This is the bundle-level structural gate (every per-
     artifact `check-*.sh` passes). Failures cause the orchestrator to
     loop the writer / reviser until PASS, never to ACK the phase as
     done with formal violations outstanding.
  2. **State-machine PASS (revise only)** —
     `scripts/check-revise-completeness.sh <prd-dir> <round>` exits 0;
     i.e. **no issue is left in `state: new`** in the current round.
     Every issue created during the prior read phase has been
     dispositioned to `fixed`, `false-positive`, `deferred`, or
     `superseded` with the appropriate metadata. (Generate's first
     round has no inbound issues, so this clause is vacuous.)
- Both gates are short-circuit: if either fails, the write phase loops
  until both PASS, OR the orchestrator escalates to HITL after the
  iteration cap (`config.yml convergence.max_iterations`).

### Read phase

- **Mode**: `review`. LLM cross-reviewer (and conditionally adversarial-
  reviewer) inspect the bundle, emit findings as JSON in
  `reviewer-output/<trace_id>.json`, and `scripts/create-issues.sh`
  materializes per-issue files in `state: new`.
- **Entry gate** (necessary before read phase starts):
  - `scripts/check-review-readiness.sh <prd-dir>` exits 0 — i.e. **no
    issue from any prior round is still in `state: new`**. This
    enforces "the previous write phase finished cleanly" (guide §7.3).
    Equivalent to verifying the prior write phase's state-machine PASS
    persists across the boundary.
- **Exit gate**: judge writes `verdict.yml`. There is no formal/state
  gate on read phase exit — read phase's job is to produce issues
  (which are by definition `state: new` until revise acts on them).
- After read phase ends, **if the verdict is `progressing`, control
  passes to revise (a write phase) which inherits the open
  `state: new` issues** and must dispose of them before exiting.

### Cycle invariants

- A `state: new` issue **only** exists during read phase output and
  the revise (write) phase that follows. It MUST NEVER survive into
  the next read phase — the readiness gate enforces this.
- A bundle that fails formal review **never** reaches LLM cross-
  reviewer dispatch. The Step 1 hard gate in `review/index.md`
  (`verify-phase-entry.sh read`) short-circuits to revise without
  spending LLM tokens (guide §6).
- Write phase loops on its own scripts (writer self-audit + reviser
  self-loop) until formal PASS — it does NOT escape to read phase
  with formal violations.

### Script-enforced boundary gates

Every phase has a **MANDATORY first step** that calls a single
boundary-gate script. The script's non-zero exit halts the phase before
any further action. Documenting the contract in prose is
enforcement-by-LLM; threading it through a script is enforcement-by-
process — even if subsequent steps are skipped or reordered, control
cannot reach a phase's main work without the gate having exited 0.

The unified entry point is `scripts/verify-phase-entry.sh <phase>
<prd-dir> [round]`. Each orchestration file's Step 1 (or Step 2 after
the bootstrap precheck for generate modes) is this call:

| Phase | Orchestration file | First call |
|-------|-------------------|------------|
| read (review) | `review/index.md` Step 1 | `verify-phase-entry.sh read <prd-dir>` |
| write (revise) | `revise/index.md` Step 1 | `verify-phase-entry.sh revise <prd-dir> <round>` |
| write (generate-fresh) | `generate/from-scratch.md` Step 2 | `verify-phase-entry.sh generate-fresh <prd-dir>` |
| write (generate-evolve) | `generate/new-version.md` Step 2 | `verify-phase-entry.sh generate-evolve <prd-dir>` |
| compact | `compact/index.md` Step 2 | `verify-phase-entry.sh compact <prd-dir>` |

`verify-phase-entry.sh` consolidates the underlying gates per phase:

| Phase | Underlying gate scripts |
|-------|-------------------------|
| read | `check-review-readiness.sh` (no `state: new` from prior rounds) AND `run-checkers.sh` (bundle formal PASS) |
| revise | round-N has at least one `state: new` issue (otherwise no work) |
| generate-fresh | bundle is empty/absent (avoids overwriting an existing PRD) |
| generate-evolve | prior delivery's `versions/<N-1>.md` exists |
| compact | current delivery's final round has `verdict: converged` AND at least one intermediate round exists |

Exit codes follow the §9 contract uniformly: `0` = phase may proceed,
`1` = phase MUST NOT proceed (precondition failed; see stdout), `2` =
script-level error → HITL.

### Boundary-to-gate mapping (cycle view)

| Boundary | Gate script(s) at the boundary | Exit gate of | Entry gate of |
|----------|--------------------------------|--------------|---------------|
| revise → review | `verify-phase-entry.sh read` (= readiness + run-checkers) | revise (write) | review (read) |
| review → revise | (verdict-driven; revise's own entry gate `verify-phase-entry.sh revise` then runs) | review (read) | revise (write) |
| revise → revise (loop) | `check-revise-completeness.sh` + `run-checkers.sh` (Step 5 + Step 4 self-loop) | revise iteration | next revise iteration |
| generate → review (first delivery) | `verify-phase-entry.sh read` | generate (write) | review (read) |
| converged → delivery | (verdict only) | review (read) | delivery sequence |

## Bootstrap Precheck

Every mode MUST call `scripts/git-precheck.sh` as the first action. On failure (non-zero exit): skill exits; does NOT enter any generate/review/revise mode.

- Verifies `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`
- If cwd is not a git repo, auto-runs `git init` + empty bootstrap commit
- During Bootstrap Precheck, orchestrator MUST write `skill-root: <absolute path to this skill's root directory>` to `<target>/.review/state.yml` so downstream sub-agents can locate this skill's own scripts.

## Core Contract

- Orchestrator is **pure dispatch + bookkeeping only**. Forbidden: reading artifact leaves, summarizing content, computing convergence verdicts, rewriting artifacts, analyzing issue priority.
- Hard dependencies: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`. NEVER add `pyyaml` / `jq` / `slugify` / any third-party package.
- Target artifact in-place mutated. History through git tags (`delivery-<N>-<slug>` annotated tags) + `.review/versions/<N>.md` + target `CHANGELOG.md`.
- `.review/` lives at target root. Pyramid-indexed: `round-<N>/` + `metrics/` + `versions/`.
- Round numbers are cross-delivery monotonic.

**Permitted main-agent reads:** in `generate/from-scratch.md` Step 7 (HITL plan-approval gate) and `generate/new-version.md` Step 7 (same), the orchestrator MUST read `<prd-dir>/.review/round-N/plan.md` to present the plan to the user. It MAY also read `README.md`, `REVISIONS.md`, and `architecture.md` (index files, not per-feature/per-journey leaves) when a cross-file routing check requires spot-verification. It MUST NOT bulk-read the per-feature or per-journey leaf set; that is the cross-reviewer's scope.

## Input Modes (Summary)

```
/prd-analysis                                          # interactive mode (default)
/prd-analysis path/to/notes.md                         # document-based mode
/prd-analysis --output docs/raw/prd/my-project         # custom output dir
/prd-analysis notes.md --output ./prd                  # both
/prd-analysis --review docs/raw/prd/xxx/               # review existing PRD (single round)
/prd-analysis --review docs/raw/prd/xxx/ --auto        # auto-loop review↔revise until convergence
/prd-analysis --revise docs/raw/prd/xxx/               # per-issue revise loop (state-machine: new → fixed/false-positive/deferred/superseded)
/prd-analysis --revise docs/raw/prd/xxx/ --auto        # same loop, entered from the revise side
/prd-analysis --evolve docs/raw/prd/xxx/               # incremental PRD for new iteration
/prd-analysis --evolve docs/raw/prd/xxx/ notes.md      # evolve with document input
/prd-analysis --compact docs/raw/prd/xxx/              # retire intermediate review rounds before next stage
```

## Output Structure

```
docs/raw/prd/YYYY-MM-DD-{product-slug}/
├── README.md                # Product overview + journey index + feature index + roadmap
├── REVISIONS.md             # Revision history (only present after first --revise)
├── journeys/
│   ├── J-001-{slug}.md      # Individual journey spec (self-contained)
│   └── ...
├── architecture.md          # INDEX ONLY (~50-80 lines) — diagram + links to topic files
├── architecture/            # Topic files — each standalone, independently readable
│   ├── tech-stack.md
│   ├── design-tokens.md
│   ├── data-model.md
│   ├── coding-conventions.md
│   ├── security.md
│   └── ...
├── features/
│   ├── F-001-{slug}.md      # Self-contained feature spec (inline-copies context)
│   └── ...
└── .review/                 # Transient — not version-controlled
    ├── state.yml
    ├── traces/
    │   └── round-N/
    │       └── dispatch-log.jsonl
    ├── round-N/
    │   ├── issues/
    │   │   └── I-NNN.md
    │   └── self-reviews/        # Writer self-review archives — only when self_review_status == PARTIAL; FULL_PASS writers leave no file (status carried by ACK + dispatch-log)
    ├── metrics/
    └── versions/
```

Use templates: `common/templates/prd-template.md` (README), `common/templates/journey-template.md` (individual journeys), `common/templates/architecture-template.md` (architecture index + topic files), `common/templates/feature-template.md` (feature specs). Evolve mode uses `common/templates/evolve-readme-template.md` instead of `common/templates/prd-template.md`.

## Output Path

- **Default:** `docs/raw/prd/YYYY-MM-DD-{product-slug}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing

## Immutability Rule

| Downstream State | Modify in Place? | Rationale |
|-----------------|-----------------|-----------|
| No design exists | Yes | No downstream consumers to break |
| Design exists, not implemented | Yes + append entry to `REVISIONS.md` | Design team needs the change record |
| Implementation exists | No — create new version | Modifying in place would invalidate implemented code |

**Evolve mode note:** `--evolve` always creates a new directory (new date) — it never modifies the predecessor PRD.

## Key Principles

- **One question at a time** — don't overwhelm the user
- **MVP ruthlessly** — push back on scope creep
- **Minimal context** — agents read one small file, not a giant document
- **Copy, don't reference** — feature files include relevant data models, conventions, and journey context inline
- **README is stable navigation** — revision history lives in `REVISIONS.md`, not README
- **No ambiguity** — if a requirement can be interpreted two ways, clarify now
- **Omit empty sections** — if a section has nothing useful, skip it
- **Discipline files are non-optional** — `common/parallel-dispatch.md` and `common/output-discipline.md` rules take precedence over per-mode wording that conflicts

## Orchestrator Dispatch Contract

<!-- snippet-c-fingerprint: dispatch-log-v1 -->

### Per every dispatch (mandatory)

For **every** sub-agent dispatch the orchestrator MUST:

1. **Assign a `trace_id`** in the format `R{round}-{role-letter}-{nnn}` where:
   - `round` is the integer round number
   - `role-letter` is the single-letter code from the table below (**no two-letter forms**)
   - `nnn` is a zero-padded 3-digit sequence counter, per-round per-role (`001`, `002`, …)

   | Role | Letter | Notes |
   |------|--------|-------|
   | domain-Consultant | `C` | |
   | Planner | `P` | |
   | Writer | `W` | |
   | reViewer (cross + adversarial) | `V` | Single letter for both reviewer variants; distinguish via `reviewer_variant` in dispatch-log |
   | Reviser | `R` | |
   | Summarizer | `S` | |
   | Judge | `J` | |

   > Example: `R3-W-007` = Round 3, writer, 7th call. `R5-V-003` = Round 5, reviewer, 3rd call
   > (cross vs. adversarial is determined by `reviewer_variant` in the dispatch-log, not the letter).
   > Note: in `R3-R-001` the leading `R` means "Round 3"; the second `R` is the reviser role code —
   > parse by splitting on `-` into three segments, never by letter shape.

2. **Before dispatch — append a `launched` event** to
   `.review/traces/round-<N>/dispatch-log.jsonl` (one JSONL line, see schema below).

3. **After dispatch — append a `completed` event** to the same file once the ACK is received
   (see schema below).

4. **Inject `trace_id`** as the **literal first line** of the sub-agent's first user message:
   ```
   trace_id: R3-W-007
   ```

### `launched` event schema

One JSONL line appended before dispatch:

```jsonl
{"event": "launched", "trace_id": "R3-W-007", "role": "writer", "reviewer_variant": null, "tier": "balanced", "model": "claude-sonnet-4-5", "delivery_id": 3, "dispatched_at": "2026-04-20T10:15:30Z", "prompt_hash": "sha256:...", "linked_issues": ["I-012"], "session_file": "/Users/me/.claude/projects/my-project/abc-def.jsonl"}
```

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `event` | `"launched"` | Literal string |
| `trace_id` | string | JOIN key; must match user-prompt first line and sub-agent ACK |
| `role` | string | One of: `writer`, `reviewer`, `reviser`, `planner`, `summarizer`, `judge`, `domain_consultant` |
| `reviewer_variant` | `"cross"` \| `"adversarial"` \| `null` | Required when `role == "reviewer"`; `null` for all other roles |
| `tier` | string | Model tier classification |
| `model` | string | Model identifier requested via the Agent-tool `model` parameter. MUST be the config-mapped value for this role's tier (e.g. `balanced` → `claude-sonnet-4-5`). Used for pricing lookup; `--diagnose` flags drift when the harness-observed model disagrees. |
| `delivery_id` | integer | `--delivery` scope filter for `metrics-aggregate.sh` |
| `dispatched_at` | ISO-8601 | Time-window start for fallback JOIN + latency calculation |
| `prompt_hash` | string | `sha256:...` of full prompt text; required if skill supports resume (§17) |
| `linked_issues` | array of strings | Issue IDs relevant to this dispatch; may be empty array `[]` |
| `session_file` | string \| omit | Absolute path to harness JSONL for this dispatch; omit if unavailable — falls back to rglob scan |

### `completed` event schema

One JSONL line appended after ACK is received:

```jsonl
{"event": "completed", "trace_id": "R3-W-007", "role": "writer", "ack_status": "OK", "linked_issues": ["I-012"], "self_review_status": "PARTIAL", "fail_count": 1, "returned_at": "2026-04-20T10:16:10Z"}
```

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `event` | `"completed"` | Literal string |
| `trace_id` | string | Must match the paired `launched` event |
| `role` | string | Same as `launched` |
| `ack_status` | `"OK"` \| `"FAIL"` | See §3.9 ACK semantics |
| `linked_issues` | array of strings | Backfilled from ACK; may be empty |
| `returned_at` | ISO-8601 | Time-window end for fallback JOIN + latency calculation |
| `self_review_status` | `"FULL_PASS"` \| `"PARTIAL"` | **Writer only** (required); omit for all other roles |
| `fail_count` | integer | **Writer only** (required); number of FAIL rows in self-review archive; `0` when `FULL_PASS`; omit for all other roles |

### FORBIDDEN

The orchestrator MUST NOT:

- **Read artifact leaves** — no reading of `<artifact-path>` content; those paths belong to sub-agents
- **Summarize or compute verdicts** from artifact content
- **Rewrite or generate artifacts** (production content belongs to sub-agents only)
- **Write to `.review/` business archive files** (self-reviews, issues, plan, verdict) — those are sub-agent write targets

The orchestrator's ONLY write targets are `state.yml` and `dispatch-log.jsonl` (§5.1 pure-dispatch principle).

### Permitted Actions (guide §5.1)

1. Dispatch one sub-agent via Task tool
2. Fan-out multiple sub-agents in parallel
3. Decide next step from ACK / judge verdict / §16 failure classification
4. Internal bookkeeping: Edit/Write to `.review/state.yml` + `.review/traces/round-*/dispatch-log.jsonl`; call `scripts/` deterministic scripts

### Forbidden Actions (guide §5.1)

- Reading artifact leaves
- Summarizing content
- Computing convergence verdicts
- Rewriting artifacts
- Analyzing issue priority
- Writing business archives (issues / self-reviews / plan.md / verdict.yml / index.md / CHANGELOG)

## `--diagnose` Mode

**Pure script mode. MUST NOT** load any sub-agent prompt.

### Execution Steps (FORBIDDEN to deviate)

1. Validate `scripts/metrics-aggregate.sh` exists and is executable.
2. Pass-through args verbatim.
3. Invoke:
   ```bash
   scripts/metrics-aggregate.sh --diagnose "$@" \
     --review-dir ./.review \
     --harness-dir "${CLAUDE_HARNESS_DIR:-$HOME/.claude/projects}" \
     --config common/config.yml
   ```
4. Handle exit codes: 0=success; 1=argument error; 2=input error; 3=JOIN coverage < 50%.
5. Relay script output verbatim — no LLM post-processing.

## Model Tiers

Abstract: `heavy` / `balanced` / `light`. Mapping in `common/config.yml` (`model_tier_defaults` + `model_mapping`).

### Per-dispatch model override (MANDATORY for cost control)

When the orchestrator dispatches a sub-agent via the Claude Code Agent tool, it **MUST**
pass the `model` parameter to override the default (parent-session inheritance). Without
this override, all sub-agents run on the parent session's model — typically `opus` —
which costs 5–25× the configured tier rate. Per the `tool_permissions` +
`model_tier_defaults` sections of `common/config.yml`:

| Role | Default tier | Agent-tool `model` value |
|------|------|------|
| domain-consultant | `heavy` | `"opus"` |
| planner | `heavy` | `"opus"` |
| writer | `balanced` | `"sonnet"` |
| reviewer (cross + adversarial) | `heavy` | `"opus"` |
| reviser | `balanced` | `"sonnet"` |
| summarizer | `light` | `"haiku"` |
| judge | `light` | `"haiku"` |

Users may override a single dispatch via `--tier <role>=<tier>` (see CLI Flags).

Orchestrator MUST log both `model_requested` (the tier-mapped value passed to the Agent
tool) and the `model` actually observed in the harness JSONL for each dispatch, so
`--diagnose` can flag drift.

## CLI Flags

| Flag | Applies to | Semantics |
|------|-----------|-----------|
| `--interactive` | Generate | Force-dispatch `domain-consultant` even on dense input. |
| `--no-consultant` | Generate | Skip `domain-consultant` even if triggers fire; orchestrator synthesizes a minimal `clarification.yml` (R-001..R-007 = `deferred`) from the user prompt in `input.md`. Saves the consultant's heavy-tier dispatch (~$4 at opus rates). |
| `--force-continue` | Generate | Override `oscillating`/`diverging` judge verdict and run one more round; requires HITL approval gate. |
| `--tier <role>=<tier>` | Generate / Review / Revise | Override model tier for one dispatch role (e.g. `--tier writer=heavy`). |
| `--max-iterations N` | Generate / Review / Revise | Override `config.yml.convergence.max_iterations`. |
| `--full` | Review | Force the next review round to apply every LLM criterion to every leaf, regardless of incremental scope. **Single invocation only** — `scripts/compute-review-scope.sh` honors the flag exactly once; in `--auto` mode the orchestrator drops `--full` from subsequent rounds in the same loop so the rest of the loop runs with normal incremental scoping. Use to recover from a suspected stale `leaves-manifest.yml` or to force a fresh look at unchanged leaves after editing `common/review-criteria.md`. Without this flag, scoping is automatic: full on the first round of each delivery (no prior manifest) and incremental thereafter. |
| `--auto` | Review / Revise | Non-interactive review-revise loop. Iterate until terminal verdict (`converged`, `oscillating`, `diverging`, `stalled`) or `max_iterations` is reached, **without HITL prompts**. On `converged`, the orchestrator runs the full delivery sequence (`review/index.md` Step 9), which includes auto-compaction of the just-converged delivery's intermediate rounds via `scripts/compact-delivery.sh` so the bundle is hand-off-ready for the next pipeline stage. On non-converged terminal verdicts the orchestrator prints the verdict + summary path and exits non-zero (1 = non-converged, 2 = script error). Suitable for `claude -p ... --auto` batch use. Implies `hitl.auto_approve = [plan_approval, force_continue, regression_justification, stalled_release]` for the duration of the run; user-facing prompts are replaced by an `auto_decision` block in `state.yml` (containing `verdict`, `round`, `reason`, and verdict-specific IDs — see `review/index.md` Step 8 for the schema) so the run can be inspected post-hoc. The orchestrator does NOT write any sidecar file under `.review/round-<N>/` — that would violate the pure-dispatch write-set above; `state.yml` is the only auto-mode artifact. |

## Next Steps Hint

After committing, print the following guidance to the user:

**Initial creation and revise mode:**
```
PRD complete: {output path}

Next steps:
  Interactive — /system-design {output path}
  Automated  — claude -p "generate system design based on {output path}" --auto
```

**Evolve mode** — use the cascade notification from the "Commit Message & Post-Commit Cascade" section of `generate/evolve-mode.md` instead.

## Configuration & Subagent Files

- **Config**: `common/config.yml`
- **Review criteria**: `common/review-criteria.md` (script-tier and LLM-tier criteria; see guide §1)
- **Issue schema**: `common/issue-schema.md` (on-disk issue format + LLM raw-output format + summary.yml format)
- **Domain glossary**: `common/domain-glossary.md`
- **Formal-review scripts** — one per artifact type (guide §1.1 + §9 contract: 3-state returncode + stdout restates meaning + idempotent + agent-actionable):
  - `scripts/run-checkers.sh` — dispatcher; auto-discovers and invokes every `check-*.sh` (except phase gates), aggregates findings
  - PRD bundle:
    - `scripts/check-readme.sh`              README.md (CR-PP01, CR-PP03, CR-PP04)
    - `scripts/check-journey.sh`             journeys/J-NNN-*.md (CR-PP02, CR-PP04, CR-FM01)
    - `scripts/check-feature.sh`             features/F-NNN-*.md (CR-PP02, CR-PP04, CR-PP15F, CR-FM01)
    - `scripts/check-revisions.sh`           REVISIONS.md (CR-PP05, CR-PP04)
    - `scripts/check-architecture-index.sh`  architecture.md (CR-PP01-ARCH, CR-PP03 soft, CR-PP04)
    - `scripts/check-architecture-topic.sh`  architecture/*.md (CR-PP04)
  - Audit artifacts (guide §10 self-closure):
    - `scripts/check-issue.sh`               .review/round-*/issues/I-NNN.md (CR-IS01)
    - `scripts/check-clarification.sh`       .review/round-0/clarification/*.yml (CR-CL01, CR-CL02)
    - `scripts/check-plan.sh`                .review/round-*/plan.md (CR-PL01, CR-PL02)
    - `scripts/check-self-review.sh`         .review/round-*/self-reviews/*.md (CR-SR01..03)
    - `scripts/check-reviewer-output.sh`     .review/round-*/reviewer-output/*.json (CR-RO01, CR-RO02)
    - `scripts/check-round-index.sh`         .review/round-*/index.md (CR-RI01, CR-RI02)
    - `scripts/check-verdict.sh`             .review/round-*/verdict.yml (CR-VD01, CR-VD02)
    - `scripts/check-version.sh`             .review/versions/*.md (CR-VS01, CR-VS02)
    - `scripts/check-compacted-history.sh`   .review/round-*/compacted-history.md (CR-CH01, CR-CH02)
  - Phase gates (separate argument shape; invoked by orchestrator, not by run-checkers):
    - `scripts/check-review-readiness.sh`    no prior `state: new` issues (guide §7.3)
    - `scripts/check-revise-completeness.sh` no `state: new` in current round (guide §7.3)
  - Helpers:
    - `scripts/create-issues.sh`             script-driven issue creation from LLM raw JSON (guide §7.1)
    - `scripts/update-summary.sh`            cross-round fingerprint summary (guide §7.6)
    - `scripts/synthesize-clarification.sh`  --no-consultant: synthesize deferred-only clarification.yml without violating orchestrator pure-dispatch contract
    - `scripts/compact-delivery.sh`          `--compact` mode: aggregates intermediate review rounds of the current delivery into `compacted-history.md` and deletes their `round-N/` + `traces/round-N/` trees
  - Pipeline-stage scripts (per audit-design guide §6):
    - `scripts/prepare-input.sh`             input-classification (CR-CL) → planner-input (CR-PL)
    - `scripts/commit-delivery.sh`           finalize a converged delivery (manifest snapshot + summary; invokes `prune-traces.sh`)
    - `scripts/snapshot-leaves.sh`           build / refresh the leaves manifest used for incremental scoping
    - `scripts/compute-review-scope.sh`      emit the per-round review scope from the leaves manifest
    - `scripts/prune-traces.sh`              drop trace artifacts retired by `--compact` / commit-delivery
    - `scripts/glossary-probe.sh`            extract candidate domain terms during questioning to seed the glossary
    - `scripts/git-precheck.sh`              workspace cleanliness gate; called as first action of every mode
    - `scripts/metrics-aggregate.sh`         `--diagnose` mode: aggregate harness JSONL + dispatch-log → `.review/metrics/<scope>.metrics.yml`
- **Sub-agent prompts**:
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md` — substantive reviewer (LLM-tier criteria only)
  - `review/adversarial-reviewer-subagent.md` — conditional adversarial probe (on critical findings)
  - `revise/per-issue-reviser-subagent.md` — state-machine transitions (guide §7.2)
  - `shared/summarizer-subagent.md`
  - `shared/judge-subagent.md` — verdict per `formal_PASS ∧ substantive_PASS` (guide §5)
