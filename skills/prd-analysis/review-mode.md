# PRD Review Mode (`--review`)

Instructions for reviewing an existing PRD bundle for quality, completeness, and consistency.
This mode is read-only — it reports findings but does not modify any PRD files.

The ~50 review dimensions and their per-file / cross-file scope split are defined in
`review-checklist.md`. Read that file during Step 2 dispatch setup.

---

## Step 0 — Version Discovery

Scan the parent directory for sibling PRD directories with the same product slug (the portion
after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the
`YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step.

If multiple versions exist: identify which version is being reviewed, which is latest (by date
prefix), and whether the versions form a consistent chain. Chain links may be via `REVISIONS.md`
(revise-mode) or Baseline.Predecessor (evolve-mode) — check both. Record this context for
subsequent steps.

If the reviewed PRD is an evolve-mode PRD (has a Baseline section): additionally validate all
`→ baseline` reference links, Change Summary accuracy, and change annotation completeness using the
evolve-specific checks from the Evolve Step 4 Review Checklist.

## Step 0.5 — Convergence Gate

Count prior review-driven revision passes by grepping `{PRD-dir}/REVISIONS.md` for the pattern
`^## .*review-finding`. If `REVISIONS.md` is absent the count is 0.

Apply the Pass-Count Severity Gate:

| Prior review-driven passes | Severities to emit | Decision |
|----------------------------|---------------------|----------|
| 0–1 | Critical + Important + Suggestion | Proceed — full review |
| 2 | Critical + Important (drop Suggestion) | Proceed — gated review |
| ≥3 | Critical only | See abort condition below |

**Abort condition:** if prior review-driven passes ≥3 AND the most recent matching REVISIONS.md
entry's Rationale reports zero remaining Critical findings (or the prior `--revise` ran to
completion with no Critical left), do NOT run a new review pass. Report to the user:

> This PRD has completed 3+ remediation passes with no remaining Critical findings. Further review
> rounds are unlikely to surface correctness issues — remaining gaps are better surfaced by running
> system-design. Skipping review.

Then exit without writing any review output.

Otherwise, record the severity gate value and pass it into every dispatched subagent (Step 2) so
they emit only findings at or above the gate. The main agent's cross-file pass (Step 3) follows
the same gate.

## Step 1 — Inventory (main agent, minimal reads)

The main agent MUST NOT read all journey / architecture topic / feature files itself — doing so
fills the main context unnecessarily and leaves no budget to aggregate subagent findings. Read only:

- `README.md`
- `REVISIONS.md` (if present)
- `architecture.md` (the index file, not the `architecture/` topic files)

Then enumerate file inventory via `Glob`:

- `journeys/J-*.md`
- `architecture/*.md`
- `features/F-*.md`

Record the file lists for use in Step 2.

## Step 2 — Script-First Checks (main agent)

Before dispatching LLM review subagents, run the structural (script-type) checks from
`common/review-criteria.md`. These checks are mechanical and fast; running them first ensures
LLM subagents are not dispatched against bundles with broken structure that would contaminate
semantic findings.

Script checks to run (in order):

1. **CR-PP01 prd-directory-structure** — verify `README.md`, `journeys/`, `features/`,
   `architecture/` all exist.
2. **CR-PP02 id-format-monotonic** — verify Feature IDs are `F-NNN` zero-padded sequential with
   no gaps; Journey IDs follow `J-NNN`; README indexes list IDs in ascending order with no
   duplicates.
3. **CR-PP03 readme-index-complete** — verify every `J-NNN.md` has a README journey-index entry
   and every `F-NNN-slug.md` has a README feature-index entry; no orphan leaves; no stale entries.
4. **CR-PP04 no-tbd-remaining** — grep for literal `TBD`, `TODO`, `FIXME` in all leaf files and
   `README.md`.
5. **CR-PP05 version-chain-integrity** — if `REVISIONS.md` exists, verify every `Previous Version`
   path resolves to a directory on disk; check Baseline section if present (evolve-mode).

Record any script-check findings as `[Critical]` (CR-PP01) or `[Important]` (CR-PP02–05)
violations. If CR-PP01 fails, stop immediately and report the structural failure — dispatching
LLM subagents against a broken bundle is wasteful.

## Step 3 — Dispatch Parallel Review Subagents (LLM-type dimensions)

Dispatch **one round** of subagents covering disjoint file sets, split by artifact class.
Do not dispatch a second review pass for the same files — if a subagent's findings are vague,
MUST route to `--revise` — re-reviewing the same files is FORBIDDEN.

### Dispatch rules

- Group files by artifact class: `features/`, `journeys/`, `architecture/`. Do not mix classes
  within a cluster.
- Each cluster contains **10–15 files** (not the ≤3 used by Fix subagents).
- Every subagent runs only the **per-file** dimensions from `review-checklist.md` — cross-file
  dimensions run in Step 4 on the main agent.
- Read `parallel-dispatch.md` before constructing dispatch — it defines the mandatory dispatch
  rules (single-response parallel emission, `subagent_type`, model tier, cluster sizing, tool
  usage, prompt contract).

### Subagent prompt template

Copy the following into each dispatch, substituting the severity gate from Step 0.5 and the
absolute file paths from Step 1:

```
Review the following PRD files against the per-file review dimensions.

**Severity gate for this pass:** {all | critical_important | critical_only}
Emit ONLY findings at or above this gate. The orchestrator computed this from the prior-pass
count — do not re-derive.

Target files (read each exactly once, in parallel):
- <abs path 1>
- <abs path 2>
- ...

Per-file dimensions to check:
<paste the Per-file rows from review-checklist.md Execution Scope table>

**Convergence Rules — apply BEFORE flagging any finding:**
1. Pass-Count Severity Gate — drop findings below the gate value above.
2. Dimension Saturation Rules (see review-checklist.md → Convergence Rules) — do NOT flag a
   dimension whose saturation condition is met. Specifically: Testability (c) does not require
   per-endpoint p95; Testability (d) does not require enumerating every role×workspace×org
   combination; Testability (h) does not require prescribed fixture shapes; i18n backend tables
   do not require one row per EC.
3. Oscillation detection — read the most recent 2–3 entries' **Themes:** sections from
   REVISIONS.md (always available). If a Theme line records a prior pass adding content you're
   about to flag as violation (or removing content you're about to demand), emit a single
   [Critical] Convergence conflict citing the REVISIONS.md entry date + Theme line, NOT the
   per-dimension finding. Local .reviews/*.applied.md may be consulted as a supplement when
   present.

For each file, report findings in this exact format:

### <relative path from PRD dir>
- [Critical|Important|Suggestion] <Dimension>: <one-line finding>
  Fix: <concrete action>

If a file has no findings, write: ### <path>\n(no issues)

**Dimension names MUST be copied verbatim from review-checklist.md** (e.g.
`i18n per-feature — backend`, not `Backend Internationalization`). Downstream tooling matches
these strings literally to scope delta review.

Rules:
- You MUST read <skill-dir>/review-checklist.md once to load the Convergence Rules and
  dimension definitions.
- You MUST Grep the most recent 2–3 entries of {PRD-dir}/REVISIONS.md for oscillation detection
  (skip if file absent). .reviews/*.applied.md is OPTIONAL supplementary signal — gitignored and
  may be missing.
- Do not Read, Glob, or Grep any files outside the listed target files and review-checklist.md.
- Do not read architecture.md or other feature/journey files for cross-reference — cross-file
  checks are handled separately.
- Write your per-file findings to `{PRD-dir}/.review/round-{N}/subagent-findings/{trace_id}.md`
  using the Write tool. Structure the file with one `### <relative path>` section per reviewed
  file, findings under each heading.
- Your Task return MUST be exactly one ACK line:
  `OK trace_id={trace_id} role=reviewer linked_issues=<comma-list-of-finding-count or empty>`
- FORBIDDEN: returning findings inline in your reply, summarising findings in assistant text,
  or writing any prose outside the findings file. The ACK line is the only text returned.
```

## Step 4 — Cross-File Checks (main agent)

After subagents return, the main agent runs the **cross-file** dimensions from `review-checklist.md`
using:

- The already-read `README.md` + `REVISIONS.md` + `architecture.md` index
- Per-file findings from Step 3 (not the full file contents)
- Targeted reads of specific files only when a cross-file finding requires it (e.g. verifying a
  dependency chain entry)

If verifying a cross-file check requires reading a feature or journey file, read only that single
file — never re-read the whole set.

## Step 5 — Emit Issue Files

After aggregating all findings (script checks from Step 2 + subagent per-file findings from Step 3
+ cross-file findings from Step 4), write one issue file per distinct finding to:

```
{PRD-dir}/.review/round-N/issues/<issue-id>.md
```

where `N` is the current review round (infer from existing `.review/round-*/` directories; start
at 1 if none exist) and `<issue-id>` is a zero-padded sequential ID, e.g. `I-001`, `I-002`.

**Issue file structure:**

```markdown
# Issue <issue-id>

**Severity**: Critical | Important | Suggestion
**Dimension**: <verbatim dimension name from review-checklist.md>
**Scope**: per-file | cross-file
**Affected files**: <comma-separated relative paths>

## Finding

<One-paragraph description of the finding.>

## Fix

<Concrete, actionable fix instruction. Must be specific enough for --revise to execute without
re-reading the finding. Include what to write, not just "reword this".>
```

Requirements for every issue file:

- Every issue MUST have a `Fix:` section with a concrete action. Vague instructions like
  "reword this" are FORBIDDEN — state what to write.
- The dimension name MUST be copied verbatim from `review-checklist.md` — downstream `--revise`
  matches on this string to scope delta review.
- Findings below the severity gate (from Step 0.5) MUST NOT be emitted — filter before writing.

**Not version-controlled.** The `.review/` directory is a transient scratch space consumed by
`--revise`. If `.gitignore` does not yet exclude `.review/`, prompt the user to add the pattern
`docs/raw/prd/*/.review/` after Step 7.

## Step 6 — Present Findings

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
- The top ~10 findings by severity as a table (inline) with a pointer to the issue files at
  `{PRD-dir}/.review/round-N/issues/`.
- Do not dump the full findings table inline for large PRDs — the issue files are the source of
  truth.

## Step 7 — Recommend Next Step

- Issues are minor (wording, missing cross-links): note them for the next revision cycle.
- Issues are significant (missing journeys, orphan features, gaps): recommend `--revise {PRD-dir}`.
  Tell the user the revise command will auto-consume the issue files in Pre-Answered Mode — no
  need to re-enumerate findings.
- Reviewing an older version: note that the latest version should be reviewed instead, unless
  the user explicitly requested this version.

### Compaction Hint

After presenting findings and before the user proceeds to `--revise`, emit this message verbatim:

> **Context compaction recommended**
>
> The review phase has loaded your journey/architecture/feature files into context (~280k tokens).
> If you plan to run `--revise` next, running `/compact` now will let the revise phase start with
> a cleaner context — saves roughly $20–$30 in cache_read costs on a PRD this size.
>
> Run `/compact` to proceed, or skip this if you are not revising this session.

**Skip this message if:**
- No issue files were written (convergence gate aborted in Step 0.5), OR
- Combined Critical + Important finding count is below 5 (revise is unlikely to be worth running
  at that point).

## Prototypes — How to Handle

If `prototypes/` exists, list `prototypes/screenshots/` (directory structure and filenames only).
This covers the three prototype dimensions: alignment uses filenames vs. state machine states,
feedback incorporation uses the `Confirmed` date in each feature's Prototype Reference section,
archival completeness uses screenshot presence per feature as a proxy.

NEVER list or read `prototypes/src/` — source is seed code, not part of the spec. Only read an
individual screenshot file when a state-machine ↔ screenshot mismatch is suspected for a specific
feature and visual confirmation is needed; skip otherwise.
