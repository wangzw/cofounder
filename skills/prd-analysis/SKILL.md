---
name: prd-analysis
version: 0.1.0
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, or prepare requirements for AI coding agents. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis'."
---

# prd-analysis — AI-coding-ready PRDs from sparse product ideas

## Artifact Variant: Document

This skill generates a **multi-file markdown pyramid** rooted at `docs/raw/prd/YYYY-MM-DD-{product-slug}/`. The root `README.md` is a navigational index (product overview + journey index + feature index + roadmap). Subdirectories hold self-contained leaf files: `journeys/J-NNN-{slug}.md`, `features/F-NNN-{slug}.md`, plus `architecture.md` (~50-80 line index) and `architecture/*.md` topic files (tech-stack, data-model, nfr, security, observability, etc.). Each leaf is <300 lines and reads independently — any referenced context (data models, conventions, journey context) is **copied inline** rather than cross-referenced, so a downstream AI coding agent can read a single feature file and implement it without opening a second file. This is the generative-skill guide §7.1 **document variant**; no variant-specific extensions beyond the baseline pyramid.

## Input Modes

```
/cofounder:prd-analysis                               # interactive FromScratch (conversational questioning)
/cofounder:prd-analysis path/to/notes.md              # document-based FromScratch (parse provided file)
/cofounder:prd-analysis --output docs/raw/prd/foo     # custom output directory
/cofounder:prd-analysis --review --target <prd-dir>   # review an existing PRD
/cofounder:prd-analysis --revise --target <prd-dir>   # per-issue revise loop on an existing PRD
/cofounder:prd-analysis --evolve --target <prd-dir>   # incremental PRD for a new iteration (maps to generate new-version)
/cofounder:prd-analysis --diagnose [--round N | --delivery N | --since <iso>]
```

`--evolve` is the user-facing alias for the canonical `generate (new version)` mode — it creates a new date-stamped PRD directory that references the predecessor baseline and contains only delta leaves.

## Mode Routing

| Mode | Args | Loaded Files | Semantics |
|------|------|-------------|-----------|
| generate (from scratch) | `/cofounder:prd-analysis "<product idea>"` or `/cofounder:prd-analysis <notes.md>` | `generate/from-scratch.md`, `common/review-criteria.md` | New PRD directory from a sparse product idea (interactive questioning) or provided notes file (document-based). Domain-consultant clarifies product scope, planner plans the journey/feature/architecture-topic leaf set, writers fan out to author leaves. |
| generate (new version) | `/cofounder:prd-analysis --evolve --target <prd-dir>` (or `--target <prd-dir> "<change>"`) | `generate/new-version.md`, `common/review-criteria.md` | Evolve an existing PRD into a new date-stamped directory. Planner emits a delta plan (add / modify / tombstone) against `.review/versions/<N-1>.md`; predecessor is read-only input; forced full cross-review on the first round. |
| review | `/cofounder:prd-analysis --review --target <prd-dir>` | `review/index.md`, `common/review-criteria.md` | Script-type checks (pyramid shape, leaf size <300 lines, F-/J-/M-NNN ID format, cross-reference integrity, required template sections, kebab-case slugs, artifact nudity) plus LLM cross-reviewer + adversarial-reviewer passes. One issue file per finding under `.review/round-<N>/issues/`. |
| revise | `/cofounder:prd-analysis --revise --target <prd-dir>` | `revise/index.md`, `common/review-criteria.md` | Per-issue reviser loop driven by open issues from the last review round. Each dispatch rewrites only the minimal span of one leaf while preserving self-contained-inline-copy invariants, ID stability, and neighbor cross-refs. |
| `--diagnose` | `[--round N \| --delivery N \| --since <iso>]` | Only `scripts/metrics-aggregate.sh` (pure script; NO sub-agent prompt loaded) | Aggregate harness JSONL + `dispatch-log.jsonl` into `.review/metrics/<scope>.metrics.yml`. Pure script mode — no LLM post-processing, no artifact reads. |

## Bootstrap Precheck

Every mode MUST call `scripts/git-precheck.sh` as the first action. On failure (non-zero exit) the skill exits immediately; it does NOT enter any generate / review / revise mode.

- Verifies `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`.
- If the current working directory is not a git repo, auto-runs `git init` + an empty bootstrap commit.
- Bootstrap Precheck initializes `<target>/.review/state.yml` with `current_round`, `current_delivery`, `mode`, and `phase`. Script paths are resolved relative to the skill root (parent of `.review/`); downstream sub-agents reference shared scripts as `../scripts/<name>.sh`.

## Core Contract

- Orchestrator is **pure dispatch + bookkeeping only**. FORBIDDEN: reading artifact leaves, summarizing leaf content, computing convergence verdicts, rewriting artifacts, analyzing issue priority.
- Hard dependencies: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8`. NEVER add `pyyaml` / `jq` / `slugify` / any third-party package.
- Target PRD directory is in-place mutated. History through git tags (`delivery-<N>-<slug>` annotated tags) + `.review/versions/<N>.md` + the PRD's `CHANGELOG.md`.
- `.review/` lives at the PRD directory root. Pyramid-indexed: `round-<N>/` (plan, self-reviews, issues, verdict) + `metrics/` + `versions/` + `traces/`.
- Round numbers are **cross-delivery monotonic**. Delivery-1 spans round-1..k; delivery-2 starts at round-k+1.
- Metrics aggregated ONLY by `scripts/metrics-aggregate.sh` via `--diagnose` mode — never by a sub-agent.
- Self-contained file principle: every leaf (journey, feature, architecture topic, README) MUST be readable on its own. Any cross-context needed by a downstream coding agent MUST be copied inline into the leaf, not referenced by path.

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

   > Example: `R3-W-007` = Round 3, writer, 7th call. `R5-V-003` = Round 5, reviewer, 3rd call (cross vs. adversarial distinguished by `reviewer_variant` in the dispatch-log, not the letter). In `R3-R-001` the leading `R` means "Round 3"; the second `R` is the reviser role code — parse by splitting on `-` into three segments, never by letter shape.

2. **Before dispatch — append a `launched` event** to `.review/traces/round-<N>/dispatch-log.jsonl` (one JSONL line, see schema below).

3. **After dispatch — append a `completed` event** to the same file once the ACK is received (see schema below).

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
| `model` | string | Model identifier; used for pricing lookup and fallback JOIN |
| `delivery_id` | integer | `--delivery` scope filter for `metrics-aggregate.sh` |
| `dispatched_at` | ISO-8601 | Time-window start for fallback JOIN + latency calculation |
| `prompt_hash` | string | `sha256:...` of full prompt text; required if skill supports resume |
| `linked_issues` | array of strings | Issue IDs relevant to this dispatch; may be empty array `[]` |
| `session_file` | string \| omit | Absolute path to harness JSONL for this dispatch; omit if unavailable — falls back to rglob scan |

### `completed` event schema

One JSONL line appended after the ACK is received:

```jsonl
{"event": "completed", "trace_id": "R3-W-007", "role": "writer", "ack_status": "OK", "linked_issues": ["R3-012"], "self_review_status": "PARTIAL", "fail_count": 1, "returned_at": "2026-04-20T10:16:10Z"}
```

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `event` | `"completed"` | Literal string |
| `trace_id` | string | Must match the paired `launched` event |
| `role` | string | Same as `launched` |
| `ack_status` | `"OK"` \| `"FAIL"` | ACK semantics per writer-subagent Snippet D |
| `linked_issues` | array of strings | Backfilled from ACK; may be empty |
| `returned_at` | ISO-8601 | Time-window end for fallback JOIN + latency calculation |
| `self_review_status` | `"FULL_PASS"` \| `"PARTIAL"` | **Writer only** (required); omit for all other roles |
| `fail_count` | integer | **Writer only** (required); number of FAIL rows in self-review archive; `0` when `FULL_PASS`; omit for all other roles |

### FORBIDDEN

The orchestrator MUST NOT:

- **Read artifact leaves** — no reading of PRD leaf content; those paths belong to sub-agents.
- **Summarize or compute verdicts** from artifact content.
- **Rewrite or generate artifacts** — all production content belongs to sub-agents.
- **Write to `.review/` business archive files** (self-reviews, issues, plan, verdict, clarification) — those are sub-agent write targets.

The orchestrator's ONLY write targets are `state.yml` and `dispatch-log.jsonl`.

### Permitted Actions

1. Dispatch one sub-agent via the Task tool.
2. Fan-out multiple sub-agents in parallel.
3. Decide next step from ACK / judge verdict / failure classification.
4. Internal bookkeeping: Edit/Write to `.review/state.yml` + `.review/traces/round-*/dispatch-log.jsonl`; call `scripts/` deterministic scripts.

## `--diagnose` Mode

**Pure script mode. MUST NOT** load any sub-agent prompt. **MUST NOT** read artifact leaves, `.review/versions/`, or `review-criteria.md`.

### Execution Steps (FORBIDDEN to deviate)

1. **Validate**: check that `scripts/metrics-aggregate.sh` exists and is executable.
2. **Pass-through args**: forward user-provided `--round N` / `--delivery N` / `--since <iso>` verbatim.
3. **Invoke**:
   ```bash
   scripts/metrics-aggregate.sh --diagnose "$@" \
     --review-dir ./.review \
     --harness-dir "${CLAUDE_HARNESS_DIR:-$HOME/.claude/projects}" \
     --config common/config.yml
   ```
4. **Handle exit codes**: `0` = success; `1` = argument error; `2` = input error; `3` = JOIN coverage < 50%.
5. **No LLM post-processing**: relay script output verbatim.

## Model Tiers

Abstract tiers: `heavy` / `balanced` / `light`. Concrete model mapping is defined in `common/config.yml`.

## Configuration & Subagent Files

- **Config**: `common/config.yml`
- **Review criteria**: `common/review-criteria.md`
- **Domain glossary**: `common/domain-glossary.md`
- **PRD leaf templates**: `common/templates/artifact-template.md` (journey, feature, architecture topic, README index shapes)
- **Sub-agent prompts**:
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md`
  - `review/adversarial-reviewer-subagent.md`
  - `revise/per-issue-reviser-subagent.md`
  - `shared/summarizer-subagent.md`
  - `shared/judge-subagent.md`
