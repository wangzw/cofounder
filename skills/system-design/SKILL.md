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
/cofounder:system-design --review docs/raw/design/xxx/      # read-only review
/cofounder:system-design --revise docs/raw/design/xxx/      # change management
```

**Note on evolved PRDs:** When a PRD has been evolved (`/cofounder:prd-analysis --evolve`), pass the new incremental PRD path to generate a fresh design, or use `--revise` on the existing design to propagate specific PRD changes. There is no dedicated `--evolve` mode for system-design — `--revise` handles both in-place PRD changes and evolved PRD deltas.

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:system-design "<description or prd-path>"` | `generate/from-scratch.md`, `common/review-criteria.md` | New design from PRD/draft/interactive; domain-consultant clarifies intent, planner decomposes modules, writers fan-out (one per module + API + README); structural-lint runs BEFORE semantic review |
| generate (new version) | `/cofounder:system-design --target <design-dir> "<change>"` | `generate/new-version.md`, `common/review-criteria.md` | Evolve existing design; planner emits delta plan (delete/modify/add/keep); forced full cross-review on first round |
| review | `/cofounder:system-design --review <design-dir>` | `review/index.md`, `common/review-criteria.md` | Read-only: scripts/run-checkers.sh (structural-lint) runs first; then cross-reviewer + adversarial-reviewer dispatch in parallel; produces LINT-*.md + REVIEW-*.md under `.review/round-<N>/issues/` |
| revise | `/cofounder:system-design --revise <design-dir>` | `revise/index.md`, `common/review-criteria.md` | Per-issue revise loop driven by open REVIEW-*.md + LINT-*.md from last review round; re-runs structural-lint gate after batch |
| `--diagnose` | `[--round N \| --delivery N \| --since <iso>]` | Only `scripts/metrics-aggregate.sh` (pure script; no sub-agent prompt loaded, no artifact leaves read) | Aggregate harness JSONL + dispatch-log; output `.review/metrics/<scope>.metrics.yml` |

Do NOT load files not listed for the current mode — unused files waste context.

## Output Structure

```
docs/raw/design/YYYY-MM-DD-{product-name}/
├── README.md              # Design overview + module index + Feature-Module mapping matrix
├── REVISIONS.md           # Appended by --revise (created on first revision)
├── modules/
│   └── M-NNN-{slug}.md    # Self-contained per-module spec (one writer per module in fan-out)
├── api/                   # Only generated when project has APIs
│   └── API-NNN-{slug}.md  # Self-contained API contract
└── .reviews/              # Transient — not version-controlled
    ├── REVIEW-*.md / .applied.md   # Semantic findings (LLM reviewers)
    └── LINT-*.md / .applied.md     # Mechanical findings (structural-lint scripts)
```

**Agent consumption:** read `README.md` (overview + Feature-Module mapping matrix) → read one `modules/M-NNN-{slug}.md` → implement. The module file alone is sufficient for a coding agent to start working.

**gitignore:** add `docs/raw/design/*/.reviews/` to `.gitignore` (transient review artefacts are not version-controlled).

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
{"event": "launched", "trace_id": "R3-W-007", "role": "writer", "reviewer_variant": null, "tier": "balanced", "model": "claude-sonnet-4-5", "delivery_id": 3, "dispatched_at": "2026-04-20T10:15:30Z", "prompt_hash": "sha256:...", "linked_issues": ["R3-012"], "session_file": "/Users/me/.claude/projects/my-project/abc-def.jsonl"}
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
{"event": "completed", "trace_id": "R3-W-007", "role": "writer", "ack_status": "OK", "linked_issues": ["R3-012"], "self_review_status": "PARTIAL", "fail_count": 1, "returned_at": "2026-04-20T10:16:10Z"}
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
   | 3 | JOIN coverage < 50% | Report output path; **relay verbatim** every entry under `warnings:` in the output YAML (copy exact text, no rewriting, no interpreting, no summarizing); suggest user verify orchestrator is injecting `trace_id:` markers |

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
| `--full` | `--review` | Force full review — bypass skip-set, treat every leaf as `cross_reviewer_focus`. Orchestrator passes `--full` to `scripts/run-checkers.sh`; `skip-set.yml` records `forced_full: true`. |
| `--interactive` | Generate | Force-dispatch `domain-consultant` even on dense input. |
| `--no-consultant` | Generate | Skip `domain-consultant` even if triggers fire; orchestrator synthesizes a minimal `clarification.yml` (R-001..R-006 = `deferred`) from the user prompt + `input.md` expanded refs. Saves the consultant's heavy-tier dispatch (~$4 at opus rates). |
| `--force-continue` | Generate | Override `oscillating`/`diverging` judge verdict and run one more round; requires HITL approval gate. |
| `--tier <role>=<tier>` | Generate / Review / Revise | Override model tier for one dispatch role (e.g. `--tier writer=heavy`). Abstract tiers `heavy/balanced/light` map via `config.yml.model_tier_defaults`. |
| `--max-iterations N` | Generate / Review / Revise | Override `config.yml.convergence.max_iterations` (stalled verdict threshold; default 5). |

## Next Steps Hint

After committing, print the following guidance to the user:

```
System design complete: {output path}

Next steps:
  /cofounder:autoforge {output path}
```

## Configuration & Subagent Files

- **Config**: `common/config.yml` (all thresholds, model tiers, tool permissions)
- **Review criteria**: `common/review-criteria.md` (CR catalog: script-type L1..L5 + X1..X8 structural-lint checks + LLM-type design-review dimensions)
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
- **Structural-lint scripts** (auto-discovered by `scripts/run-checkers.sh` via `check-*.sh` glob):
  - `scripts/check-api-per-endpoint-blocks.sh` — L1: all seven per-endpoint subsections present
  - `scripts/check-placeholder-json.sh` — L2: no placeholder JSON tokens in code blocks
  - `scripts/check-boundary-enforcement-cols.sh` — L3: all four Boundary Enforcement columns filled
  - `scripts/check-api-surface-cols.sh` — L4: all seven API Surface table columns filled per row
  - `scripts/check-module-interface-types.sh` — L5: type names resolve to inline or imported definition
  - `scripts/check-module-deps-vs-protocols.sh` — X1: Module Deps edges match README Interaction Protocols
  - `scripts/check-endpoint-literal-vs-api.sh` — X2: endpoint literals in module API Surface exist in api/
  - `scripts/check-architecture-coverage.sh` — X3: every PRD architecture/ file appears in Implementation Conventions table
  - `scripts/check-analytics-coverage.sh` — X4: every PRD analytics event appears in Analytics Coverage section
  - `scripts/check-feature-module-traceability.sh` — X5: every PRD F-NNN referenced in Feature-Module matrix
  - `scripts/check-dependency-layering.sh` — X6: no reverse-layer imports (blockers, not warnings)
  - `scripts/check-single-source-of-truth.sh` — X7: data-model/endpoint/boundary definitions have exactly one canonical home
  - `scripts/check-readme-references.sh` — X8: all relative paths in README.md resolve to existing files
