---
name: system-design
version: 0.1.0
description: "Use when the user needs to create system design documents from a PRD or requirements, perform module decomposition, define interfaces and data models, or review existing designs. Triggers: /cofounder:system-design, 'system design', 'module design', 'technical design', 'design review'."
---

# system-design — AI-Coding-Ready Technical Design Documents

## Artifact

system-design generates technical design documents as a **multi-file directory** — a pyramid-indexed bundle of README, per-module specs, and optional API contracts. It operates as a **multi-role generative pipeline** (planner → parallel writer fan-out → structural-lint → cross/adversarial review → revise → judge convergence), not a single-pass orchestrator. Each module spec is a self-contained file that a coding agent can read independently. This maps to guide §7.1 (Document variant): the primary artifact is a structured Markdown document set consumed by `/cofounder:autoforge` and human reviewers alike.

## Pipeline Position

```
/cofounder:prd-analysis  →  /cofounder:system-design  →  /cofounder:autoforge
```

- **Consumes**: PRD output at `docs/raw/prd/YYYY-MM-DD-{slug}/`
- **Produces**: design output at `docs/raw/design/YYYY-MM-DD-{slug}/`
- **Feeds**: `/cofounder:autoforge` reads `README.md` (Feature-Module matrix) + `modules/M-NNN-{slug}.md` (implementation specs)

## Input Modes

```
/cofounder:system-design                                    # interactive (no PRD path)
/cofounder:system-design path/to/prd/                       # PRD-based
/cofounder:system-design path/to/draft.md                   # document-based
/cofounder:system-design --output docs/raw/design/my-product
/cofounder:system-design --review docs/raw/design/xxx/      # read-only review (single round)
/cofounder:system-design --review docs/raw/design/xxx/ --auto  # auto-loop review↔revise until convergence
/cofounder:system-design --revise docs/raw/design/xxx/      # change management
/cofounder:system-design --revise docs/raw/design/xxx/ --auto  # same loop, entered from the revise side
/cofounder:system-design --evolve docs/raw/design/xxx/      # generate new version from an evolved PRD
/cofounder:system-design --evolve docs/raw/design/xxx/ notes.md  # supply explicit change notes
/cofounder:system-design --compact docs/raw/design/xxx/     # retire intermediate review rounds before next stage
```

**Note on evolved PRDs:** When a PRD has been evolved (`/cofounder:prd-analysis --evolve`),
either pass the new PRD path to a fresh design (`/cofounder:system-design <new-prd-path>`),
use `--evolve <design-dir>` to generate a delta-aware new version of an existing design,
or use `--revise <design-dir>` to thread specific PRD changes through the change-management
state machine.

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:system-design "<description or prd-path>"` | `generate/from-scratch.md` (+ `common/review-criteria.md` and `common/templates/*` are read by writer subagent at self-audit time, not loaded into orchestrator context) | New design from PRD/draft/interactive; domain-consultant clarifies intent, planner decomposes modules, writers fan-out (one per module + API + README); formal-review hard gate runs BEFORE semantic review |
| generate (new version) | `/cofounder:system-design --evolve <design-dir>` | `generate/new-version.md` (+ same on-demand reads as from-scratch) | Evolve existing design; planner emits delta plan (delete/modify/add/keep) |
| review | `/cofounder:system-design --review <design-dir>` | `review/index.md` | Formal hard gate (scripts) → substantive LLM review → script-driven issue creation; issues filed under `.review/round-N/issues/` per `common/issue-schema.md` (read at runtime by `create-issues.sh` and `check-issue.sh`, not loaded into the orchestrator's prompt context). |
| revise | `/cofounder:system-design --revise <design-dir>` | `revise/index.md` | Per-issue revise loop with state-machine transitions (new → fixed/false-positive/deferred/superseded); phase gate via `check-revise-completeness.sh`. Schema reference `common/issue-schema.md` is read at runtime by reviser subagent, not loaded by orchestrator. |
| compact | `/cofounder:system-design --compact <design-dir>` | `compact/index.md` | Pure-script mode (no sub-agent dispatch). Aggregates intermediate review rounds of the current delivery into a single `.review/round-<final>/compacted-history.md` and deletes the intermediate `round-N/` and `traces/round-N/` directories. Gated on `verdict: converged` for the current delivery's final round. |
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
- **Goal**: produce a design bundle that is structurally well-formed and,
  in the revise case, has no open issues.
- **Exit gate** (necessary before write phase ends):
  1. **Formal review PASS** — `scripts/run-checkers.sh <design-dir>`
     exits 0. This is the bundle-level structural gate (every per-
     artifact `check-*.sh` passes). Failures cause the orchestrator to
     loop the writer / reviser until PASS, never to ACK the phase as
     done with formal violations outstanding.
  2. **State-machine PASS (revise only)** —
     `scripts/check-revise-completeness.sh <design-dir> <round>` exits 0;
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
  - `scripts/check-review-readiness.sh <design-dir>` exits 0 — i.e. **no
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
<design-dir> [round]`. Each orchestration file's Step 1 (or Step 2 after
the bootstrap precheck for generate modes) is this call:

| Phase | Orchestration file | First call |
|-------|-------------------|------------|
| read (review) | `review/index.md` Step 1 | `verify-phase-entry.sh read <design-dir>` |
| write (revise) | `revise/index.md` Step 1 | `verify-phase-entry.sh revise <design-dir> <round>` |
| write (generate-fresh) | `generate/from-scratch.md` Step 2 | `verify-phase-entry.sh generate-fresh <design-dir>` |
| write (generate-evolve) | `generate/new-version.md` Step 2 | `verify-phase-entry.sh generate-evolve <design-dir>` |
| compact | `compact/index.md` Step 2 | `verify-phase-entry.sh compact <design-dir>` |

`verify-phase-entry.sh` consolidates the underlying gates per phase:

| Phase | Underlying gate scripts |
|-------|-------------------------|
| read | `check-review-readiness.sh` (no `state: new` from prior rounds) AND `run-checkers.sh` (bundle formal PASS) |
| revise | round-N has at least one `state: new` issue (otherwise no work) |
| generate-fresh | bundle is empty/absent (avoids overwriting an existing design) |
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

## Output Structure

```
docs/raw/design/YYYY-MM-DD-{product-name}/
├── README.md              # Design overview + module index + Feature-Module mapping matrix
├── REVISIONS.md           # Appended by --revise (created on first revision)
├── modules/
│   └── M-NNN-{slug}.md    # Self-contained per-module spec (one writer per module in fan-out)
├── api/                   # Only generated when project has APIs
│   └── API-NNN-{slug}.md  # Self-contained API contract
└── .review/               # Review/revise harness directory — transient, not version-controlled
    ├── state.yml                        # Orchestrator bookkeeping (skill-root, round number)
    ├── traces/round-<N>/
    │   └── dispatch-log.jsonl           # Per-dispatch launched/completed events
    ├── round-<N>/
    │   ├── issues/                      # Reviewer-written issue files (I-NNN.md per common/issue-schema.md)
    │   ├── self-reviews/                # Writer self-review archives
    │   ├── plan.md                      # Planner output
    │   └── verdict.yml                  # Judge convergence verdict
    ├── metrics/                         # --diagnose output
    └── versions/                        # Summarizer snapshots
```

**Agent consumption:** read `README.md` (overview + Feature-Module mapping matrix) → read one `modules/M-NNN-{slug}.md` → implement. The module file alone is sufficient for a coding agent to start working.

**gitignore:** add `docs/raw/design/*/.review/` to `.gitignore` (the review harness directory is transient and not version-controlled).

## Output Path

- **Default:** `docs/raw/design/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing
- **Cross-document paths:** when referencing PRD files, use relative paths from the design directory. Example: if PRD is at `docs/raw/prd/2026-04-09-foo/` and design is at `docs/raw/design/2026-04-09-foo/`, a module's Source Feature link is `../../../prd/2026-04-09-foo/features/F-001-slug.md`

## Core Principles

1. **Self-contained file** — each module/API spec is independently consumable by a coding agent. Copy relevant data models, interface definitions, and conventions inline; never link to a sibling file the agent must also read.
2. **Two-phase quality gate** — structural-lint (deterministic, grep-runnable: placeholder JSON, missing per-endpoint blocks, unfilled Boundary Enforcement columns, dangling endpoint references, PRD-architecture/analytics coverage gaps) runs BEFORE semantic LLM review. Mechanical findings never reach the semantic reviewer.
3. **Feature-Module mapping matrix** — the bridge between PRD features and implementation modules (README.md). Symbols: `✦` = module modifies data for the feature, `△` = module provides read-only support. The matrix is the key input for `/cofounder:autoforge`.
4. **Copy, don't reference** — relevant data models, conventions, and interface definitions are copied inline into each module file. A coding agent reading one module file should need no other file.
5. **Mode routing** — detect mode from flags; load only the relevant routing file. Templates are loaded per-writer dispatch, not globally.
6. **Dependency layering** — forward-only layer order; reverse-layer imports are blockers (not warnings), requiring: (a) consumer-side interface extraction into a lower layer, (b) callee relocation, or (c) documented cross-cutting exemption.
7. **API/module endpoint consistency** — every endpoint named in any module's API Surface table MUST exist in `api/`, and every `api/` endpoint MUST attach to a module's API Surface.
8. **Implementation Conventions enumeration** — every file under PRD's `architecture/` MUST appear as a row in README's Implementation Conventions table, or be explicitly marked `N/A — {reason}`.
9. **Status lifecycle** — Design-level Status: `Draft → Finalized → Implementing → Implemented`. Module-level `Impl` column: `NotStarted → InProgress → Done`.
10. **README is a stable navigational index** — revision history accumulates in `REVISIONS.md`, not README; REVISIONS.md is created on first revision; README's References section links to it once it exists.

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
- Round numbers are cross-delivery monotonic. Delivery-1 round-1..k, delivery-2 starts at round-k+1.
- Metrics aggregated ONLY by `scripts/metrics-aggregate.sh` via `--diagnose` mode, never by a sub-agent.

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

**Pure script mode. MUST NOT** load any sub-agent prompt. **MUST NOT** read artifact leaves, `.review/versions/`, or `review-criteria.md`. This mode's sole responsibility is to **proxy the script call and relay its output verbatim**.

### Execution Steps (FORBIDDEN to deviate)

1. **Validate**: check that `scripts/metrics-aggregate.sh` exists and is executable; if not, exit and prompt the user to restore it.
2. **Pass-through args**: forward user-provided `--round N` / `--delivery N` / `--since <iso>` verbatim to the script; if omitted, the script defaults to aggregating the latest round.
3. **Invoke**:
   ```bash
   scripts/metrics-aggregate.sh --diagnose "$@" \
     --review-dir ./.review \
     --harness-dir "${CLAUDE_HARNESS_DIR:-$HOME/.claude/projects}" \
     --config common/config.yml
   ```
4. **Handle exit codes**:

   | Exit code | Meaning | Response |
   |-----------|---------|----------|
   | 0 | Success | Report output path `.review/metrics/<scope>.metrics.yml`; **do not** expand full content |
   | 1 | Argument error | Relay script stderr verbatim; prompt user to correct CLI |
   | 2 | Input error | Relay script stderr verbatim; prompt user to verify `--review-dir`/`--harness-dir` |
   | 3 | JOIN coverage < 50% | Report output path; **relay verbatim** every entry under `warnings:` in the output YAML (copy exact text, no rewriting, no interpreting, no summarizing); suggest user verify orchestrator is injecting `trace_id: R3-W-007` (canonical format) as first line of each dispatch prompt |

5. **No LLM post-processing**: do not rewrite, summarize, or embellish script output. The `.review/metrics/<scope>.metrics.yml` file is the machine-readable source of truth.

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
| `--tier <role>=<tier>` | Generate / Review / Revise | Override model tier for one dispatch role (e.g. `--tier writer=heavy`). Abstract tiers `heavy/balanced/light` map via `config.yml.model_tier_defaults`. |
| `--max-iterations N` | Generate / Review / Revise | Override `config.yml.convergence.max_iterations` (stalled verdict threshold; default 5). |
| `--full` | Review | Force the next review round to apply every LLM criterion to every leaf, regardless of incremental scope. **Single invocation only** — `scripts/compute-review-scope.sh` honors the flag exactly once; in `--auto` mode the orchestrator drops `--full` from subsequent rounds in the same loop so the rest of the loop runs with normal incremental scoping. Use to recover from a suspected stale `leaves-manifest.yml` or to force a fresh look at unchanged leaves after editing `common/review-criteria.md`. Without this flag, scoping is automatic: full on the first round of each delivery (no prior manifest) and incremental thereafter. |
| `--auto` | Review / Revise | Non-interactive review-revise loop. Iterate until terminal verdict (`converged`, `oscillating`, `diverging`, `stalled`) or `max_iterations` is reached, **without HITL prompts**. On `converged`, the orchestrator runs the full delivery sequence (`review/index.md` Step 9), which includes auto-compaction of the just-converged delivery's intermediate rounds via `scripts/compact-delivery.sh` so the bundle is hand-off-ready for the next pipeline stage. On non-converged terminal verdicts the orchestrator prints the verdict + summary path and exits non-zero (1 = non-converged, 2 = script error). Suitable for `claude -p ... --auto` batch use. Implies `hitl.auto_approve = [plan_approval, force_continue, regression_justification, stalled_release]` for the duration of the run; user-facing prompts are replaced by an `auto_decision` block in `state.yml` (containing `verdict`, `round`, `reason`, and verdict-specific IDs — see `review/index.md` Step 8 for the schema) so the run can be inspected post-hoc. The orchestrator does NOT write any sidecar file under `.review/round-<N>/` — that would violate the pure-dispatch write-set; `state.yml` is the only auto-mode artifact. |

## Next Steps Hint

After committing, print the following guidance to the user:

```
System design complete: {output path}

Next steps:
  /cofounder:autoforge {output path}
```

## Configuration & Subagent Files

- **Config**: `common/config.yml` (all thresholds, model tiers, tool permissions)
- **Review criteria**: `common/review-criteria.md` (CR catalog: formal script-type CR-SD01..CR-SD19 + frontmatter CR-SDFM01..03 + LLM-type CR-SD-DESIGN01..11 + audit-artifact schema CRs + meta CRs)
- **Issue schema**: `common/issue-schema.md` (issue-file frontmatter contract, state-machine transitions, history append-only invariants — read at runtime by `create-issues.sh`, `check-issue.sh`, and the reviser subagent)
- **Domain glossary**: `common/domain-glossary.md` (system-design domain terms: module, API surface, Boundary Enforcement, Feature-Module mapping, etc.)
- **Templates**:
  - `common/templates/design-readme-template.md`
  - `common/templates/module-template.md`
  - `common/templates/api-template.md` (used only when project has APIs)
  - `common/templates/revision-entry-template.md` (used by --revise summarizer)
- **Sub-agent prompts**:
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md`
  - `review/adversarial-reviewer-subagent.md`
  - `revise/per-issue-reviser-subagent.md`
  - `shared/summarizer-subagent.md`
  - `shared/judge-subagent.md`
- **Mode routing files**:
  - `generate/from-scratch.md`
  - `generate/new-version.md`
  - `review/index.md`
  - `revise/index.md`
- **Per-artifact formal-review scripts** (per-artifact harness; auto-discovered by `scripts/run-checkers.sh`; the authoritative CR-ID list for each script is the `# CR-ID …` block at the top of the script itself):
  - `scripts/check-readme.sh` — README-class checks (CR-SD01, CR-SD02, CR-SD03, CR-SDFM01)
  - `scripts/check-module.sh` — Module-class checks (CR-SD03, CR-SD04, CR-SD06, CR-SD07, CR-SD08, CR-SD09, CR-SDFM02)
  - `scripts/check-api.sh` — API-class checks (CR-SD03, CR-SD10, CR-SD11, CR-SD12, CR-SD13, CR-SDFM03)
  - `scripts/check-feature-module-mapping.sh` — Feature ↔ Module bidirectional mapping (CR-SD05)
  - `scripts/check-architecture-coverage.sh` — every PRD `architecture/*.md` topic referenced (CR-SD14)
  - `scripts/check-analytics-coverage.sh` — every PRD analytics event covered by a module (CR-SD15)
  - `scripts/check-readme-references.sh` — every relative path in README resolves (CR-SD18)
  - `scripts/check-dependency-layering.sh` — module dependency DAG forward-only (CR-SD16)
  - `scripts/check-issue.sh` — issue-file frontmatter + state-machine schema (CR-IS01)
  - `scripts/check-compacted-history.sh` — `compacted-history.md` schema (CR-CH01, CR-CH02)
  - `scripts/check-self-review.sh` — writer self-review files (CR-SR01, CR-SR02, CR-SR03)
  - `scripts/check-plan.sh` — planner plan.md (CR-PL01, CR-PL02)
  - `scripts/check-clarification.sh` — Round-0 clarification yml (CR-CL01, CR-CL02)
  - `scripts/check-version.sh` — `.review/versions/<N>.md` summarizer snapshots (CR-VS01, CR-VS02)
  - `scripts/check-round-index.sh` — `.review/round-<N>/index.md` schema (CR-RI01, CR-RI02)
  - `scripts/check-placeholder-json.sh` — placeholder-JSON lint (CR-SD17)
  - `scripts/check-single-source-of-truth.sh` — duplicated data-model definitions (CR-SD19)
  - `scripts/check-revisions.sh` — `REVISIONS.md` version-chain integrity (CR-RV01, CR-SD03)
- **Phase-gate scripts**:
  - `scripts/verify-phase-entry.sh` — single entry point dispatched per `<phase>` argument (`read | revise | generate-fresh | generate-evolve | compact`); composes the underlying gates below
  - `scripts/check-review-readiness.sh` — read-phase entry: zero `state: new` issues from prior rounds
  - `scripts/check-revise-completeness.sh` — write-phase exit (revise): zero `state: new` issues in current round
  - `scripts/run-checkers.sh` — bundle-level formal-review gate (composes every per-artifact `check-*.sh`)
- **Pipeline-stage scripts** (per audit-design guide §6):
  - `scripts/prepare-input.sh` — input-classification (CR-CL) → planner-input (CR-PL)
  - `scripts/create-issues.sh` — reviewer-output (CR-RO) → issue files (CR-IS01); idempotent
  - `scripts/check-reviewer-output.sh` — reviewer-output schema gate (CR-RO)
  - `scripts/check-verdict.sh` — round verdict (CR-VD) using fixed convergence rule
  - `scripts/update-summary.sh` — round / delivery summarizer Phase 1/2 (CR-VS)
  - `scripts/commit-delivery.sh` — finalize a converged delivery (manifest snapshot + summary)
  - `scripts/snapshot-leaves.sh` — build / refresh the leaves manifest used for incremental scoping
  - `scripts/compute-review-scope.sh` — emit the per-round review scope from the leaves manifest
  - `scripts/prune-traces.sh` — drop trace artifacts retired by `--compact`
- **Helpers / bootstrap scripts**:
  - `scripts/glossary-probe.sh` — Round-0 glossary probe (guide §6.2)
  - `scripts/synthesize-clarification.sh` — emit a minimal deferred-only clarification.yml
  - `scripts/git-precheck.sh` — bootstrap git-state precheck (guide §21.0 + §8.3)
- **Diagnostic scripts**:
  - `scripts/metrics-aggregate.sh` — aggregate harness JSONL + dispatch-log into `.review/metrics/<scope>.metrics.yml`
- **Compact scripts** (`--compact` mode):
  - `scripts/compact-delivery.sh` — aggregates intermediate review rounds of the current delivery into `compacted-history.md` and deletes their `round-N/` + `traces/round-N/` trees
