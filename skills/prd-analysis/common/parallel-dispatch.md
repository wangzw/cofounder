# Parallel Dispatch Protocol

Shared dispatch rules for fan-out generation of feature/journey/architecture leaves (generation Step 3),
review subagents (review-mode Step 2), the clustering subagent (revise-mode Pre-Answered Mode), and
fix subagents (revise-mode Step 5). These rules take precedence over any per-mode wording that conflicts.

---

## Rule 1 — Single-Response Parallel Emission (MANDATORY)

When dispatching N subagents for independent work, emit all N `Agent` tool_use blocks in a
**single assistant response**.

Sequential dispatch (one Agent call per response, waiting for return before next dispatch) is
**FORBIDDEN** for independent work.

**Why:** each sequential dispatch replays the full context cache_read (~280k tokens per turn on
typical PRDs). N sequential dispatches cost N × cache_read; one parallel dispatch costs
1 × cache_read. Observed: a 32-subagent serial dispatch cost $41.6 that would have been ~$1.30
if parallelized.

**"Independent" means:** no subagent's output is an input to another's. Fix subagents across
different file clusters are always independent. Review subagents across disjoint file sets are
always independent. Writer subagents across different leaf files are always independent.

---

## Rule 2 — Subagent Parameters (MANDATORY)

- `subagent_type: "general-purpose"` — never `Explore` (lightweight tier, miscalibrated for PRD
  judgment work)
- `model: "sonnet"` — never pin a specific version like `claude-sonnet-4-6`. Use the tier alias
  so the policy survives model rotations.
- **Escalation to `model: "opus"`** is permitted ONLY when BOTH hold:
  (a) the PRD has been through ≥3 `--review → --revise` cycles, AND
  (b) the same dimension keeps surfacing findings across those cycles.
  Escalate for the specific file+dimension combination, not the whole batch. Any other escalation
  requires explicit justification in the dispatch prompt.

---

## Rule 3 — Cluster Sizing (MANDATORY)

- **Writer subagents (generation fan-out):** one subagent per leaf file. Batch all leaves of the
  same artifact class (journeys, features, architecture) in a single parallel emission. If the
  total leaf count exceeds 20, split into two emissions of ≤20; emit the second only after all
  ACKs from the first are collected (to stay within Agent-tool concurrency limits).
- **Fix subagents:** ≤3 target files per cluster.
- **Review subagents:** 10–15 files per cluster, grouped by artifact class (`features/`,
  `journeys/`, `architecture/`). If a class has ≤15 files total, put all in one cluster (no
  artificial split). Split only when a class has >15 files, into disjoint ranges.
- A file with **>8 findings** gets its own 1-file cluster — large edit counts replay more
  cache_read per turn.
- No file appears in two clusters.

---

## Rule 4 — Trace-ID Schema (MANDATORY)

Every writer subagent dispatch carries a unique `trace_id` injected as the first line of its
prompt. Format:

```
trace_id: R<round>-W-<NNN>
```

- `<round>`: integer (1, 2, 3, …). Round 1 is the initial generation; subsequent rounds are
  review/revise cycles.
- `<NNN>`: three-digit zero-padded sequential counter within the round, assigned by the
  orchestrator before dispatch. Counters reset to 001 each new round.
- Example: `trace_id: R1-W-007` — round 1, seventh writer subagent.

The orchestrator MUST record every dispatched `trace_id` in `dispatch-log.jsonl` before emitting
the parallel Agent blocks (pre-registration prevents orphaned subagent writes).

---

## Rule 5 — Per-Leaf Isolation Contract (MANDATORY)

Each writer subagent owns exactly one leaf file. It MUST NOT:

- Read or write any leaf outside its assigned `<target-path>`.
- Use Grep/Glob to discover sibling files — all context is pre-supplied in the dispatch prompt.
- Perform a post-write re-read of the file it just wrote.
- Emit content in its Task return beyond the single-line ACK.

The dispatch prompt MUST supply the writer with all context it needs inline (journey context,
data-model excerpts, design-token definitions, applicable conventions) so that no cross-file
reads are needed. This is the mechanical enforcement of the self-contained-file principle.

---

## Rule 6 — Tool Usage Inside Subagents (MANDATORY)

- File with **1 edit** → use `Edit`
- File with **>1 edit** → use `MultiEdit` (one tool call, all edits)
- Sequential `Edit` calls on the same file are **FORBIDDEN** — each Edit triggers a cache_read
  replay of full conversation state.
- No post-edit "verification re-read" of a file you just edited.
- No Grep/Glob exploration inside subagents — all target paths are pre-listed in the dispatch
  prompt.
- Writer subagents creating a new file use a **single `Write` call** for the artifact and a
  **single `Write` call** for the self-review archive. Two writes total; no more.

---

## Rule 7 — Dispatch Prompt Contract (MANDATORY)

Every dispatch prompt MUST include:

1. `trace_id` as the first line (writer subagents only).
2. Absolute target file paths (no globs, no discovery).
3. Exact dimensions or findings scope (no open-ended "also check X").
4. All inline context the subagent needs (journey text, data-model excerpt, token definitions).
5. Report/ACK format specification (one line per file, no prose summary).
6. Forbidden list (files outside target set, Grep/Glob, post-edit re-read).

---

## Rule 8 — Reduce Step After Writer Fan-Out (MANDATORY)

After all writer ACKs for a batch are collected, the orchestrator runs a reduce step:

1. Parse each ACK for `self_review_status` and `fail_count`.
2. Update `state.yml`: mark each leaf as `written` or `written-partial`.
3. Update the PRD `README.md` index: add/update the summary row for every leaf whose writer
   returned `OK`. Use a **single `Edit`** (or `MultiEdit` if multiple rows change) — not one
   Edit per leaf.
4. If any writer returned `FAIL` (technical failure), log the `trace_id` to `dispatch-log.jsonl`
   with `status: failed` and re-dispatch that writer in the next emission before proceeding.
5. Writers with `self_review_status: PARTIAL` are flagged for the cross-reviewer in the next
   review round — do not re-dispatch them now.

See `review/index.md` Step 2 and `revise/revise-mode.md` Step 5 for the full templates that bake
these rules in.
