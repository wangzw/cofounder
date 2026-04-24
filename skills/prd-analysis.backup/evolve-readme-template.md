# Incremental PRD Template — README.md (Evolve Mode)

The incremental README.md is the navigational entry point for an evolved PRD directory. It references a predecessor PRD as baseline, summarizes changes, and provides a complete index that mixes local files (changed items) with baseline references (unchanged items).

## Directory Structure

```
{output-dir}/
├── README.md              # Incremental overview + baseline ref + change summary + full index
├── journeys/
│   ├── J-{NNN}-{slug}.md  # Only new or modified journeys (full rewrite + change annotations)
│   └── ...
├── architecture.md        # Incremental architecture index (all topics, local or baseline ref)
├── architecture/
│   ├── {topic}.md         # Only changed topic files (full rewrite + change annotations)
│   └── ...
├── features/
│   ├── F-{NNN}-{slug}.md  # New features, modified features (full rewrite), or tombstones
│   └── ...
├── prototypes/            # Only new/modified feature prototypes
│   ├── src/
│   └── screenshots/
```

## Template

The incremental README.md follows this structure. Omit any section that has no useful content.

### Header

```
# {Product Name} — Incremental PRD

> {One-sentence product vision (updated if changed, otherwise same as baseline)}
```

### Baseline

| Field | Value |
|-------|-------|
| Predecessor | [{YYYY-MM-DD-product-name}](../YYYY-MM-DD-product-name/README.md) |
| Flattened from | {version chain, e.g.: 2026-01-15 → 2026-03-20 → 2026-06-15} |
| Date | {YYYY-MM-DD} |

### Change Summary

Categorize every change. This section is the first thing a reader sees — keep it scannable.

#### Added
- F-{NNN} {Feature Name} — {one-line description}
- J-{NNN} {Journey Name} — {one-line description}

#### Modified
- F-{NNN} {Feature Name} — {what changed}
- J-{NNN} {Journey Name} — {what changed}

#### Deprecated
- F-{NNN} {Feature Name} — {reason, replaced by what or N/A}

#### Architecture Changes
- {topic-file}.md — {what changed}

### Problem & Goals

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#problem--goals)"}
{If changed: full rewrite of section + change annotations using inline markers}

### Evidence Base

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#evidence-base)"}
{If changed: full rewrite + change annotations}

### Competitive Landscape

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#competitive-landscape)"}
{If changed: full rewrite + change annotations}

### Users

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#users)"}
{If changed: full rewrite + change annotations}

### User Journeys

{Complete index table — includes ALL journeys (local + baseline references). Always present, never reference-only.}

| ID | Journey | Persona | Status | Spec |
|----|---------|---------|--------|------|
| J-001 | {name} | {persona} | Unchanged | [→ baseline](../YYYY-MM-DD-product-name/journeys/J-001-{slug}.md) |
| J-002 | {name} | {persona} | **Modified** | [J-002](journeys/J-002-{slug}.md) |
| J-{NNN} | {name} | {persona} | **Added** | [J-{NNN}](journeys/J-{NNN}-{slug}.md) |

### Cross-Journey Patterns

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#cross-journey-patterns)"}
{If changed: full rewrite + change annotations. Deprecated features removed from "Addressed by Feature" column.}

### Feature Index

{Complete index table — includes ALL features (local + baseline references). Always present, never reference-only.}

| ID | Feature | Type | Status | Impact | Effort | Priority | Deps | Spec |
|----|---------|------|--------|--------|--------|----------|------|------|
| F-001 | {name} | UI | Unchanged | H | M | P0 | — | [→ baseline](../YYYY-MM-DD-product-name/features/F-001-{slug}.md) |
| F-003 | {name} | UI | **Modified** | H | M | P0 | F-001 | [F-003](features/F-003-{slug}.md) |
| F-005 | {name} | API | **Deprecated** | — | — | — | — | [F-005](features/F-005-{slug}.md) |
| F-012 | {name} | UI | **Added** | H | L | P0 | F-003 | [F-012](features/F-012-{slug}.md) |

### Risks

{If no new/changed risks: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#risks)"}
{If risks changed: full rewrite + change annotations. Include all risks (baseline + new), annotate changes.}

### Roadmap

{Updated roadmap reflecting this iteration's changes. Include all phases — unchanged features listed for context with "(baseline)" note, new/modified features annotated.}

**Phase 1 — MVP** (P0 features)
- [F-001: {name}](../YYYY-MM-DD-product-name/features/F-001-{slug}.md) (baseline)
- [F-012: {name}](features/F-012-{slug}.md) **[ADDED]**

**Phase 2** (P1 features)
- [F-003: {name}](features/F-003-{slug}.md) **[MODIFIED]**

### References

- Baseline PRD: [{predecessor path}](../YYYY-MM-DD-product-name/README.md)
- Journeys: [journeys/](journeys/) + [baseline journeys](../YYYY-MM-DD-product-name/journeys/)
- Architecture: [architecture/](architecture/) + [baseline architecture](../YYYY-MM-DD-product-name/architecture/)
- Prototypes: [prototypes/](prototypes/) + [baseline prototypes](../YYYY-MM-DD-product-name/prototypes/) {omit if no prototypes}

## Tombstone File Format (Deprecated Features)

Deprecated features get a short tombstone file instead of being silently removed. This prevents agents from looking for the feature in the old PRD.

```
# F-{NNN}: {Feature Name} — DEPRECATED

| Field | Value |
|-------|-------|
| Status | Deprecated |
| Reason | {why deprecated} |
| Replaced by | [F-{NNN}](F-{NNN}-{slug}.md) or N/A |
| Original | [→ baseline](../../YYYY-MM-DD-product-name/features/F-{NNN}-{slug}.md) |

{1-2 sentences explaining why deprecated, for agent context.}
{If Replaced by is N/A, explain why no replacement is needed.}
```

## Change Annotation Convention

All content types (features, journeys, architecture topics) use the same annotation system. See SKILL.md's Evolve Mode section for the full convention (metadata header + inline markers).

All change annotations (file-level metadata headers, inline `[MODIFIED]`/`[ADDED]`/`[REMOVED]`/`[UNCHANGED]` tags) follow the **Change Annotation Convention** defined in `evolve-mode.md`. Refer to that file for the complete format specification, tag syntax, and examples.

## Key Rules

- README.md contains **complete indexes** for journeys, features, and architecture — mixing local and baseline references
- Change Summary is always present and categorized (Added / Modified / Deprecated / Architecture Changes)
- Sections unchanged from baseline use a single-line reference, not a full copy
- Baseline field is always present and links to the predecessor PRD
- Tombstone files prevent agents from chasing deprecated features into old PRDs
- Feature / Journey IDs continue from baseline (new IDs > baseline max ID)
