# Revise Mode (`--revise`)

Interactively modify an existing design — whether it's still pre-implementation or already being coded. Auto-detects downstream state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

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

Based on the mutability determination from Step 5 (not just Step 1 — Step 5's module-level check is the final decision):

**Modify in place** (Design Status is Draft/Finalized, OR Status is Implementing/Implemented but all affected modules are `—`):
1. Apply all changes directly to existing files
2. Append an entry to `REVISIONS.md` with Change Type = "In-place edit" (create the file using the template in `design-template.md` if this is the first revision, and add a link to it from README.md's References section)
3. Update all impacted files identified in Step 5

**New version** (any affected module has Impl `In progress` or `Done`):
1. Create new dated directory (e.g. `docs/raw/design/2026-04-10-{product-name}/`)
2. Copy all files from original directory (including any existing `REVISIONS.md`)
3. Apply changes to the new copy
4. Append an entry to `REVISIONS.md` (create it if absent) with Change Type = "New version", linking back to previous version's directory; add a link to `REVISIONS.md` from README.md's References section
5. Set `Design Input > Status` to `Finalized`; reset all module `Impl` to `—` (implementation restarts from new design)

## Step 7: Post-Change Review (Delta-Focused)

**Do NOT run the full Design Review checklist.** Run only the dimensions relevant to what actually changed. Load `design-review-checklist.md` only if you need to reference a dimension's exact wording.

**Always run (every revision):**
- **Consistency** — updated module interfaces match their callers; data models match API contracts
- **Version integrity** — REVISIONS.md entry is present; README References links to REVISIONS.md; all version paths resolve

**Run if modules were added, removed, restructured, or boundaries changed:**
- **Completeness** — every Feature still has module coverage; no orphan features
- **Dependency sanity** — no circular dependencies; Dependency Layering table still valid; no reverse-layer imports
- **PRD traceability** — every module still traces back to at least one Feature
- **Interaction completeness** — all cross-module interactions in README's Module Interaction Protocols are in sync with updated interfaces
- **Testability** — changed modules remain independently testable; test double strategies still valid
- **Enforcement coverage** — changed modules' Boundary Enforcement sections reference valid constraints

**Run if interfaces changed:**
- **API completeness** — API contracts referencing the changed interface have updated schemas, error codes, and examples
- **Frontend-backend contract alignment** — frontend modules' API call entries match the updated API contracts

**Run if NFR budgets were reallocated:**
- **NFR coverage** — all PRD NFRs still decomposed to at least one module; reallocated budgets don't exceed PRD-level targets

**Run if technology decisions changed:**
- **Convention translation** — README's Implementation Conventions patterns still valid for the changed stack; module Relevant Conventions updated to match

**Run if frontend modules changed:**
- **UI coverage** — changed frontend modules have complete UI Architecture sections
- **Frontend performance** — performance targets consistent with PRD NFRs after restructuring
- **Form implementation consistency** — form patterns still consistent across changed views
- **Analytics coverage** — all PRD analytics events still mapped to a responsible module

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
