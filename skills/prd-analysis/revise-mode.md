# PRD Revise Mode (`--revise`)

This file contains instructions for interactively modifying an existing PRD — whether it's still a draft or already finalized. Auto-detects PRD state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

Review Checklist dimensions are defined in `review-checklist.md` — load it on demand (Step 6 specifies when).

---

## Pre-Answered Mode (Automated / CI / Review-driven fix pass)

If the invocation prompt already provides answers to Steps 1–4 (downstream state confirmed, PRD overview skipped, change list enumerated, impact analysis resolved), **skip Steps 1–4 entirely** and jump directly to Step 5. Do not re-ask questions or re-run analysis that is already settled.

**Review-driven fix pass:** If `{PRD-dir}/.reviews/REVIEW-*.md` files exist (produced by `--review` Step 4), treat the newest as pre-answered input.

**DO NOT read the REVIEW file in the main agent.** For a PRD with ~30–50 features the file routinely exceeds 800–1500 lines (~20–40k tokens) and, once loaded, stays in the main-agent prompt cache for every subsequent turn (15–20 turns × main-agent cache_read = the largest single avoidable cost line in a revise session). Delegate the read + cluster step to a Sonnet subagent and consume only its compact manifest.

**Flow:**

1. **Select the REVIEW file** — list `{PRD-dir}/.reviews/REVIEW-*.md`, sort by timestamp, pick the newest file that does NOT end in `.applied.md`. This is a directory-listing step (`Glob` / `Bash ls`), not a file read — the REVIEW body itself is not loaded into main context.
2. **Dispatch the Clustering Subagent** (see template below). It reads the REVIEW file, parses per-file findings, packs files into ≤3-file clusters, and returns a structured manifest. The manifest is typically **2–4k tokens** — small enough to stay in main context cheaply.
3. **Consume the manifest directly** — no further reads of the REVIEW file by the main agent. Use `cluster.target_files` and `cluster.dimensions_tagged` to drive Step 5 dispatch and Step 6 delta-review scoping.
4. **Jump to Step 5** and dispatch one Fix subagent per cluster using Template A (Template A points each Fix subagent at the REVIEW file itself — Fix subagents read only the sections they need).
5. **Step 6 delta-review scope** comes from the manifest's union of `dimensions_tagged` plus the always-run checks. Do not re-run dimensions the review already validated as passing.
6. **After all edits succeed**, rename the consumed file to `.reviews/REVIEW-{timestamp}.applied.md` (`Bash mv`) so it is not re-applied on a subsequent invocation. `.reviews/` is not version-controlled — the durable audit for this revision is the `REVISIONS.md` entry produced by Step 5.

**Clustering-Subagent dispatch template** (main agent emits this):

```
Cluster the findings in {REVIEW file absolute path} into fix batches.

Read the REVIEW file exactly once. Do not read any other file.

Parse every `### <relative path>` section under `## Per-File Findings`. For each section, count findings, collect the unique `Dimension:` tags, and note the severities present.

Produce clusters using these rules:
- Each cluster contains AT MOST 3 target files.
- Files are grouped within the same artifact class first (features/*, journeys/*, architecture/*); do not mix classes within a cluster unless a class has <3 files left.
- Files with >8 findings get their own cluster (1 file only) — large edit counts replay more cache_read per turn.
- Preserve source order within a class (F-001..F-003, F-004..F-006, ...).
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
- Grep/Glob/Bash exploration of the PRD directory.
- Emitting the `Fix:` text of individual findings — clusters carry only the list of target files and dimension tags; Fix subagents will read the REVIEW themselves for the edit text (Template A).
- Prose commentary outside the YAML block.

Absolute paths only (resolve them from the REVIEW's `Reviewed:` header + each `### <relative path>` header).
```

The main agent consumes the returned YAML as the cluster plan. Fix-subagent dispatches in Step 5 use `cluster.target_files` directly; Step 6 delta-review scope uses `dimensions_tagged_union`.

**Dispatch execution (MANDATORY — see `parallel-dispatch.md` Rule 1):**

Once the manifest is consumed, emit ALL Fix subagent dispatches in a **single assistant response** containing N `Agent` tool_use blocks (one per cluster). Sequential dispatch is **FORBIDDEN** — it replays ~280k cache_read per cluster, costing roughly $1.30 per cluster on a typical PRD. A 10-cluster revision dispatched in parallel costs ~$1.30; dispatched serially costs ~$13.

Do NOT emit any intermediate assistant response between consuming the manifest and the dispatch. No "Now I will dispatch the fix subagents" preamble — proceed directly to the multi-tool-use response.

**Clustering-Subagent dispatch parameters:** Use `subagent_type: "general-purpose"` and `model: "sonnet"`. Do not use `Explore` (lightweight tier — will misparse the structured findings schema). Do not use `opus` (simple parsing + grouping is not top-tier work). Never pin a specific version.

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

Read README.md in parallel with a quick scan of journey filenames (do not read full journey files yet). Summarize:

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
- **Prototype impact** — Does the change invalidate existing prototypes? Mark affected prototypes as needing regeneration (set Confirmed date to empty); after regeneration, overwrite old source and screenshots, then update Confirmed date. Impact is derived from the spec delta alone — **do not list or read `prototypes/src/` or `prototypes/screenshots/`**. Which features have prototypes is determined from each feature file's Prototype Reference section, not from the filesystem.
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

### Batch by File (Required)

Before making any edits, **group all pending changes by target file**. For each file, collect every change that applies to it, then read the file once, apply all changes in a single pass, and write it once. Never read or write a file more than once per revision cycle. This is mandatory — per-finding sequential edits cause O(n) file re-reads and dramatically increase cost.

**Grouping procedure:**
1. List all changes (from Step 3 or from the pre-answered findings list).
2. For each change, identify the target file(s) it affects.
3. Build a file → [changes] map.
4. Process each file in the map: read → apply all its changes → write.
5. After all files are processed, handle cross-reference updates (README, journey Mapped Feature columns, Feature Index) as a final sweep — also one read-and-write per cross-reference file.

**Parallelism:** If the change set is large (>15 changes), group files into independent clusters (features/*, architecture/*, journeys/*, README.md) and process clusters in parallel where no cluster's output is an input to another cluster's edit. For example: fix all feature files in parallel, then fix architecture files that reference those features, then update README/cross-references.

**Cluster sizing:** each Fix subagent handles **at most 3 files**. Larger clusters balloon the per-turn cache_read: a 5-file cluster doing 40 edits across 40 turns replays ~165k context per turn; splitting into 3-file clusters caps the replay at ~60k. Bias toward more smaller clusters (dispatched in parallel) over few large clusters.

### Fix-Subagent Dispatch Rules

**Read `parallel-dispatch.md` first** — it defines the mandatory dispatch rules (single-response parallel emission, model tier, cluster sizing ≤3 files, MultiEdit for >1 edit, forbidden post-edit re-reads, dispatch prompt contract).

**Revise-mode-specific rules:**

- If a `.reviews/REVIEW-*.md` was consumed (Pre-Answered Mode), use **Template A** (reference-based, below).
- Otherwise (interactive revise, Step 3 gathered the change list), use **Template B** (inline edits list, below).

When delegating a cluster to a `general-purpose` subagent, the dispatch prompt MUST use this template. Free-form prompts lead to the subagent re-reading files (4× observed on same file) and running its own Glob/Grep to re-discover the change set — both are pure waste.

**Template A — reference-based dispatch** (when REVIEW-*.md exists):

```
Apply the findings from {REVIEW-*.md absolute path} that target the files listed below.
The REVIEW file groups findings by file under `### <relative path>` headings; each finding has a `Fix:` line describing the concrete edit.

Read each target file exactly once (in parallel). For each file, collect all matching findings from the REVIEW file, then apply them in a single pass:
- file with 1 finding: use `Edit`
- file with >1 finding: use `MultiEdit` (mandatory — no sequential Edits on the same file)
Write once per file.

**Oscillation guard:** if a finding's Fix would undo content that is clearly the result of a prior remediation (e.g. the Fix removes text that looks like it was added by a prior review pass — inline fixtures, capability statements, extra edge cases), do NOT apply it. Skip that finding and report it with status `skipped: oscillation suspected — <one line why>`. The main agent will resolve oscillations; subagents must not swing content back and forth.

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

**On completion**, report per-file: `applied N edits` OR `skipped M: oscillation suspected` OR `file not found` OR `anchor not found: <anchor>`. No prose summary.
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

### Handling Subagent Returns

Follow `output-discipline.md` Rule 2 (no inter-dispatch commentary) and Rule 3 (TaskUpdate parsimony):

- When Fix subagent returns arrive, the main agent's NEXT action is the next tool call (cross-reference sweep, REVISIONS.md append, or user-facing summary) — NOT a standalone ack response.
- `TaskUpdate` fires once when all clusters dispatched, once when all returned. Do NOT update per-cluster.
- When writing REVISIONS.md, use `Write` directly with the full entry body — do NOT echo the body in assistant text first (output-discipline Rule 1).

The orchestrator (main agent) owns the cluster plan — but how it is built depends on mode:

- **Pre-Answered Mode (REVIEW-*.md exists):** the orchestrator MUST delegate the read + group step to the Clustering Subagent described at the top of this file, and consume its YAML manifest. The orchestrator never reads the REVIEW body itself.
- **Interactive mode (Template B):** the orchestrator already has the change list in context from Step 3, so it pre-materializes every edit and dispatches directly. No Clustering Subagent is needed.

When using Template A, Fix subagents extract the exact edit text from the REVIEW file they read; when using Template B, the orchestrator pre-materializes every edit. Do not push cluster-composition into Fix subagents in either mode.

---

Based on the downstream state confirmed in Step 1:

**Modify directly (no design, or design exists but not implemented):**
- Update affected files in place (using batch-by-file procedure above)
- If design exists: append an entry to `REVISIONS.md` summarizing what changed and why (create the file using the template in `prd-template.md` if this is the first revision, and add a link to it from README.md's References section) — this record helps the design update process (`/system-design --revise`) identify what PRD changes need to propagate

**Create new version (implementation exists):**
- Create new dated directory (e.g. `docs/raw/prd/YYYY-MM-DD-{product-name}/`)
- Copy forward unchanged files (including any existing `REVISIONS.md` from the previous version)
- Apply changes to affected files (using batch-by-file procedure above)
- Append an entry to `REVISIONS.md` (create it if absent) linking back to the previous version's directory; add a link to `REVISIONS.md` from README.md's References section

In both cases:
- Update all cross-references (journey Mapped Feature columns, feature Dependencies, Cross-Journey Patterns "Addressed by Feature" column)
- Mark deprecated features clearly — remove the feature file and remove it from Feature Index, Roadmap, and any Mapped Feature references
- Re-derive affected User Stories if journey touchpoints changed (re-run Phase 4 Step 1 extraction for affected journeys only)

### REVISIONS.md Entry Format (Required for Convergence Tracking)

`REVISIONS.md` is the version-controlled source of truth used by `review-mode.md` Step 0.5 to count prior passes and detect oscillations. Review-driven fix-pass entries MUST use a stable heading format and include a `**Themes:**` section detailed enough for oscillation detection.

**Heading format for Pre-Answered Mode (REVIEW-driven fix passes) — MANDATORY:**

```
## {YYYY-MM-DD} — {Nth}-pass review-finding fixes (REVIEW-{timestamp})
```

The word `review-finding` MUST appear in the heading — `review-mode.md` Step 0.5 greps `^## .*review-finding` to count passes. Do not rephrase this anchor.

**Required sections in each review-driven entry:**

- **Rationale:** which REVIEW file was consumed, finding counts by severity, remaining-Critical count (explicit "zero Critical remaining" if applicable — this triggers the convergence-gate abort condition on the next `--review`).
- **Themes:** one bullet per thematic cluster of fixes. Each bullet MUST be specific enough that a future reviewer can tell what was added or removed (e.g. "Removed SQL DDL blocks from F-018/F-021/F-022" — not "Scope cleanup"). This powers oscillation detection: future reviews grep Themes to check whether a new finding would swing content back.
- **Files affected:** count and class breakdown.
- **Downstream impact:** whether design exists and what it will inherit.

For non-review-driven revisions (interactive feature add/modify/deprecate), use a different heading (e.g. `## {date} — Add F-049 SSO` / `## {date} — Deprecate F-005`) so they are NOT counted by the convergence gate.

### Rolling Detail Window (keeps REVISIONS.md bounded)

`REVISIONS.md` grows monotonically and would bloat subagent context. Every append uses a rolling window: the 3 most recent entries keep full bodies; older entries are compacted to heading + one-line summary, with full detail recoverable via `git log -p REVISIONS.md`.

**Append procedure (execute in this order):**

1. **Compact older bodies** — before appending the new entry, identify entries that will become older than the 3rd-most-recent after the append (i.e. entries currently 3rd-most-recent and older). For each such entry still in full-body form, replace its body (everything between its `## ...` heading and the next `---` separator, or EOF) with a single line:

   ```
   **Summary:** {one-line themes digest}. Full detail in git history (`git log -p REVISIONS.md`).
   ```

   The one-line digest SHOULD be derived from the entry's current `**Themes:**` bullets — take the noun phrases (e.g. `Scope-boundary tightening; testability tightening; authorization matrices; UI state machine completions`). Keep the heading line and any trailing `---` separator intact.

2. **Append the new full-body entry** after compaction.

3. **The detail window applies to review-driven entries only.** Non-review-driven entries (feature add/modify/deprecate) are treated as standalone narrative — do not compact them; they record substantive product decisions worth keeping in line.

**Invariants preserved by this procedure:**

- **Pass count stays exact.** `Grep` of `^## .*review-finding` still matches every compacted entry — only bodies change, not headings.
- **Oscillation detection stays accurate.** The 3-entry detailed window matches `review-mode.md` Step 2's "read most recent 2–3 entries" — all the signal it needs is still in full form.
- **No audit loss.** Full body of every compacted entry is recoverable via `git log -p REVISIONS.md` — the compaction commit is itself the pointer.

**When NOT to apply compaction:** first 3 review-driven passes (nothing to compact); entry being compacted is already in summary form (idempotent — skip). Never compact the entry you are currently appending.

## Revise Step 6 — Post-Change Review (Delta-Focused)

**Do NOT run the full 52-dimension review checklist.** Run only the checklist dimensions relevant to what actually changed. Load `review-checklist.md` only if you need to reference a dimension's exact definition.

**Review-driven fix pass scope:** If this revision consumed a `REVIEW-*.md` file (Pre-Answered Mode), the delta review scope is:

- The **always-run** set below, **plus**
- Only the dimensions whose tags appeared in the consumed `REVIEW-*.md`.

Do not re-run dimensions the review already validated as passing.

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
