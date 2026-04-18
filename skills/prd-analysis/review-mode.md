# PRD Review Mode (`--review`)

This file contains instructions for reviewing an existing PRD for quality, completeness, and consistency. This mode is read-only — it reports findings but does not modify any files.

Review Checklist dimensions and the per-file / cross-file scope split are defined in `review-checklist.md` — read that first.

---

## Step 0 — Version Discovery

Scan the parent directory for sibling PRD directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the versions form a consistent chain. Chain links may be via `REVISIONS.md` (revise-mode) or Baseline.Predecessor (evolve-mode) — check both. Record this context for subsequent steps. If the reviewed PRD is an evolve-mode PRD (has Baseline section): additionally validate all `→ baseline` reference links, Change Summary accuracy, and change annotation completeness using the evolve-specific checks from the Evolve Step 4 Review Checklist.

## Step 0.5 — Convergence Gate

Count prior review-driven revision passes via `Grep` on `{PRD-dir}/REVISIONS.md` with pattern `^## .*review-finding` (version-controlled — works on fresh clones). If `REVISIONS.md` is absent, the count is 0.

Apply the Pass-Count Severity Gate from `review-checklist.md` → Convergence Rules:

| Prior review-driven passes | Severities to emit | Decision |
|----------------------------|---------------------|----------|
| 0–1 | Critical + Important + Suggestion | Proceed — full review |
| 2 | Critical + Important (drop Suggestion) | Proceed — gated review |
| ≥3 | Critical only | See abort condition below |

**Abort condition:** if prior review-driven passes ≥3 AND the most recent matching REVISIONS.md entry's Rationale reports zero remaining Critical findings (or the prior `--revise` ran to completion with no Critical left), do NOT run a new review pass. Report to the user:

> This PRD has completed 3+ remediation passes with no remaining Critical findings. Further review rounds are unlikely to surface correctness issues — remaining gaps are better surfaced by running system-design. Skipping review.

Then exit without writing a REVIEW file.

Otherwise, record the severity gate value and pass it into every dispatched subagent (Step 2) so they only emit findings at or above the gate. The main agent's cross-file pass (Step 3) follows the same gate.

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

**Subagent prompt template** (copy into each dispatch, substituting the severity gate from Step 0.5):

```
Review the following files against the PRD per-file review dimensions.

**Severity gate for this pass:** {all | critical_important | critical_only}
Emit ONLY findings at or above this gate. The orchestrator already computed this from prior-pass count — do not re-derive.

Target files (read each exactly once, in parallel):
- <abs path 1>
- <abs path 2>
- ...

Per-file dimensions to check:
<paste the Per-file row from review-checklist.md Execution Scope table>

**Convergence Rules — apply BEFORE flagging any finding:**
1. **Pass-Count Severity Gate** — drop findings below the gate value above.
2. **Dimension Saturation Rules** (see `review-checklist.md` → Convergence Rules) — do NOT flag a dimension whose saturation condition is met. Specifically: Testability (c) does not require per-endpoint p95; Testability (d) does not require enumerating every role×workspace×org combination; Testability (h) does not require prescribed fixture shapes; i18n backend tables do not require one row per EC.
3. **Scope Boundary partition** — flag scope-boundary violations ONLY for content clearly in the "defer to system-design" column of the partition table (SQL DDL, handler names, concurrency mechanism, library choice). Storage-hint nouns and capability statements are NOT violations.
4. **Oscillation detection** — read the most recent 2–3 entries' `**Themes:**` sections from `REVISIONS.md` (version-controlled, always available). If a Theme line records a prior pass adding content you're about to flag as violation (or removing content you're about to demand), emit a single `[Critical] Convergence conflict` citing the REVISIONS.md entry date + Theme line, NOT the per-dimension finding. Local `.reviews/*.applied.md` may be consulted as a supplement when present.

For each file, report findings in this exact format:

### <relative path from PRD dir>
- [Critical|Important|Suggestion] <Dimension>: <one-line finding>
  Fix: <concrete action>

If a file has no findings, write: `### <path>\n(no issues)`.

**Dimension names MUST be copied verbatim from `review-checklist.md`** (e.g. `i18n per-feature — backend`, not `Backend Internationalization`). Downstream tooling matches these strings literally to scope delta review.

Rules:
- You MUST read `<skill-dir>/review-checklist.md` once to load the Convergence Rules and dimension definitions.
- You MUST `Grep` the most recent 2–3 entries of `{PRD-dir}/REVISIONS.md` for oscillation detection (skip if file absent). `.reviews/*.applied.md` is OPTIONAL supplementary signal — gitignored and may be missing.
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
