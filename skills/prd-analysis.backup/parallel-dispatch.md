# Parallel Subagent Dispatch Rules

Shared dispatch rules for review subagents (review-mode Step 2), the clustering subagent (revise-mode Pre-Answered Mode), and fix subagents (revise-mode Step 5). These rules take precedence over any per-mode wording that conflicts.

## Rule 1 — Single-Response Parallel Emission (MANDATORY)

When dispatching N subagents for independent work, emit all N `Agent` tool_use blocks in a **single assistant response**.

Sequential dispatch (one Agent call per response, waiting for return before next dispatch) is **FORBIDDEN** for independent work.

**Why:** each sequential dispatch replays the full context cache_read (~280k tokens per turn on typical PRDs). N sequential dispatches cost N × cache_read; one parallel dispatch costs 1 × cache_read. Observed: a 32-subagent serial dispatch cost $41.6 that would have been ~$1.30 if parallelized.

**"Independent" means:** no subagent's output is an input to another's. Fix subagents across different file clusters are always independent. Review subagents across disjoint file sets are always independent.

## Rule 2 — Subagent Parameters (MANDATORY)

- `subagent_type: "general-purpose"` — never `Explore` (lightweight tier, miscalibrated for PRD judgment work)
- `model: "sonnet"` — never pin a specific version like `claude-sonnet-4-6`. Use the tier alias so the policy survives model rotations.
- **Escalation to `model: "opus"`** is permitted ONLY when BOTH hold:
  (a) the PRD has been through ≥3 `--review → --revise` cycles, AND
  (b) the same dimension keeps surfacing findings across those cycles.
  Escalate for the specific file+dimension combination, not the whole batch. Any other escalation requires explicit justification in the dispatch prompt.

## Rule 3 — Cluster Sizing (MANDATORY)

- Fix subagents: **≤3 target files** per cluster.
- Review subagents: **10–15 files** per cluster, grouped by artifact class (`features/`, `journeys/`, `architecture/`). If a class has ≤15 files total, put all in one cluster (no artificial split). Split only when a class has >15 files, into disjoint ranges.
- A file with **>8 findings** gets its own 1-file cluster — large edit counts replay more cache_read per turn.
- No file appears in two clusters.

## Rule 4 — Tool Usage Inside Subagents (MANDATORY)

- File with **1 edit** → use `Edit`
- File with **>1 edit** → use `MultiEdit` (one tool call, all edits)
- Sequential `Edit` calls on the same file are **FORBIDDEN** — each Edit triggers a cache_read replay of full conversation state.
- No post-edit "verification re-read" of a file you just edited.
- No Grep/Glob exploration inside subagents — all target paths are pre-listed in the dispatch prompt.

## Rule 5 — Dispatch Prompt Contract

Every dispatch prompt MUST include:

1. Absolute target file paths (no globs, no discovery).
2. Exact dimensions or findings scope (no open-ended "also check X").
3. Report format specification (one line per file, no prose summary).
4. Forbidden list (files outside target set, Grep/Glob, post-edit re-read).

See `review-mode.md` Step 2 and `revise-mode.md` Step 5 for the full templates that bake these rules in.
