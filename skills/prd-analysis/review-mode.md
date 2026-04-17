# PRD Review Mode (`--review`)

This file contains instructions for reviewing an existing PRD for quality, completeness, and consistency. This mode is read-only — it reports findings but does not modify any files.

Review Checklist dimensions and the per-file / cross-file scope split are defined in `review-checklist.md` — read that first.

---

## Step 0 — Version Discovery

Scan the parent directory for sibling PRD directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the versions form a consistent chain. Chain links may be via `REVISIONS.md` (revise-mode) or Baseline.Predecessor (evolve-mode) — check both. Record this context for subsequent steps. If the reviewed PRD is an evolve-mode PRD (has Baseline section): additionally validate all `→ baseline` reference links, Change Summary accuracy, and change annotation completeness using the evolve-specific checks from the Evolve Step 4 Review Checklist.

## Step 1 — Inventory (main agent, minimal reads)

The main agent must **not** read all journey / architecture topic / feature files itself — doing so fills main context unnecessarily and leaves no budget to aggregate subagent findings. Read only:

- `README.md`
- `REVISIONS.md` (if present)
- `architecture.md` (the index file, not the `architecture/` topic files)

Then enumerate file inventory via `Glob`:

- `journeys/J-*.md`
- `architecture/*.md`
- `features/F-*.md`

Record the file lists for use in Step 2.

## Step 2 — Dispatch Parallel Review Subagents

Dispatch **one round** of subagents, covering disjoint file sets, split by artifact class. **Do not dispatch a second review pass for the same files** — if a subagent's findings are vague, prefer `--revise` over re-reviewing.

**Subagent type and model — REQUIRED:**

- Use `subagent_type: "general-purpose"` (NOT `Explore`). Explore defaults to a lightweight tier that is miscalibrated for PRD judgment work: it produces surface-level findings (wording / formatting), misses cross-field consistency and AC-completeness issues, and gives vague "Fix:" actions. The net effect is slow convergence — review rounds keep flagging trivial items while hard issues persist across revise cycles.
- Pass `model: "sonnet"` explicitly. Per-file review requires understanding dimension semantics, spotting subtle logical gaps, and writing actionable fixes — that is mid-tier work, not light-tier pattern matching.
- Never pin a specific model version (e.g. `claude-sonnet-4-6`). Use the tier alias `sonnet` so the policy survives model rotations.
- **Escalation (rare):** if a PRD has gone through ≥3 `--review → --revise` cycles and the same dimension keeps surfacing findings, escalate that file's next review to `model: "opus"` — recurring findings at that point usually mean the dimension requires cross-feature design judgment that Sonnet is not catching.

**Dispatch rules:**

- Group files by artifact class: `features/`, `journeys/`, `architecture/`.
- Target **~10–15 files per subagent**. A class with ≤15 files → one subagent; with more → split into disjoint ranges (e.g. F-001..F-015, F-016..F-030, F-031..F-048).
- File sets across subagents must not overlap.
- Each subagent runs only the **per-file** dimensions from `review-checklist.md`.
- Each subagent prompt MUST include:
  1. Exact absolute paths of target files (no globs — prevents re-discovery).
  2. Instruction to read each target file exactly once, in parallel.
  3. The per-file dimensions list from `review-checklist.md`.
  4. The findings schema from Step 4 below.
  5. Instruction to skip `prototypes/src/` entirely; list `prototypes/screenshots/` only if needed.

**Subagent prompt template** (copy into each dispatch):

```
Review the following files against the PRD per-file review dimensions.

Target files (read each exactly once, in parallel):
- <abs path 1>
- <abs path 2>
- ...

Per-file dimensions to check:
<paste the Per-file row from review-checklist.md Execution Scope table>

For each file, report findings in this exact format:

### <relative path from PRD dir>
- [Critical|Important|Suggestion] <Dimension>: <one-line finding>
  Fix: <concrete action>

If a file has no findings, write: `### <path>\n(no issues)`.

**Dimension names MUST be copied verbatim from `review-checklist.md`** (e.g. `i18n per-feature — backend`, not `Backend Internationalization`). Downstream tooling matches these strings literally to scope delta review.

Rules:
- You MAY read `<skill-dir>/review-checklist.md` once to look up the exact check text for each per-file dimension.
- Do not Read, Glob, or Grep any other files outside the listed target files.
- Do not read architecture.md or other feature/journey files for cross-reference — cross-file checks are handled separately.
- Do not write or edit anything.
```

## Step 3 — Cross-File Checks (main agent)

After subagents return, the main agent runs the **cross-file** dimensions from `review-checklist.md` using:

- The already-read README + REVISIONS + architecture.md index
- Per-file findings from Step 2 (not the full file contents)
- Targeted reads of specific files only when a cross-file finding requires it (e.g. verifying a dependency chain entry)

If verifying a cross-file check requires reading a feature or journey file, read only that single file — never re-read the whole set.

## Step 4 — Write Findings to `.reviews/REVIEW-{timestamp}.md`

Before presenting to the user, write the aggregated findings to `{PRD-dir}/.reviews/REVIEW-{ISO-timestamp}.md` (create the `.reviews/` directory if absent). This artifact is consumed by `--revise` in Pre-Answered Mode — without it, a subsequent fix pass has to re-discover issues.

**Not version-controlled.** `.reviews/` is a transient scratch directory — teams should add `docs/raw/prd/*/.reviews/` to `.gitignore`. Durable audit history belongs in `REVISIONS.md` (appended by `--revise` post-change), not in raw review dumps. If `.gitignore` does not yet exclude `.reviews/`, prompt the user to add it after Step 5.

**Timestamp format:** `YYYYMMDD-HHMMSS` (e.g. `REVIEW-20260417-153045.md`).

**File structure:**

```markdown
# PRD Review — {ISO timestamp}

Reviewed: {absolute path of PRD directory}
Reviewer: claude (prd-analysis --review)
Version context: {from Step 0; omit if no sibling versions}

## Summary

- Critical: N
- Important: N
- Suggestion: N

## Per-File Findings

### <relative path e.g. features/F-027-xxx.md>
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
- Every finding MUST include the dimension name so `--revise` Step 6 can scope delta review to tagged dimensions only.
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
- The top ~10 findings by severity as a table (inline) with a pointer to the full `REVIEW-{timestamp}.md` file.
- Do not dump the full findings table inline for large PRDs — the file is the source of truth.

## Step 6 — Recommend Next Step

- Issues are minor (wording, missing cross-links): note them for the next revision cycle.
- Issues are significant (missing journeys, orphan features, gaps): recommend `--revise {PRD-dir}`. Tell the user the revise command will auto-consume the latest `REVIEW-*.md` in Pre-Answered Mode — no need to re-enumerate findings.
- Reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version.

## Prototypes — How to Handle

If `prototypes/` exists, list `prototypes/screenshots/` (directory structure and filenames only). This covers the three prototype dimensions: alignment uses filenames vs. state machine states, feedback incorporation uses the `Confirmed` date in each feature's Prototype Reference section, archival completeness uses screenshot presence per feature as a proxy. **Never list or read `prototypes/src/`** — source is seed code, not part of the spec. Only read an individual screenshot file when a state-machine ↔ screenshot mismatch is suspected for a specific feature and visual confirmation is needed; skip otherwise.
