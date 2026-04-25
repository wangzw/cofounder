# Incremental PRD Template — README.md (Evolve Mode)

The incremental README.md is the navigational entry point for an evolved PRD directory. It
references a predecessor PRD as baseline, summarizes changes, and provides a complete index that
mixes local files (changed items) with baseline references (unchanged items).

All change annotations (file-level metadata headers, inline `[MODIFIED]`/`[ADDED]`/`[REMOVED]`/
`[UNCHANGED]` tags) follow the **Change Annotation Convention** defined in `evolve-mode.md`. Refer
to that file for the complete format specification, tag syntax, and examples.

---

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

---

## Template

The incremental README.md follows this structure. Omit any section that has no useful content.

### Header

```
# {Product Name} — Incremental PRD

> {One-sentence product vision (updated if changed, otherwise same as baseline)}
```

### Baseline Reference

| Field | Value |
|-------|-------|
| Predecessor | [{YYYY-MM-DD-product-name}](../YYYY-MM-DD-product-name/README.md) |
| Flattened from | {version chain, e.g.: 2026-01-15 → 2026-03-20 → 2026-06-15} |
| Date | {YYYY-MM-DD} |

The Predecessor path MUST resolve to an actual directory on disk (enforced by CR-PP05). If this
is the first evolution, Flattened from is the same as Predecessor.

### Change Summary

Categorize every change. This section is the first thing a reader sees — keep it scannable.

#### Added
- F-{NNN} {Feature Name} — {one-line description}
- J-{NNN} {Journey Name} — {one-line description}

#### Modified
- F-{NNN} {Feature Name} — {what changed, one line}
- J-{NNN} {Journey Name} — {what changed, one line}

#### Deprecated
- F-{NNN} {Feature Name} — {reason; replaced by F-{NNN} or N/A}
- J-{NNN} {Journey Name} — {reason; replaced by J-{NNN} or N/A}

#### Architecture Changes
- {topic-file}.md — {what changed, one line}

If a category has no entries, omit it entirely. Do not write "None."

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

Complete index table — includes ALL journeys (local + baseline references). Always present,
never reference-only. Status column uses: `Unchanged`, `**Modified**`, `**Added**`,
`**Deprecated**`.

| ID | Journey | Persona | Status | Spec |
|----|---------|---------|--------|------|
| J-001 | {name} | {persona} | Unchanged | [→ baseline](../YYYY-MM-DD-product-name/journeys/J-001-{slug}.md) |
| J-002 | {name} | {persona} | **Modified** | [J-002](journeys/J-002-{slug}.md) |
| J-{NNN} | {name} | {persona} | **Added** | [J-{NNN}](journeys/J-{NNN}-{slug}.md) |
| J-{NNN} | {name} | {persona} | **Deprecated** | [J-{NNN}](journeys/J-{NNN}-{slug}.md) |

### Cross-Journey Patterns

{If unchanged: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#cross-journey-patterns)"}
{If changed: full rewrite + change annotations. Deprecated features removed from "Addressed by
Feature" column.}

### Feature Index

Complete index table — includes ALL features (local + baseline references). Always present,
never reference-only. Status column uses: `Unchanged`, `**Modified**`, `**Added**`,
`**Deprecated**`.

| ID | Feature | Type | Status | Impact | Effort | Priority | Deps | Spec |
|----|---------|------|--------|--------|--------|----------|------|------|
| F-001 | {name} | UI | Unchanged | H | M | P0 | — | [→ baseline](../YYYY-MM-DD-product-name/features/F-001-{slug}.md) |
| F-003 | {name} | UI | **Modified** | H | M | P0 | F-001 | [F-003](features/F-003-{slug}.md) |
| F-005 | {name} | API | **Deprecated** | — | — | — | — | [F-005](features/F-005-{slug}.md) |
| F-012 | {name} | UI | **Added** | H | L | P0 | F-003 | [F-012](features/F-012-{slug}.md) |

### Deprecated-Item Tombstone Index

Lists every deprecated feature and journey in this iteration (and all prior iterations not yet
superseded). Each entry links to the tombstone file. Agents use this index to confirm deprecation
status without opening the baseline PRD.

| ID | Name | Type | Deprecated In | Reason | Replaced By |
|----|------|------|---------------|--------|-------------|
| F-{NNN} | {name} | Feature | {YYYY-MM-DD iteration} | {short reason} | F-{NNN} or N/A |
| J-{NNN} | {name} | Journey | {YYYY-MM-DD iteration} | {short reason} | J-{NNN} or N/A |

If no items were deprecated in any iteration in the chain, omit this section.

### ID-Stability Ledger

Tracks all ID assignments across the version chain for this evolve iteration. Provides the
authoritative record of which IDs are active, deprecated, or reserved.

| ID | Status | Introduced | Last Changed | Notes |
|----|--------|------------|--------------|-------|
| F-001 | Active | {YYYY-MM-DD baseline} | {YYYY-MM-DD or "—"} | {note or "—"} |
| F-005 | Deprecated | {YYYY-MM-DD baseline} | {this iteration} | Replaced by F-012 |
| F-012 | Active | {this iteration} | — | New in this iteration |

Rules:
- IDs are never reused. Once assigned (active or deprecated), the ID is permanently reserved.
- New IDs in this iteration MUST be greater than the maximum ID in the baseline.
- If an ID appears in the baseline as active and is not listed here, it is implicitly active
  and unchanged — no entry required for unchanged items.

### Cascade-Impact Map

Documents all cascade effects triggered by this iteration's changes. A cascade occurs when a
journey modification forces feature changes, or a feature deprecation forces journey updates, or
an architecture change propagates into multiple leaves.

| Trigger | Trigger Type | Cascades To | Impact |
|---------|-------------|-------------|--------|
| J-{NNN} modified | Journey | F-{NNN}, F-{NNN} | {what changed in the dependent features} |
| F-{NNN} deprecated | Feature | J-{NNN} | {how the journey touchpoint was updated} |
| {topic}.md changed | Architecture | F-{NNN}, F-{NNN} | {convention/contract updated in features} |

If no cascades occurred in this iteration, write: "No cascades in this iteration."

### Risks

{If no new/changed risks: "No changes — see [baseline](../YYYY-MM-DD-product-name/README.md#risks)"}
{If risks changed: full rewrite + change annotations. Include all risks (baseline + new), annotate
changes.}

### Roadmap

Updated roadmap reflecting this iteration's changes. Include all phases — unchanged features
listed for context with "(baseline)" note, new/modified features annotated.

**Phase 1 — MVP** (P0 features)
- [F-001: {name}](../YYYY-MM-DD-product-name/features/F-001-{slug}.md) (baseline)
- [F-012: {name}](features/F-012-{slug}.md) **[ADDED]**

**Phase 2** (P1 features)
- [F-003: {name}](features/F-003-{slug}.md) **[MODIFIED]**

### References

- Baseline PRD: [{YYYY-MM-DD-product-name}](../YYYY-MM-DD-product-name/README.md)
- Journeys: [journeys/](journeys/) + [baseline journeys](../YYYY-MM-DD-product-name/journeys/)
- Architecture: [architecture/](architecture/) + [baseline architecture](../YYYY-MM-DD-product-name/architecture/)
- Prototypes: [prototypes/](prototypes/) + [baseline prototypes](../YYYY-MM-DD-product-name/prototypes/) {omit if no prototypes}

---

## Tombstone File Format (Deprecated Features and Journeys)

Deprecated features and journeys get a short tombstone file instead of being silently removed.
This prevents agents from looking for the item in the old PRD and discovering stale content.

```
# {F|J}-{NNN}: {Name} — DEPRECATED

| Field | Value |
|-------|-------|
| Status | Deprecated |
| Reason | {why deprecated} |
| Replaced by | [{F|J}-{NNN}]({F|J}-{NNN}-{slug}.md) or N/A |
| Original | [→ baseline](../../YYYY-MM-DD-product-name/{features|journeys}/{F|J}-{NNN}-{slug}.md) |

{1-2 sentences explaining why deprecated, for agent context.}
{If Replaced by is N/A, explain why no replacement is needed.}
```

---

## Key Rules

- README.md contains **complete indexes** for journeys, features, and architecture — mixing local
  and baseline references. An agent navigating this PRD must never need to open the baseline
  README to get the full picture.
- Change Summary is always present and categorized (Added / Modified / Deprecated / Architecture
  Changes). Categories with no entries are omitted.
- Sections unchanged from baseline use a single-line reference link, not a full copy.
- The Baseline Reference field is always present and links to the predecessor PRD.
- Tombstone files prevent agents from chasing deprecated items into old PRDs.
- Feature and Journey IDs continue from baseline: new IDs MUST be greater than the baseline max ID.
- The ID-Stability Ledger tracks all ID assignments across the version chain; IDs are never reused.
- The Cascade-Impact Map documents all cross-leaf propagations triggered by this iteration's
  changes, so reviewers can verify no cascade was missed.
- The Deprecated-Item Tombstone Index provides a single lookup point for all deprecated items
  across the entire version chain visible from this iteration.
