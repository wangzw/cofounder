# Revise Mode — Orchestration (`--revise`)

Entry doc for `/cofounder:system-design --revise <design-dir>`. Reads open issues from
`<design-dir>/.review/round-<N>/issues/`, dispatches per-issue revisers, re-runs structural
lint, summarizer updates issue status and appends REVISIONS.md.

This file is loaded by the orchestrator when mode = `--revise`. It is **not** a sub-agent prompt
and does not carry the Snippet D fingerprint.

---

## Step Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

On failure (non-zero exit): skill exits immediately. Do NOT enter the revise phase.

### Step 2 — Determine Latest Round and Read Open Issues

Read `<design-dir>/.review/state.yml` to get `last_round` → N.

If `state.yml` does not exist or `.review/round-<N>/issues/` is empty or does not exist: print
`No open issues found. Run --review first.` and exit.

Enumerate `<design-dir>/.review/round-<N>/issues/` via `Glob`:

- Collect all `*.md` issue files whose frontmatter `status` field is one of: `new`, `persistent`,
  `regressed`. Skip issues with `status: resolved` or `status: wont_fix`.

If no open issues after filtering: print `All issues in round <N> are resolved.` and exit.

### Step 3 — Structural-Lint Gate

Re-run structural lint unconditionally before dispatching any LLM reviser:

```bash
scripts/run-checkers.sh <design-dir>/ round-<N>
```

New script-tier issues are written to `<design-dir>/.review/round-<N>/issues/` and added to the
open issue list from Step 2. **Do NOT dispatch LLM revisers until every blocker-severity lint
finding has been triaged.** Blocker findings must be resolved first — dispatch a Fix subagent
(per-issue reviser) for each blocker, confirm fix, then re-run lint before proceeding with
semantic issues.

Non-blocker mechanical findings may be batched with the LLM reviser fan-out.

### Step 4 — Per-Issue Reviser Fan-Out (parallel)

Group all open issues by their `file` frontmatter field. Each unique target file gets one reviser
dispatch. Revisers run in parallel (scoped to non-overlapping leaf files).

**Hard rule — scope containment:** each reviser opens ONLY the files named in its issue. It MUST
NOT widen scope to adjacent modules or unrelated sections. Lateral edits are a reviser protocol
violation.

Dispatch `revise/per-issue-reviser-subagent.md` for each group:

Per-reviser inputs:
- The issue file path (from `<design-dir>/.review/round-<N>/issues/<issue-id>.md`)
- The current artifact leaf path(s) named in the issue's `file` field
- Resolved-issues history (up to 20 most recent resolved issues from this round for regression context)

Per-reviser outputs:
- Revised artifact leaf written in-place at `<design-dir>/<leaf-path>`
- ACK with `linked_issues` list

**Orchestrator action on all ACKs:** collect `linked_issues` fields from every reviser ACK; proceed to Step 5.

### Step 5 — Structural-Lint Post-Pass

After all revisers return, re-run structural lint:

```bash
scripts/run-checkers.sh <design-dir>/ round-<N>
```

Any new issue that was NOT present before revisers ran = regression. Write a new issue file to
`<design-dir>/.review/round-<N>/issues/` and loop back to Step 4 for the new findings only.
Cap the loop at `config.yml convergence.max_iterations` (default: 3) to avoid infinite cycling.

If post-pass is clean: proceed to Step 6.

### Step 6 — Summarizer: Update Issue Status and Finalize REVISIONS.md

Dispatch `shared/summarizer-subagent.md` (update-status phase):

- For each issue whose `linked_issues` appears in a reviser ACK: update its frontmatter
  `status: resolved` in `<design-dir>/.review/round-<N>/issues/<issue-id>.md`.
- Count modules and API files touched across all reviser ACKs.
- Write or append `<design-dir>/REVISIONS.md` (create if absent, using
  `common/templates/revision-entry-template.md`). Record: date, source issue IDs (all resolved
  issue IDs from this `--revise` run), modules touched, summary of changes, change type
  (`In-place edit`).

Summarizer MUST NOT read artifact leaf content — consume only reviser ACK fields and issue
frontmatter.

**Orchestrator action on ACK:** update `.review/state.yml` with `last_revise_round: <N>`;
proceed to Step 7.

### Step 7 — Print to User

```
<N> issues resolved, <M> modules touched.
REVISIONS.md updated: <design-dir>/REVISIONS.md

Run `/cofounder:system-design --review <design-dir>` to verify.
```

Where `<N>` = count of issues whose status was updated to `resolved` this invocation,
and `<M>` = count of distinct module/API leaf files written by revisers.

---

## Hard Rules

- `--revise` MUST NOT widen issue scope. A reviser for one issue file opens only the files named
  in that issue. Cross-file blast radius is prohibited.
- `--revise` MUST NOT auto-chain into `--review`. Exit after Step 7. The operator advances the
  lifecycle by invoking `/cofounder:system-design --review <design-dir>` explicitly.
- Issue status updates (`status: resolved`) happen in the summarizer step — NOT in individual
  revisers. Revisers only fix artifacts; the orchestrator/summarizer marks issues done.
- All revisers run on `model: sonnet` (balanced tier). Do not escalate to opus unless an issue
  is explicitly tagged as requiring cross-module design judgment.

---

## Output Path Reference

| Artifact | Path |
|----------|------|
| Revised module/API leaves | `<design-dir>/modules/M-NNN-{slug}.md` or `<design-dir>/api/API-NNN.md` |
| Revised README | `<design-dir>/README.md` (only if issue targets it) |
| Revision history | `<design-dir>/REVISIONS.md` (appended each `--revise` run) |
| Issue status updates | `<design-dir>/.review/round-<N>/issues/<issue-id>.md` (frontmatter `status: resolved`) |

`.review/` is transient and not version-controlled. Add `docs/raw/design/*/.review/` to
`.gitignore`. Durable history belongs in `REVISIONS.md`, not in raw review files.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) — Per-issue reviser sub-agent
  prompt (one dispatch per target artifact leaf; reads ONE issue, applies minimal fix in-place)
