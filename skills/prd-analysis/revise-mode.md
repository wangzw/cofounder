# PRD Revise Mode (`--revise`)

This file contains instructions for interactively modifying an existing PRD — whether it's still a draft or already finalized. Auto-detects PRD state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

Review Checklist dimensions are defined in `SKILL.md` — read that first.

---

## Revise Step 1 — Detect Downstream State & Confirm Intent

Auto-detect what has been built on top of this PRD, then confirm with the user.

**Auto-detection:**

1. **Check for design:** scan for a system-design directory whose `Design Input > Source` references this PRD path
2. **Check for implementation:** if a design exists, read its `Design Input > Status` field — `Implementing` or `Implemented` means code exists

**Detection algorithm:**
1. Extract the product slug from the PRD directory name: `YYYY-MM-DD-{slug}` -> `{slug}`
2. Scan `docs/raw/design/` for directories matching `*-{slug}/` -- if any exist, a design exists
3. For each matching design directory, read its README.md Module Index `Impl` column:
   - If any module has Impl = `In Progress` or `Done` -> implementation exists
   - If all modules have Impl = `—` -> design exists but no implementation
4. If no matching design directories found -> no downstream consumers (modify in place freely)

**Ask user to confirm detected state:**

> I detected the following downstream state for this PRD:
> - Design: {found at path / not found}
> - Implementation: {Status field value / N/A}
>
> Is this correct? If not, what's the actual state?

**Resolve action based on confirmed state:**

| Downstream State | Action |
|-----------------|--------|
| No design exists | Modify PRD files directly |
| Design exists, not implemented | Modify PRD files directly + append entry to `REVISIONS.md` (create the file if absent) describing what changed (so design can be updated accordingly) |
| Implementation exists (Status = Implementing or Implemented) | Create new PRD version (new dated directory); original untouched |

If the user disagrees with the auto-detection (e.g. "the design exists but is outdated and will be regenerated"), defer to user judgment.

## Revise Step 2 — Present PRD Overview

Read and summarize the current PRD so the user has context before describing changes:

- Product name and vision
- Personas and journey count
- Feature count by priority (P0/P1/P2) and roadmap phase
- Key risks and open items (if any)

## Revise Step 3 — Gather Changes (interactive, one at a time)

Ask the user to select change types (multiple allowed):

1. **Add requirement** — new feature, new journey, or new persona
2. **Modify requirement** — change existing feature behavior, scope, priority, or acceptance criteria
3. **Deprecate requirement** — remove a feature or journey that's no longer needed
4. **Environment change** — external shift (tech stack, competitor, regulation, user feedback) that affects existing requirements
5. **Convention/policy change** — change to developer conventions, test isolation, security policy, git strategy, code review, observability, performance testing, or other architecture-level policies

Then deep-dive each selected type:

**Add requirement:**
- What persona does this serve? (existing or new?)
- What journey does it belong to? (existing or new?)
- What touchpoint / pain point does it address?
- What's the expected priority (P0/P1/P2)?
- Does it depend on any existing features?
- Does any existing feature need to change to accommodate this?

**Modify requirement:**
- Which feature(s) / journey(s)?
- What specifically changes? (behavior, scope, priority, acceptance criteria, interaction design)
- Why the change? (new evidence, user feedback, technical constraint, scope adjustment)
- Is the change additive (extending behavior) or breaking (changing existing behavior)?

**Deprecate requirement:**
- Which feature(s) / journey(s)?
- Why? (no longer needed, superseded by another feature, too expensive, invalidated by evidence)
- What replaces it, if anything?

**Environment change:**
- What changed externally? (tech stack shift, new competitor, regulatory change, user research findings)
- Which existing features / journeys are affected?
- Does this change priorities?
- Are new features needed in response?

**Convention/policy change:**
- Which section(s) in architecture.md? (Coding Conventions / Test Isolation / Security Coding Policy / Git & Branch Strategy / Code Review Policy / Observability Requirements / Performance Testing / Development Workflow / Backward Compatibility / Shared Conventions / AI Agent Configuration / Deployment Architecture)
- What specifically changes? (new policy, relaxed policy, stricter policy, removed policy)
- Why the change? (incident, new team member onboarding friction, CI flakiness, security audit finding, performance regression, workflow bottleneck)
- Is this additive (new policy alongside existing ones) or breaking (changes behavior that existing features already follow)?
- Which features are most affected? (features that copy this convention into "Relevant conventions", or features whose tests/edge cases depend on this policy)

## Revise Step 4 — Impact Analysis & Conflict Detection

After gathering all changes, systematically trace their impact through the PRD.

**Impact propagation** — for each changed/added/deprecated item (feature, journey, or persona):

| Check | How |
|-------|-----|
| Journey impact | Which journeys reference the affected feature(s)? Do touchpoints need updating? If a journey itself changed, which features map to its touchpoints? |
| Dependency chain | Which features depend on the affected item? Which features does it depend on? |
| Cross-journey patterns | Does this change affect any documented cross-journey pattern? If a journey is added/removed, do patterns need re-evaluation? |
| Metrics impact | Does the affected item feed a Goal metric? Will removing/changing it leave a metric unmeasured? |
| Roadmap impact | Does this change affect phase ordering? Do dependencies still respect phase boundaries? |
| Risk impact | Does this change introduce new risks or invalidate existing mitigations? |
| Test impact | Which Acceptance Criteria, Edge Cases, and E2E Test Scenarios are invalidated or need updating? Which dependent Features' test cases need regression re-verification? List affected items by Feature/Journey ID |
| Design token impact | Does the change affect design tokens in architecture.md? If so, ALL features referencing those tokens are impacted — check every user-facing feature's Interaction Design section |
| Navigation impact | Does the change add/remove/rename screens? If so, architecture.md Navigation Architecture (site map, routes) and all affected features' Screen & Layout sub-sections need updating |
| Component contract impact | Does the change modify a shared component's contract? If so, check which features use that component and whether their state machines and interactions are still valid |
| Accessibility baseline impact | Does the change affect architecture.md's Accessibility Baseline? If so, every user-facing feature's Accessibility sub-section that references the baseline may need updating |
| i18n baseline impact | Does the change affect architecture.md's Internationalization Baseline (frontend or backend)? If frontend baseline changed, every user-facing feature's i18n sub-section and i18n key prefixes may need updating. If backend baseline changed (locale resolution, timezone handling), every backend feature returning user-visible text may need updating |
| Form specification impact | Does the change affect a feature's Form Specification (fields, validation, dependencies)? If so, check if the feature's state machine, acceptance criteria, and E2E Test Scenarios still cover the updated form behavior |
| Micro-interaction & motion impact | Does the change introduce, remove, or modify UI interactions? If so, check affected features' Micro-Interactions & Motion sub-sections for consistency with updated state machines and component contracts |
| Interaction mode impact | Does the change modify a journey's touchpoints or interaction patterns? If so, check that the Interaction Mode column is updated and that corresponding feature component contracts support the changed interaction mode |
| Prototype impact | Does the change invalidate existing prototypes? Mark affected prototypes as needing regeneration in the feature's Prototype Reference section (set Confirmed date to empty); after regeneration, overwrite old source in `prototypes/src/{feature-slug}/` and old screenshots in `prototypes/screenshots/{feature-slug}/`, then update Confirmed date |
| Coding conventions impact | Does the change affect architecture.md's Coding Conventions (e.g. new concurrency requirement, changed error handling policy)? If so, every feature's "Relevant conventions" section that copies those policies may need updating |
| Test isolation impact | Does the change affect architecture.md's Test Isolation policies (e.g. new resource isolation requirement, changed timeout defaults)? If so, affected features' Test Data Requirements sections may need updating |
| Development workflow impact | Does the change affect architecture.md's Development Workflow (e.g. new CI gate, changed prerequisites)? If so, check all features' Implementation Notes for consistency |
| Security policy impact | Does the change affect architecture.md's Security Coding Policy (e.g. new validation requirement, changed secret handling rules)? If so, every feature's edge cases and acceptance criteria should be checked for security-relevant scenarios |
| Backward compatibility impact | Does the change affect architecture.md's Backward Compatibility policy (e.g. new API version, changed migration strategy)? If so, affected features' API contracts and data model sections may need versioning annotations |
| Git & Branch Strategy impact | Does the change affect architecture.md's Git & Branch Strategy (e.g. changed merge strategy, new branch protection)? If so, features' Implementation Notes and Development Workflow CI gates may need updating |
| Code review policy impact | Does the change affect architecture.md's Code Review Policy (e.g. new review dimension, changed approval requirements)? If so, check if any feature's quality or testing criteria need alignment |
| Observability requirements impact | Does the change affect architecture.md's Observability Requirements (e.g. new mandatory event, changed alerting rules)? If so, affected features' Analytics & Tracking sections may need new events added |
| Performance testing impact | Does the change affect architecture.md's Performance Testing policy (e.g. new budget, changed regression threshold)? If so, affected features' non-behavioral acceptance criteria may need updating |
| AI agent configuration impact | Does the change affect architecture.md's AI Agent Configuration (e.g. new instruction file, changed structure policy, updated convention references)? If so, the Development Infrastructure feature's CLAUDE.md deliverable may need updating; check if instruction file references still point to valid convention files |
| Deployment architecture impact | Does the change affect architecture.md's Deployment Architecture (e.g. new environment, changed CD pipeline policy, updated rollback strategy, modified environment isolation)? If so, the Deployment Infrastructure feature's deliverables may need updating; check environment-specific configs, CD pipeline definitions, and isolation configurations |

**Conflict detection** — check for these types:

| Conflict Type | What to Check |
|---------------|---------------|
| Dependency conflict | New feature depends on a deprecated feature; modifying a feature breaks a dependent feature's assumptions |
| Priority conflict | A P0 depends on a P1/P2 (phase ordering violation); a new P0 isn't on any core journey happy path |
| Behavior conflict | New requirement contradicts an existing requirement (e.g. "data is public by default" vs. "data is private by default") |
| Scope conflict | Changes push total effort beyond stated MVP boundary without re-scoping |
| Coverage gap | Deprecating a feature leaves a journey touchpoint or pain point with no feature coverage |
| Metric orphan | Removing a feature that was the sole measurement point for a Goal metric |

Present findings to the user before proceeding:
- **Conflicts** — must be resolved before continuing (ask user how to resolve each one)
- **Impacts** — changes that propagate to other files, user confirms awareness
- **Warnings** — potential issues that don't block but should be acknowledged

## Revise Step 5 — Execute Changes

Based on the downstream state confirmed in Step 1:

**Modify directly (no design, or design exists but not implemented):**
- Update affected files in place
- If design exists: append an entry to `REVISIONS.md` summarizing what changed and why (create the file using the template in `prd-template.md` if this is the first revision, and add a link to it from README.md's References section) — this record helps the design update process (`/system-design --revise`) identify what PRD changes need to propagate

**Create new version (implementation exists):**
- Create new dated directory (e.g. `docs/raw/prd/YYYY-MM-DD-{product-name}/`)
- Copy forward unchanged files (including any existing `REVISIONS.md` from the previous version)
- Apply changes to affected files
- Append an entry to `REVISIONS.md` (create it if absent) linking back to the previous version's directory; add a link to `REVISIONS.md` from README.md's References section

In both cases:
- Update all cross-references (journey Mapped Feature columns, feature Dependencies, Cross-Journey Patterns "Addressed by Feature" column)
- Mark deprecated features clearly — remove the feature file and remove it from Feature Index, Roadmap, and any Mapped Feature references
- Re-derive affected User Stories if journey touchpoints changed (re-run Phase 4 Step 1 extraction for affected journeys only)

## Revise Step 6 — Post-Change Review

Run the full Review Checklist on the modified/new PRD, with special attention to:
- Traceability chain integrity after changes
- No orphan features (especially after deprecation)
- No uncovered touchpoints or pain points (especially after deprecation)
- Dependency ordering still valid after priority changes
- Cross-journey patterns still accurate
- All conflicts from Step 4 resolved
- Interaction Design sections consistent with any changed journeys (interaction modes, page transitions, state machines)
- Architecture-level baselines (a11y, i18n, design tokens) still consistent with per-feature sections after changes
- Prototype archival up to date (no stale screenshots or source for changed features)
- Developer convention sections (Coding Conventions, Test Isolation, Security Coding Policy, Git & Branch Strategy, Code Review Policy, Observability Requirements, Performance Testing, Development Workflow, Backward Compatibility) still consistent with per-feature "Relevant conventions" sections after changes
- Security Coding Policy changes reflected in affected features' edge cases (e.g. new input validation boundary → new edge case testing unauthorized input)
- Performance Testing budget changes reflected in affected features' non-behavioral acceptance criteria
- Code Review Policy changes aligned with features that have Reviewer-related user stories or acceptance criteria
- Observability Requirements changes reflected in affected features' Analytics & Tracking events
- Test Isolation policy changes reflected in affected features' Test Data Requirements sections
- Development Workflow changes (CI gates, prerequisites) reflected in affected features' Implementation Notes
- Backward Compatibility policy changes reflected in affected features' API Contracts and data model versioning annotations
- Git & Branch Strategy changes reflected in affected features' Implementation Notes and Development Workflow CI gates
- AI Agent Configuration consistency: instruction file structure policy still valid, convention references still point to existing files, maintenance triggers still aligned with changed conventions

Then proceed to user review → commit (same as initial creation flow steps 7-8).

**Commit message format:** describe the revision, e.g. "Revise PRD: add F-014 SSO, deprecate F-005, reprioritize F-008 to P0"

**Post-revise cascade notification:**

After committing the revision, check for downstream consumers and print applicable next steps:

1. **If a system-design exists for this PRD** (detected in Revise Step 1): print:
   ```
   ⚠ Downstream design exists: {design path}
   The following PRD sections changed: {list of changed sections}
   
   Next step: run system-design --revise {design path} to propagate these changes
     - Implementation Conventions may need re-translation
     - Module specs referencing changed conventions may need updating
   ```

2. **If no downstream design exists**: print only the standard next steps hint (same as initial creation).
