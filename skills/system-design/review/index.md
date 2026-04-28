# Review Mode — Orchestration (`--review`)

Entry doc for `/cofounder:system-design --review <design-dir>`. **This mode is strictly
read-only** — it reports findings but NEVER modifies any artifact file. All output goes to
`<design-dir>/.reviews/`.

This file is loaded by the orchestrator when mode = `--review`. It is **not** a sub-agent prompt
and does not carry the Snippet D fingerprint.

---

## Distinction from Generate-Mode Review

Two review paths exist in this skill:

| Path | Triggered by | Writes to | Semantics |
|------|-------------|-----------|-----------|
| **--review (this file)** | User running `/cofounder:system-design --review <dir>` | `<design-dir>/.reviews/LINT-<NNN>.md`, `REVIEW-<NNN>.md`, `REVIEW-SUMMARY-<ISO-ts>.md` | End-user review of an existing design. Finds stay in `.reviews/`; never renamed `.applied.md`. |
| **Generate-mode internal review** | `generate/from-scratch.md` Step 10 / `generate/new-version.md` Step 11 | `<design-dir>/.review/round-<N>/issues/<issue-id>.md` | In-pipeline review inside a generate loop. Writes per-issue files per skill-forge harness convention; judge drives convergence. |

Never conflate these two paths. The `.reviews/` directory (user-facing, with capital S) is distinct
from `.review/` (internal harness, no capital S).

---

## Step Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

On failure (non-zero exit): skill exits immediately. Do NOT enter any review phase.

### Step 2 — Inventory Pre-Scan

Read only:

- `<design-dir>/README.md`
- `<design-dir>/REVISIONS.md` (if present)

Then enumerate via `Glob`:

- `<design-dir>/modules/M-*.md`
- `<design-dir>/api/API-*.md` (if `api/` directory exists)

Record file lists for lint fan-out and reviewer dispatch. Also scan the parent directory for
sibling design directories with the same product slug (the portion after `YYYY-MM-DD-`). If
multiple versions exist, record version context (position, latest path, REVISIONS.md chain
integrity) for presentation in Step 7.

### Step 3 — Lint Pre-Pass (Phase 1: Script Output)

```bash
scripts/run-checkers.sh <design-dir>/
```

The script runs all **per-file structural checks** (CR-L1..CR-L5) and all **cross-file structural
checks** (CR-X1..CR-X8) against the design directory. For each failure it emits a finding. The
orchestrator collects all findings and writes them to:

```
<design-dir>/.reviews/LINT-<NNN>.md
```

where `<NNN>` is a zero-padded sequence number (001, 002, …) incremented per run. Create the
`.reviews/` directory if absent.

**LINT file lifecycle in --review mode:** review is read-only, so the LINT file stays in
`.reviews/` unrenamed. The `.applied.md` rename NEVER happens in --review — it only happens when
`--revise` or generate-mode's lint-fix step consumes the file. The next `--review` run writes a
new `LINT-<NNN>.md`; prior LINT files are superseded but kept for traceability.

**Effect on Phase 2 (Step 4):** include the LINT file path in every review subagent prompt and
instruct them to skip per-file dimensions already fully covered by a matching lint check ID.
Semantic dimensions (Implementability, Risk awareness, Self-containment, Testability,
Frontend performance, Backend i18n coverage, Form implementation consistency) are always run
regardless of lint results — they require judgment that scripts cannot perform.

**Do NOT block on lint findings.** Unlike generate-mode's two-phase quality gate (which halts
semantic review on critical script errors), --review mode always proceeds to Step 4. The user
receives both the LINT report and the semantic REVIEW in one pass.

### Step 4 — Reviewer Dispatch (Phase 2: Parallel LLM Review)

Dispatch **cross-reviewer** and **adversarial-reviewer** in parallel. Both perform a **forced full
review** — do NOT apply any skip-set. Every leaf in the design directory is in scope.

#### 4a — Cross-Reviewer

- **Dispatches**: `review/cross-reviewer-subagent.md`
- **Sub-agent type**: `general-purpose`; **model**: `sonnet` (tier alias — do not pin a version)
- **Sub-agent inputs**:
  - Absolute paths to all `modules/M-*.md` and `api/API-*.md` files (no globs)
  - `<design-dir>/README.md`
  - LINT file path from Step 3
  - `common/review-criteria.md` (CR-L01..CR-L11 and CR-X1..CR-X8 semantic sides)
- **Sub-agent outputs**: one `REVIEW-<NNN>.md` file per finding cluster written to
  `<design-dir>/.reviews/`
- **Filter rule**: sub-agent MUST NOT report findings that are already declared in the LINT file
  (mechanical/script-type). Semantic findings only.

#### 4b — Adversarial-Reviewer

- **Dispatches**: `review/adversarial-reviewer-subagent.md`
- **Sub-agent type**: `general-purpose`; **model**: `sonnet`
- **Sub-agent inputs**: same as 4a
- **Sub-agent outputs**: one `REVIEW-<NNN>-ADV.md` file per finding cluster written to
  `<design-dir>/.reviews/`
- **Filter rule**: same — no re-reporting of lint-declared mechanical findings

REVIEW file naming: `REVIEW-001.md`, `REVIEW-002.md`, … for cross-reviewer; `REVIEW-001-ADV.md`,
`REVIEW-002-ADV.md`, … for adversarial. Sequence numbers are shared (i.e. if cross-reviewer
writes `REVIEW-001.md` and `REVIEW-002.md`, adversarial writes `REVIEW-003-ADV.md`).

**REVIEW file lifecycle in --review mode:** REVIEW files stay in `.reviews/` unrenamed. The
`.applied.md` rename only happens when `--revise` consumes and closes an issue. Users can
periodically clean `.reviews/` — the directory is not version-controlled.

### Step 5 — Summarizer

After both reviewers return, the orchestrator writes:

```
<design-dir>/.reviews/REVIEW-SUMMARY-<YYYYMMDD-HHMMSS>.md
```

**Summary file structure:**

```markdown
# Design Review Summary — {ISO timestamp}

Reviewed: {absolute path of design directory}
Reviewer: claude (system-design --review)
Version context: {from Step 2; omit if no sibling versions found}

## Counts

| Category            | Count |
|---------------------|-------|
| Mechanical (LINT)   | N     |
| Semantic Critical   | N     |
| Semantic Important  | N     |
| Suggestion          | N     |

## LINT File

{absolute path to LINT-<NNN>.md}

## Semantic Review Files

- {absolute path to REVIEW-001.md} — cross-reviewer
- {absolute path to REVIEW-003-ADV.md} — adversarial
- ...

## Top Findings (by severity)

| Sev | Source | File | Dimension | Finding |
|-----|--------|------|-----------|---------|
| Critical | cross | modules/M-003-auth.md | Self-containment | ... |
| Critical | adv | modules/M-007-billing.md | Implementability | ... |
| ...top ~10... |

## Recommended Next Step

{see Step 6 — populated by orchestrator}
```

### Step 6 — Recommend Next Step

Evaluate findings and populate the Recommended Next Step section of the summary:

- **Mechanical (LINT) blockers present** — recommend `--revise <design-dir>`. Revise-mode
  Pre-Answered Mode regenerates its own structural-lint report (it does not read the --review
  LINT file directly) and fixes every mechanical gap in batch before Fix subagents touch semantic
  issues. The LINT artifact is regenerated so it always reflects current state.
- **Semantic Critical findings present** — recommend `--revise <design-dir>`. Tell the user the
  revise command auto-consumes the latest `.reviews/REVIEW-*.md` files in Pre-Answered Mode.
- **Only Suggestions / minor Important findings** — note them for the next revision cycle;
  `--revise` is optional.
- **Reviewing an older version** (detected in Step 2) — note that the latest version should be
  reviewed instead, unless the user explicitly requested this version.

### Step 7 — Print to User

```
Version context (if multiple versions detected):
  Reviewing: {path} ({position, e.g. v1 of 2})
  Latest:    {path of latest}
  Chain:     {REVISIONS.md chain integrity}
  ⚠ You are reviewing an older version.    ← only if not latest

{N} mechanical findings (LINT)  ·  {M} semantic findings  ({K} Critical, {J} Important, {P} Suggestions)

LINT report:  {absolute path to LINT-<NNN>.md}
Full review:  {absolute path to REVIEW-SUMMARY-<ts>.md}

Top findings:
{inline table of top ~10 by severity — group by theme: completeness, consistency,
implementability, risk, testability. Lead with Critical, then Important, then Suggestions.
Do not dump the full findings table inline for large designs — the file is the source of truth.}

Next step:  {recommendation from Step 6}
Run `/cofounder:system-design --revise <design-dir>` to apply fixes.
```

**Hard rule:** --review MUST NOT auto-chain into --revise. Exit after printing to user. The
operator advances the lifecycle by invoking the next flag.

---

## Output Path Reference

| Artifact | Path |
|----------|------|
| Mechanical findings | `<design-dir>/.reviews/LINT-<NNN>.md` |
| Cross-reviewer findings | `<design-dir>/.reviews/REVIEW-<NNN>.md` |
| Adversarial findings | `<design-dir>/.reviews/REVIEW-<NNN>-ADV.md` |
| Run summary + index | `<design-dir>/.reviews/REVIEW-SUMMARY-<YYYYMMDD-HHMMSS>.md` |

`.reviews/` is transient and not version-controlled. Add `docs/raw/design/*/.reviews/` to
`.gitignore`. Durable audit history belongs in `REVISIONS.md` (appended by `--revise`
post-change), not in raw review dumps.

---

## Files in This Directory

- [cross-reviewer-subagent.md](cross-reviewer-subagent.md) — Cross-reviewer sub-agent prompt
  (per-file + cross-file semantic dimensions from `common/review-criteria.md`)
- [adversarial-reviewer-subagent.md](adversarial-reviewer-subagent.md) — Adversarial-reviewer
  sub-agent prompt (attack-angle review: interface gaps, dependency leaks, coverage blind spots)
