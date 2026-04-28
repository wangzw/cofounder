# Template: artifact-template.md — Shape Reference for Writer

This template is READ by the writer sub-agent when authoring the TARGET SKILL's
`common/templates/artifact-template.md`. That file defines the shape of what the target skill
in turn produces for its users. This is NOT the skeleton's DOMAIN_FILL stub — this is the
writer's reference for what a FILLED artifact template looks like.

---

## Document Artifact Shape

skill-forge produces document artifacts: human-readable markdown documents (PRDs, decision logs,
design docs, wikis, runbooks). Every scaffolded skill produces this shape.

### Canonical Directory Layout

```
<artifact-root>/
├── README.md               # Pyramid index: lists all subdirs + brief description of each
├── <section-A>/
│   ├── index.md            # Section index: lists all leaves in this subdir with one-line summaries
│   ├── <slug-001>.md       # Individual leaf — self-contained, ≤ 300 lines
│   └── <slug-002>.md
├── <section-B>/
│   ├── index.md
│   └── <slug-003>.md
└── CHANGELOG.md            # Delivery history (written by summarizer, not artifact writer)
```

### Leaf Shape

```markdown
---
<domain-frontmatter-fields>   # e.g. id, status, date, deciders
---

# <Leaf Title>

## <Section 1>
...

## <Section 2>
...
```

Each leaf MUST be self-contained: any reader opening just the leaf MUST have all context needed
to understand and act on it. Cross-references to other leaves are permitted for navigation but
MUST NOT be load-bearing (i.e., the leaf must be fully comprehensible without opening the link).

---

## Multi-Level Index Requirement (CR-S13)

Artifacts MUST satisfy:

1. **No single leaf exceeds 300 lines** — split large content across multiple leaves.
2. **README.md at root** — lists all subdirectories with brief descriptions (pyramid apex).
3. **index.md in each subdirectory** — lists all leaves in that subdir with one-line summaries.
4. **Leaves are self-contained** (CR-L05) — opening one file MUST give a reader everything needed
   to understand and act on that file's content.

A flat single-file artifact (one file, 1000+ lines) violates both CR-S13 and CR-L05.

---

## Positive Example — decision-log

Directory layout:

```
decisions/
├── README.md               # Index of decisions by quarter + action-item tracker link
├── 2026-Q1/
│   ├── index.md            # Q1 decisions: D-001, D-002, D-003 with status and one-line summaries
│   ├── D-001-auth-middleware.md    # 85 lines — self-contained decision record
│   └── D-002-billing-tier.md      # 120 lines — self-contained decision record
├── 2026-Q2/
│   ├── index.md
│   └── D-003-queue-backend.md
└── action-items/
    ├── index.md            # Open action items by assignee
    └── AI-001-compliance-audit.md  # 40 lines — single action item with full context
```

`README.md` excerpt:

```markdown
# Decision Log

| Quarter | Decisions | Open Action Items |
|---------|-----------|------------------|
| [2026-Q1](2026-Q1/index.md) | 2 | 1 |
| [2026-Q2](2026-Q2/index.md) | 1 | 0 |

Action items tracker: [action-items/index.md](action-items/index.md)
```

`2026-Q1/D-001-auth-middleware.md` excerpt (self-contained):

```markdown
---
decision_id: D-001
status: accepted
date: 2026-01-12
deciders: [alice, bob]
---

# D-001 — Adopt JWT middleware for API auth

## Context
The REST API had no unified auth layer; each endpoint handled its own token validation.
The team evaluated Passport.js and a custom JWT middleware.

## Decision
Adopt a custom JWT middleware at the Express router level.

## Rationale
Passport.js adds 3 strategy plugins + session management that are not needed for a pure
stateless API. The custom middleware is 80 lines, fully auditable, and has no external deps.
Passport.js was dismissed: over-engineered for this use case.

## Action Items
| Item | Assignee | Due |
|------|----------|-----|
| Write JWT middleware + tests | alice | 2026-01-20 |
```

---

## Negative Example — monolithic single-file artifact

```
decisions/
└── decisions.md    # 1200 lines containing all 12 decisions in one file
```

Violations:
- **CR-S13 fires**: no pyramid index — single flat file, no README, no subdirectory index.
- **CR-L05 fires**: opening `decisions.md` loads 1200 lines of context; a consuming agent
  building on D-003 must parse the entire file rather than reading a self-contained leaf.
- **No per-decision frontmatter** → checkers cannot index individual decisions.

---

## How to Fill

1. Read `clarification.artifact_structure` for the domain-specific directory layout and leaf shape.
2. Adapt the canonical directory layout for the domain (replace `<section-A>` etc. with real names from `clarification.sections`).
3. Ensure the filled template explicitly states the 300-line leaf limit and pyramid index requirement.
4. Ensure the filled template describes leaf self-containedness — inline context, not cross-references.
