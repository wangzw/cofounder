# PRD Evolve Mode (`--evolve`) — Domain Conventions

**Scope.** This file documents the **domain-content conventions** that apply when generating
an incremental PRD for a new software iteration on top of a delivered baseline: how to flatten
the version chain, how to ask delta-aware questions per phase, what evolve-specific metadata
and inline change markers look like, the two-layer review checklist, and the commit /
post-commit cascade format.

**Orchestration lives elsewhere.** The dispatch sequence (git precheck → phase-entry verify →
prepare-input → glossary probe → planner sub-agent → HITL plan-approval → writer fan-out →
review loop) is defined in `generate/new-version.md`. This file does **not** define an
alternate orchestration path; the section headers below describe domain-content concerns
that the planner, writer, and reviewer sub-agents (dispatched by `new-version.md`) consult
when their work touches evolve semantics.

For evolve mode, also read `generate/questioning-phases.md` — the per-phase questioning guide is reused
with a "review existing → ask delta → deep-dive" pattern.

Review checklist dimensions are defined in `common/templates/review-checklist.md` — load it on demand
(see "Evolve Review Checklist (Two-Layer)" below for which dimensions apply when).

---

**When to use `--evolve` vs `--revise`:**
- `--revise`: small corrections or adjustments to an existing PRD (edits in place)
- `--evolve`: new iteration/release cycle — existing features should be (partially) implemented,
  and you need a new PRD reflecting the next round of requirements

---

## Baseline Loading & Flattening

1. **Read the specified baseline PRD directory**, validate structural integrity (`README.md`,
   `journeys/`, `features/`, `architecture/` exist).
2. **Detect version chain** — read the baseline `README.md`. If a `Baseline` section exists with
   a `Predecessor` field, the baseline is itself incremental. Recursively read the predecessor
   chain.
3. **Flatten in memory** — merge all predecessors to build "current complete product state":
   - Features: later PRD's version overwrites the same-ID feature in the parent. A tombstone
     (deprecated) removes the feature from the flattened view.
   - Journeys: same rules as features.
   - Architecture topics: later PRD's topic file overwrites the same-name file in the parent.
   - README sections (Problem & Goals, Users, Risks, Roadmap): if the later PRD rewrites a
     section it overwrites; otherwise the parent version is kept.
   - Personas: accumulated from all PRDs; later PRD's persona table overwrites if changed.

**Flattening algorithm (pseudocode):**

```
function flatten(current_prd_path):
    baseline = read(current_prd_path / "README.md").Baseline.Predecessor
    if baseline is None:
        return read_all_files(current_prd_path)   # base case: original PRD

    parent  = flatten(baseline)                    # recursive: flatten predecessor first
    current = read_all_files(current_prd_path)

    merged = copy(parent)
    for item in current.features:
        if item.status == "Deprecated":
            merged.features.remove(item.id)        # tombstone removes from baseline
        else:
            merged.features[item.id] = item        # new/modified overwrites same-ID

    for item in current.journeys:
        merged.journeys[item.id] = item            # same logic as features

    for topic in current.architecture:
        merged.architecture[topic.name] = topic    # changed topics overwrite

    # IDs: new items use max(merged.*.id) + 1 to avoid collisions
    return merged
```

**Edge cases:**
- Feature deprecated in version N then re-added in version N+1: the re-add creates a **new**
  feature ID. The old ID remains marked deprecated in the chain — it is never reused.
- Duplicate IDs across versions: flattening always takes the latest version's entry, resolving
  duplicates by recency.

4. **Present baseline summary to user:**

> Baseline loaded {if chain: "(chain: 2026-01-15 → 2026-03-20 → current flattened)"}
> - Product: {name} — {vision}
> - Personas: {count} ({list names})
> - Journeys: {count} ({list IDs and names})
> - Features: {count} — P0: {n}, P1: {n}, P2: {n} ({list IDs and names per priority})
> - Architecture topics: {count changed in latest iteration} / {total count}
>
> Is this baseline correct?

Wait for user confirmation. If the user corrects something (e.g. "F-005 was actually deprecated
informally"), adjust the baseline accordingly before proceeding.

---

## Per-Phase Incremental Analysis Patterns

Reuse the Phase 1–8 definitions from `generate/questioning-phases.md`. Each phase runs in the pattern:
**review existing → ask if changes → deep-dive changes**. Requirements sources are identical to
initial analysis (interactive questioning, or parsed from a user-provided document).

**Phase 1 — Vision & Context**
- **Review:** display baseline's Problem statement, Goals (with metrics), Scope boundary,
  Competitive landscape.
- **Ask:** "Has the vision, goals, or competitive landscape changed?"
- **Deep-dive (if changes):** standard Phase 1 questioning flow. Changes cause README Problem &
  Goals / Evidence Base / Competitive Landscape sections to be rewritten.

**Phase 2 — Users & Journeys**
- **Review:** list all baseline personas and journeys (ID, name, persona, key touchpoints).
- **Ask:** "New personas? Journey changes? New journeys? Journeys to deprecate?"
- **Deep-dive:**
  - New persona → standard persona definition flow.
  - New journey → standard journey deep-dive (happy path, error paths, alternative paths,
    metrics) using `common/templates/journey-template.md`.
  - Modified journey → display current journey details, walk through touchpoints to confirm
    what changes. **Cascade check:** if a journey change removes or re-scopes a touchpoint,
    identify all features that map to that touchpoint and queue them for Phase 4 review.
  - Deprecated journey → confirm reason and replacement. **Cascade check:** all features
    exclusively mapped to the deprecated journey must either be deprecated or remapped to a
    surviving journey before Step 3.
- **ID numbering:** new journeys get IDs continuing from baseline max (e.g. if baseline has
  J-001 through J-003, new journeys start at J-004). IDs are never reused.

**Phase 3 — Frontend Foundation** *(skip if no user-facing interface)*
- **Review:** display baseline's tech stack, design tokens, navigation architecture, a11y/i18n
  baselines.
- **Ask:** "Any frontend infrastructure changes? (framework upgrade, new design tokens,
  navigation changes, etc.)"
- **Deep-dive (if changes):** standard Phase 3 questioning. Changes produce rewritten
  architecture topic files (`design-tokens.md`, `navigation.md`, etc.).
  **Cascade check:** if design tokens or navigation conventions change, queue all user-facing
  features for interaction-design review in Phase 4.

**Phase 4 — Features & Interaction Design**
- **Review:** list all baseline features (ID, name, type, priority, mapped journeys), including
  any queued from Phase 2/3 cascade checks.
- **Ask:** "New features? Feature changes? Features to deprecate?"
- **Deep-dive:**
  - New feature → standard flow: user story extraction from journey touchpoints → grouping →
    interaction design using `common/templates/feature-template.md`.
  - Modified feature → display current feature details, walk through sections to confirm
    changes (requirements, AC, API contract, interaction design).
  - Deprecated feature → confirm reason and replacement. Generate a tombstone file. Verify no
    surviving feature depends on the deprecated one.
  - **Cascade from architecture changes:** if Phase 3 or Phase 6 changed conventions, verify
    Development Infrastructure and Deployment Infrastructure features need corresponding
    updates.
- **ID numbering:** new features continue from baseline max (e.g. if baseline has F-001 through
  F-011, new features start at F-012). IDs are never reused.

**Phase 5 — Frontend Draft** *(REQUIRED for every new/modified user-facing feature; skip only if no user-facing features in this delivery's plan)*
- **Review:** list baseline features and their recorded Frontend Draft paths.
- **Run for every user-facing add/modify in the plan.** The orchestration hook lives in `generate/new-version.md` Step 8c (post-writer-fan-out, pre-review-entry); see that file for the dispatch sequence. This file describes only the domain content the user produces during the phase.
- **Deep-dive:** run the Phase 5 flow (`generate/questioning-phases.md` → Phase 5: Frontend Draft) for every new and modified user-facing feature. Modify their code at the baseline's Frontend Implementation Path **in place** — do not create a `prototypes/` directory under the evolved PRD. Unchanged features' drafts remain untouched and are referenced by their existing path. Production hardening (i18n / a11y / tests / lint / perf) for the modified draft is **not** a Phase 5 concern; it is folded into system-design's Production Promotion Plan.
- **Record outcome on the feature file.** After the user confirms the draft, populate the feature's `#### Frontend Draft Reference` subsection with `Draft path:` (concrete repo-relative path) and `Confirmed (experience): YYYY-MM-DD`. When the user explicitly defers the draft, set `Confirmed (experience): null` and add a sibling `Drift:` line explaining the deferral.
- **Convergence-time backstop:** `scripts/check-frontend-draft.sh` (rule **CR-PP-FD01**, registered in `common/review-criteria.md`) is auto-discovered by `run-checkers.sh` and fires inside `verify-phase-entry.sh read`. A delivery whose plan touched a user-facing feature CANNOT enter the review phase — and therefore cannot converge with `formal_pass: true` — until every affected feature file's Frontend Draft Reference is populated (or explicitly deferred via `null + Drift:`).

**Phase 6 — Technical Architecture**
- **Review:** list all baseline architecture topic files with one-line key-decision summaries.
- **Ask:** "Any technical architecture changes? (new conventions, policy changes, security
  updates, etc.)"
- **Deep-dive:** discuss each changed topic individually. Changed topic files are fully rewritten
  into the new PRD's `architecture/` directory using `common/templates/architecture-template.md` structure.

**Phase 7 — NFRs & Priority**
- **Review:** display baseline's impact/effort matrix and roadmap.
- **Ask:** "What priority for new features? Any priority adjustments for existing features?"
- **Deep-dive:**
  - Assess impact/effort/priority for each new feature.
  - Re-assess modified features if scope changed.
  - Revalidate roadmap phase assignments (P0 → Phase 1, P1 → Phase 2, P2 → Phase 3).
  - Verify dependency ordering is still valid (no P0 depending on P1/P2 across phase
    boundaries).

**Phase 8 — Risks**
- **Review:** display baseline's risk list.
- **Ask:** "Do these changes introduce new risks? Do existing risks need updates?"
- **Deep-dive:** standard risk identification (technical, dependency, data/compliance, scope,
  validation risks).

---

## Incremental File Generation Rules

Generate files using the standard templates, with the following evolve-specific rules:

1. **README.md** — use `common/templates/evolve-readme-template.md` instead of `common/templates/prd-template.md`. Populate the
   Baseline section, Change Summary, deprecated-item tombstone index, and complete indexes that
   mix local files with baseline cross-references.
2. **New features** — use `common/templates/feature-template.md` as normal. Add evolve metadata header with
   `Status = Added`, `Baseline = N/A`.
3. **Modified features** — use `common/templates/feature-template.md` for a full rewrite. Add evolve metadata
   header with `Status = Modified`, `Baseline = {link to predecessor's version}`, and a concise
   Change summary. Add inline change markers (`[ADDED]`, `[MODIFIED]`, `[REMOVED]`) at relevant
   points in the body.
4. **Deprecated features** — create a tombstone file per the format in
   `common/templates/evolve-readme-template.md`.
5. **New/modified journeys** — same rules as features: full rewrite using `common/templates/journey-template.md`
   plus evolve metadata header and inline markers.
6. **New/modified architecture topics** — same rules: full rewrite using `common/templates/architecture-template.md`
   topic structure, plus evolve metadata header and inline markers.
7. **`architecture/` index** — incremental index listing all topics. Changed topics link to
   local files; unchanged topics link to baseline.
8. **Frontend draft** — REQUIRED for every new/modified user-facing feature; modify the code at the baseline's Frontend Implementation Path in place. Update each affected feature file's `#### Frontend Draft Reference` (`Draft path:` + `Confirmed (experience): YYYY-MM-DD`). When Phase 5 is explicitly deferred for a feature, write `Confirmed (experience): null` plus a sibling `Drift:` line stating why. Do not create a `prototypes/` directory under the evolved PRD. Enforced at convergence time by **CR-PP-FD01**.
9. **Cross-links** — same as initial creation: backfill journey Mapped Feature columns, feature
   Deps, Cross-Journey Patterns. For items referencing baseline features/journeys, use relative
   paths to the baseline PRD directory.

**Output path:** `docs/raw/prd/YYYY-MM-DD-{product-name}/` (same product slug, new date).
Confirm path with user before writing any files.

### Batch by File (Required)

Before writing any files, **group all content by target file**. Generate each file's complete
content once, then write it. Never write a file more than once per evolve cycle. For large delta
sets (>10 files), write independent clusters in parallel: `features/*` and `journeys/*` in
parallel, then `architecture/*` in parallel, then `README.md` and cross-reference updates as a
final sweep.

---

## Evolve Review Checklist (Two-Layer)

Run a two-layer review. Load `common/templates/review-checklist.md` only when you need to reference a dimension's
exact definition.

**Layer 1 — Delta review (new and modified files only):** Do NOT re-check baseline files that
have not changed — they were reviewed at initial creation. Only run checklist dimensions relevant
to what actually changed in this evolve cycle.

**Always run (every evolve):**
- **Traceability** — no orphan features; every new/modified touchpoint maps to a feature;
  Cross-Journey Patterns updated for any new/changed journeys.
- **No ambiguity** — no TBD/TODO/vague descriptions in any new or modified file.
- **Version integrity** — README Baseline section and Change Summary are present and accurate;
  all `→ baseline` links valid.

**Run if features were added or modified:**
- **Priority** — new/modified feature priority aligns with roadmap phase; dependencies respect
  phase ordering; no P0 depending on a P1/P2 across phase boundaries.
- **Self-containment** — each new/modified feature file can be read and implemented
  independently (inline-copy rule enforced).
- **Testability** (sub-checks a, b, e, f only) — ACs precise; edge cases have Given/When/Then;
  error paths map to an AC or edge case; cross-feature dependencies have integration-level AC.

**Run if features were deprecated:**
- **Traceability** (focused) — no journey touchpoint left uncovered; no metric orphan; no
  surviving feature depends on the deprecated one; tombstone file present.

**Run if architecture conventions changed:**
- The single relevant architecture-completeness dimension for what changed (e.g.
  CR-PP40 coding-conventions-complete if `coding-conventions.md` changed).

**Run if UI changes (new/modified screens, components, interactions):**
- **Interaction Design coverage** — modified user-facing features have complete Interaction
  Design sections (CR-PP18).
- **State machine integrity** — no dead states; loading states have success and error exits
  (CR-PP24).
- **Accessibility per-feature** — modified user-facing features have Accessibility sub-sections
  (CR-PP29).
- **Frontend Draft Reference populated** — every new/modified user-facing feature carries a
  populated `#### Frontend Draft Reference` (or an explicit `Confirmed (experience): null` plus a
  sibling `Drift:` deferral). Mechanically enforced by **CR-PP-FD01** at the formal hard gate;
  the Layer-1 reviewer's role is only to confirm the recorded path matches what the user actually
  validated in Phase 5.

**Layer 2 — Evolve-specific checks:**

| Dimension | Check |
|-----------|-------|
| Change annotation completeness | Every modified/added file has a metadata header (Status, Baseline, Change summary); every file's internal change points have inline tags; Change summary is consistent with inline tags; every deprecated feature has a tombstone |
| Reference validity | README `Baseline.Predecessor` path points to valid old PRD directory; all `→ baseline` links in Journey/Feature/Architecture indexes resolve to existing files; Baseline field links in changed files resolve correctly; tombstone Original links are valid |
| Incremental consistency | Feature/Journey IDs have no conflicts with baseline (new IDs > baseline max ID); changed features referencing changed architecture conventions point to this PRD's version (not old PRD); deprecated features removed from Feature Index/Roadmap/Cross-Journey Patterns; deprecated journeys' mapped features are either also deprecated or remapped; README Change Summary matches actual files |
| Flatten integrity | Combined (flattened) view passes existing review checklist; new features' journey mappings exist in the flattened journey set; new features' dependencies exist in the flattened feature set; no references to deprecated items appear in surviving files |
| Cascade completeness | Every journey touchpoint removed or re-scoped in Phase 2 has a corresponding feature update or deprecation; every architecture convention change from Phase 3/6 is reflected in affected feature interaction-design sections |

Fix issues directly in files, same as initial creation.

---

## Commit Message & Post-Commit Cascade

After the `new-version.md` review loop converges and the user approves the bundle, the
orchestrator commits using the format below.

**Commit message format:**
`"PRD evolve: {product-name} — add F-012, modify F-003, deprecate F-005"` (list key changes)

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

---

## ID Stability Contract

ID stability is the core guarantee that makes evolve mode safe across multiple iterations.

| Rule | Detail |
|------|--------|
| **IDs are permanent** | Once assigned, a Feature or Journey ID is never reassigned to a different item, even after the original is deprecated |
| **IDs are monotonic** | New items always get `max(existing IDs) + 1`; gaps in the sequence are allowed (from tombstoned items) and MUST NOT be filled |
| **Tombstones preserve IDs** | A deprecated Feature/Journey retains its ID in the tombstone file so the deprecation event is traceable across the chain |
| **Re-adds create new IDs** | If a deprecated concept is revived in a later iteration it gets a new ID; the deprecated ID remains tombstoned |
| **Cross-PRD references use stable IDs** | Surviving features referencing a baseline feature use the baseline feature's stable ID in their Deps section, with a relative path to the baseline PRD directory |

---

## Change Annotation Convention

All content types in evolve mode (features, journeys, architecture topics) use the same
annotation system.

### File-Level Metadata Header

Every changed or added file gets a metadata header table immediately after the title. This header
is evolve-mode only — initial PRD files and revise-mode files do not use it.

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

**Deprecated file (tombstone):** see tombstone format in `common/templates/evolve-readme-template.md`.

### Inline Change Markers

Within a fully-rewritten file body, annotate specific change points using blockquotes with tags:

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

### Available Tags

| Tag | Meaning |
|-----|---------|
| `[ADDED]` | New content not present in baseline |
| `[MODIFIED]` | Content changed from baseline (include description of what changed) |
| `[REMOVED]` | Content removed from this item (include reason) |
| `[UNCHANGED]` | Optional — only when emphasizing "this did NOT change" matters for context |

### Annotation Granularity

- **Section level** — if an entire section is new/modified, annotate after the section heading.
- **Item level** — if only specific items within a section changed, annotate after those items.
- **Don't annotate every line** — `[UNCHANGED]` is optional; most unchanged content needs no
  marker.
- The file-level Change summary MUST be consistent with the inline markers (no omissions or
  extras).

---

## Tombstone Semantics

A tombstone is a minimal file that marks a Feature or Journey as deprecated. It is the only
artifact written to `features/` or `journeys/` for deprecated items in the evolve iteration.

**Required fields:**

| Field | Value |
|-------|-------|
| Status | **Deprecated** |
| Deprecated in | {YYYY-MM-DD PRD directory name} |
| Reason | {one-sentence justification} |
| Replacement | {ID + link to replacement Feature/Journey, or "None — capability removed"} |
| Original | [{ID} in {predecessor-dir-name}]({relative-path-to-original-file}) |

**Tombstone rules:**
- The tombstone file lives at the same path the full feature file would occupy (e.g.
  `features/F-005-slug.md`) so directory listings remain stable.
- Tombstone files are excluded from the Feature Index and Roadmap sections of the evolve README
  but listed in the Deprecated Items section.
- No content beyond the metadata table should appear in a tombstone — prose justification
  belongs in the Reason field.
- A tombstone is permanent: it is carried forward into all future evolve iterations by the
  flattening algorithm and is never removed or overwritten with live content.

---

## Cascade Rules

Cascade rules define which downstream artifacts must be updated when an upstream item changes.

| Trigger | Cascade target | Action required |
|---------|---------------|-----------------|
| Journey touchpoint removed or re-scoped | All features mapped to that touchpoint | Review each feature's user stories and ACs; modify or deprecate as needed |
| Journey deprecated | All features exclusively mapped to that journey | Must be deprecated (tombstoned) or remapped to a surviving journey before Step 3 |
| Design token changed (Phase 3) | All user-facing features referencing that token | Update Interaction Design section to use new token name/value |
| Navigation convention changed (Phase 3) | All journey files with affected screen/route names | Update touchpoint Screen/View column and route references |
| Architecture convention changed (Phase 6) | Development Infrastructure feature | Add or modify deliverable line for the changed convention |
| Feature deprecated | All features listing it as a dependency | Remove from Deps or replace with the designated successor feature |
| Priority re-assigned (Phase 7) | Roadmap section of evolve README | Re-bucket feature into correct phase; verify dependency ordering still holds |

Cascade checks are verified in Step 4 Layer 2 (Cascade completeness row). A missing cascade
update is a blocking issue — it must be fixed before user review.
