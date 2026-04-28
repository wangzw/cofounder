# Artifact Template — system-design

This file defines the canonical output structure for artifacts produced by the system-design skill.
The writer sub-agent uses this template as a structural scaffold when authoring new artifact files.

## Artifact Structure

All system-design output uses a **multi-level index** layout:

```
docs/raw/design/YYYY-MM-DD-{product-slug}/
├── README.md                   ← top-level index (summaries only, not full content)
├── modules/
│   ├── M-001-{slug}.md
│   ├── M-002-{slug}.md
│   └── ...
└── api/
    ├── API-001-{slug}.md
    └── ...
```

- **README.md** is the index file. It contains the Feature-Module Mapping matrix,
  Analytics Coverage table, Implementation Conventions table, and cross-reference links
  to all module and API leaf files. It does NOT inline full module or API content.
- **modules/M-NNN-{slug}.md** — one file per implementation module. Self-contained;
  all referenced context (data models, conventions) is copied inline.
- **api/API-NNN-{slug}.md** — one file per API surface area, if applicable.

No single leaf file may exceed 300 lines. Flat single-file artifacts are not valid output.

## Required Fields

Every artifact directory MUST contain:

| File / Path | Purpose |
|---|---|
| `README.md` | Index: Feature-Module Mapping, Analytics Coverage, Implementation Conventions, References |
| `modules/M-001-*.md` | At least one module file |

## Optional Sections

| Path | When to include |
|---|---|
| `api/API-NNN-*.md` | When the design specifies external API surfaces |
| `REVISIONS.md` | When the design has been revised from a prior version |

## Example

Minimal valid artifact tree:

```
docs/raw/design/2026-01-01-my-app/
├── README.md
└── modules/
    └── M-001-core.md
```

`README.md` must link to each module: `[M-001 Core](modules/M-001-core.md)`.
