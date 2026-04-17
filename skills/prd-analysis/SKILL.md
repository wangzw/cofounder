---
name: prd-analysis
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, prepare requirements for AI coding agents, or evolve an existing PRD for a new iteration. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis', 'evolve PRD', 'new iteration'."
---

# PRD Analysis — AI-Coding-Ready Requirements

Generate PRDs as a **multi-file directory**. Each feature spec is a self-contained file — coding agents read only the file they need, minimizing context consumption.

## Scope

PRD captures **product-level decisions**: what to build, for whom, why, and at what priority. It does NOT specify implementation-level details — those belong to system-design. See `scope-reference.md` for the full PRD vs. system-design boundary table (loaded in authoring modes).

## Input Modes

```
/prd-analysis                          # interactive mode
/prd-analysis path/to/notes.md         # document-based mode
/prd-analysis --output docs/raw/prd/my-project  # custom output dir
/prd-analysis notes.md --output ./prd  # both
/prd-analysis --review docs/raw/prd/xxx/        # review existing PRD
/prd-analysis --revise docs/raw/prd/xxx/        # change management for existing PRD
/prd-analysis --evolve docs/raw/prd/xxx/        # incremental PRD for new iteration
/prd-analysis --evolve docs/raw/prd/xxx/ notes.md  # evolve with document input
```

## Mode Routing

After detecting the invocation mode, read the corresponding files before proceeding:

| Mode | Read These Files |
|------|-----------------|
| Initial analysis (no flags) | `questioning-phases.md`, `scope-reference.md`, `review-checklist.md` |
| Initial analysis + document input | `questioning-phases.md`, `document-mode.md`, `scope-reference.md`, `review-checklist.md` |
| `--review` | `review-mode.md`, `review-checklist.md` |
| `--revise` | `revise-mode.md`, `scope-reference.md`, `review-checklist.md` |
| `--evolve` | `evolve-mode.md`, `questioning-phases.md`, `scope-reference.md`, `review-checklist.md` |

Do NOT read files not listed for the current mode — they are not needed and waste context.

## Process

1. **Gather requirements** — interactive questioning or parse provided document
2. **Fill gaps** — ask targeted follow-up questions for missing info
3. **Generate PRD files** — using templates in this skill directory
4. **Cross-link** — backfill cross-references that couldn't exist during initial generation: journey Mapped Feature columns, feature Deps, feature Journey Context links, Cross-Journey Patterns "Addressed by Feature" column
5. **Write files** — write all generated files to disk (not yet committed)
6. **Self-review** — read each written file against the review checklist (see Review Checklist below), fix issues directly in files
7. **User review** — user reviews files in their editor, confirms or requests changes
8. **Commit** — commit all files to git

### Review Checklist

See `review-checklist.md` (loaded via mode routing for initial analysis, `--review`, `--revise`, and `--evolve` modes). Applied as step 6 of the process (after writing, before commit) — check each dimension and fix issues directly in the written files.

### Immutability Rule

Whether PRD files can be modified in place depends on their **downstream consumption state** — what has been built on top of them:

| Downstream State | Modify in Place? | Rationale |
|-----------------|-----------------|-----------|
| No design exists | Yes | No downstream consumers to break |
| Design exists, not implemented | Yes + append entry to `REVISIONS.md` (create the file if this is the first revision) | Design team needs the change record to update design accordingly |
| Implementation exists | No — create new version | Modifying in place would invalidate implemented code |

Steps 6-7 (self-review, user review) always occur before commit and are part of the creation process — modifying files during these steps is expected regardless of downstream state.

**Evolve mode note:** `--evolve` always creates a new directory (new date) — it never modifies the predecessor PRD. The predecessor is read-only input.

## Output Structure

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md                # Product overview + journey index + feature index + roadmap
├── REVISIONS.md             # Revision history (only present after first --revise)
├── journeys/
│   ├── J-001-{slug}.md      # Individual journey spec
│   └── ...
├── architecture.md          # INDEX ONLY (~50-80 lines) — diagram + links to topic files
├── architecture/            # Topic files — each standalone, independently readable
│   ├── tech-stack.md
│   ├── design-tokens.md     # (omit if no UI)
│   ├── navigation.md        # (omit if no UI)
│   ├── accessibility.md     # (omit if no UI)
│   ├── i18n.md
│   ├── data-model.md
│   ├── external-deps.md
│   ├── coding-conventions.md
│   ├── test-isolation.md
│   ├── security.md
│   ├── dev-workflow.md
│   ├── git-strategy.md
│   ├── code-review.md
│   ├── observability.md
│   ├── performance.md
│   ├── backward-compat.md   # (omit for v1)
│   ├── ai-agent-config.md
│   ├── deployment.md
│   ├── shared-conventions.md
│   ├── auth-model.md        # (omit if single-role)
│   ├── privacy.md           # (omit if no personal data)
│   └── nfr.md
├── features/
│   ├── F-001-{slug}.md      # Self-contained feature spec
│   └── ...
├── prototypes/              # Interactive prototypes (seed code for production)
│   ├── src/                 # Runnable prototype source
│   └── screenshots/         # Key state screenshots per feature
```

Use templates: `prd-template.md` (README), `journey-template.md` (individual journeys), `architecture-template.md` (architecture index + topic files), and `feature-template.md` (feature specs). Evolve mode uses `evolve-readme-template.md` instead of `prd-template.md` for the README; all other templates are reused with the addition of the Change Annotation Convention (defined in `evolve-mode.md`).

**Agent consumption:** read README.md (~concise overview) → read one feature file → implement. Each feature file copies all needed context inline (data models, conventions, journey context), so the feature file alone is sufficient for implementation. Agents do NOT need to read architecture.md or architecture/ files — those are source-of-truth for the PRD author, not for coding agents. The feature file is the coding agent's only input.

**Evolve mode output** — only delta files present:

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md                # Incremental README (baseline ref + change summary + full indexes)
├── journeys/
│   ├── J-{NNN}-{slug}.md   # Only new or modified journeys
│   └── ...
├── architecture.md          # Incremental index (changed → local, unchanged → baseline ref)
├── architecture/
│   ├── {changed-topic}.md   # Only changed topic files
│   └── ...
├── features/
│   ├── F-{NNN}-{slug}.md   # New features, modified features, or tombstones (deprecated)
│   └── ...
├── prototypes/              # Only new/modified feature prototypes
│   ├── src/
│   └── screenshots/
```

**Agent consumption (evolve mode):** read incremental README.md → for a new/modified feature, read the local feature file (self-contained). For an unchanged feature, follow the `→ baseline` link to the predecessor PRD's feature file.

## Output Path

- **Default:** `docs/raw/prd/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing

## Key Principles

- **One question at a time** — don't overwhelm
- **MVP ruthlessly** — push back on scope creep
- **Minimal context** — agents read one small file, not a giant document
- **Copy, don't reference** — feature files include relevant data models, conventions, and journey context inline
- **README is a stable navigational index, REVISIONS.md tracks history** — README.md is the entry point and should not accumulate revision entries that destabilize navigation across versions. Revision history (entries written by `--revise`) lives in a sibling `REVISIONS.md`, created on first revision and grown thereafter. Both files coexist; the README's References section links to `REVISIONS.md` when present.
- **No ambiguity** — if a requirement can be interpreted two ways, clarify now
- **Omit empty sections** — if a section has nothing useful, skip it

## Next Steps Hint

After committing, print the following guidance to the user:

**Initial creation and revise mode:**
```
PRD complete: {output path}

Next steps:
  Interactive — /system-design {output path}
  Automated  — claude -p "generate system design based on {output path}" --auto
```

**Evolve mode** — use the cascade notification from Evolve Step 5 instead.
