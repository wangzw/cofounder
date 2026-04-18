# `prd-analysis` Cost & Performance Optimization — Design Spec

**Date:** 2026-04-18
**Status:** Approved (pending spec review)
**Author:** Zhanwei Wang

## Overview

Session `e4db92e7-9bd4-4439-94c1-3ef5c24216f1` (castworks PRD, `--review` → `--revise` 6th pass) cost **$199.50** over 2h24m of Opus 4.7 main-agent time. Root-cause analysis identified three dominant waste categories totaling 50–65% of session cost:

| Waste category | Cost | Cause |
|---|---|---|
| Serial subagent dispatch (32 Fix subagents, one per response) | ~$41.6 | Skill wording permissive ("parallel where possible"), not mandatory |
| Main-agent commentary / no-tool responses (87 turns) | ~$71.6 | No rule suppressing inter-dispatch acks and Write echo |
| 1h cache writes (2.46M tokens) | ~$73.8 | SKILL.md / mode files re-loaded on mode switches; no shared stable prefix |

This spec optimizes the `prd-analysis` skill to recover **$70–$120 (35–60%)** per comparable session via in-skill rule changes only — no harness changes, no breaking contract changes. Per-rule breakdown is in the Expected Cost Impact section.

## Goals

- Convert permissive dispatch language ("preferred", "where possible") to mandatory rules (`MUST`, `FORBIDDEN`).
- Introduce a shared, stable rule block loaded by both `--review` and `--revise` so 1h cache can amortize across mode transitions.
- Eliminate the two highest-frequency runtime waste patterns: sequential subagent dispatch and tool-less acknowledgment responses.
- Nudge the user toward context compaction between `--review` and `--revise`.

## Non-Goals

- No change to user-facing CLI surface (`--review`, `--revise`, `--evolve` flags remain identical).
- No change to PRD output file structure or REVISIONS.md format.
- No migration required for existing PRDs.
- No change to subagent prompt contracts visible to downstream consumers (system-design, autoforge).

## Pipeline Position

Unchanged. `prd-analysis` continues to sit at the start of the DevForge pipeline:

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

The change is internal to the skill.

## File Structure Changes

### New Files

```
skills/prd-analysis/
├── parallel-dispatch.md    (~80 lines)  Mandatory subagent dispatch rules
└── output-discipline.md    (~40 lines)  Main-agent output discipline
```

### Modified Files

| File | Change |
|---|---|
| `SKILL.md` | Mode-routing table adds `parallel-dispatch.md` (--review, --revise) and `output-discipline.md` (all modes). One-line addition to Key Principles. |
| `review-mode.md` | Step 2 trimmed: dispatch rules become reference to `parallel-dispatch.md`; review-specific overrides kept inline. Subagent prompt template gains one Output-Discipline line. Step 6 appends a **Compaction Hint Block**. |
| `revise-mode.md` | Step 5 Fix-Subagent Dispatch Rules trimmed into reference. Pre-Answered Mode gains an explicit **Dispatch Execution** block mandating single-response parallel emission after Clustering manifest consumption. Step 5 appends a **Handling Subagent Returns** block referencing `output-discipline.md` Rules 2 and 3. |

### Deleted Files

None. Fully backward compatible.

## `parallel-dispatch.md` — Content Specification

Scope: rules that apply to review subagents (review-mode Step 2), the clustering subagent (revise-mode Pre-Answered Mode), and fix subagents (revise-mode Step 5).

**Rules (all MANDATORY unless noted):**

1. **Single-Response Parallel Emission** — when N subagents handle independent work, emit all N `Agent` tool_use blocks in **one** assistant response. Sequential dispatch is FORBIDDEN for independent work. Independence rule: no subagent's output is an input to another's. Citation: observed 32-subagent serial dispatch wasted $41.6.
2. **Subagent Parameters** — `subagent_type: "general-purpose"` (never `Explore`), `model: "sonnet"` (never pin a version like `claude-sonnet-4-6`). Escalation to `model: "opus"` is permitted ONLY when BOTH of the following hold: (a) the PRD has been through ≥3 `--review → --revise` cycles, AND (b) the same dimension keeps surfacing findings across those cycles. In that case, escalate for the specific file+dimension combination, not the whole batch. Any other escalation requires explicit justification in the dispatch prompt.
3. **Cluster Sizing** — Fix subagents: ≤3 target files. Review subagents: 10–15 files grouped by artifact class. Files with >8 findings get their own 1-file cluster. No file appears in two clusters.
4. **Tool Usage Inside Subagents** — 1 edit → `Edit`; >1 edit → `MultiEdit` (single call). Sequential `Edit` on the same file FORBIDDEN. No post-edit verification re-read. No Grep/Glob exploration — target paths are pre-listed.
5. **Dispatch Prompt Contract** — every dispatch prompt includes: absolute target paths, exact scope (no open-ended "also check X"), report format, forbidden list.

Templates (Template A, Template B, Clustering Subagent template) remain inline in `revise-mode.md` — moving them would hurt readability.

## `output-discipline.md` — Content Specification

Scope: the main agent in ALL prd-analysis modes.

**Rules:**

1. **No Echo-Then-Write (MANDATORY)** — write large artifacts (REVIEW files, feature files, journey files, architecture topic files) directly via `Write`. Do NOT include the full body in assistant text before the tool call. Permitted: one-line summary. Citation: observed 35k-token REVIEW report generated twice, cost $5.98.
2. **No Inter-Dispatch Commentary (MANDATORY)** — after a `<task-notification>` subagent return, do NOT emit a tool-less assistant response containing only acknowledgment. Proceed directly to the next tool call (TaskUpdate, next dispatch, Write) in the same response that processes the return. Citation: 87 tool-less responses in one session, $71.6.
3. **Task Board Parsimony** — TaskUpdate fires ONLY at cluster milestones (all dispatched / all returned / all complete). Targets: ≤3 TaskUpdate calls per `--review` pass, ≤5 per `--revise` pass.
4. **Bash Consolidation** — when multiple independent read-only Bash commands are needed (git status, git diff, ls), combine in one response via parallel tool_use blocks or chain with `&&`. Never split a git inspection batch across multiple responses.

## `review-mode.md` Changes

### Change 1 — Step 2 Trim

Replace the "Subagent type and model" / "Dispatch rules" subsections with:

> **Read `parallel-dispatch.md` first** — it defines the mandatory dispatch rules (single-response parallel emission, subagent_type, model tier, cluster sizing, tool usage). Review-mode-specific overrides:
>
> - Group files by artifact class: `features/`, `journeys/`, `architecture/`. Do not mix classes within a cluster.
> - Each cluster contains 10–15 files (not the ≤3 used by Fix subagents).
> - Every subagent runs only the **per-file** dimensions from `review-checklist.md` — cross-file dims run in Step 3 on the main agent.

Subagent prompt template (unchanged in its body) gets one Rules-list addition:

> - Output discipline: follow `output-discipline.md` Rule 1 (no echo of full findings list before writing). Emit per-file findings directly as structured text — no prose preamble.

### Change 2 — Step 6 Compaction Hint Block

Append to Step 6 "Recommend Next Step":

```
### Compaction Hint

After presenting findings and before the user proceeds to --revise,
emit this message verbatim:

> 💡 Context compaction recommended
>
> The review phase has loaded your journey/architecture/feature files
> into context (~280k tokens). If you plan to run --revise next,
> running /compact now will let the revise phase start with a cleaner
> context — saves roughly $20–$30 in cache_read costs on a PRD this
> size.
>
> Run /compact to proceed, or skip this if you are not revising this
> session.

Skip this message if no REVIEW-*.md was written (convergence gate
aborted in Step 0.5) or if Critical + Important finding count is
below 5 (revise is unlikely to be worth running at that point).
```

## `revise-mode.md` Changes

### Change 1 — Pre-Answered Mode Dispatch Execution Block

After "The main agent consumes the returned YAML as the cluster plan", insert:

```
**Dispatch execution (MANDATORY — see `parallel-dispatch.md` Rule 1):**

Once the manifest is consumed, emit ALL Fix subagent dispatches in a
**single assistant response** containing N `Agent` tool_use blocks
(one per cluster). Sequential dispatch is FORBIDDEN — it replays
~280k cache_read per cluster, costing roughly $1.30 per cluster on a
typical PRD. A 10-cluster revision dispatched in parallel costs
~$1.30; dispatched serially costs ~$13.

Do NOT emit any intermediate assistant response between consuming the
manifest and the dispatch. No "Now I will dispatch the fix subagents"
preamble — proceed directly to the multi-tool-use response.
```

### Change 2 — Step 5 Fix-Subagent Dispatch Rules Trim

Replace the "Model tier / Tool usage" paragraphs with:

> **Read `parallel-dispatch.md` first** — it defines the mandatory dispatch rules (single-response parallel emission, model tier, cluster sizing ≤3 files, MultiEdit for >1 edit, forbidden re-reads).
>
> **Revise-mode-specific rules:**
>
> - If a `.reviews/REVIEW-*.md` was consumed (Pre-Answered Mode), use **Template A** (reference-based, below).
> - Otherwise (interactive revise, Step 3 gathered change list), use **Template B** (inline edits list, below).

Template A and Template B bodies are unchanged.

### Change 3 — Step 5 Handling Subagent Returns

Append after Template B:

```
### Handling Subagent Returns

Follow `output-discipline.md` Rule 2 (no inter-dispatch commentary)
and Rule 3 (TaskUpdate parsimony):

- When Fix subagent returns arrive, the main agent's NEXT action is
  the next tool call (cross-reference sweep, REVISIONS.md append, or
  user-facing summary) — NOT a standalone ack response.
- TaskUpdate fires once when all clusters dispatched, once when all
  returned. Do not update per-cluster.
- When writing REVISIONS.md, use `Write` directly with the full entry
  body — do NOT echo the body in assistant text first (Rule 1).
```

## `SKILL.md` Changes

### Mode Routing Table

| Mode | Read These Files |
|------|-----------------|
| Initial analysis (no flags) | `questioning-phases.md`, **`output-discipline.md`** (scope-reference.md on demand; review-checklist.md at Step 6) |
| Initial analysis + document input | `questioning-phases.md`, `document-mode.md`, **`output-discipline.md`** (same on-demand rules) |
| `--review` | `review-mode.md`, `review-checklist.md`, **`parallel-dispatch.md`**, **`output-discipline.md`** |
| `--revise` | `revise-mode.md`, **`parallel-dispatch.md`**, **`output-discipline.md`** (scope-reference.md and review-checklist.md on demand per revise-mode.md instructions) |
| `--evolve` | `evolve-mode.md`, `questioning-phases.md`, **`output-discipline.md`** (same on-demand rules) |

`parallel-dispatch.md` is loaded only by modes that actually dispatch parallel subagents (`--review`, `--revise`). `output-discipline.md` is loaded by all modes — it is 40 lines and its rules apply universally.

### Key Principles addition

Append one bullet:

> - **Discipline files are non-optional** — `parallel-dispatch.md` (for --review / --revise) and `output-discipline.md` (all modes) are loaded at mode entry and their rules take precedence over any per-mode wording that conflicts.

## Expected Cost Impact

Projected savings on a session comparable to `e4db92e7` ($199.50 baseline):

| Rule | Mechanism | Projected recovery |
|---|---|---|
| parallel-dispatch Rule 1 (32 Fix + 8 Review parallelized) | cache_read replay drops from N× to 1× | $30–40 |
| output-discipline Rule 2 (no inter-dispatch commentary) | Eliminates ~70 of the 87 tool-less responses | $15–25 |
| output-discipline Rule 1 (no Write echo) | REVIEW report generated once, not twice | $3–6 |
| output-discipline Rule 3 (TaskUpdate parsimony) | Cuts 29 TaskUpdate responses to ~8 | $5–10 |
| Compaction Hint (user opts in) | revise-phase cache_read drops 283k → ~80k | $15–25 (when user compacts) |
| Shared 1h cache prefix (parallel-dispatch + output-discipline) | Avoids 1h rewrite on mode switch | $5–15 |
| **Total (projected range)** | | **$70–120 (35–60%)** |

Mid-range target: **$90 saved per comparable session**.

## Backward Compatibility

- User CLI flags unchanged.
- Output file formats unchanged (PRD structure, REVISIONS.md format).
- Subagent prompts for existing PRDs run unchanged — wording tightens but contracts hold.
- Existing castworks PRD (`docs/raw/prd/2026-04-11-castworks/`) can be used for regression testing without modification.

## Testing Strategy

Regression-style validation via the existing castworks PRD:

1. **`--review` regression** — run against `docs/raw/prd/2026-04-11-castworks/` (already passed 6 revision cycles). Expected: convergence gate aborts in Step 0.5 (zero Critical remaining) OR produces a near-empty REVIEW file.
2. **Parallel dispatch verification** — if any review subagents do dispatch, verify from the new session's jsonl that multiple `Agent` tool_use blocks appear in a single assistant `message.content` array (not across multiple responses).
3. **Echo suppression verification** — grep the new session's assistant text for any span of ≥5k output tokens immediately preceding a `Write` tool_use. Expected: zero matches.
4. **Cost comparison** — parse the new session's `message.usage` totals; compare to $199.50 baseline on a comparable `--review + --revise` cycle (acknowledging castworks is already converged, so a fresh PRD will be the better benchmark).

No automated test harness exists for skills. Manual verification on one real invocation is the acceptance bar.

## Open Questions

None blocking. Two future considerations documented for follow-up but not in scope:

1. **Automated `/compact` call** — currently Compaction Hint requires user action. A future harness-level feature could allow skills to programmatically request compaction.
2. **Cross-skill `output-discipline.md`** — rules 1–4 arguably apply to `system-design`, `autoforge`, `go-to-market` as well. Promoting the file to a shared location is out of scope for this iteration but should be revisited once the rules prove out in `prd-analysis`.

## Implementation Plan Reference

Implementation plan will be generated via the `writing-plans` skill after this spec is user-approved. The plan will break the work into file-level tasks with verification commands.
