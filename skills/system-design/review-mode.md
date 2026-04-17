# Review Mode (`--review`)

Review an existing design directory for quality, completeness, and consistency. **This mode is read-only** — it reports findings but does not modify any files.

Design Review checklist dimensions and the per-file / cross-file scope split are defined in `design-review-checklist.md` — read that first.

---

## Step 0 — Version Discovery

Scan the parent directory for sibling design directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether `REVISIONS.md` in each version forms a consistent chain (each newer version links back to its predecessor). Record this context for subsequent steps.

## Step 1 — Inventory (main agent, minimal reads)

The main agent must **not** read all module and API files itself — doing so fills main context unnecessarily and leaves no budget to aggregate subagent findings. Read only:

- `README.md`
- `REVISIONS.md` (if present)

Then enumerate file inventory via `Glob`:

- `modules/M-*.md`
- `api/API-*.md` (if the `api/` directory exists)

Record the file lists for use in Step 2.

## Step 2 — Dispatch Parallel Review Subagents

Dispatch **one round** of `Explore` subagents, covering disjoint file sets, split by artifact class. **Do not dispatch a second review pass for the same files** — if a subagent's findings are vague, prefer `--revise` over re-reviewing.

**Dispatch rules:**

- Group files by artifact class: `modules/`, `api/`.
- Target **~10–15 files per subagent**. A class with ≤15 files → one subagent; with more → split into disjoint ranges (e.g. M-001..M-015, M-016..M-030).
- File sets across subagents must not overlap.
- Each subagent runs only the **per-file** dimensions from `design-review-checklist.md`.
- Each subagent prompt MUST include:
  1. Exact absolute paths of target files (no globs — prevents re-discovery).
  2. Instruction to read each target file exactly once, in parallel.
  3. The per-file dimensions list from `design-review-checklist.md`.
  4. The findings schema from Step 4 below.

**Subagent prompt template** (copy into each dispatch):

```
Review the following files against the design per-file review dimensions.

Target files (read each exactly once, in parallel):
- <abs path 1>
- <abs path 2>
- ...

Per-file dimensions to check:
<paste the Per-file row from design-review-checklist.md Execution Scope table>

For each file, report findings in this exact format:

### <relative path from design dir>
- [Critical|Important|Suggestion] <Dimension>: <one-line finding>
  Fix: <concrete action>

If a file has no findings, write: `### <path>\n(no issues)`.

**Dimension names MUST be copied verbatim from `design-review-checklist.md`** (e.g. `API completeness`, not `API spec completeness`). Downstream tooling matches these strings literally to scope delta review.

Rules:
- You MAY read `<skill-dir>/design-review-checklist.md` once to look up the exact check text for each per-file dimension.
- Do not Read, Glob, or Grep any other files outside the listed target files.
- Do not read README.md or other module/api files for cross-reference — cross-file checks are handled separately.
- Do not write or edit anything.
```

## Step 3 — Cross-File Checks (main agent)

After subagents return, the main agent runs the **cross-file** dimensions from `design-review-checklist.md` using:

- The already-read README + REVISIONS
- Per-file findings from Step 2 (not the full file contents)
- Targeted reads of specific files only when a cross-file check requires it (e.g. verifying a cross-module interface alignment for Consistency)
- Targeted reads of PRD files (for PRD traceability, Analytics coverage, NFR coverage, Convention translation, PRD-Design freshness) — read the PRD README and the specific feature/architecture topic file needed, not the whole PRD

If verifying a cross-file check requires reading a module or API file, read only that single file — never re-read the whole set.

## Step 4 — Write Findings to `.reviews/REVIEW-{timestamp}.md`

Before presenting to the user, write the aggregated findings to `{design-dir}/.reviews/REVIEW-{ISO-timestamp}.md` (create the `.reviews/` directory if absent). This artifact is consumed by `--revise` in Pre-Answered Mode — without it, a subsequent fix pass has to re-discover issues.

**Not version-controlled.** `.reviews/` is a transient scratch directory — teams should add `docs/raw/design/*/.reviews/` to `.gitignore`. Durable audit history belongs in `REVISIONS.md` (appended by `--revise` post-change), not in raw review dumps. If `.gitignore` does not yet exclude `.reviews/`, prompt the user to add it after Step 5.

**Timestamp format:** `YYYYMMDD-HHMMSS` (e.g. `REVIEW-20260417-153045.md`).

**File structure:**

```markdown
# Design Review — {ISO timestamp}

Reviewed: {absolute path of design directory}
Reviewer: claude (system-design --review)
Version context: {from Step 0; omit if no sibling versions}

## Summary

- Critical: N
- Important: N
- Suggestion: N

## Per-File Findings

### <relative path e.g. modules/M-003-xxx.md>
- [Critical] <Dimension>: <one-line finding>
  Fix: <concrete action>
- [Important] <Dimension>: ...
  Fix: ...

### <next file>
...

## Cross-File Findings

- [Critical] <Dimension>: <finding>
  Affects: <path1>, <path2>
  Fix: <concrete action>
- [Important] ...
```

Requirements:

- Every finding MUST have a `Fix:` line describing a concrete action (not just "reword this" — say what to write). `--revise` consumes these directly.
- Every finding MUST include the dimension name so `--revise` Step 7 can scope delta review to tagged dimensions only.
- Files with no findings may be omitted from the Per-File Findings section.

## Step 5 — Present Findings

Lead with a version context block if multiple versions were discovered in Step 0:

```
Version context:
  Reviewing: {path of reviewed directory} ({position, e.g. v1 of 2})
  Latest:    {path of latest directory}
  Chain:     {whether REVISIONS.md links form a consistent chain}
  ⚠ You are reviewing an older version.       ← only if not latest
```

Then present:

- Summary counts (Critical / Important / Suggestion).
- The top ~10 findings by severity as a table (inline) with a pointer to the full `.reviews/REVIEW-{timestamp}.md` file.
- Do not dump the full findings table inline for large designs — the file is the source of truth.

Group the inline top-N by theme (completeness, consistency, implementability, etc.) rather than raw checklist order. Lead with Critical, then Important, then Suggestions.

## Step 6 — Recommend Next Step

- Issues are minor (wording, missing cross-links): note them for the next revision cycle.
- Issues are significant (missing modules, interface mismatches, coverage gaps): recommend `--revise {design-dir}`. Tell the user the revise command will auto-consume the latest `.reviews/REVIEW-*.md` in Pre-Answered Mode — no need to re-enumerate findings.
- Reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version.

## Key Difference vs. Self-Review

`--review` is **read-only**. The fix step from the self-review flow (generate-mode Phase 1 Step 10, revise-mode Step 7) is replaced with a findings artifact and a `--revise` recommendation. To apply fixes, the user must follow up with `--revise` (which auto-consumes the artifact).
