# PRD Evolve Mode (`--evolve`)

This file contains instructions for generating an incremental PRD for a new software iteration, using an existing PRD as baseline. The new PRD contains only delta (new/modified/deprecated items) and references the predecessor for unchanged content.

For evolve mode, also read `questioning-phases.md` — the per-phase questioning guide is reused with "review existing → ask delta → deep-dive" pattern.

Review Checklist dimensions are defined in `SKILL.md` — read that first.

---

**When to use `--evolve` vs `--revise`:**
- `--revise`: small corrections or adjustments to an existing PRD (edits in place)
- `--evolve`: new iteration/release cycle — existing features should be (partially) implemented, and you need a new PRD reflecting the next round of requirements

## Evolve Step 1 — Load & Flatten Baseline

1. **Read the specified old PRD directory**, validate structural integrity (README.md, journeys/, features/, architecture.md exist)
2. **Detect version chain** — read old PRD's README.md. If a `Baseline` section exists with a `Predecessor` field, the old PRD is itself incremental. Recursively read the predecessor chain.
3. **Flatten in memory** — merge all predecessors to build "current complete product state":
   - Features: later PRD's version overwrites same-ID feature in parent. Tombstone (deprecated) removes feature from baseline.
   - Journeys: same rules as features.
   - Architecture topics: later PRD's topic file overwrites same-name file in parent.
   - README sections (Problem & Goals, Users, Risks, Roadmap): if the later PRD rewrites the section, it overwrites; otherwise parent version is kept.
   - Personas: accumulated from all PRDs (later PRD's persona table overwrites if changed).

**Flattening algorithm (pseudocode):**
```
function flatten(current_prd_path):
    baseline = read(current_prd_path / "README.md").Baseline.Predecessor
    if baseline is None:
        return read_all_files(current_prd_path)  # base case: original PRD
    
    parent = flatten(baseline)  # recursive: flatten the predecessor first
    current = read_all_files(current_prd_path)
    
    merged = copy(parent)
    for item in current.features:
        if item.status == "Deprecated":
            merged.features.remove(item.id)  # tombstone removes from baseline
        else:
            merged.features[item.id] = item  # new/modified overwrites same-ID
    
    for item in current.journeys:
        merged.journeys[item.id] = item  # same logic as features
    
    for topic in current.architecture:
        merged.architecture[topic.name] = topic  # changed topics overwrite
    
    # IDs: new items use max(merged.*.id) + 1 to avoid collisions
    return merged
```

**Edge cases:**
- Feature deprecated in version N then re-added in version N+1: the re-add creates a NEW feature ID (the old ID remains deprecated in the chain)
- Duplicate IDs across versions: the flattening always takes the latest version's entry, so duplicates are resolved by recency

4. **Present baseline summary to user:**

> Baseline loaded {if chain: "(chain: 2026-01-15 → 2026-03-20 → current flattened)"}
> - Product: {name} — {vision}
> - Personas: {count} ({list names})
> - Journeys: {count} ({list IDs and names})
> - Features: {count} — P0: {n}, P1: {n}, P2: {n} ({list IDs and names per priority})
> - Architecture topics: {count changed in latest iteration} / {total count}
>
> Is this baseline correct?

Wait for user confirmation. If user corrects something (e.g. "F-005 was actually deprecated informally"), adjust the baseline accordingly.

## Evolve Step 2 — Per-Phase Incremental Analysis

Reuse existing Phase 1–8 definitions. Each phase runs in the standard mode: **review existing → ask if changes → deep-dive changes**. Requirements sources are identical to initial analysis (interactive questioning, or parsed from user-provided document).

**Phase 1 — Vision & Context**
- **Review:** display baseline's Problem statement, Goals (with metrics), Scope boundary, Competitive landscape
- **Ask:** "Has the vision, goals, or competitive landscape changed?"
- **Deep-dive (if changes):** standard Phase 1 questioning flow. Changes cause README Problem & Goals / Evidence Base / Competitive Landscape sections to be rewritten.

**Phase 2 — Users & Journeys**
- **Review:** list all baseline personas and journeys (ID, name, persona, key touchpoints)
- **Ask:** "New personas? Journey changes? New journeys? Journeys to deprecate?"
- **Deep-dive:**
  - New persona → standard persona definition flow
  - New journey → standard journey deep-dive (happy path, error paths, alternative paths, metrics) using `journey-template.md`
  - Modified journey → display current journey details, walk through touchpoints to confirm what changes
  - Deprecated journey → confirm reason and replacement, check mapped features for impact
- **ID numbering:** new journeys get IDs continuing from baseline max (e.g. if baseline has J-001 through J-003, new journeys start at J-004)

**Phase 3 — Frontend Foundation** (skip if no user-facing interface)
- **Review:** display baseline's tech stack, design tokens, navigation architecture, a11y/i18n baselines
- **Ask:** "Any frontend infrastructure changes? (framework upgrade, new design tokens, navigation changes, etc.)"
- **Deep-dive (if changes):** standard Phase 3 questioning. Changes produce rewritten architecture topic files (design-tokens.md, navigation.md, etc.)

**Phase 4 — Features & Interaction Design**
- **Review:** list all baseline features (ID, name, type, priority, mapped journeys)
- **Ask:** "New features? Feature changes? Features to deprecate?"
- **Deep-dive:**
  - New feature → standard flow: user story extraction from journey touchpoints → grouping → interaction design using `feature-template.md`
  - Modified feature → display current feature details, walk through sections to confirm changes (requirements, AC, API contract, interaction design)
  - Deprecated feature → confirm reason and replacement, generate tombstone file
  - **Auto-derivation check:** if architecture conventions changed in Phase 3 or Phase 6, check whether Development Infrastructure and Deployment Infrastructure features need corresponding updates
- **ID numbering:** new features get IDs continuing from baseline max (e.g. if baseline has F-001 through F-011, new features start at F-012)

**Phase 5 — Interactive Prototype** (skip if no user-facing features)
- **Review:** list baseline features that have prototypes
- **Ask:** "Do new/modified user-facing features need prototypes?"
- **Deep-dive:** run prototype flow only for new and modified user-facing features. Unchanged feature prototypes stay in old PRD and are referenced.

**Phase 6 — Technical Architecture**
- **Review:** list all baseline architecture topic files with one-line key decision summaries
- **Ask:** "Any technical architecture changes? (new conventions, policy changes, security updates, etc.)"
- **Deep-dive:** discuss each changed topic individually. Changed topic files are fully rewritten into new PRD's architecture/ directory using `architecture-template.md` structure.

**Phase 7 — NFRs & Priority**
- **Review:** display baseline's impact/effort matrix and roadmap
- **Ask:** "What priority for new features? Any priority adjustments for existing features?"
- **Deep-dive:**
  - Assess impact/effort/priority for each new feature
  - Re-assess modified features if scope changed
  - Revalidate roadmap phase assignments (P0 → Phase 1, P1 → Phase 2, P2 → Phase 3)
  - Verify dependency ordering is still valid (no P0 depending on P1/P2 across phase boundaries)

**Phase 8 — Risks**
- **Review:** display baseline's risk list
- **Ask:** "Do these changes introduce new risks? Do existing risks need updates?"
- **Deep-dive:** standard risk identification (technical, dependency, data/compliance, scope, validation risks).

## Evolve Step 3 — Generate Incremental PRD Files

Generate files using the standard templates, with the following evolve-specific rules:

1. **README.md** — use `evolve-readme-template.md` instead of `prd-template.md`. Populate Baseline section, Change Summary, and complete indexes mixing local files with baseline references.
2. **New features** — use `feature-template.md` as normal. Add evolve metadata header with Status = **Added**, Baseline = N/A.
3. **Modified features** — use `feature-template.md` for full rewrite. Add evolve metadata header with Status = **Modified**, Baseline = link to predecessor's version, Change summary = concise list. Add inline change markers (`[ADDED]`, `[MODIFIED]`, `[REMOVED]`) at relevant points in the body.
4. **Deprecated features** — create tombstone file per format in `evolve-readme-template.md`.
5. **New/modified journeys** — same rules as features: full rewrite using `journey-template.md` + evolve metadata header + inline markers.
6. **New/modified architecture topics** — same rules: full rewrite using `architecture-template.md` topic structure + evolve metadata header + inline markers.
7. **architecture.md** — incremental index listing all topics. Changed topics link to local files. Unchanged topics link to baseline.
8. **Prototypes** — only for new/modified user-facing features.
9. **Cross-link** — same as initial creation: backfill journey Mapped Feature columns, feature Deps, Cross-Journey Patterns. For items referencing baseline features/journeys, use relative paths to the baseline PRD directory.

**Output path:** `docs/raw/prd/YYYY-MM-DD-{product-name}/` (same product name, new date). Confirm path with user before writing.

## Evolve Step 4 — Review Checklist

Run a two-layer review:

**Layer 1 — Flattened view review:** mentally merge the incremental PRD with its baseline to form a complete product view. Run the full Review Checklist (see above) against this combined view. This catches issues like orphan features, broken traceability chains, or missing coverage.

**Layer 2 — Evolve-specific checks:**

| Dimension | Check |
|-----------|-------|
| Change annotation completeness | Every modified/added file has a metadata header (Status, Baseline, Change summary); every file's internal change points have inline tags; Change summary is consistent with inline tags; every deprecated feature has a tombstone |
| Reference validity | README Baseline.Predecessor path points to valid old PRD directory; all `→ baseline` links in Journey/Feature/Architecture indexes resolve to existing files; Baseline field links in changed files resolve correctly; tombstone Original links are valid |
| Incremental consistency | Feature/Journey IDs have no conflicts with baseline (new IDs > baseline max ID); changed features referencing changed architecture conventions point to this PRD's version (not old PRD); deprecated features removed from Feature Index/Roadmap/Cross-Journey Patterns; deprecated journeys' mapped features are handled (also deprecated, or remapped); README Change Summary matches actual files |
| Flatten integrity | Combined (flattened) view passes existing Review Checklist; new features' journey mappings exist in flattened journey set; new features' dependencies exist in flattened feature set; no references to deprecated items |

Fix issues directly in files, same as initial creation.

## Evolve Step 5 — User Review & Commit

Same as initial creation flow:

1. User reviews files
2. Fix any requested changes
3. Commit all files

**Commit message format:** `"PRD evolve: {product-name} — add F-012, modify F-003, deprecate F-005"` (list key changes)

**Post-commit cascade notification:**

```
Incremental PRD committed: {output path}

Change summary:
  Added:        {list of added features/journeys}
  Modified:     {list of modified features/journeys}
  Deprecated:   {list of deprecated features/journeys}
  Architecture: {list of changed topic files}

Next steps:
  If system-design exists → /system-design --revise {design-path} (propagate PRD changes)
  If no system-design     → /system-design {this PRD path}
```

## Change Annotation Convention (Evolve Mode)

All content types in evolve mode (features, journeys, architecture topics) use the same annotation system.

### File-level metadata header

Every changed or added file gets a metadata header table immediately after the title. This header is evolve-mode only — initial PRD files and revise-mode files do not use it.

**Modified file:**

| Field | Value |
|-------|-------|
| Status | **Modified** |
| Baseline | [{ID} in {predecessor-dir-name}]({relative-path-to-predecessor-file}) |
| Change summary | {concise list of what changed — maps to inline markers below} |

**Added file:**

| Field | Value |
|-------|-------|
| Status | **Added** |
| Baseline | N/A |

**Deprecated file (tombstone):** see tombstone format in `evolve-readme-template.md`.

### Inline change markers

Within the fully-rewritten file body, annotate specific change points using blockquotes with tags:

```
> **[ADDED]** {description of what was added}
```

```
> **[MODIFIED]** {description of what changed compared to baseline}
```

```
> **[REMOVED]** {description of what was removed and why}
```

```
> **[UNCHANGED]** {optional — only when explicitly calling out that something did NOT change is important for context}
```

### Available tags

| Tag | Meaning |
|-----|---------|
| `[ADDED]` | New content not present in baseline |
| `[MODIFIED]` | Content changed from baseline (include description of what changed) |
| `[REMOVED]` | Content removed from this item (include reason) |
| `[UNCHANGED]` | Optional — only when emphasizing "this did NOT change" matters for context |

### Annotation granularity

- **Section level** — if an entire section is new/modified, annotate after the section heading
- **Item level** — if only specific items within a section changed, annotate after those items
- **Don't annotate every line** — `[UNCHANGED]` is optional; most unchanged content needs no marker
- The file-level Change summary must be consistent with the inline markers (no omissions or extras)
