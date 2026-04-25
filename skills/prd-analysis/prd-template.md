# PRD README Template

The README.md is the navigational entry point for the PRD directory. It is an index-only file —
full content lives in leaf files under `journeys/` and `features/`. Omit any section that has
nothing useful to say.

---

## Directory Structure

```
{output-dir}/
├── README.md              # This file — product overview, journey index, feature index, roadmap
├── REVISIONS.md           # Revision history (created on first --revise; absent on initial output)
├── journeys/
│   ├── J-001-{slug}.md    # Self-contained journey spec
│   └── ...
├── architecture/          # Architecture topic files (data model, conventions, design tokens, etc.)
│   ├── design-tokens.md
│   └── ...
├── features/
│   ├── F-001-{slug}.md    # Self-contained feature spec
│   └── ...
└── prototypes/            # Interactive prototypes (optional — omit when not generated)
    ├── src/               # Runnable prototype source, organized per feature
    │   ├── F-001-{slug}/
    │   └── ...
    └── screenshots/       # Key-state screenshots per feature
        ├── F-001-{slug}/
        └── ...
```

---

## Template

The README.md follows this structure exactly. Replace every `{placeholder}` with product-specific
content. Omit optional sections (marked *Omit if …*) only when the stated condition applies.

---

### Header

```
# PRD: {Product Name}

> {One-sentence product vision — what exists for whom, and what changes for them}
```

---

### Problem & Goals

{Problem statement: who has the problem, why it matters — 2–3 sentences. State the pain, not the
solution.}

**Goals:**

| Metric | Target | Baseline | How to Measure |
|--------|--------|----------|----------------|
| {metric name} | {target value} | {current value or N/A} | {measurement method — e.g. event tracking, analytics query, user survey} |

**Scope:** {What is explicitly in scope and out of scope for this version — brief, bullet or
sentence form.}

---

### Evidence Base

| Decision | Evidence Type | Source | Confidence |
|----------|---------------|--------|------------|
| {e.g. "Task splitting is the core pain"} | {User interviews / Analytics / Feedback / Competitive analysis / Assumption} | {e.g. "12 interviews, Q1 2026"} | {High / Medium / Low} |

{Low-confidence rows based on assumptions MUST be reflected as validation risks in the Risks
section below.}

---

### Competitive Landscape

*Omit for purely internal tools with no external alternatives — write "N/A — internal tool" in
place of the table.*

| Alternative | How It Solves the Problem | Strengths | Weaknesses |
|-------------|--------------------------|-----------|------------|
| {competitor or common workaround} | {brief description} | {what it does well} | {where it falls short} |

**Our Differentiation:** {1–2 sentences — why users choose this product over alternatives.}

**Table Stakes:** {Features users expect as baseline — omitting these prevents adoption. List
briefly.}

---

### Target Users

| Persona | Role | Primary Goal |
|---------|------|--------------|
| {Name} | {role or job title} | {what they are trying to accomplish} |

---

### User Journeys

| ID | Journey | Persona | Key Pain Points | Spec |
|----|---------|---------|-----------------|------|
| J-001 | {journey name} | {persona name} | {1–2 pain points in brief} | [spec](journeys/J-001-{slug}.md) |

See [journeys/](journeys/) for full journey maps with touchpoints, alternative paths, interaction
modes, and error recovery.

---

### Cross-Journey Patterns

*Omit this section if only one journey exists.*

Document patterns observed across multiple journeys — shared pain points, repeated touchpoints,
common infrastructure needs, or handoff points between personas. Each pattern MUST be addressed by
at least one feature.

| Pattern | Affected Journeys | Implication | Addressed by Feature |
|---------|-------------------|-------------|----------------------|
| {e.g. "Anxiety during async-wait stages"} | J-001, J-003 | {e.g. "Unified progress/status feedback mechanism needed"} | [F-{NNN}](features/F-{NNN}-{slug}.md) |
| {e.g. "Admin and member journeys share search touchpoint"} | J-002, J-004 | {e.g. "Shared search component with role-based result filtering"} | [F-{NNN}](features/F-{NNN}-{slug}.md) |

---

### Feature Index

| ID | Feature | Type | Impact | Effort | Priority | Deps | Prototype | Spec |
|----|---------|------|--------|--------|----------|------|-----------|------|
| F-001 | {feature name} | {type} | H | M | P0 | — | [screenshots](prototypes/screenshots/F-001-{slug}/) | [spec](features/F-001-{slug}.md) |
| F-002 | {feature name} | {type} | H | S | P0 | F-001 | — | [spec](features/F-002-{slug}.md) |

**Type values** (non-exclusive — use comma-separated when applicable):
- `UI` — user-facing, has Interaction Design
- `API` — exposes or consumes APIs
- `Backend` — background jobs, infrastructure, no direct user surface

**Impact / Effort:** `H` = High, `M` = Medium, `S` = Small, `L` = Low

**Priority:** `P0` = MVP (Phase 1), `P1` = Phase 2, `P2` = Phase 3

**Prototype column:** link to `prototypes/screenshots/F-{NNN}-{slug}/`; use `—` when no prototype
exists.

> **Mandatory auto-derived features (always include, regardless of product):**
> Two features MUST appear in every Feature Index as P0/Phase 1 with no journey dependency (`Deps = —`):
> 1. **Development Infrastructure** — one requirement per architecture convention section (coding standards, tooling, repo setup, etc.); `Type = Backend`.
> 2. **Deployment Infrastructure** — one requirement per deployment architecture aspect (hosting, CI/CD, environments, monitoring, etc.); `Type = Backend`.
> These are never derived from user journeys; they are derived from the architecture and deployment convention sections.

---

### Design Tokens Summary

*Omit if design tokens are fully specified only in `architecture/design-tokens.md` and no
README-level summary is needed. When present, this is a summary index — not the authoritative
definition.*

| Token Category | Scope | Notes |
|----------------|-------|-------|
| {e.g. color} | {web / TUI / both} | {e.g. semantic palette: primary, surface, error, on-*} |
| {e.g. typography} | {web / TUI / both} | {e.g. scale: display, body, caption} |
| {e.g. spacing} | {web / TUI / both} | {e.g. 4px base grid, xs/sm/md/lg/xl} |
| {e.g. motion} | {web} | {e.g. duration and easing tokens for key transitions} |

Full token definitions: [architecture/design-tokens.md](architecture/design-tokens.md).

---

### Constraints

| Constraint | Type | Impact |
|------------|------|--------|
| {e.g. "Must run offline-first"} | {Technical / Regulatory / Business / Resource} | {which features or journeys are affected} |

---

### Risks

| Risk | Likelihood | Impact | Mitigation | Affected Features |
|------|-----------|--------|------------|-------------------|
| {what can go wrong} | H/M/L | H/M/L | {mitigation strategy} | F-{NNN}, F-{MMM} |

{Rows with Confidence = Low in the Evidence Base MUST appear here as validation risks.}

---

### Roadmap

Default mapping: **Phase 1 (MVP) = all P0**, **Phase 2 = P1**, **Phase 3 = P2**. Override only
with explicit rationale (e.g. a technical dependency forces a P1 feature into Phase 1).

**Phase 1 — MVP** (P0 features)
- [F-001: {name}](features/F-001-{slug}.md)
- [F-002: {name}](features/F-002-{slug}.md)

**Phase 2** (P1 features)
- [F-003: {name}](features/F-003-{slug}.md)

**Phase 3** (P2 features)
- [F-004: {name}](features/F-004-{slug}.md)

---

### Glossary

*Omit if no domain-specific terms require definition.*

| Term | Definition |
|------|-----------|
| {term} | {definition — 1–2 sentences, as a coding agent would need to understand it} |

---

### References

- [User Journeys](journeys/)
- [Architecture, Design Tokens & Data Model](architecture/)
- [Interactive Prototypes](prototypes/) *(omit if no prototypes generated)*
- [Revision History](REVISIONS.md) *(omit on initial creation — added by `--revise` mode)*

---

## REVISIONS.md Template

The REVISIONS.md file records the version chain for this PRD. It is created on the first
`--revise` invocation and appended on each subsequent revision. **Omit this file on initial
creation — only `--revise` writes it.**

```markdown
# Revision History — {Product Name}

Chronological record of revisions to this PRD. Most recent entry first.

| Version | Date | Change Type | Previous Version | Summary of Changes |
|---------|------|-------------|------------------|--------------------|
| {this directory name or "in-place"} | {YYYY-MM-DD} | {New version / In-place edit} | [{previous dir}]({relative path}) or N/A | {what changed and why} |
```

**Rules:**
- New entries are inserted at the top of the table (most recent first).
- `Previous Version` links are relative paths from this directory — e.g.
  `../2026-03-01-{product}/REVISIONS.md`.
- For in-place edits, `Version` may be the literal string `in-place` plus a date suffix when
  multiple in-place edits occur in the same directory.

---

## Key Rules

- README.md is **index-only** — no feature details, no architecture deep-dives, no inline-copy of
  journey touchpoint tables. Full content lives in leaf files.
- Revision History lives in `REVISIONS.md`, not in README.md — keeps the navigational entry point
  stable as the version chain grows.
- Omit any section that has nothing useful to say — do not emit empty section headers.
- Every feature in the Feature Index MUST have a corresponding file at the listed path.
- Every journey in the User Journeys table MUST have a corresponding file at the listed path.
- IDs are zero-padded, sequential, and stable across iterations: F-001, F-002, …; J-001, J-002, …
