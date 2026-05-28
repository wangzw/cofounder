# feature/add.md — Single-Feature Add Orchestration

Loaded by the orchestrator when `add <prd-dir> "description"` is provided.
Creates a single new feature file with the next available ID, updates the README
index, and appends CHANGELOG.

Same lightweight contract as `modify` — no planner, no questioning phases, no review loop.

## Contract

- **Scope:** exactly one new feature file + one README index row + one CHANGELOG entry
- **ID assignment:** next available ID = `max(existing feature IDs) + 1`. Gaps from
  deprecated features are NOT filled (per ID Stability Contract).
- **No regression:** existing feature files are never opened.

## Orchestration Sequence

### Step 1 — Git Precheck

```bash
scripts/git-precheck.sh
```

### Step 2 — Determine next available ID

Read `README.md` Feature Index table to find the current max F-ID.
Compute `next_id = max + 1` (zero-padded, e.g. "F-005").
If the PRD has no features yet, start at `F-001`.

### Step 3 — Dispatch writer to create the feature file

- Dispatch: `generate/writer-subagent.md`
- Role: `writer`
- Inputs: the user's description + the assigned ID + the PRD context
  (READ the PRD README for product context, data models, design tokens,
  existing conventions — these are needed for self-contained inline copying)
- The writer prompt must instruct the writer to:
  1. Generate a complete feature file using `common/templates/feature-template.md`
  2. Use the assigned ID
  3. Copy relevant data models, conventions, design tokens inline (self-contained)
  4. Include all required sections per the template
  5. Self-audit with `scripts/check-feature.sh features/F-NNN-*.md`

The orchestrator MUST pass enough PRD context to the writer so the feature file is
self-contained — the writer needs to inline-copy applicable data models, conventions,
and design tokens from the PRD's `architecture/` topic files.

### Step 4 — Write the feature file

Write the writer's output to `features/F-{NNN}-{slug}.md` where `slug` is derived
from the feature name.

### Step 5 — Update README index

Append a new row to the Feature Index table in `README.md`. The row format matches
existing rows:

```
| F-{NNN} | {Name} | features/F-{NNN}-{slug}.md | {Priority} | {Effort} | active |
```

Also add the feature to the Roadmap section if a Priority is assigned.

The orchestrator performs this as a mechanical edit. Do NOT dispatch a sub-agent.

### Step 6 — Append CHANGELOG

Append a new entry to `CHANGELOG.md` (create the file if it doesn't exist). Format:

```markdown
## {YYYY-MM-DD}

### F-{NNN}: {Feature Name} — added
- **What:** {one-line feature summary}
- **Why:** {extracted from user's description}
- **Breaks:** N/A
```

### Step 7 — Commit

Commit with message: `feat(prd): add F-{NNN} — {feature name}`

### Step 8 — Report

Output a concise summary to the user:

```
Feature added: F-{NNN} — {feature name}
File: {prd-dir}/features/F-{NNN}-{slug}.md

Next: /system-design delta F-{NNN}  (to compute module impacts)
```

## FORBIDDEN

- Modifying existing feature files
- Dispatching a planner
- Running questioning phases
- Entering the review loop
