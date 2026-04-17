# PRD Revise Mode (`--revise`)

This file contains instructions for interactively modifying an existing PRD — whether it's still a draft or already finalized. Auto-detects PRD state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

Review Checklist dimensions are defined in `review-checklist.md` — load it on demand (Step 6 specifies when).

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

After gathering all changes, run **only the impact checks relevant to each change type**. Do not run checks for change types not present in this revision.

**Impact checks by change type:**

| Change Type | Run These Impact Checks |
|-------------|------------------------|
| **Add requirement** | Journey impact · Dependency chain · Cross-journey patterns · Metrics impact · Roadmap impact · Risk impact · Test impact |
| **Modify requirement — priority only** | Roadmap impact · Dependency chain (phase ordering) |
| **Modify requirement — behavior/scope/AC** | Journey impact · Dependency chain · Test impact · Prototype impact; plus conditionally: Design token impact (if tokens referenced), Navigation impact (if screens added/removed/renamed), Component contract impact (if shared component changed), Accessibility baseline impact (if a11y requirements changed), i18n baseline impact (if i18n requirements changed), Form specification impact (if form fields changed), Micro-interaction & motion impact (if animations/transitions changed), Interaction mode impact (if touchpoint interaction pattern changed) |
| **Deprecate requirement** | Journey impact · Dependency chain · Cross-journey patterns · Metrics impact · Risk impact · Prototype impact |
| **Environment change** | Risk impact · Metrics impact; then determine which additional checks apply based on the specific external change (tech stack shift → AI agent config impact; security/compliance → Security policy impact; competitor → note in risks only) |
| **Convention/policy change** | Run only the single convention category that changed: Coding conventions → Coding conventions impact + per-feature Relevant conventions; Test isolation → Test isolation impact + Test Data Requirements; Security policy → Security policy impact + edge cases; Backward compat → Backward compatibility impact + API contracts; Git strategy → Git & Branch Strategy impact + Implementation Notes; Code review policy → Code review policy impact; Observability → Observability requirements impact + Analytics events; Performance testing → Performance testing impact + non-behavioral AC; AI agent config → AI agent configuration impact; Deployment architecture → Deployment architecture impact + Deployment Infrastructure feature |

**Impact check definitions** (consult only the definitions relevant to your change types):

- **Journey impact** — Which journeys reference the affected feature(s)? Do touchpoints need updating? If a journey itself changed, which features map to its touchpoints?
- **Dependency chain** — Which features depend on the affected item? Which features does it depend on?
- **Cross-journey patterns** — Does this change affect any documented cross-journey pattern? If a journey is added/removed, do patterns need re-evaluation?
- **Metrics impact** — Does the affected item feed a Goal metric? Will removing/changing it leave a metric unmeasured?
- **Roadmap impact** — Does this change affect phase ordering? Do dependencies still respect phase boundaries?
- **Risk impact** — Does this change introduce new risks or invalidate existing mitigations?
- **Test impact** — Which Acceptance Criteria, Edge Cases, and E2E Test Scenarios are invalidated or need updating? Which dependent features' test cases need regression re-verification?
- **Design token impact** — Does the change affect design tokens in architecture.md? If so, check every user-facing feature's Interaction Design section for references to those tokens.
- **Navigation impact** — Does the change add/remove/rename screens? If so, update architecture.md Navigation Architecture and affected features' Screen & Layout sub-sections.
- **Component contract impact** — Does the change modify a shared component's contract? If so, check which features use that component and whether their state machines and interactions are still valid.
- **Accessibility baseline impact** — Does the change affect architecture.md's Accessibility Baseline? If so, affected user-facing features' Accessibility sub-sections may need updating.
- **i18n baseline impact** — Does the change affect architecture.md's Internationalization Baseline? If frontend baseline changed, check user-facing features' i18n sub-sections. If backend baseline changed, check backend features returning user-visible text.
- **Form specification impact** — Does the change affect a feature's Form Specification? If so, check whether the state machine, acceptance criteria, and E2E Test Scenarios still cover the updated form behavior.
- **Micro-interaction & motion impact** — Does the change introduce, remove, or modify UI interactions? If so, check affected features' Micro-Interactions & Motion sub-sections.
- **Interaction mode impact** — Does the change modify a journey's touchpoints or interaction patterns? If so, check that the Interaction Mode column is updated and corresponding feature component contracts support the changed mode.
- **Prototype impact** — Does the change invalidate existing prototypes? Mark affected prototypes as needing regeneration (set Confirmed date to empty); after regeneration, overwrite old source and screenshots, then update Confirmed date.
- **Coding conventions impact** — Which features copy affected policies into their "Relevant conventions" section? Update those inline copies.
- **Test isolation impact** — Which features' Test Data Requirements reference the changed policies? Update those sections.
- **Development workflow impact** — Which features' Implementation Notes reference the changed CI gates or prerequisites? Update those sections.
- **Security policy impact** — Which features' edge cases and acceptance criteria cover security-relevant scenarios affected by the change? Update those sections.
- **Backward compatibility impact** — Which features' API contracts and data model sections need versioning annotations for the changed strategy?
- **Git & Branch Strategy impact** — Which features' Implementation Notes and Development Workflow CI gates reference the changed strategy?
- **Code review policy impact** — Which features have Reviewer-related user stories or acceptance criteria that need alignment?
- **Observability requirements impact** — Which features' Analytics & Tracking sections need new or updated events for the changed requirements?
- **Performance testing impact** — Which features' non-behavioral acceptance criteria reference the changed budgets or thresholds?
- **AI agent configuration impact** — Does the Development Infrastructure feature's CLAUDE.md deliverable need updating? Do any convention file references still point to valid files?
- **Deployment architecture impact** — Does the Deployment Infrastructure feature's deliverables need updating for the changed environments, pipeline policy, or isolation configuration?

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

## Revise Step 6 — Post-Change Review (Delta-Focused)

**Do NOT run the full 52-dimension review checklist.** Run only the checklist dimensions relevant to what actually changed. Load `review-checklist.md` only if you need to reference a dimension's exact definition.

**Always run (every revision):**
- **Traceability** — no orphan features; every touchpoint still maps to a feature; Cross-Journey Patterns still accurate
- **No ambiguity** — no TBD/TODO/vague descriptions in modified files
- **Version integrity** — REVISIONS.md entry is present and correct; README References section links to REVISIONS.md; all `→ baseline` links valid if applicable
- **All conflicts from Step 4 resolved**

**Run if features were added or modified:**
- **Priority** — new/modified feature's priority aligns with roadmap phase; dependencies respect phase ordering
- **Self-containment** — modified feature file can be read and implemented independently
- **Testability** (sub-checks a, b, e, f only) — ACs are precise; edge cases have Given/When/Then; error paths map to an AC or edge case; cross-feature dependencies have integration-level AC
- **Scope boundary** — no implementation-level details crept into the modified feature

**Run if features were deprecated:**
- **Traceability** (focused) — no journey touchpoint or pain point left uncovered; no Metric orphan; no Dependency conflict (no remaining feature depends on the deprecated one)

**Run additionally if the change touches UI (screens, components, interactions):**
- **Interaction Design coverage** — modified user-facing features have complete Interaction Design sections
- **State machine integrity** — no dead states; every transition has system feedback; loading states have success and error exits
- **Component contract consistency** — shared components used by modified features have consistent contracts
- **Journey interaction mode coverage** — touchpoints in modified journeys have Interaction Mode specified
- **Accessibility per-feature** — modified user-facing features have Accessibility sub-sections
- **i18n per-feature — frontend** — modified user-facing features have no hardcoded strings

**Run additionally if architecture conventions changed:**
- The single relevant architecture completeness dimension (e.g., "Coding conventions completeness" if coding conventions changed)
- **Development infrastructure feature** — check that the concrete deliverable for the changed convention is still present and correct

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
