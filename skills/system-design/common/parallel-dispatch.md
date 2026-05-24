# Parallel Dispatch Protocol

Shared dispatch rules for fan-out generation of module / API / README leaves (generation
Step 8 writer fan-out), cross-reviewer subagents (review-mode Step 2 per-category fan-out),
and per-criterion-cluster reviser subagents (revise-mode Step 3 fan-out). These rules take
precedence over any per-mode wording that conflicts.

> **Note on review phase.** system-design's review phase fans out one cross-reviewer per
> criterion category (per `common/criterion-categories.md`). All cross-reviewer dispatches
> in a round emit as a single parallel batch per Rule 1. The conditional adversarial-reviewer
> (`review/index.md` Step 3) still fires once per round, after the cross-reviewer batch ACKs.

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
- **Reviser subagents (revise fan-out):** grouping is by `criterion_id`, NOT by leaf. One
  reviser per criterion-cluster. Each cluster carries ≤`common/config.yml revise.edit_cap`
  issues (default 8). The leaf count in a cluster is emergent (depends on how the
  criterion's issues are distributed across leaves) and is **not directly capped** — the
  edit-count cap is the protection. If a single criterion has >`edit_cap` issues this round,
  split into multiple clusters with monotonic `cluster_id`s (`R<round>-CC-<nnn>`); the same
  criterion's clusters may run in parallel. The same leaf may appear in multiple clusters —
  `Edit`'s unique-match semantics serialize sibling writes naturally (see Rule 6).
- **Reviewer subagents (review fan-out):** grouping is by **criterion category**, not by
  artifact class. One cross-reviewer per category active this round (see
  `common/criterion-categories.md`). Each reviewer receives all in-scope leaves and ONLY
  the CR-IDs in its category. If a single category's leaf set exceeds
  `common/config.yml review.cluster_leaf_cap` (default 25), split into multiple sub-clusters
  by leaf range; sub-clusters carry identical criteria and disjoint leaf subsets.
- No leaf appears in two reviewer clusters; a leaf MAY appear in multiple reviser clusters
  when different criteria touch it (this is expected with the criterion-centric model).

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

## Rule 5 — Per-Work-Unit Isolation Contract (MANDATORY)

Each sub-agent owns exactly one work unit. The work-unit definition varies by role:

- **Writer**: one leaf file. (Unchanged from prior contract.)
- **Reviewer (cross / adversarial)**: one category cluster — all leaves listed in the
  cluster + the cluster's CR-ID list. The reviewer MUST NOT apply CR-IDs outside the
  cluster and MUST NOT emit findings for criteria from other categories.
- **Reviser**: one criterion-cluster — ≤`revise.edit_cap` issues, all sharing the same
  `criterion_id`, plus their `affected_leaves` list. The reviser MUST NOT Edit leaves
  outside `affected_leaves`, MUST NOT touch issues outside its cluster, and MUST use `Edit`
  only on artifact leaves (never `Write`).

Common to all roles:

- No Grep/Glob to discover sibling files — all target paths are pre-supplied in the
  dispatch prompt.
- No post-write re-read of files just written.
- No Task return content beyond the single-line ACK.
- The dispatch prompt MUST supply all inline context (criterion-category notes, PRD feature
  text, data-model excerpts, sibling-module Public Interface excerpts, applicable
  conventions) so cross-file reads outside the work unit are unnecessary. This is the
  mechanical enforcement of the self-contained-file principle.

---

## Rule 6 — Tool Usage Inside Subagents (MANDATORY)

- **Revisers**: `Edit` only on artifact leaves. **Never `Write`.** Each issue corresponds
  to one `Edit` call (one precision replacement). If multiple Edits hit the same leaf
  within the same cluster, issue them sequentially within the sub-agent. Do NOT merge
  multiple Edits into a single `Write` — `Write` would silently overwrite parallel
  revisers' changes on the same leaf (one criterion's reviser cannot see another
  criterion's reviser's work). The cache_read cost of multiple sequential Edits inside one
  cluster is bounded by the `edit_cap` (default 8) and is a deliberate trade-off for
  concurrency safety.
- **Writers**: rule unchanged. File with 1 edit → `Edit`. File being created → single
  `Write`. Multi-edit on the same file in a single dispatch → Read once, merge in memory,
  single `Write` with final content.
- **Reviewers**: read-only on artifact leaves (no `Edit`, no `Write`); single `Write` to
  `reviewer-output/<trace_id>.json`. Rule unchanged.
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

See `review/index.md` Step 2 (per-category reviewer fan-out) and `revise/index.md` Step 2 +
Step 3 (per-criterion reviser fan-out
revisers) for the full integration.
