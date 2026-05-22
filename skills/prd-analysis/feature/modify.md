# feature/modify.md — Single-Feature Modify Orchestration

Loaded by the orchestrator when `modify <prd-dir> F-NNN "description"` is provided.
Modifies a single feature file in-place, updates the README index row, and appends
CHANGELOG. Other feature files are NOT read, NOT modified.

This is a **lightweight** operation — no planner dispatch, no questioning phases,
no review loop. The writer self-audits with `check-feature.sh` as the sole quality gate.

## Contract

- **Scope:** exactly one feature file + one README index row + one CHANGELOG entry
- **Concurrency-safe:** no file locking needed — the orchestrator modifies only files
  owned by the target feature (the feature file, its README row, and CHANGELOG).
  Concurrent `modify` operations for different features write to disjoint README rows.
- **No regression:** other feature files are never opened. `git diff` after a modify
  MUST show changes only to: `features/F-NNN-*.md`, `README.md`, `CHANGELOG.md`.

## Orchestration Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

### Step 2 — Locate the target feature file

Read the PRD README to find the feature file path for the given F-ID.
The README Feature Index contains rows like:

```
| F-001 | Auth | features/F-001-auth.md | P0 | M | active |
```

Extract the file path column. If the F-ID is not found, exit with error:

> F-{NNN} not found in PRD at {prd-dir}. Available features: {list from README index}.

### Step 3 — Dispatch writer to modify the feature file

- Dispatch: `generate/writer-subagent.md`
- Role: `writer`
- Inputs: the existing feature file content + the user's change description
- The writer prompt must instruct the writer to:
  1. Read the existing feature file
  2. Apply the change described by the user
  3. Preserve the existing frontmatter (`id`, `title`, `status`) and ID
  4. Self-audit with `scripts/check-feature.sh features/F-NNN-*.md`
  5. Return the modified file content

The writer uses the same template (`common/templates/feature-template.md`) as a full
generation, but starts from the existing file content and only modifies sections
affected by the change description.

### Step 4 — Update README index row

Read `README.md`. Find the Feature Index table row for F-NNN. Update the row:
- If the feature's name, priority, or effort changed in the modified file, reflect those
  changes in the table row.
- If the feature is unchanged structurally, leave the row as-is (the file is the same).

The orchestrator performs this as a mechanical edit — search for the table row
containing `F-{NNN}` and replace it with the updated values. Do NOT dispatch a
sub-agent for this step.

### Step 5 — Append CHANGELOG

Append a new entry to `CHANGELOG.md` (create the file if it doesn't exist). Format:

```markdown
## {YYYY-MM-DD}

### F-{NNN}: {Feature Name} — modified
- **What:** {concise description of what changed}
- **Why:** {extracted from user's change description}
- **Breaks:** {N/A or list of affected feature IDs}
```

Generate the "What" and "Breaks" from the writer's output. The "Why" is the user's
change description verbatim.

### Step 6 — Commit

Commit with message: `feat(prd): modify F-{NNN} — {short summary}`

### Step 7 — Report

Output a concise summary to the user:

```
F-{NNN} modified: {prd-dir}/features/F-{NNN}-{slug}.md

Changes: {one-line summary from writer}
Next: /system-design delta F-{NNN}  (to compute affected modules)
```

## FORBIDDEN

- Reading other feature files (F-YYY where YYY ≠ NNN)
- Dispatching a planner or running questioning phases
- Entering the review loop
- Modifying architecture topic files
- Modifying journey files
- Modifying any file outside `features/F-{NNN}-*.md`, `README.md`, and `CHANGELOG.md`
