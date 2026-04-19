---
name: system-design
description: "Use when the user needs to create system design documents from a PRD or requirements, perform module decomposition, define interfaces and data models, or review existing designs. Triggers: /system-design, 'system design', 'module design', 'technical design', 'design review'."
---

# System Design — AI-Coding-Ready Technical Design

Generate system design documents as a **multi-file directory**. Each module spec is a self-contained file — coding agents read only the file they need. Includes a structured design review phase that directly improves the documents.

## Input Modes

```
/system-design                                    # interactive mode
/system-design path/to/prd/                       # PRD-based mode
/system-design path/to/draft.md                   # document-based mode
/system-design --output docs/raw/design/my-project    # custom output dir
/system-design path/to/prd/ --output ./design     # both
/system-design --review docs/raw/design/xxx/          # review existing design (read-only)
/system-design --revise docs/raw/design/xxx/          # change management for existing design
```

**Note on evolved PRDs:** When a PRD has been evolved (`/prd-analysis --evolve`), use `/system-design` with the new incremental PRD path to generate a fresh design, or use `--revise` on the existing design to propagate specific PRD changes. There is no dedicated `--evolve` mode for system-design — `--revise` handles both in-place PRD changes and evolved PRD deltas.

## Mode Routing

Detect mode from the input flags and load only the relevant topic file. The Design Review checklist and the Structural Lint checklist are shared across modes.

| Mode | Trigger | Read These Files |
|------|---------|------------------|
| **Generate** (default) | No `--review` / `--revise` flag | `generate-mode.md` (load `structural-lint.md` at Step 9a; load `design-review-checklist.md` at Step 10) |
| **Review** | `--review <design-dir>` | `review-mode.md` + `design-review-checklist.md` (load `structural-lint.md` at Step 1.5 pre-scan) |
| **Revise** | `--revise <design-dir>` | `revise-mode.md` (load `structural-lint.md` at Step 7.0 gate; load `design-review-checklist.md` on demand per revise-mode.md instructions) |

Detect the mode first. Read the routing files for that mode only — do not load the others. Templates (`design-template.md`, `module-template.md`, `api-template.md`) are loaded per-section as needed during file generation.

**Structural Lint vs Design Review:** `structural-lint.md` catches deterministic, grep-runnable gaps (placeholder JSON, missing per-endpoint blocks, unfilled Boundary Enforcement columns, dangling hook↔endpoint references). It runs before the semantic `design-review-checklist.md` so mechanical findings never consume reviewer attention. If the checklist keeps flagging a mechanical class across `--revise` cycles, extend `structural-lint.md` rather than accepting the review cost.

## Output Structure

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md              # Design overview + module index + mapping matrix
├── REVISIONS.md           # Revision history (only present after first --revise)
├── modules/
│   ├── M-001-{slug}.md    # Self-contained module design
│   └── ...
├── api/                   # Only generated when project has APIs
│   ├── API-001-{slug}.md  # Self-contained API contract
│   └── ...
└── .reviews/              # Transient — not version-controlled (gitignore: docs/raw/design/*/.reviews/)
    ├── REVIEW-*.md            # Semantic review findings, produced by --review, consumed by --revise
    ├── REVIEW-*.applied.md    # Same, after --revise consumes it (renamed by Bash mv)
    ├── LINT-*.md              # Structural-lint findings (L1..L5, X1..X8), produced by generate/review/revise
    └── LINT-*.applied.md      # Same, after generate/revise fixes and re-runs clean
```

Use templates: `design-template.md` (README), `module-template.md` (module specs),
`api-template.md` (API contracts).

**Agent consumption:** read README.md (overview + mapping matrix) → read one module file → implement. The module file alone is sufficient for a coding agent to start working.

## Output Path

- **Default:** `docs/raw/design/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing
- **Cross-document paths:** when referencing PRD files (Source Features, References, Analytics Coverage), use relative paths from the design directory to the PRD directory. Example: if PRD is at `docs/raw/prd/2026-04-09-foo/` and design is at `docs/raw/design/2026-04-09-foo/`, a module's Source Feature link would be `../../../prd/2026-04-09-foo/features/F-001-slug.md`

## Key Principles

- **Self-contained** — each module file can be independently consumed by a coding agent
- **Copy, don't reference** — relevant data models, interface definitions are copied inline
- **One question at a time** — don't overwhelm during interactive refinement
- **Design ≠ Plan** — this skill produces "how to build it" designs, not "who does what in what order" — task assignment and execution are handled by `/autoforge`
- **Review writes reports, revise applies them** — `--review` is read-only and produces `REVIEW-*.md` (semantic findings) plus `LINT-*.md` (mechanical gaps) in `.reviews/`. `--revise` consumes the newest REVIEW and re-runs lint to fix the gaps. Generate-mode's Step 10 self-review is the one place where review and fix happen in a single pass.
- **README is a stable navigational index, REVISIONS.md tracks history** — README.md stays a clean entry point so module/api links are easy to follow across versions; revision entries (written by `--revise`) accumulate in `REVISIONS.md` instead. REVISIONS.md is created on first revision; the README's References section links to it once it exists.
- **Omit empty sections** — if a section has nothing useful, skip it
- **Feature-Module mapping** — the mapping matrix is the bridge between requirements and implementation, serving as the key input for the planning phase

## Next Steps Hint

After committing, print the following guidance to the user:

```
System design complete: {output path}

Next steps:
  /autoforge {output path}
```
