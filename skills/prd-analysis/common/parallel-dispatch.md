# Parallel Dispatch Protocol

Shared dispatch rules for fan-out generation of feature/journey/architecture leaves (generation
Step 3), review subagents (review-mode Step 2), and per-issue reviser subagents (revise-mode
Step 2 fan-out). These rules take precedence over any per-mode wording that conflicts.

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

- File with **1 edit** → use `Edit`.
- File with **>1 edit on the same file** → Read the file once, merge every change in memory,
  and emit a **single `Write`** that overwrites the leaf with the final content. Do NOT issue
  multiple `Edit` calls on the same file in sequence — each Edit triggers a cache_read
  replay of full conversation state.
- No post-edit "verification re-read" of a file you just edited.
- No Grep/Glob exploration inside subagents — all target paths are pre-listed in the dispatch
  prompt.
- Writer subagents creating a new file use a **single `Write` call** for the artifact, plus
  **at most one** `Write` for the self-review archive — and only when the writer is about to
  ACK with `self_review_status: PARTIAL` (i.e. ≥1 FAIL row). FULL_PASS writers omit the
  self-review write entirely and emit only one Write total. See
  `generate/writer-subagent.md` Output Contract Write 2.

---

## Rule 7 — Dispatch Prompt Contract (MANDATORY)

Every dispatch prompt MUST include:

1. `trace_id` as the first line (writer subagents only).
2. Absolute target file paths (no globs, no discovery).
3. Exact dimensions or findings scope (no open-ended "also check X").
4. All inline context the subagent needs (journey text, data-model excerpt, token definitions).
5. Report/ACK format specification (one line per file, no prose summary).
6. Forbidden list (files outside target set, Grep/Glob, post-edit re-read, **any Write/Edit
   under `~/.claude/skills/` or `~/.claude/plugins/cache/` — see Rule 7a below**).

### Rule 7a — Skill Catalog is Read-Only (MANDATORY)

**Every dispatch prompt for every sub-agent role (writer, cross-reviewer, adversarial-reviewer,
reviser, planner, summarizer, judge, domain-consultant) MUST include this prohibition,
verbatim or paraphrased:**

> You MUST NOT use the Write, Edit, or NotebookEdit tools on any file under
> `~/.claude/skills/`, `~/.claude/plugins/cache/`, or any other directory containing the
> running skill bundle. The skill catalog is **read-only** from inside a sub-agent. If your
> task seems to require adding a new criterion ID, dispatch template, snippet, or example,
> the new ID is a **string label in your JSON / markdown output ONLY** — do NOT modify the
> catalog file. The orchestrator's criteria-evolution loop (see review-criteria.md
> `CR-META-mechanize` / `CR-META-adversarial`) is the only path that promotes a runtime
> string label into a registered CR; sub-agents propose, the orchestrator does not.

**Why this rule exists.** Production incident on 2026-05-15: an adversarial-reviewer sub-agent
under high pressure coined three new CR IDs (`CR-PP-XR`, `CR-AR-MULTITENANT`, `CR-AR-CRED-EVENT`)
and appended 102 lines to `~/.claude/skills/prd-analysis/common/review-criteria.md` to register
them. The user caught and reverted the mutation. Any consuming session can quietly mutate the
skill from inside a sub-agent dispatch unless this rule is present in the dispatch prompt.

**Optional defense-in-depth.** Orchestrators MAY run `git -C ~/.claude/skills/prd-analysis
diff --quiet && git -C ~/.claude/skills/system-design diff --quiet` after each dispatch; a
non-zero exit indicates a sub-agent has mutated the skill and the orchestrator MUST abort to
HITL rather than continue.

---

## Rule 8 — Reduce Step After Writer Fan-Out (MANDATORY)

After all writer ACKs for a batch are collected, the orchestrator runs a reduce step:

1. Parse each ACK for `self_review_status` and `fail_count`.
2. Update `state.yml`: mark each leaf as `written` or `written-partial`.
3. Update the PRD `README.md` index: add/update the summary row for every leaf whose writer
   returned `OK`. If only one row changes, use a **single `Edit`**. If multiple rows change,
   Read the README once, merge all row updates in memory, and overwrite via a **single `Write`**.
   Never issue one Edit per leaf.
4. If any writer returned `FAIL` (technical failure), log the `trace_id` to `dispatch-log.jsonl`
   with `status: failed` and re-dispatch that writer in the next emission before proceeding.
5. Writers with `self_review_status: PARTIAL` are flagged for the cross-reviewer in the next
   review round — do not re-dispatch them now.

See `review/index.md` Step 2 and `revise/index.md` Step 2 (Fan-out) for the full templates that bake
these rules in.
