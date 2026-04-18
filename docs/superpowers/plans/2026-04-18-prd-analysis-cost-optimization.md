# prd-analysis Cost & Perf Optimization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover $70–$120 (35–60%) per `prd-analysis` `--review + --revise` session by converting permissive dispatch wording to mandatory rules, centralizing them in two new discipline files, and nudging users to `/compact` between phases.

**Architecture:** Two new rule files (`parallel-dispatch.md`, `output-discipline.md`) loaded via `SKILL.md` mode-routing. Existing `review-mode.md` and `revise-mode.md` trim their duplicated dispatch rules into references. No change to user-facing CLI or output file formats.

**Tech Stack:** Markdown skill files only. No runtime code. Verification is grep-based.

**Spec:** `docs/superpowers/specs/2026-04-18-prd-analysis-cost-optimization-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `skills/prd-analysis/parallel-dispatch.md` | CREATE | Mandatory subagent dispatch rules (shared by --review, --revise) |
| `skills/prd-analysis/output-discipline.md` | CREATE | Main-agent output discipline rules (all modes) |
| `skills/prd-analysis/SKILL.md` | MODIFY | Mode-routing table + Key Principles |
| `skills/prd-analysis/review-mode.md` | MODIFY | Step 2 trim, Step 2 prompt template, Step 6 Compaction Hint |
| `skills/prd-analysis/revise-mode.md` | MODIFY | Pre-Answered Dispatch Execution, Step 5 trim, Step 5 Handling Returns |

No test files — this project has no automated skill-testing harness. Verification is manual + grep.

---

### Task 1: Create `parallel-dispatch.md`

**Files:**
- Create: `skills/prd-analysis/parallel-dispatch.md`

- [ ] **Step 1: Write the file with the full content below**

Path: `/Users/wangzw/workspace/cofounder/skills/prd-analysis/parallel-dispatch.md`

```markdown
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
- Review subagents: **10–15 files** per cluster, grouped by artifact class (`features/`, `journeys/`, `architecture/`).
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
```

- [ ] **Step 2: Verify file exists and has expected structure**

Run: `grep -c "^## Rule" /Users/wangzw/workspace/cofounder/skills/prd-analysis/parallel-dispatch.md`
Expected output: `5`

Run: `grep -c "MANDATORY\|FORBIDDEN" /Users/wangzw/workspace/cofounder/skills/prd-analysis/parallel-dispatch.md`
Expected output: `9` or higher (5 MANDATORY + 4 FORBIDDEN)

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/parallel-dispatch.md
git commit -m "feat(prd-analysis): add parallel-dispatch.md mandatory rules"
```

---

### Task 2: Create `output-discipline.md`

**Files:**
- Create: `skills/prd-analysis/output-discipline.md`

- [ ] **Step 1: Write the file with the full content below**

Path: `/Users/wangzw/workspace/cofounder/skills/prd-analysis/output-discipline.md`

```markdown
# Output Discipline for Main Agent

Applies to the main agent in ALL prd-analysis modes. Subagents follow their dispatch prompt's own output rules (see `parallel-dispatch.md`).

## Rule 1 — No Echo-Then-Write (MANDATORY)

When generating large artifacts (REVIEW files, feature files, journey files, architecture topic files, REVISIONS.md entries), write them directly via the `Write` tool. Do NOT include the full body of the artifact in assistant text before the tool call.

- **Permitted:** a one-line summary like `"Writing REVIEW-20260417-*.md with 18 Critical / 47 Important / 142 Suggestion findings."`
- **Forbidden:** pasting the full 30k-token report body inline, then calling `Write` — this doubles output token cost.

**Why:** observed duplicate generation of a 35k-token REVIEW report (once as inline text, once via `Write`) cost $5.98 in a single session.

## Rule 2 — No Inter-Dispatch Commentary (MANDATORY)

After a subagent returns a `<task-notification>`, do NOT emit an assistant response that contains only acknowledgment or summary of the return.

- If the next action is another tool call (TaskUpdate at a milestone, next dispatch, Write), proceed to that tool call in the SAME response that processes the return.
- If the next action is human review, emit the full user-facing summary in that response, not an intermediate ack.

**Why:** observed 87 tool-less "thinking responses" worth $71.6 in a single session, most triggered by subagent returns.

## Rule 3 — Task Board Parsimony

`TaskUpdate` fires ONLY at cluster-level milestones:

- All subagents in a cluster dispatched
- All subagents in a cluster returned (batch the status change)
- All clusters complete

Do NOT `TaskUpdate` after each individual subagent return. **Targets:** ≤3 TaskUpdate calls per `--review` pass, ≤5 per `--revise` pass.

## Rule 4 — Bash Consolidation

When multiple independent read-only Bash commands are needed (e.g., `git status`, `git diff`, `ls`, file inspection), combine them in a single response via parallel tool_use blocks, OR chain with `&&` in one command when output ordering is deterministic.

Never emit separate Bash tool calls across multiple responses for a batch of git/ls/file-inspection operations.
```

- [ ] **Step 2: Verify file exists and has expected structure**

Run: `grep -c "^## Rule" /Users/wangzw/workspace/cofounder/skills/prd-analysis/output-discipline.md`
Expected output: `4`

Run: `grep -c "MANDATORY" /Users/wangzw/workspace/cofounder/skills/prd-analysis/output-discipline.md`
Expected output: `2` or higher

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/output-discipline.md
git commit -m "feat(prd-analysis): add output-discipline.md main-agent rules"
```

---

### Task 3: Update `SKILL.md` — mode-routing table + Key Principles

**Files:**
- Modify: `skills/prd-analysis/SKILL.md`

- [ ] **Step 1: Update the Mode Routing table**

In `/Users/wangzw/workspace/cofounder/skills/prd-analysis/SKILL.md`, replace the existing Mode Routing table (currently starting with `| Mode | Read These Files |` around line 31) with this exact table:

```markdown
| Mode | Read These Files |
|------|-----------------|
| Initial analysis (no flags) | `questioning-phases.md`, `output-discipline.md` (load `scope-reference.md` on demand if scope boundary questions arise; load `review-checklist.md` on demand at Step 6) |
| Initial analysis + document input | `questioning-phases.md`, `document-mode.md`, `output-discipline.md` (load `scope-reference.md` on demand if scope boundary questions arise; load `review-checklist.md` on demand at Step 6) |
| `--review` | `review-mode.md`, `review-checklist.md`, `parallel-dispatch.md`, `output-discipline.md` |
| `--revise` | `revise-mode.md`, `parallel-dispatch.md`, `output-discipline.md` (load `scope-reference.md` and `review-checklist.md` on demand per revise-mode.md instructions) |
| `--evolve` | `evolve-mode.md`, `questioning-phases.md`, `output-discipline.md` (load `scope-reference.md` on demand if scope boundary questions arise; load `review-checklist.md` on demand at Evolve Step 4) |
```

The unchanged sentence right after the table (`Do NOT read files not listed for the current mode — they are not needed and waste context.`) stays.

- [ ] **Step 2: Add a Key Principle**

In the "Key Principles" section of the same file, append this bullet AT THE END of the bullet list:

```markdown
- **Discipline files are non-optional** — `parallel-dispatch.md` (for `--review` / `--revise`) and `output-discipline.md` (all modes) are loaded at mode entry and their rules take precedence over any per-mode wording that conflicts.
```

- [ ] **Step 3: Verify the edits**

Run: `grep -c "output-discipline.md" /Users/wangzw/workspace/cofounder/skills/prd-analysis/SKILL.md`
Expected output: `6` (5 mode rows + 1 Key Principle)

Run: `grep -c "parallel-dispatch.md" /Users/wangzw/workspace/cofounder/skills/prd-analysis/SKILL.md`
Expected output: `3` (2 mode rows + 1 Key Principle)

Run: `grep -n "Discipline files are non-optional" /Users/wangzw/workspace/cofounder/skills/prd-analysis/SKILL.md`
Expected: one line returned.

- [ ] **Step 4: Commit**

```bash
git add skills/prd-analysis/SKILL.md
git commit -m "feat(prd-analysis): wire discipline files into mode routing"
```

---

### Task 4: Update `review-mode.md` Step 2 — trim dispatch rules into reference

**Files:**
- Modify: `skills/prd-analysis/review-mode.md`

- [ ] **Step 1: Replace the Subagent type/model and Dispatch rules subsections**

In `/Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`, find the section `## Step 2 — Dispatch Parallel Review Subagents`. It currently contains:

- An intro paragraph ("Dispatch **one round** of subagents...")
- `**Subagent type and model — REQUIRED:**` block (~8 lines of bullets)
- `**Dispatch rules:**` block (~8 lines of bullets)
- Then the `**Subagent prompt template** (copy into each dispatch...)` with a fenced template — DO NOT touch the template; only trim the two blocks above it.

**Delete** the entire `**Subagent type and model — REQUIRED:**` block and the entire `**Dispatch rules:**` block. **Replace** them with this exact text:

```markdown
**Read `parallel-dispatch.md` first** — it defines the mandatory dispatch rules (single-response parallel emission, `subagent_type`, model tier, cluster sizing, tool usage, prompt contract). Review-mode-specific overrides are below.

**Review-mode-specific rules:**

- Group files by artifact class: `features/`, `journeys/`, `architecture/`. Do not mix classes within a cluster.
- Each cluster contains **10–15 files** (not the ≤3 used by Fix subagents).
- Every subagent runs only the **per-file** dimensions from `review-checklist.md` — cross-file dimensions run in Step 3 on the main agent.
- Each subagent prompt MUST include:
  1. Exact absolute paths of target files (no globs — prevents re-discovery).
  2. Instruction to read each target file exactly once, in parallel.
  3. The per-file dimensions list from `review-checklist.md`.
  4. The findings schema from Step 4 below.
  5. Instruction to skip `prototypes/src/` entirely; list `prototypes/screenshots/` only if needed.
```

Keep the intro paragraph ("Dispatch **one round**...") and the `**Subagent prompt template**` block unchanged.

- [ ] **Step 2: Verify the trim**

Run: `grep -c "Read \`parallel-dispatch.md\` first" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected output: `1`

Run: `grep -c "Subagent type and model — REQUIRED" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected output: `0` (the old heading is gone)

Run: `grep -n "Review-mode-specific rules" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected: one line returned.

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/review-mode.md
git commit -m "refactor(prd-analysis): trim review-mode Step 2 into parallel-dispatch reference"
```

---

### Task 5: Update `review-mode.md` — add output-discipline rule to Subagent prompt template

**Files:**
- Modify: `skills/prd-analysis/review-mode.md`

- [ ] **Step 1: Add the output-discipline rule to the Subagent prompt template**

In the same file, inside the fenced code block titled `**Subagent prompt template**` (the block that tells subagents how to report findings), find the `Rules:` list near the end of the template. The current last bullet is:

```
- Do not write or edit anything.
```

Append a new bullet AFTER that line, still inside the fenced block:

```
- Output discipline: emit per-file findings directly as structured text. No prose preamble or "I will now report findings" framing. Do not echo the findings list in your final summary — the structured entries ARE the output.
```

- [ ] **Step 2: Verify**

Run: `grep -n "Output discipline: emit per-file findings" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected: one line returned.

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/review-mode.md
git commit -m "feat(prd-analysis): add output-discipline rule to review subagent prompt"
```

---

### Task 6: Update `review-mode.md` Step 6 — append Compaction Hint Block

**Files:**
- Modify: `skills/prd-analysis/review-mode.md`

- [ ] **Step 1: Append the Compaction Hint block to Step 6**

In the same file, find the section `## Step 6 — Recommend Next Step`. It currently ends with bullets about recommending `--revise` / noting older version. After the LAST bullet of Step 6 (before the next `##` section — `## Prototypes — How to Handle`), append:

```markdown

### Compaction Hint

After presenting findings and before the user proceeds to `--revise`, emit this message verbatim:

> 💡 **Context compaction recommended**
>
> The review phase has loaded your journey/architecture/feature files into context (~280k tokens). If you plan to run `--revise` next, running `/compact` now will let the revise phase start with a cleaner context — saves roughly $20–$30 in cache_read costs on a PRD this size.
>
> Run `/compact` to proceed, or skip this if you are not revising this session.

**Skip this message if:**
- No REVIEW file was written (convergence gate aborted in Step 0.5), OR
- Critical + Important finding count is below 5 (revise is unlikely to be worth running at that point).
```

- [ ] **Step 2: Verify**

Run: `grep -n "### Compaction Hint" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected: one line returned.

Run: `grep -c "Context compaction recommended" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md`
Expected output: `1`

Run: `grep -B2 "^## Prototypes" /Users/wangzw/workspace/cofounder/skills/prd-analysis/review-mode.md | head -5`
Expected: the Compaction Hint section precedes the Prototypes heading (confirms we appended in Step 6, not after Prototypes).

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/review-mode.md
git commit -m "feat(prd-analysis): add Compaction Hint to review-mode Step 6"
```

---

### Task 7: Update `revise-mode.md` Pre-Answered Mode — add Dispatch Execution block

**Files:**
- Modify: `skills/prd-analysis/revise-mode.md`

- [ ] **Step 1: Insert the Dispatch Execution block**

In `/Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`, find this exact sentence in the Pre-Answered Mode section:

> The main agent consumes the returned YAML as the cluster plan. Fix-subagent dispatches in Step 5 use `cluster.target_files` directly; Step 6 delta-review scope uses `dimensions_tagged_union`.

Immediately AFTER this paragraph (and before the next `**Clustering-Subagent dispatch parameters:**` paragraph), insert:

```markdown

**Dispatch execution (MANDATORY — see `parallel-dispatch.md` Rule 1):**

Once the manifest is consumed, emit ALL Fix subagent dispatches in a **single assistant response** containing N `Agent` tool_use blocks (one per cluster). Sequential dispatch is **FORBIDDEN** — it replays ~280k cache_read per cluster, costing roughly $1.30 per cluster on a typical PRD. A 10-cluster revision dispatched in parallel costs ~$1.30; dispatched serially costs ~$13.

Do NOT emit any intermediate assistant response between consuming the manifest and the dispatch. No "Now I will dispatch the fix subagents" preamble — proceed directly to the multi-tool-use response.
```

- [ ] **Step 2: Verify**

Run: `grep -n "Dispatch execution (MANDATORY" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected: one line returned.

Run: `grep -B1 -A1 "single assistant response.*containing N" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md | head -5`
Expected: the MANDATORY paragraph is visible.

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/revise-mode.md
git commit -m "feat(prd-analysis): mandate single-response parallel Fix dispatch in Pre-Answered Mode"
```

---

### Task 8: Update `revise-mode.md` Step 5 — trim Fix-Subagent Dispatch Rules into reference

**Files:**
- Modify: `skills/prd-analysis/revise-mode.md`

- [ ] **Step 1: Replace the Model tier + Tool usage paragraphs**

In the same file, find the section `### Fix-Subagent Dispatch Rules` (under `## Revise Step 5 — Execute Changes`). It currently has two paragraphs:

- `**Model tier:**` paragraph (starts `"Fix subagents MUST be dispatched with \`model: sonnet\`..."`)
- `**Tool usage:**` paragraph (starts `"when a file has **>1 queued edit**, the subagent MUST use \`MultiEdit\`..."`)

**Replace BOTH paragraphs** with this exact text:

```markdown
**Read `parallel-dispatch.md` first** — it defines the mandatory dispatch rules (single-response parallel emission, model tier, cluster sizing ≤3 files, MultiEdit for >1 edit, forbidden post-edit re-reads, dispatch prompt contract).

**Revise-mode-specific rules:**

- If a `.reviews/REVIEW-*.md` was consumed (Pre-Answered Mode), use **Template A** (reference-based, below).
- Otherwise (interactive revise, Step 3 gathered the change list), use **Template B** (inline edits list, below).
- When delegating a cluster to a `general-purpose` subagent, the dispatch prompt MUST use the matching template below. Free-form prompts lead to re-reading files (4× observed on the same file) and redundant Grep/Glob exploration — both pure waste.
```

Leave Template A and Template B fenced blocks unchanged. Leave the paragraph `If a \`.reviews/REVIEW-*.md\` was consumed (Pre-Answered Mode), prefer **Template A**...` in its current location (it may now be redundant with the new bullets, but it is also the paragraph that introduces the templates — keep it).

Actually — the existing sentence `If a \`.reviews/REVIEW-*.md\` was consumed (Pre-Answered Mode), prefer **Template A** (reference-based, short). Otherwise use **Template B** (inline edits list).` duplicates our new bullet. **Delete that sentence** to avoid duplication.

- [ ] **Step 2: Verify**

Run: `grep -c "Read \`parallel-dispatch.md\` first" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected output: `1`

Run: `grep -c "Fix subagents MUST be dispatched with" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected output: `0` (old text removed)

Run: `grep -c "Revise-mode-specific rules" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected output: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/revise-mode.md
git commit -m "refactor(prd-analysis): trim revise-mode Step 5 dispatch rules into reference"
```

---

### Task 9: Update `revise-mode.md` Step 5 — append Handling Subagent Returns block

**Files:**
- Modify: `skills/prd-analysis/revise-mode.md`

- [ ] **Step 1: Append the block after Template B**

In the same file, find the END of Template B (the fenced code block that ends with `"...the edits list is the contract."\n\`\`\`"`). After the closing triple-backticks of Template B, and BEFORE the next paragraph (`The orchestrator (main agent) owns the cluster plan...`), insert:

```markdown

### Handling Subagent Returns

Follow `output-discipline.md` Rule 2 (no inter-dispatch commentary) and Rule 3 (TaskUpdate parsimony):

- When Fix subagent returns arrive, the main agent's NEXT action is the next tool call (cross-reference sweep, REVISIONS.md append, or user-facing summary) — NOT a standalone ack response.
- `TaskUpdate` fires once when all clusters dispatched, once when all returned. Do NOT update per-cluster.
- When writing REVISIONS.md, use `Write` directly with the full entry body — do NOT echo the body in assistant text first (output-discipline Rule 1).
```

- [ ] **Step 2: Verify**

Run: `grep -n "### Handling Subagent Returns" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected: one line returned.

Run: `grep -B1 -A1 "main agent's NEXT action is the next tool call" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md | head -5`
Expected: the bullet is present.

Run: `grep -B2 "The orchestrator (main agent) owns the cluster plan" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md | head -5`
Expected: the Handling Subagent Returns section appears just before the orchestrator paragraph.

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/revise-mode.md
git commit -m "feat(prd-analysis): add Handling Subagent Returns block to revise-mode Step 5"
```

---

### Task 10: Final cross-file consistency check

**Files:**
- Read-only verification across all 5 skill files.

- [ ] **Step 1: Confirm all new files and cross-references exist**

Run: `ls /Users/wangzw/workspace/cofounder/skills/prd-analysis/parallel-dispatch.md /Users/wangzw/workspace/cofounder/skills/prd-analysis/output-discipline.md`
Expected: both paths listed without error.

Run: `grep -rn "parallel-dispatch.md" /Users/wangzw/workspace/cofounder/skills/prd-analysis/`
Expected: matches in SKILL.md (3), review-mode.md (1), revise-mode.md (2). Total 6 matches across those 3 files plus the self-reference lines inside parallel-dispatch.md itself (e.g., `# Parallel Subagent Dispatch Rules` — filename not self-referenced, so ignore).

Run: `grep -rn "output-discipline.md" /Users/wangzw/workspace/cofounder/skills/prd-analysis/`
Expected: matches in SKILL.md (6: 5 rows + 1 Key Principle), review-mode.md (optional — only if Task 5 used the exact filename; it did not), revise-mode.md (1 in Handling Subagent Returns).

- [ ] **Step 2: Confirm no dead anchors (old wording removed)**

Run: `grep -n "parallel where possible" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected: **zero matches** (the old permissive wording — if this still appears, Task 8 missed a spot).

Note: the phrase "Parallelism:" currently appears in revise-mode.md Step 5 "Batch by File (Required)" section (line ~243 in the pre-change version). That section is independent of the Fix-Subagent Dispatch Rules paragraphs we replaced in Task 8 and should remain — but verify its wording is consistent.

Run: `grep -n "^**Parallelism:**" /Users/wangzw/workspace/cofounder/skills/prd-analysis/revise-mode.md`
Expected: 1 match (the Batch-by-File Parallelism paragraph stays).

If the Parallelism paragraph uses language like `"process clusters in parallel where no cluster's output is an input to another cluster's edit"`, this is fine — it aligns with parallel-dispatch Rule 1's independence definition. Do NOT change it.

- [ ] **Step 3: Run a final wc -l sanity check**

Run: `wc -l /Users/wangzw/workspace/cofounder/skills/prd-analysis/parallel-dispatch.md /Users/wangzw/workspace/cofounder/skills/prd-analysis/output-discipline.md`
Expected: parallel-dispatch.md around 55–75 lines; output-discipline.md around 35–50 lines. (Rough bounds — deviation signals accidental content changes.)

- [ ] **Step 4: Final commit (marker)**

If Steps 1–3 all pass, no new edits are needed. Create an empty-state confirmation commit ONLY if there are staged changes from verification edits; otherwise skip this step.

```bash
git status
```

If clean: stop. If dirty: review, fix, commit with message `chore(prd-analysis): post-optimization verification fixes`.

---

## Spec-Coverage Self-Check

| Spec Section | Implementing Task |
|---|---|
| parallel-dispatch.md content (Rules 1–5) | Task 1 |
| output-discipline.md content (Rules 1–4) | Task 2 |
| SKILL.md Mode Routing table update | Task 3 Step 1 |
| SKILL.md Key Principles addition | Task 3 Step 2 |
| review-mode.md Step 2 trim (dispatch rules → reference) | Task 4 |
| review-mode.md Subagent prompt template output-discipline line | Task 5 |
| review-mode.md Step 6 Compaction Hint | Task 6 |
| revise-mode.md Pre-Answered Mode Dispatch Execution block | Task 7 |
| revise-mode.md Step 5 trim (Model tier + Tool usage → reference) | Task 8 |
| revise-mode.md Step 5 Handling Subagent Returns | Task 9 |
| Backward compatibility (no CLI / output format changes) | Implicit — no task touches CLI parsing or output templates |
| Testing Strategy (manual regression on castworks PRD) | Not a task — see spec; runs after plan completes |

All spec sections have a task. No placeholders. Names used consistently across tasks (`parallel-dispatch.md`, `output-discipline.md`, `Compaction Hint`, `Dispatch execution`, `Handling Subagent Returns`).
