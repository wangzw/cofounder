# Revise Mode (`--revise`)

Interactively modify an existing design — whether it's still pre-implementation or already being coded. Auto-detects downstream state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

## Pre-Answered Mode (Automated / CI / Review-driven fix pass)

If the invocation prompt already provides answers to Steps 1–5 (downstream state confirmed, PRD change detection resolved, design overview skipped, change list enumerated, impact analysis resolved), **skip Steps 1–5 entirely** and jump directly to Step 6. Do not re-ask questions or re-run analysis that is already settled.

**Review-driven fix pass:** If `{design-dir}/.reviews/REVIEW-*.md` files exist (produced by `--review` Step 4), treat the newest as pre-answered input. Structural lint always runs first (Flow step 2 below) — this is unconditional, even when the REVIEW file came from a Step 1.5-enabled review that already stripped mechanical findings, because lint is cheap and catches any gaps the prior review missed. An observed 100-finding review typically reduces to ≤20 semantic findings after lint — the savings compound across Fix subagent clusters.

**DO NOT read the REVIEW file in the main agent.** For a design with ~20–40 modules the file routinely exceeds 800–1500 lines (~20–40k tokens) and, once loaded, stays in the main-agent prompt cache for every subsequent turn (15–20 turns × main-agent cache_read = the largest single avoidable cost line in a revise session). Delegate the read + cluster step to a Sonnet subagent and consume only its compact manifest.

**Flow:**

1. **Select the REVIEW file** — list `{design-dir}/.reviews/REVIEW-*.md`, sort by timestamp, pick the newest file that does NOT end in `.applied.md`. This is a directory-listing step (`Glob` / `Bash ls`), not a file read — the REVIEW body itself is not loaded into main context.
2. **Run structural lint first (unconditional)** — execute every check in `structural-lint.md` against the current design directory. Write findings to `.reviews/LINT-{timestamp}.md`. Fix all lint failures in place via `MultiEdit` / Fix subagent (same dispatch rules as Step 6's Fix subagents). Rename the LINT file to `.applied.md` once clean. This is identical to Step 7.0 below and MUST run before the Clustering Subagent — mechanical findings in the REVIEW file become no-ops after lint fixes land, dramatically reducing cluster count. **Stale-finding handling:** because lint fixes files before clustering runs, Fix subagents in Step 5 may encounter REVIEW findings whose anchor no longer matches (the gap was already fixed by lint). The Fix-subagent contract already covers this — they report `anchor not found: <anchor>` and move on, which is the correct behavior for already-fixed findings.
3. **Dispatch the Clustering Subagent** (see template below). It reads the REVIEW file, parses per-file findings, packs files into ≤3-file clusters, and returns a structured manifest. The manifest is typically **2–4k tokens** — small enough to stay in main context cheaply.
4. **Consume the manifest directly** — no further reads of the REVIEW file by the main agent. Use `cluster.target_files` and `cluster.dimensions_tagged` to drive Step 6 dispatch and Step 7 delta-review scoping.
5. **Jump to Step 6** and dispatch one Fix subagent per cluster using Template A (Template A points each Fix subagent at the REVIEW file itself — Fix subagents read only the sections they need).
6. **Step 7 delta-review scope** comes from the manifest's union of `dimensions_tagged` plus the always-run checks. Do not re-run dimensions the review already validated as passing. Step 7.0 (structural lint) is typically a fast no-op here because Step 2 already cleared it, but still run it — fixes applied in Step 5 can re-introduce mechanical regressions.
7. **After all edits succeed**, rename the consumed REVIEW file to `.reviews/REVIEW-{timestamp}.applied.md` (`Bash mv`) so it is not re-applied on a subsequent invocation. `.reviews/` is not version-controlled — the durable audit for this revision is the `REVISIONS.md` entry produced by Step 6.

**Clustering-Subagent dispatch template** (main agent emits this):

```
Cluster the findings in {REVIEW file absolute path} into fix batches.

Read the REVIEW file exactly once. Do not read any other file.

Parse every `### <relative path>` section under `## Per-File Findings`. For each section, count findings, collect the unique `Dimension:` tags, and note the severities present.

Produce clusters using these rules:
- Each cluster contains AT MOST 3 target files.
- Files are grouped within the same artifact class first (modules/*, api/*); do not mix classes within a cluster unless a class has <3 files left.
- Files with >8 findings get their own cluster (1 file only) — large edit counts replay more cache_read per turn.
- Preserve source order within a class (M-001..M-003, M-004..M-006, ...).
- Cross-file findings from the `## Cross-File Findings` section are NOT clustered — list them separately in `cross_file_findings` so the main agent can handle them inline after Fix subagents return.

Return the manifest as YAML inside a fenced code block, exactly this shape:

```yaml
review_file: <absolute path>
total_findings: <int>
critical: <int>
important: <int>
suggestion: <int>
clusters:
  - id: 1
    target_files:
      - <absolute path>
      - <absolute path>
    finding_counts: { critical: N, important: N, suggestion: N }
    dimensions_tagged: [<dimension 1>, <dimension 2>, ...]
  - id: 2
    ...
cross_file_findings:
  - dimension: <dimension>
    severity: <Critical|Important|Suggestion>
    one_line: <the finding text, no Fix line>
dimensions_tagged_union: [<every dimension that appears anywhere>]
```

**Forbidden:**
- Reading any file other than the REVIEW file.
- Grep/Glob/Bash exploration of the design directory.
- Emitting the `Fix:` text of individual findings — clusters carry only the list of target files and dimension tags; Fix subagents will read the REVIEW themselves for the edit text (Template A).
- Prose commentary outside the YAML block.

Absolute paths only (resolve them from the REVIEW's `Reviewed:` header + each `### <relative path>` header).
```

The main agent consumes the returned YAML as the cluster plan. Fix-subagent dispatches in Step 6 use `cluster.target_files` directly; Step 7 delta-review scope uses `dimensions_tagged_union`.

**Clustering-Subagent dispatch parameters:** Use `subagent_type: "general-purpose"` and `model: "sonnet"`. Do not use `Explore` (lightweight tier — will misparse the structured findings schema). Do not use `opus` (simple parsing + grouping is not top-tier work). Never pin a specific version.

## Step 1: Detect Downstream State & Confirm Intent

Read `Design Input > Status` field for the design-level state:

| Detected Status | Implication |
|----------------|------------|
| Draft / Finalized | No modules implemented — all changes can be applied in place |
| Implementing / Implemented | Some or all modules have been implemented — mutability depends on which modules are affected |

If Status is `Implementing` or `Implemented`, read the Module Index `Impl` column to build a per-module implementation map:

| Module | Impl | Mutable? |
|--------|------|----------|
| M-001 | Done | No — changes require new version |
| M-002 | In progress | No — changes require new version |
| M-003 | — | Yes — can modify in place |

Present the detected state (design-level + module-level map) to user and ask them to confirm. The user may correct the detected state (e.g. a module shows `—` but has actually been implemented informally).

**Key rule:** the final mutability decision is made in Step 6 after impact analysis reveals which modules are actually affected by the changes.

## Step 2: Check for PRD Changes

If the design has a Source PRD, proactively detect upstream changes:

- **In-place edits:** read the source PRD's `REVISIONS.md` (if present). If entries exist with dates after the design's Date, summarize the PRD changes and ask which ones affect the design.
- **New PRD version:** scan for newer dated PRD directories with the same product name (e.g. if Source points to `docs/raw/prd/2026-03-01-foo/`, check for `docs/raw/prd/2026-04-*/foo/` or later). If a newer version exists, alert the user: "A newer PRD version exists at {path}. Should this design be updated against the new version?" If yes, read the new PRD's `REVISIONS.md` for the change summary.

If PRD changes are detected, they feed into Step 4 as change inputs alongside user-initiated changes.

## Step 3: Present Design Overview

Show the current design state to orient the user before gathering changes:

- Module index (ID, name, type, complexity, dependencies, Impl status)
- Key technical decisions summary
- Feature-Module mapping matrix
- NFR allocation summary

This helps the user point to specific areas they want to change — and see which modules are already implemented (not mutable) vs. still open for in-place modification.

## Step 4: Gather Changes

Changes come from three sources: PRD changes (Step 2), review findings (`--review` output), or user-initiated improvements. For each change, classify by type and ask deep-dive questions:

| Change Type | Description | Deep-Dive Questions |
|-------------|-------------|-------------------|
| Module restructure | Split, merge, rename, or change module boundaries | Which modules? What's wrong with current boundaries? What responsibilities move where? |
| Interface change | Modify a module's public interfaces — parameters, return types, error types | Which interface? What's the current contract? What should it become? Who are the callers? |
| Technology decision change | Swap database, framework, library, or communication pattern | Which decision from Key Technical Decisions? Why reconsider? What are the new options and trade-offs? |
| NFR reallocation | Change performance budgets, security requirements, or scalability targets across modules | Which NFR? Current budget allocation? Why is it wrong? Proposed new allocation? |
| Add module | New module for new requirements or extracted from existing module | What responsibility? Which features does it serve? What type (backend/frontend/shared)? Dependencies? |
| Remove module | Module no longer needed — responsibilities absorbed elsewhere or feature deprecated | Which module? Where do its responsibilities go? What about its callers? |
| Upstream PRD convention change | PRD architecture.md convention policies were updated (via prd-analysis --revise); need to re-translate Implementation Conventions to match updated policies | Which PRD convention sections changed? (read PRD's `REVISIONS.md` to identify). For each changed section: does the current Implementation Conventions translation still match the updated policy? Which modules reference the affected Implementation Conventions patterns? Do any module Relevant Conventions sections need updating? |

For each change, ask one question at a time. Confirm each change before moving to the next.

## Step 5: Impact Analysis & Conflict Detection

**Impact propagation** — for each change, systematically trace through these dimensions:

| Dimension | What to Check | How |
|-----------|--------------|-----|
| Dependency chain | Modules that depend on the changed module | Read changed module's dependents from Module Index Deps column and Module Interaction Protocols caller/callee |
| Interaction protocols | Cross-module interactions that reference the changed module | Scan README's Module Interaction Protocols table for entries involving the changed module |
| API contracts | API specs that expose the changed module's functionality | Scan API Index for APIs that route to the changed module |
| Feature-Module mapping | Features mapped to the changed module | Read Feature-Module Mapping matrix column for the changed module |
| NFR budget | NFR allocations that include the changed module | Read NFR Allocation table for rows listing the changed module as Primary or Supporting |
| View/Screen mapping | Views owned by changed frontend modules | Read View / Screen Index for views with the changed module as Primary Module |
| Dependency Layering | Module restructure or new dependencies violate layer order | Verify changed module's dependencies still comply with README's Dependency Layering table; check if new module needs layer assignment |
| Prototype mapping | Does the change affect modules with Reuse/Refactor prototype components? | Read Prototype-to-Production Mapping for entries targeting changed modules; Action may need updating |
| Frontend performance | Does module restructuring affect bundle size budgets or code splitting boundaries? | Check changed frontend modules' performance targets and code splitting strategy |
| Design token mapping | Does the change affect how PRD design tokens are implemented in code? | Read module's Design System Usage section and README's Design System Conventions table; check if token implementation (CSS var file, Tailwind config path, theme object structure) is impacted |
| Routing & code splitting | Do routing or lazy-load boundaries change, affecting bundle size targets or prefetch strategy? | Check all frontend modules' Routing tables; verify code splitting targets still valid after restructuring |
| State management structure | Do store structure, selectors, or sync strategies change, affecting other modules' state consumption? | Read all State Management tables across frontend modules; trace if changed module's state exports are consumed elsewhere; verify sync strategies compatible |
| Form pattern changes | Does the change affect form library, validation strategy, or error display across views? | Scan all frontend modules for form-related Key Interactions entries; if form strategy in Design System Conventions changed, verify all consumers updated |
| Component structure | Does the change affect a module's component tree, requiring child components to move or be reorganized? | Read changed module's Component Tree section; check if child components are referenced by other modules or views |
| Frontend-backend contracts | Do API endpoint calls, payloads, or response parsing change in affected frontend modules? | Cross-reference changed frontend modules' State Management (source: API call entries) with API Index; verify endpoint signatures match and consumers are updated |
| Key interactions | Does the change affect UI interaction flows (triggers, side effects, optimistic updates)? | Read Key Interactions tables in affected frontend modules; check if interaction flows are still consistent with module interfaces and state management |
| Accessibility implementation | Does the change affect a11y implementation (tab order, ARIA, testing approach) in frontend modules? | Read Accessibility Implementation sections in affected frontend modules; verify tab order, ARIA roles, and testing approach still valid after changes |
| i18n implementation (frontend) | Does the change affect i18n strategy (namespace, lazy loading, fallback) in frontend modules? | Read i18n Implementation sections in affected frontend modules; verify namespace mappings and lazy loading still align with routing and module structure |
| i18n implementation (backend) | Does the change affect backend i18n (locale resolution, message catalog, timezone conversion)? | Read Backend i18n Implementation sections in affected backend modules; verify locale context propagation still works across changed module boundaries; check if message catalog access pattern is consistent |
| Analytics coverage | Does the change affect which module is responsible for analytics events? | Read README's Analytics Coverage table; verify events mapped to changed modules still have a responsible owner after restructuring |
| Implementation conventions | Does the technology decision change affect convention translation patterns? If so, read README's Implementation Conventions section; verify all patterns still valid for the changed stack; update module Relevant Conventions accordingly | Read README's Implementation Conventions table; cross-reference with changed technology decisions; verify each pattern's Implementation Pattern and Enforcement columns are still valid; check all module-level Relevant Conventions that reference affected patterns |

**Module mutability check** — after tracing impact, collect all affected modules (directly changed + impacted). Cross-reference each with the module implementation map from Step 1:

| Affected Module | Impl | Mutable? |
|----------------|------|----------|
| M-001 (directly changed) | — | Yes |
| M-003 (impacted: dependency chain) | Done | No |

If ANY affected module is not mutable (`In progress` or `Done`), the entire change set must create a new version — a design directory must remain a coherent unit. Present this determination to the user before proceeding.

Present impact summary to user as a table:

| Changed Item | Impacted Item | Dimension | Impl | Required Action |
|-------------|--------------|-----------|------|----------------|
| M-001 interface change | M-003 (caller) | Dependency chain | Done | Update M-003's call to match new interface |
| M-001 interface change | API-002 | API contract | N/A | Update request/response schema |

`Impl` column: module items show their implementation status (`—` / `In progress` / `Done`); non-module items (API contracts, README sections) show `N/A`.

**Conflict detection** — check for these conflict types after tracing impact:

| Conflict Type | Detection Rule | Example |
|---------------|---------------|---------|
| Interface incompatibility | Changed module's interface no longer matches what callers expect | M-001 returns `TaskResult` but M-003 still expects `string` |
| Circular dependency | Restructuring introduces a dependency cycle | M-001 → M-002 → M-003 → M-001 |
| NFR budget overflow | Reallocated module budgets exceed the PRD-level NFR target | P99 modules sum to 600ms but PRD target is 500ms |
| Feature coverage gap | A feature loses module coverage after changes | F-003 mapped to removed M-004, no replacement assigned |
| Interaction protocol mismatch | Module Interaction Protocols inconsistent with updated module interfaces | Protocol says sync call but module now emits async event |
| View orphan | A view loses its primary module owner after frontend module changes | Dashboard view's primary module M-002 was merged into M-001 |

If conflicts are detected, present them and ask user how to resolve before proceeding. Each conflict must be resolved or explicitly accepted as a known trade-off.

## Step 6: Execute Changes

### Batch by File (Required)

Before making any edits, **group all pending changes by target file**. For each file, collect every change that applies to it, then read the file once, apply all changes in a single pass, and write it once. Never read or write a file more than once per revision cycle. Per-finding sequential edits cause O(n) file re-reads and dramatically increase cost.

**Grouping procedure:**
1. List all changes (from Step 4 or from the pre-answered findings list).
2. For each change, identify the target file(s) it affects.
3. Build a file → [changes] map.
4. Process each file in the map: read → apply all its changes → write.
5. After all files are processed, handle cross-reference updates (README Module Index, Feature-Module Mapping, Interaction Protocols, API Index) as a final sweep — also one read-and-write per cross-reference file.

**Parallelism:** If the change set is large (>15 changes), group files into independent clusters (`modules/*`, `api/*`, `README.md`) and process clusters in parallel where no cluster's output is an input to another cluster's edit. For example: fix all module files in parallel, then fix API files that reference those modules, then update README cross-references.

**Cluster sizing:** each Fix subagent handles **at most 3 files**. Larger clusters balloon the per-turn cache_read: a 5-file cluster doing 40 edits across 40 turns replays ~165k context per turn; splitting into 3-file clusters caps the replay at ~60k. Bias toward more smaller clusters (dispatched in parallel) over few large clusters.

### Fix-Subagent Dispatch Rules

**Model tier:** Fix subagents MUST be dispatched with `model: sonnet` (the mid-tier alias). Edit application is a deterministic text transformation — the top tier's reasoning budget is not needed and is materially more expensive per token. Only escalate to `opus` for a finding explicitly tagged as requiring cross-module design judgment (rare; must be justified in the dispatch prompt). Use aliases (`sonnet` / `opus` / `haiku`), never pin a specific version — aliases track the current tier member and avoid rot as models evolve.

**Tool usage:** when a file has **>1 queued edit**, the subagent MUST use `MultiEdit` (one tool call, one write). Sequential `Edit` calls on the same file are forbidden — each Edit triggers a cache_read replay of the full conversation state, which dominates cost on long-running edit sessions. One `Edit` only when a file has exactly one change.

When delegating a cluster to a `general-purpose` subagent, the dispatch prompt MUST use this template. Free-form prompts lead to the subagent re-reading files and running its own Glob/Grep to re-discover the change set — both are pure waste.

If a `.reviews/REVIEW-*.md` was consumed (Pre-Answered Mode), prefer **Template A** (reference-based, short). Otherwise use **Template B** (inline edits list).

**Template A — reference-based dispatch** (when REVIEW-*.md exists):

```
Apply the findings from {REVIEW-*.md absolute path} that target the files listed below.
The REVIEW file groups findings by file under `### <relative path>` headings; each finding has a `Fix:` line describing the concrete edit.

Read each target file exactly once (in parallel). For each file, collect all matching findings from the REVIEW file, then apply them in a single pass:
- file with 1 finding: use `Edit`
- file with >1 finding: use `MultiEdit` (mandatory — no sequential Edits on the same file)
Write once per file.

**Forbidden:**
- Re-reading a target file after editing it (no "verification read").
- Sequential `Edit` calls on the same file — use `MultiEdit` when >1 edit applies.
- Grep/Glob exploration — all paths are listed below.
- Editing files not listed below.
- Applying findings for files not in your list.

**Target files (read in parallel):**
- <absolute path 1>
- <absolute path 2>
- <absolute path 3>

**On completion**, report per-file: "applied N edits" or "file not found" or "anchor not found: <anchor>". No prose summary.
```

**Template B — inline edits** (interactive revise, no REVIEW-*.md):

```
Apply the following edits. Each file is listed with its queued edits.
Read each file exactly once (in parallel). Apply all edits in a single pass. Write once.

**Tool usage (mandatory):**
- file with 1 edit: use `Edit`
- file with >1 edit: use `MultiEdit` (one call with all edits). Sequential `Edit` on the same file is FORBIDDEN.

**Forbidden:**
- Re-reading a file after editing it (no "verification read").
- Grep/Glob exploration of the target directory — all paths are listed below.
- Editing files outside the list below.
- Making edits not listed below (even if you spot an adjacent issue — report it instead).

**Target files & queued edits:**

- file: <absolute path>
  edits:
    - <unique anchor text from current file>: replace with <new text>
    - <unique anchor text>: replace with <new text>
    - ...

- file: <absolute path>
  edits:
    - ...

**On completion**, report per-file: "applied N edits" or "file not found" or "anchor not found: <anchor>". Do not report prose summaries of what changed — the edits list is the contract.
```

The orchestrator (main agent) owns the cluster plan — but how it is built depends on mode:

- **Pre-Answered Mode (REVIEW-*.md exists):** the orchestrator MUST delegate the read + group step to the Clustering Subagent described at the top of this file, and consume its YAML manifest. The orchestrator never reads the REVIEW body itself.
- **Interactive mode (Template B):** the orchestrator already has the change list in context from Step 4, so it pre-materializes every edit and dispatches directly. No Clustering Subagent is needed.

When using Template A, Fix subagents extract the exact edit text from the REVIEW file they read; when using Template B, the orchestrator pre-materializes every edit. Do not push cluster-composition into Fix subagents in either mode.

---

Based on the mutability determination from Step 5 (not just Step 1 — Step 5's module-level check is the final decision):

**Modify in place** (Design Status is Draft/Finalized, OR Status is Implementing/Implemented but all affected modules are `—`):
1. Apply all changes directly to existing files (using the batch-by-file procedure above)
2. Append an entry to `REVISIONS.md` with Change Type = "In-place edit" (create the file using the template in `design-template.md` if this is the first revision, and add a link to it from README.md's References section)
3. Update all impacted files identified in Step 5

**New version** (any affected module has Impl `In progress` or `Done`):
1. Create new dated directory (e.g. `docs/raw/design/2026-04-10-{product-name}/`)
2. Copy all files from original directory (including any existing `REVISIONS.md`; do NOT copy `.reviews/` — it is transient scratch)
3. Apply changes to the new copy (using the batch-by-file procedure above)
4. Append an entry to `REVISIONS.md` (create it if absent) with Change Type = "New version", linking back to previous version's directory; add a link to `REVISIONS.md` from README.md's References section
5. Set `Design Input > Status` to `Finalized`; reset all module `Impl` to `—` (implementation restarts from new design)

## Step 7: Post-Change Review (Delta-Focused)

**Do NOT run the full Design Review checklist.** Run only the dimensions relevant to what actually changed. Load `design-review-checklist.md` only if you need to reference a dimension's exact wording.

Step 7 has three ordered sub-steps — **7.0 structural-lint gate** (mandatory first), **7.1 semantic regression sweep** (always run), and **7.2 change-scoped semantic checks** (conditional on what changed). Do not skip 7.0 or 7.1 under any circumstances; 7.2 may skip blocks whose trigger condition did not fire this revision.

**Review-driven fix pass scope:** If this revision consumed a `.reviews/REVIEW-*.md` file (Pre-Answered Mode), the delta review scope is:

- Mandatory: 7.0 structural lint + 7.1 semantic sweep (both below).
- Additional: 7.2 dimensions matching tags that appeared in the consumed `REVIEW-*.md`. Many review tags now resolve upstream at 7.0 — any review finding under "API completeness", "Enforcement coverage", or the structural sides of "Interaction completeness / Analytics coverage / Convention translation / PRD traceability / Dependency sanity" is already fixed by the lint pass; do not re-run those in 7.2.

Per-file dimensions the review already validated as passing and that are NOT listed in 7.1 or triggered in 7.2 may be skipped.

**7.0 Structural lint gate (mandatory — first sub-step of Step 7):**

Before any semantic check runs, execute every check in `structural-lint.md` (L1..L5, X1..X8) against the revised design. Most mechanical regressions from fix batches — placeholder JSON re-introduced by a careless example replacement, a newly-added endpoint missing from a module's API Surface, a fresh `Deps` pair without a Module Interaction Protocols row, a CI-job name change that orphans a Boundary Enforcement row — are caught here deterministically.

Dispatch a single `general-purpose` + `sonnet` subagent if the design has >20 modules; otherwise the main agent runs the checks via `Grep` / `Bash`. Write aggregated failures to `{design-dir}/.reviews/LINT-{timestamp}.md` (create `.reviews/` if absent). For each failure, apply the fix in place (use `MultiEdit` when a file has ≥2 fixes), re-run the lint, and repeat until the output is empty. Rename the consumed LINT file to `.applied.md` on success.

**Do not proceed to the semantic sweep below until structural lint is clean.** A mechanical gap that reaches the semantic review will compound — it inflates review-finding counts, drowns out real blockers, and guarantees another `--revise` cycle.

*Note:* in Pre-Answered Mode, Step 2 of the Flow already ran lint to completion before the Clustering Subagent. Step 7.0 still runs here — it is typically a fast no-op but catches mechanical regressions introduced by Step 6's Fix subagents (e.g. an example JSON that got a new field added without the matching Response table update).

**7.1 Semantic cross-file regression sweep (every revision):**

After 7.0's structural lint is clean, fixes can still break semantic invariants that `grep` cannot evaluate. Run this sweep on every revision regardless of which dimensions the consumed review tagged:

- **Consistency** — updated module interfaces semantically match caller expectations (beyond type names — behavior, error propagation, retry semantics); data-model constraints match API contract validation rules
- **Version integrity** — REVISIONS.md entry is present; README References links to REVISIONS.md; all version paths resolve
- **Interaction completeness (semantic)** — structural lint X1 already verifies every Deps pair has a row; here verify each row's `Method`, `Data Format`, and `Error Strategy` cells make sense for the actual call pattern (sync vs async, retry vs fail-fast)
- **Convention translation (semantic)** — structural lint X3 verifies every PRD architecture topic has a row; here verify the row's `Implementation Pattern` still matches the current tech stack (e.g. a Go-specific pattern after switching to TypeScript is a semantic failure the lint will not catch)
- **Analytics coverage (semantic)** — structural lint X4 verifies every event has a row or sweep match; here verify the `Emitting Channel` and `Responsible Module` remain appropriate after module restructuring
- **Dependency sanity (semantic)** — structural lint X6 verifies no reverse-layer imports; here verify the Dependency Layering *layer assignments* still reflect architectural intent (a module that moved from Service to Runtime changes the layer's semantic meaning)

If any semantic sweep dimension fails, treat it as blocking and fix before Step 8. Do not defer sweep failures to the next revision cycle — that is how regression compounds.

**7.2 Change-scoped semantic checks:**

Run only when the trigger condition for a block fired this revision. Dimensions listed below focus on **semantic** aspects that structural lint cannot evaluate. The structural sides (row presence, column fill, path resolution) are already covered by 7.0 and are not repeated here.

**Run if modules were added, removed, restructured, or boundaries changed:**
- **Completeness** — every Feature still has *meaningful* module coverage (not just a mapping matrix entry but substantive implementation); no orphan features
- **PRD traceability** — every module still traces back to at least one Feature with a plausible responsibility match (not a vestigial `Source Features:` header from a deleted mapping)
- **Testability** — changed modules remain independently testable; test double strategies still match the new dependency graph
- **Dependency sanity (semantic)** — layer assignment still reflects architectural intent after restructuring; a module that moved across layers did not silently change the layer's meaning (lint X6 already caught reverse-layer edges)
- **Interaction completeness (semantic)** — Method/Data Format/Error Strategy cells on Protocols rows still make sense after restructuring (lint X1 already caught missing rows)

**Run if interfaces changed:**
- **Consistency** — caller behavior, error propagation, retry semantics match the new interface beyond just type-name agreement
- **Frontend-backend contract alignment (semantic)** — frontend error handling and response parsing remain correct for the updated contract's error codes and response shape (lint X2 already caught dangling endpoint literals)

**Run if NFR budgets were reallocated:**
- **NFR coverage** — all PRD NFRs still decomposed to at least one module; reallocated budgets don't exceed PRD-level targets; budget distribution makes architectural sense (e.g. I/O-bound operation's budget isn't dominated by CPU-bound modules)

**Run if technology decisions changed:**
- **Convention translation (semantic)** — README's Implementation Conventions patterns still valid for the changed stack (e.g. after Go→TypeScript switch, `fmt.Errorf` pattern must be replaced); module Relevant Conventions updated to match (lint X3 already caught topic-row omissions)

**Run if frontend modules changed:**
- **UI coverage** — changed frontend modules have complete UI Architecture sections and views map back to PRD journey touchpoints
- **Frontend performance** — performance targets consistent with PRD NFRs after restructuring
- **Form implementation consistency** — form patterns still consistent across changed views
- **Analytics coverage (semantic)** — Emitting Channel / Responsible Module assignments remain appropriate after restructuring (lint X4 already caught missing rows)

Fix any issues found. Present change summary to user.

## Step 8: User Review

User reviews the changed files, confirms or requests further changes.

## Step 9: Commit

Commit with a descriptive message (e.g. "Revise design: restructure M-001/M-002 boundary, update API-002 contract").

### Post-Revise Cascade Notification

After committing the revision, check for downstream implementation and print applicable next steps:

1. **If implementation exists** (detected in Revise Step 1 via design Status field = "Implementing" or "Implemented"): print:
   ```
   ⚠ Implementation exists for this design.
   The following modules changed: {list of changed module specs}

   Next step: re-run autoforge for affected modules
     autoforge --cleanup {plan path} && autoforge {design path} (full re-run)
   ```

2. **If no implementation exists**: print only the standard next steps hint.
