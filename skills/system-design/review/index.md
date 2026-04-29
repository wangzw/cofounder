# Review Mode — Orchestration (`--review`)

Entry doc for `/cofounder:system-design --review <design-dir>`. **This mode is strictly
read-only** — it reports findings but NEVER modifies any artifact file. All output goes to
`<design-dir>/.review/round-<N>/issues/`.

This file is loaded by the orchestrator when mode = `--review`. It is **not** a sub-agent prompt
and does not carry the Snippet D fingerprint.

---

## Step Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

On failure (non-zero exit): skill exits immediately. Do NOT enter any review phase.

### Step 2 — Bootstrap: Determine Round Number

Read `<design-dir>/.review/state.yml`:

- If the file exists, read `last_round` → N = last_round + 1.
- If the file does not exist, create it with `last_round: 0` → N = 1.

Create directory: `<design-dir>/.review/round-<N>/issues/`

During Bootstrap, orchestrator MUST write `skill-root: <absolute path to this skill's root directory>` to `<design-dir>/.review/state.yml` so downstream sub-agents can locate this skill's own scripts. Also write `last_round: <N>`.

### Step 3 — Inventory Pre-Scan

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

### Step 4 — Structural-Lint Pre-Pass

```bash
scripts/run-checkers.sh <design-dir>/ round-<N>
```

The script runs all per-file structural checks (CR-L1..CR-L5) and all cross-file structural
checks (CR-X1..CR-X8). For each failure it writes an issue file to:

```
<design-dir>/.review/round-<N>/issues/R<N>-<seq>.md
```

**Exit on critical/error findings:** if `run-checkers.sh` exits non-zero and any issue has
`severity: blocker` or `severity: error`, stop here. Print the lint findings to the user and
recommend fixing them with `--revise` before re-running `--review`. Do NOT proceed to Step 5.

**Semantic dimensions** (Implementability, Risk awareness, Self-containment, Testability,
Frontend performance, Backend i18n coverage, Form implementation consistency) are always run
regardless of lint results — they require judgment that scripts cannot perform. Once lint is
clean, proceed to Step 5.

### Step 5 — Reviewer Dispatch (Parallel LLM Review)

Dispatch **cross-reviewer** and **adversarial-reviewer** in parallel. Both perform a **forced
full review** — do NOT apply any skip-set. Every leaf in the design directory is in scope.

#### 5a — Cross-Reviewer

- **Dispatches**: `review/cross-reviewer-subagent.md`
- **Sub-agent type**: `general-purpose`; **model**: `opus`
- **Sub-agent inputs**:
  - Absolute paths to all `modules/M-*.md` and `api/API-*.md` files (no globs)
  - `<design-dir>/README.md`
  - Lint issue paths from Step 4 (if any non-blocker lint issues remain)
  - `common/review-criteria.md` (CR-L01..CR-L11 and CR-X1..CR-X8 semantic sides)
  - Round number N and target issue directory: `<design-dir>/.review/round-<N>/issues/`
- **Sub-agent outputs**: issue files written to `<design-dir>/.review/round-<N>/issues/<issue-id>.md`
  Issue IDs: `R<N>-V-<seq>` (zero-padded 3 digits, continuing from highest existing seq in `round-<N>/issues/`)
- **Filter rule**: sub-agent MUST NOT report findings already declared by lint (mechanical/script-type). Semantic findings only.

#### 5b — Adversarial-Reviewer

- **Dispatches**: `review/adversarial-reviewer-subagent.md`
- **Sub-agent type**: `general-purpose`; **model**: `opus`
- **Sub-agent inputs**: same as 5a
- **Sub-agent outputs**: issue files written to `<design-dir>/.review/round-<N>/issues/<issue-id>.md`
  Issue IDs: `R<N>-V-<seq>-ADV` (continuing sequence from cross-reviewer output)
- **Filter rule**: same — no re-reporting of lint-declared mechanical findings

### Step 6 — Summarizer

After both reviewers return, dispatch `shared/summarizer-subagent.md` (if present) or
synthesize counts directly:

- Count issues by severity: `blocker`, `error`, `warning`, `suggestion`
- Count by source: `script` (from run-checkers.sh), `cross` (cross-reviewer), `adversarial`
- Write `<design-dir>/.review/round-<N>/verdict.yml`:

```yaml
round: <N>
status: reviewed        # always "reviewed" for --review mode (no judge convergence loop)
reviewed_at: <ISO-8601>
counts:
  total: N
  by_severity:
    blocker: N
    error: N
    warning: N
    suggestion: N
  by_source:
    script: N
    cross: N
    adversarial: N
issues_dir: .review/round-<N>/issues/
```

### Step 7 — Recommend Next Step

Evaluate findings and determine the recommendation:

- **Blocker/error findings present** — recommend `--revise <design-dir>`.
- **Only suggestion/warning findings** — note them; `--revise` is optional.
- **Reviewing an older version** (detected in Step 3) — note that the latest version should be reviewed instead, unless the user explicitly requested this version.

### Step 8 — Print to User

```
Version context (if multiple versions detected):
  Reviewing: {path} ({position, e.g. v1 of 2})
  Latest:    {path of latest}
  Chain:     {REVISIONS.md chain integrity}
  ⚠ You are reviewing an older version.    ← only if not latest

Round <N>: {blocker} blocker · {error} error · {warning} warning · {suggestion} suggestion

Issue files: <design-dir>/.review/round-<N>/issues/
Verdict:     <design-dir>/.review/round-<N>/verdict.yml

Top findings:
{inline table of top ~10 by severity — group by theme: completeness, consistency,
implementability, risk, testability. Lead with blockers/errors, then warnings, then suggestions.
Do not dump the full findings table inline for large designs — the issue files are the source of truth.}

Next step:  {recommendation from Step 7}
Run `/cofounder:system-design --revise <design-dir>` to apply fixes.
```

**Hard rule:** `--review` MUST NOT auto-chain into `--revise`. Exit after printing to user. The
operator advances the lifecycle by invoking the next flag.

---

## Output Path Reference

| Artifact | Path |
|----------|------|
| Mechanical findings | `<design-dir>/.review/round-<N>/issues/R<N>-<seq>.md` |
| Cross-reviewer findings | `<design-dir>/.review/round-<N>/issues/R<N>-V-<seq>.md` |
| Adversarial findings | `<design-dir>/.review/round-<N>/issues/R<N>-V-<seq>-ADV.md` |
| Round verdict | `<design-dir>/.review/round-<N>/verdict.yml` |
| Harness state | `<design-dir>/.review/state.yml` |

`.review/` is transient and not version-controlled. Add `docs/raw/design/*/.review/` to
`.gitignore`. Durable audit history belongs in `REVISIONS.md` (appended by `--revise`
post-change), not in raw review files.

---

## Files in This Directory

- [cross-reviewer-subagent.md](cross-reviewer-subagent.md) — Cross-reviewer sub-agent prompt
  (per-file + cross-file semantic dimensions from `common/review-criteria.md`)
- [adversarial-reviewer-subagent.md](adversarial-reviewer-subagent.md) — Adversarial-reviewer
  sub-agent prompt (attack-angle review: interface gaps, dependency leaks, coverage blind spots)
