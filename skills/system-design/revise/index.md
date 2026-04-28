# Revise Mode — Orchestration (`--revise`)

Entry doc for `/cofounder:system-design --revise <design-dir>`. Consumes the newest unapplied
REVIEW-*.md and LINT-*.md from `<design-dir>/.reviews/`, dispatches per-issue revisers, re-runs
structural lint, summarizer appends REVISIONS.md, then renames applied issue files via `git mv`.

This file is loaded by the orchestrator when mode = `--revise`. It is **not** a sub-agent prompt
and does not carry the Snippet D fingerprint.

---

## Step Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

On failure (non-zero exit): skill exits immediately. Do NOT enter the revise phase.

### Step 2 — Inventory `<design-dir>/.reviews/`

Enumerate the directory with `Glob` or `Bash ls`:

- Collect all `REVIEW-*.md` files that do NOT end in `.applied.md` — these are open semantic
  findings from `--review` (cross-reviewer + adversarial).
- Collect all `LINT-*.md` files that do NOT end in `.applied.md` — these are open mechanical
  findings from the structural-lint pre-pass.

If `.reviews/` does not exist or is empty of unapplied files: print
`No open issues found in <design-dir>/.reviews/. Run --review first.` and exit.

### Step 3 — Lint Pre-Pass Gate

Re-run structural lint unconditionally before dispatching any LLM reviser:

```bash
scripts/run-checkers.sh <design-dir>/
```

If the script surfaces new mechanical findings not already represented by an open LINT-*.md in
scope, write a fresh `<design-dir>/.reviews/LINT-<NNN>.md` and add it to the open issue list from
Step 2. This preserves the legacy `revise-mode.md` Step 7.0 gate: **do NOT dispatch LLM revisers
until every blocker-severity LINT finding has a corresponding open LINT-*.md issue file in scope.**

Non-blocker mechanical findings may be batched with the LLM reviser fan-out. Blocker findings must
be resolved first — dispatch a Fix subagent (per-issue reviser) for each blocker LINT file, confirm
fix, then re-run lint before proceeding.

### Step 4 — Per-Issue Reviser Fan-Out (parallel)

Group all open issues — both REVIEW-*.md (semantic) and LINT-*.md (mechanical) — by their target
file. Each unique target file gets one reviser dispatch. Revisers run in parallel (they are scoped
to non-overlapping leaf files).

**Hard rule — scope containment:** each reviser opens ONLY the files named in its issue. It MUST
NOT widen scope to adjacent modules or unrelated sections. Lateral edits are a reviser protocol
violation.

Dispatch `revise/per-issue-reviser-subagent.md` for each group:

```
Dispatch N parallel reviser instances. Each handles ONE issue file targeting ONE artifact leaf.
```

Per-reviser inputs:
- The issue file (REVIEW-*.md or LINT-*.md) — exactly the one this reviser owns.
- The current artifact leaf path(s) named in the issue.
- Resolved-issues history up to `config.yml regression_gate.max_injected_resolved` (default: 20).

Per-reviser outputs:
- Revised artifact leaf written in-place at `<design-dir>/<leaf-path>`.
- One REVISIONS.md append entry (create `<design-dir>/REVISIONS.md` if absent, using
  `common/templates/revision-entry-template.md`).

**Orchestrator action on all ACKs:** collect `linked_issues` fields from every reviser ACK; update
`state.yml`; proceed to Step 5.

**Multi-issue REVISIONS.md:** all issues closed in this `--revise` invocation map to a single
REVISIONS.md entry. The orchestrator instructs the last reviser (or a summarizer) to write the
consolidated entry; each individual reviser writes a placeholder that the summarizer merges.

### Step 5 — Lint Post-Pass Verification

After all revisers return, re-run structural lint:

```bash
scripts/run-checkers.sh <design-dir>/
```

For each issue that had a corresponding LINT-*.md: confirm the check passes on the revised
artifact. Any newly surfaced finding that was not present in Step 3 output = write a new
`<design-dir>/.reviews/LINT-<NNN>.md` and loop back to Step 4 for the new findings only. Cap
this loop at `config.yml convergence.max_iterations` to avoid infinite cycling.

If post-pass is clean: proceed to Step 6.

### Step 6 — Summarizer: Finalize REVISIONS.md Entry

Dispatch `shared/summarizer-subagent.md` (update-status phase):

- Confirm a REVISIONS.md entry is present for this `--revise` invocation.
- Count modules and API files touched across all reviser ACKs.
- Merge per-reviser placeholder entries into one consolidated REVISIONS.md entry.
- Record: date, source issue IDs (all REVIEW-* and LINT-* consumed), modules touched, summary of
  changes, change type (`In-place edit`).

Summarizer MUST NOT read artifact leaf content — consume only reviser ACK fields and the placeholder
REVISIONS.md lines.

**Orchestrator action on ACK:** proceed to Step 7.

### Step 7 — Rename Applied Issue Files

For each issue file (REVIEW-*.md or LINT-*.md) whose linked issues are fully resolved, rename it
to `*.applied.md` via git-tracked move:

```bash
git mv <design-dir>/.reviews/REVIEW-007.md <design-dir>/.reviews/REVIEW-007.applied.md
git mv <design-dir>/.reviews/LINT-003.md   <design-dir>/.reviews/LINT-003.applied.md
```

**Important:** `.applied.md` rename happens HERE (in `--revise`), NOT in `--review`. The `--review`
mode never renames files — it only produces new findings. The rename marks an issue as consumed and
prevents it from being re-applied on subsequent `--revise` invocations.

Partially-resolved issues (where the reviser reported `anchor not found` or `file not found`):
leave the original filename unchanged so the next `--revise` picks it up.

### Step 8 — Print to User

```
<N> issues applied, <M> modules touched.
REVISIONS.md updated: <design-dir>/REVISIONS.md

Run `/cofounder:system-design --review <design-dir>` to verify.
```

Where `<N>` = count of issue files successfully renamed to `.applied.md`, and `<M>` = count of
distinct module/API leaf files written by revisers this invocation.

---

## Hard Rules

- `--revise` MUST NOT widen issue scope. A reviser for REVIEW-007.md opens only the files
  named in that issue file. Cross-file blast radius is prohibited.
- `--revise` MUST NOT auto-chain into `--review`. Exit after Step 8. The operator advances the
  lifecycle by invoking `/cofounder:system-design --review <design-dir>` explicitly.
- `.applied.md` rename ONLY happens here — never in `--review` or in generate-mode's internal
  review loop (which uses a separate `.review/` harness directory, not `.reviews/`).
- All revisers run on `model: sonnet` (balanced tier). Do not escalate to opus unless an issue
  is explicitly tagged as requiring cross-module design judgment.

---

## Output Path Reference

| Artifact | Path |
|----------|------|
| Revised module/API leaves | `<design-dir>/modules/M-NNN-{slug}.md` or `<design-dir>/api/API-NNN.md` |
| Revised README | `<design-dir>/README.md` (only if issue targets it) |
| Revision history | `<design-dir>/REVISIONS.md` (appended each `--revise` run) |
| Applied REVIEW files | `<design-dir>/.reviews/REVIEW-*.applied.md` |
| Applied LINT files | `<design-dir>/.reviews/LINT-*.applied.md` |
| New LINT findings (if loop) | `<design-dir>/.reviews/LINT-<NNN>.md` |

`.reviews/` is transient and not version-controlled. Add `docs/raw/design/*/.reviews/` to
`.gitignore`. Durable history belongs in `REVISIONS.md`, not in raw review dumps.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) — Per-issue reviser sub-agent
  prompt (one dispatch per target artifact leaf; reads ONE issue, applies minimal fix in-place)
