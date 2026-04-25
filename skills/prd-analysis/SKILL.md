---
name: prd-analysis
version: 0.1.0
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert sparse product ideas or brainstorming notes into structured self-contained PRDs optimized for AI coding agents, or evolve an existing PRD for a new iteration. Triggers: /cofounder:prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis'."
---

# prd-analysis — AI-Coding-Ready Product Requirements Documents

## Artifact Variant: Document

This skill generates a **multi-file markdown PRD pyramid** from sparse product descriptions, brainstorming notes, or `@`-referenced source files. It follows the Document variant per guide §7.1 — no code execution, no schema validation, no hybrid behaviors.

The output is a directory rooted at `docs/raw/prd/YYYY-MM-DD-{product-slug}/` containing:

- **`README.md`** — pyramid index: product overview, persona summary, journey index table (J-NNN links), feature index table (F-NNN, priority, MVP flag, journey refs), cross-journey patterns, design-token reference, and roadmap. The README is a stable navigational hub; it is NOT load-bearing for any single coding-agent task.
- **`journeys/J-NNN-{slug}.md`** — self-contained journey specs (persona, goal, touchpoint table, mapped features, post-conditions).
- **`features/F-NNN-{slug}.md`** — self-contained feature specs (user story, acceptance criteria, state machine, interaction mode, inline data model, inline journey context, inline conventions, dependencies, MVP boundary note). A coding agent reads exactly one feature file and nothing else.
- **`architecture.md`** — index-only file (~50–80 lines) with a Mermaid dependency diagram and links to topic files under `architecture/`.
- **`architecture/{topic}.md`** leaves — standalone topic files (tech-stack, data-model, design-tokens, navigation, accessibility, i18n, security, observability, deployment, auth-model, privacy, nfr, etc.). Source-of-truth for the PRD author; coding agents do NOT read these directly.

**Self-contained file principle**: every feature file copies all needed context inline — data models, conventions, journey context. Cross-references to other files are FORBIDDEN inside feature leaves. This minimizes context consumption when an AI coding agent consumes a single spec (R-003, R-002, CLAUDE.md §Self-Contained File Principle).

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:prd-analysis "<description>"` | `generate/from-scratch.md`, `common/review-criteria.md` | New PRD pyramid from sparse description; domain-consultant clarifies intent, planner plans, writers fan-out across journey/feature/architecture leaves |
| generate (new version) | `/cofounder:prd-analysis --target <prd-path> "<change>"` | `generate/new-version.md`, `common/review-criteria.md` | Evolve existing PRD; planner emits delta plan (delete/modify/add/keep); forced full cross-review on first round; tombstones for deprecated features |
| review | `/cofounder:prd-analysis --review --target <prd-path>` | `review/index.md`, `common/review-criteria.md` | Script-type checks + LLM cross/adversarial review; produces issue files under `.review/round-<N>/issues/` |
| revise | `/cofounder:prd-analysis --revise --target <prd-path>` | `revise/index.md`, `common/review-criteria.md` | Per-issue revise loop driven by open issues from last review round; each reviser dispatch targets one issue + one leaf |
| `--diagnose` | `[--round N \| --delivery N \| --since <iso>]` | Only `scripts/metrics-aggregate.sh` (pure script; no sub-agent prompt loaded, no artifact leaves read) | Aggregate harness JSONL + dispatch-log; output `.review/metrics/<scope>.metrics.yml` |

## Bootstrap Precheck

Every mode MUST call `scripts/git-precheck.sh` as the first action. On failure (non-zero exit): skill exits; does NOT enter any generate/review/revise mode.

- Verifies `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`
- If cwd is not a git repo, auto-runs `git init` + empty bootstrap commit
- During Bootstrap Precheck, orchestrator MUST write the following line to `<target>/.review/state.yml` so downstream sub-agents can locate this skill's own scripts:
  ```
  skill-root: <absolute path to this prd-analysis skill root directory>
  ```

## Core Contract

- Orchestrator is **pure dispatch + bookkeeping only**. Forbidden: reading artifact leaves, summarizing content, computing convergence verdicts, rewriting artifacts, analyzing issue priority.
- Hard dependencies: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`. NEVER add `pyyaml` / `jq` / `slugify` / any third-party package.
- Target PRD pyramid in-place mutated. History through git tags (`delivery-<N>-<slug>` annotated tags) + `.review/versions/<N>.md` + target `CHANGELOG.md`.
- `.review/` lives at target PRD root. Pyramid-indexed: `round-<N>/` + `metrics/` + `versions/`.
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
| `prompt_hash` | string | `sha256:...` of full prompt text; required if skill supports resume |
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
| `ack_status` | `"OK"` \| `"FAIL"` | See IPC ACK semantics (writer-subagent.md §IPC Contract) |
| `linked_issues` | array of strings | Backfilled from ACK; may be empty |
| `returned_at` | ISO-8601 | Time-window end for fallback JOIN + latency calculation |
| `self_review_status` | `"FULL_PASS"` \| `"PARTIAL"` | **Writer only** (required); omit for all other roles |
| `fail_count` | integer | **Writer only** (required); number of FAIL rows in self-review archive; `0` when `FULL_PASS`; omit for all other roles |

### FORBIDDEN

The orchestrator MUST NOT:

- **Read artifact leaves** — no reading of PRD leaf content (`features/`, `journeys/`, `architecture/`); those paths belong to sub-agents
- **Summarize or compute verdicts** from PRD artifact content
- **Rewrite or generate PRD artifacts** (production content belongs to sub-agents only)
- **Write to `.review/` business archive files** (self-reviews, issues, plan, verdict) — those are sub-agent write targets

The orchestrator's ONLY write targets are `state.yml` and `dispatch-log.jsonl` (pure-dispatch principle).

### Permitted Actions

1. Dispatch one sub-agent via Task tool
2. Fan-out multiple sub-agents in parallel (e.g., writer fan-out across feature leaves)
3. Decide next step from ACK / judge verdict / failure classification
4. Internal bookkeeping: Edit/Write to `.review/state.yml` + `.review/traces/round-*/dispatch-log.jsonl`; call `scripts/` deterministic scripts

### Forbidden Actions

- Reading PRD artifact leaves
- Summarizing PRD content
- Computing convergence verdicts
- Rewriting PRD artifacts
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

### Why `--diagnose` does not dispatch sub-agents

- LLMs cannot self-report token usage (API usage fields are invisible to sub-agents)
- Aggregating JSONL + arithmetic is 100% deterministic; LLMs drift
- Sub-agent dispatch quota is finite and must not be consumed by mechanical work

## Model Tiers

Abstract: `heavy` / `balanced` / `light`. Mapping in `common/config.yml` (`model_tier_defaults` + `model_mapping`).

### Per-dispatch model override (MANDATORY for cost control)

When the orchestrator dispatches a sub-agent via the Claude Code Agent tool, it **MUST**
pass the `model` parameter to override the default (parent-session inheritance). Without
this override, all sub-agents run on the parent session's model — typically `opus` —
which costs 5–25× the configured tier rate. Per the `tool_permissions` + `model_tier_defaults`
sections of `common/config.yml`:

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
| `--full` | `--review` | Force full review — bypass skip-set, treat every PRD leaf as `cross_reviewer_focus`. Orchestrator passes `--full` to `scripts/run-checkers.sh`; `skip-set.yml` records `forced_full: true`. |
| `--interactive` | Generate | Force-dispatch `domain-consultant` regardless of sparse-input triggers; used when user wants explicit clarification dialogue even on dense input or `@`-referenced brainstorm files. |
| `--no-consultant` | Generate | Skip the `domain-consultant` dispatch entirely even if `sparse_input: true` or `glossary_hit: true` would normally trigger it. Orchestrator synthesizes a minimal `clarification/<ts>.yml` with R-001..R-007 = `deferred`, using the user prompt + expanded `@`-refs as the sole signal. Cost floor drops by ~$4 at opus rates (consultant is the single heaviest Round-0 cost); use when the prompt already names slug/variant explicitly or `@`-references a baseline PRD with a SKILL.md present. |
| `--force-continue` | Generate | Override `oscillating`/`diverging` judge verdict and run one more PRD revision round. Requires HITL `force_continue` approval gate; records the override in `.review/hitl/<ts>-force-continue.yml`. |
| `--tier <role>=<tier>` | Generate / Review / Revise | Override model tier for one dispatch role (e.g., `--tier writer=heavy`). Abstract tiers `heavy/balanced/light` map via `config.yml.model_tier_defaults`. |
| `--max-iterations N` | Generate / Review / Revise | Override `config.yml.convergence.max_iterations` (stalled verdict threshold; default 5). Useful for cheap iteration budgets during testing or when PRD scope is narrow. |

## Configuration & Subagent Files

- **Config**: `common/config.yml` (all thresholds, model tiers, tool permissions)
- **Review criteria**: `common/review-criteria.md` (structural CR-S01..CR-S15 + semantic CR-L01..CR-L16)
- **Domain glossary**: `common/domain-glossary.md` (touchpoint, persona, user journey, feature, MVP boundary, design token, interaction mode, cross-journey pattern, feature-module mapping, tombstone, self-contained file)
- **Sub-agent prompts**:
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md`
  - `review/adversarial-reviewer-subagent.md`
  - `revise/per-issue-reviser-subagent.md`
  - `shared/summarizer-subagent.md`
  - `shared/judge-subagent.md`
