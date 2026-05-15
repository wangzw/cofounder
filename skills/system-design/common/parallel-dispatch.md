# Parallel Dispatch Protocol

Shared dispatch rules for fan-out generation of module / API / README leaves (generation
Step 8 writer fan-out) and per-issue reviser subagents (revise-mode Step 3 fan-out). These
rules take precedence over any per-mode wording that conflicts.

> **Note on review phase.** system-design's review phase uses a single-shot cross-reviewer
> plus a conditional adversarial-reviewer (`review/index.md` Step 2 + Step 3) — there is no
> per-leaf reviewer fan-out, so the per-cluster sizing rule (Rule 3) does not apply to
> reviewers. Rule 1 (single-response parallel emission) STILL applies whenever both the
> cross- and adversarial-reviewer fire in the same round — emit them as a parallel pair, not
> sequentially.

---

## Rule 1 — Single-Response Parallel Emission (MANDATORY)

When dispatching N subagents for independent work, emit all N `Agent` tool_use blocks in a
**single assistant response**.

Sequential dispatch (one Agent call per response, waiting for return before next dispatch) is
**FORBIDDEN** for independent work.

**Why:** each sequential dispatch replays the full context cache_read (~280k tokens per turn on
typical design bundles). N sequential dispatches cost N × cache_read; one parallel dispatch
costs 1 × cache_read. Observed: a 32-subagent serial dispatch cost $41.6 that would have been
~$1.30 if parallelized.

**"Independent" means:** no subagent's output is an input to another's. Reviser subagents
across different leaves are always independent. Writer subagents across different leaf files
are always independent. Cross- and adversarial-reviewer dispatches in the same round are
independent.

---

## Rule 2 — Subagent Parameters (MANDATORY)

- `subagent_type: "general-purpose"` — never `Explore` (lightweight tier, miscalibrated for
  design judgment work).
- `model:` — pass the tier alias mapped from the role per `SKILL.md` "Model Tiers" section
  (e.g. writer/reviser → `"sonnet"`, planner/reviewer/domain-consultant → `"opus"`,
  summarizer/judge → `"haiku"`). Never pin a specific version like `claude-sonnet-4-5`.
- **Escalation across tiers** is permitted ONLY when both hold:
  (a) the design has been through ≥3 `--review → --revise` cycles, AND
  (b) the same dimension keeps surfacing findings across those cycles.
  Escalate for the specific file+dimension combination, not the whole batch. Any other
  escalation requires explicit justification in the dispatch prompt.

---

## Rule 3 — Cluster Sizing (MANDATORY)

- **Writer subagents (generation fan-out):** one subagent per leaf file. Batch all leaves
  listed in `plan.add` (and `plan.modify` for `--evolve`) in a single parallel emission. If
  the total leaf count exceeds 20, split into two emissions of ≤20; emit the second only
  after all ACKs from the first are collected (to stay within Agent-tool concurrency limits).
- **Reviser subagents:** one subagent per leaf with `state: new` issues. A leaf with
  **>8 issues** gets its own dispatch — large edit counts replay more cache_read per turn.
  Otherwise batch all reviser dispatches in a single parallel emission.
- No leaf appears in two reviser dispatches in the same round.
- (Reviewer fan-out: not applicable; see top-of-file note.)

---

## Rule 4 — Trace-ID Schema (MANDATORY)

Every subagent dispatch carries a unique `trace_id` injected as the first line of its
prompt. Format:

```
trace_id: R<round>-<role-letter>-<NNN>
```

- `<round>`: integer (1, 2, 3, …). Round 1 is the initial generation; subsequent rounds are
  review/revise cycles.
- `<role-letter>`: per `SKILL.md` Orchestrator Dispatch Contract (`W` writer, `R` reviser,
  `V` reviewer, `P` planner, `C` domain-consultant, `S` summarizer, `J` judge).
- `<NNN>`: three-digit zero-padded sequential counter within the round, assigned by the
  orchestrator before dispatch. Counters reset to 001 each new round.
- Example: `trace_id: R1-W-007` — round 1, seventh writer subagent.

The orchestrator MUST record every dispatched `trace_id` in `dispatch-log.jsonl` before
emitting the parallel Agent blocks (pre-registration prevents orphaned subagent writes).

---

## Rule 5 — Per-Leaf Isolation Contract (MANDATORY)

Each writer / reviser subagent owns exactly one leaf file. It MUST NOT:

- Read or write any leaf outside its assigned `<target-path>`.
- Use Grep/Glob to discover sibling files — all context is pre-supplied in the dispatch
  prompt.
- Perform a post-write re-read of the file it just wrote.
- Emit content in its Task return beyond the single-line ACK.

The dispatch prompt MUST supply the subagent with all context it needs inline (PRD feature
text, data-model excerpts, sibling-module Public Interface excerpts, applicable conventions)
so that no cross-file reads are needed. This is the mechanical enforcement of the
self-contained-file principle.

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

1. `trace_id` as the first line.
2. Absolute target file paths (no globs, no discovery).
3. Exact dimensions or findings scope (no open-ended "also check X").
4. All inline context the subagent needs (PRD feature text, data-model excerpt, conventions,
   sibling-module Public Interfaces).
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
> catalog file. The orchestrator's criteria-evolution loop (see `common/review-criteria.md`
> entries `CR-META-mechanize` and `CR-META-adversarial`) is the only path that promotes a
> runtime string label into a registered CR; sub-agents propose, the orchestrator does not.

**Why this rule exists.** Production incident on 2026-05-15: an adversarial-reviewer sub-agent
under high pressure coined three new CR IDs and appended 102 lines to a sibling skill's
`review-criteria.md`. The user caught and reverted the mutation. Any consuming session can
quietly mutate the skill from inside a sub-agent dispatch unless this rule is present in the
dispatch prompt.

**Optional defense-in-depth.** Orchestrators MAY run `git -C ~/.claude/skills/system-design
diff --quiet && git -C ~/.claude/skills/prd-analysis diff --quiet` after each dispatch; a
non-zero exit indicates a sub-agent has mutated a skill and the orchestrator MUST abort to
HITL rather than continue.

---

## Rule 8 — Reduce Step After Writer Fan-Out (MANDATORY)

After all writer ACKs for a batch are collected, the orchestrator runs a reduce step:

1. Parse each ACK for `self_review_status` and `fail_count`.
2. Update `state.yml`: mark each leaf as `written` or `written-partial`.
3. Update the design `README.md` Module Index: add/update the row for every module/API leaf
   whose writer returned `OK`. If only one row changes, use a **single `Edit`**. If multiple
   rows change, Read the README once, merge all row updates in memory, and overwrite via a
   **single `Write`**. Never issue one Edit per leaf.
4. If any writer returned `FAIL` (technical failure), log the `trace_id` to
   `dispatch-log.jsonl` with `status: failed` and re-dispatch that writer in the next
   emission before proceeding.
5. Writers with `self_review_status: PARTIAL` are flagged for the cross-reviewer in the next
   review round — do not re-dispatch them now.

See `review/index.md` Step 2/3 (single-shot reviewers) and `revise/index.md` Step 3 (fan-out
revisers) for the full integration.
