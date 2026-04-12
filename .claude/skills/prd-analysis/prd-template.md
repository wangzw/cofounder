# PRD Template — README.md

The README.md is the navigational entry point for the PRD directory. Omit any section that has no useful content.

## Directory Structure

```
{output-dir}/
├── README.md              # Product overview + journey index + feature index + roadmap
├── journeys/
│   ├── J-001-{slug}.md    # Individual journey spec
│   └── ...
├── architecture.md        # Architecture, tech stack, design tokens, data model, NFRs
├── features/
│   ├── F-001-{slug}.md    # Self-contained feature spec
│   └── ...
├── prototypes/            # Interactive prototypes (seed code for production)
│   ├── src/               # Runnable prototype source code, organized per feature
│   │   ├── F-001-{slug}/  # Prototype for F-001
│   │   ├── F-006-{slug}/  # Prototype for F-006
│   │   └── ...
│   └── screenshots/       # Key state screenshots/snapshots per feature
│       ├── F-001-{slug}/  # Browser screenshots (web) or teatest golden files (TUI)
│       └── ...
```

## Template

The README.md follows this structure:

### Header

```
# PRD: {Product Name}

> {One-sentence product vision}
```

### Problem & Goals

{Problem statement: who has the problem, why it matters — 2-3 sentences}

**Goals:**

| Metric | Target | Baseline | How to Measure |
|--------|--------|----------|----------------|
| {metric} | {target value} | {current value or N/A} | {measurement method, e.g. event tracking, analytics query} |

**Scope:** {in/out of scope — brief}

### Evidence Base

| Decision | Evidence Type | Source | Confidence |
|----------|-------------|--------|------------|
| {e.g. "Task splitting is the core pain"} | {User interviews / Analytics / Feedback / Assumption} | {e.g. "12 interviews, Q1 2026"} | {High / Medium / Low} |

{Low-confidence decisions based on assumptions should be flagged as validation risks in the Risks section.}

### Competitive Landscape

{Omit for purely internal tools with no external alternatives.}

| Alternative | How It Solves the Problem | Strengths | Weaknesses |
|-------------|--------------------------|-----------|------------|
| {competitor or workaround} | {brief} | {what it does well} | {where it falls short} |

**Our Differentiation:** {1-2 sentences — why users will choose us over the alternatives}
**Table Stakes:** {features users expect as baseline — omit these and users won't adopt}

### Users

| Persona | Role | Primary Goal |
|---------|------|-------------|
| {Name} | {role} | {goal} |

### User Journeys

| ID | Journey | Persona | Key Pain Points | Spec |
|----|---------|---------|----------------|------|
| J-001 | {name} | {persona} | {brief} | [journey](journeys/J-001-{slug}.md) |

See [journeys/](journeys/) for full journey maps with touchpoints, alternative paths, and error recovery.

### Cross-Journey Patterns

{Omit if only one journey exists. Document patterns discovered across multiple journeys — these inform shared features and infrastructure.}

| Pattern | Affected Journeys | Implication | Addressed by Feature |
|---------|------------------|-------------|---------------------|
| {e.g. multiple journeys have anxiety during "waiting" stages} | J-001, J-003 | {e.g. unified progress/status feedback mechanism needed} | [F-{XXX}](features/F-{XXX}-{slug}.md) |
| {e.g. admin and member journeys share the same search touchpoint} | J-002, J-004 | {e.g. shared search component with role-based result filtering} | [F-{XXX}](features/F-{XXX}-{slug}.md) |

### Feature Index

| ID | Feature | Type | Impact | Effort | Priority | Deps | Prototype | Spec |
|----|---------|------|--------|--------|----------|------|-----------|------|
| F-001 | {name} | UI | H | M | P0 | — | [screenshots](prototypes/screenshots/F-001-{slug}/) | [spec](features/F-001-{slug}.md) |
| F-002 | {name} | API | H | S | P0 | F-001 | — | [spec](features/F-002-{slug}.md) |

Type: `UI` (user-facing, has Interaction Design section) | `API` (exposes/consumes APIs) | `Backend` (background jobs, infrastructure)

### Risks

| Risk | Likelihood | Impact | Mitigation | Affected Features |
|------|-----------|--------|------------|-------------------|
| {what can go wrong} | H/M/L | H/M/L | {strategy} | F-{XXX}, F-{YYY} |

### Roadmap

Default mapping: **Phase 1 (MVP) = all P0**, **Phase 2 = P1**, **Phase 3 = P2**. Override only with explicit rationale (e.g. technical dependency forces a P1 into Phase 1).

**Phase 1 — MVP** (P0 features)
- [F-001: {name}](features/F-001-{slug}.md)
- [F-002: {name}](features/F-002-{slug}.md)

**Phase 2** (P1 features)
- [F-003: {name}](features/F-003-{slug}.md)

### References

- [User Journeys](journeys/)
- [Architecture, Design Tokens & Data Model](architecture.md)
- [Interactive Prototypes](prototypes/) {omit if no prototypes}

### Revision History

{Populated by `--revise` mode. Omit on initial creation.}

| Version | Date | Change Type | Previous Version | Summary of Changes |
|---------|------|-------------|-----------------|-------------------|
| {this directory name or "in-place"} | {YYYY-MM-DD} | {New version / In-place edit} | [{previous directory name}]({relative path}) or N/A | {what changed and why} |

## Key Rules

- README.md is **navigational only** — no feature details, no architecture deep-dives
- No section should exist if it has nothing useful to say — omit empty sections
