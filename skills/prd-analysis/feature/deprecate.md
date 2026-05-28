# feature/deprecate.md — Single-Feature Deprecate Orchestration

Loaded by the orchestrator when `deprecate <prd-dir> F-NNN ["reason"]` is provided.
Creates a tombstone file for the deprecated feature, updates the README index
(move from active index to Deprecated Items), and appends CHANGELOG.

This is a **pure mechanical** operation — no writer dispatch, no AI generation needed.
The orchestrator handles all steps directly.

## Contract

- **Scope:** one tombstone file + one README update (remove from Feature Index/Roadmap,
  add to Deprecated Items) + one CHANGELOG entry
- **No regression:** other feature files are never opened.

## Tombstone Format

Per `generate/evolve-mode.md` Tombstone Semantics:

```markdown
# F-{NNN}: {Feature Name} — DEPRECATED

| Field | Value |
|-------|-------|
| Status | **Deprecated** |
| Deprecated in | {YYYY-MM-DD PRD directory name} |
| Reason | {user-provided reason, or "No reason provided"} |
| Replacement | None — capability removed |
| Original | [F-{NNN} in {prd-dir-name}](features/F-{NNN}-{slug}.md) |
```

## Orchestration Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

### Step 2 — Locate the target feature file

Read the PRD README to find the feature file path and name for the given F-ID.
If the F-ID is not found in the Feature Index, exit with error:

> F-{NNN} not found in PRD at {prd-dir}.

If the F-ID is already in the Deprecated Items list, exit with error:

> F-{NNN} is already deprecated.

### Step 3 — Read the feature file for metadata

**Permitted read:** the orchestrator reads only the first ~20 lines (header + frontmatter)
of the target feature file to extract metadata needed for tombstone construction
(feature name, file slug). This is a mechanical metadata extraction, not content
comprehension — consistent with the SKILL.md exception for "cross-file routing check
requires spot-verification" applied to artifact leaves. No other feature file content
is read.

Extract:
- Feature name (from the `# F-{NNN}: {Name}` header)
- File slug (from the existing filename)

### Step 4 — Create tombstone file

Overwrite the feature file at `features/F-{NNN}-{slug}.md` with the tombstone content
using the format above. The tombstone replaces the feature file at the same path
so directory listings remain stable.

### Step 5 — Update README

Two mechanical edits to `README.md`:

**5a. Remove from Feature Index:** Delete the table row containing `F-{NNN}`.

**5b. Remove from Roadmap (if present):** If the Roadmap section has a row containing
`F-{NNN}`, delete it.

**5c. Add to Deprecated Items:** If the Deprecated Items section exists, append a row:

```
| F-{NNN} | {Feature Name} | {reason summary} | N/A |
```

If the Deprecated Items section does not exist, create it before the Roadmap section:

```markdown
## Deprecated Items

| ID | Name | Reason | Replaced by |
|----|------|--------|-------------|
| F-{NNN} | {Feature Name} | {reason} | N/A |
```

### Step 6 — Cascade check

Scan the README for any other feature's Depends-on that references F-{NNN}.
If found, warn the user:

> F-{NNN} is deprecated but is listed as a dependency by F-{YYY}. F-{YYY}
> may need to be updated. Run `/prd-analysis modify <prd-dir> F-{YYY} "remove F-{NNN} dependency"`.

Do NOT automatically modify other features — only report the warning.

### Step 7 — Append CHANGELOG

Append to `CHANGELOG.md`:

```markdown
## {YYYY-MM-DD}

### F-{NNN}: {Feature Name} — deprecated
- **What:** Feature deprecated
- **Why:** {user-provided reason}
- **Breaks:** {list of features that depend on F-{NNN}, or N/A}
```

### Step 8 — Commit

Commit with message: `feat(prd): deprecate F-{NNN} — {feature name}`

### Step 9 — Report

Output a concise summary:

```
F-{NNN} deprecated.
Tombstone: {prd-dir}/features/F-{NNN}-{slug}.md
Dependents to update: {list, or "none"}

Next: review dependents and update them individually, then run
  /system-design delta to propagate module impacts if needed.
```

## FORBIDDEN

- Modifying other feature files
- Dispatching a sub-agent (this is pure mechanical)
- Silently modifying dependent features
