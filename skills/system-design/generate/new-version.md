# generate/new-version.md — NewVersion Mode Entry (system-design)

This file is loaded by the orchestrator when mode = Generate and `--target <design-dir>` is
provided with a change description pointing at an EXISTING system-design output directory. It is
**not** a sub-agent prompt. It defines the NewVersion dispatch sequence for system-design, which
differs from the generic skill-forge canonical in four key areas:

1. **Planner reads the full existing design** (every `modules/M-*.md` + `api/API-*.md` +
   `README.md` + `REVISIONS.md`) in addition to the change description and (when applicable) the
   new PRD directory.
2. **Delta plan is at MODULE granularity** — delete/modify/add/keep entries refer to
   `modules/M-NNN-slug.md` and `api/API-NNN-slug.md` files, not to arbitrary skill files.
   `README.md` is always classified as `modify`.
3. **Two-phase quality gate** — structural-lint scripts (`scripts/run-checkers.sh`) run BEFORE
   LLM cross-reviewer + adversarial-reviewer, matching the FromScratch two-phase model.
4. **Summarizer appends a REVISIONS.md entry** — not a CHANGELOG section — per legacy
   system-design convention (REVISIONS.md tracks in-place revision history; `CHANGELOG.md`
   tracks delivery-level summaries at the skill level, not inside the design artifact).

---

## Key Differences from FromScratch

| Aspect | FromScratch | NewVersion |
|--------|-------------|------------|
| Scaffold | `scaffold.sh` NOT run (outputs a design dir, not a skill) | NOT re-run; `check-scaffold-sha.sh` verifies no drift on boilerplate files |
| Consultant | Conditional (glossary_hit or sparse_input) | Typically skipped (user has specific change description) |
| Planner inputs | New PRD or clarification.yml | Also reads existing README.md + REVISIONS.md + every modules/M-*.md + api/API-*.md |
| Plan shape | `add` only (all new) | `{delete, modify, add, keep}` at MODULE granularity |
| Writer fan-out | All `add` files | Only `modify` + `add` modules/api files; README always in `modify` |
| Structural lint | `scripts/run-checkers.sh` on new design | `scripts/run-checkers.sh` on ALL leaves (not just modified) — regressions from deletes/moves |
| Cross-review | All leaves | **Forced full review on first round of a new delivery** (§10.2) — all leaves, not just modified |
| Round numbering | Starts at 1 | Continues from last delivery (cross-delivery monotonic §10.5) |
| Revision record | Creates REVISIONS.md on first --revise | Appends entry to existing REVISIONS.md (or creates if absent) |

---

## Trigger Conditions

NewVersion mode fires when the user invokes one of:

```
/cofounder:system-design --target docs/raw/design/YYYY-MM-DD-{slug}/ "<change description>"
/cofounder:system-design docs/raw/design/YYYY-MM-DD-{slug}/ --revise "<PRD evolution summary>"
```

The change description can be:
- A free-text description of architectural changes (module restructure, interface changes,
  technology decision changes, NFR reallocations).
- A pointer to an evolved PRD produced by `/cofounder:prd-analysis --evolve`, in which case the
  planner reads the evolved PRD's feature diff to derive the module delta.
- A review-driven fix pass: if `.review/round-*/issues/` has open issues from a previous
  `--review` run, the planner consumes them as part of the change input.

---

## NewVersion Round Sequence

Let `K` = the last completed round number across all deliveries for this design directory
(read from `<design-dir>/.review/state.yml` key `last_completed_round`).

All new round files write to `round-<K+1>/`.

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

- **Orchestrator**: if exit non-zero → stop. Same as FromScratch.

### Step 2 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<change-description>" <design-dir>/.review
```

- **Outputs**: `<design-dir>/.review/round-<K+1>/input.md`, `input-meta.yml`
  where K = last completed round from previous delivery.
- `input.md` should capture the full change description, including any pointer to an evolved PRD
  directory and any REVIEW-*.md file paths that are pre-answered input.

### Step 3 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <design-dir>/.review/round-<K+1> common/domain-glossary.md
```

- Probes for system-design domain terms (module, API surface, Boundary Enforcement, etc.) in the
  change description.
- **Outputs**: `round-<K+1>/trigger-flags.yml`

### Step 4 — Scaffold Drift Check (script)

```bash
scripts/check-scaffold-sha.sh <design-dir>/ (manifest-pinned scripts via common/shared-scripts-manifest.yml)
```

- Verifies boilerplate files in `<design-dir>/` have not drifted from known-good SHAs.
- If drift detected → report which files drifted; prompt user to decide: restore or accept as
  intentional customization.
- **Note**: the design directory (`modules/`, `api/`, `README.md`, `REVISIONS.md`) is NOT
  scaffolded by `scaffold.sh`; this check covers only the skill-level boilerplate. The design
  content itself is under user/planner control.

### Step 5 — Domain Consultant (usually skipped)

**Condition**: dispatch ONLY if `trigger-flags.yml` reports `glossary_hit: true` OR user
explicitly passed `--interactive`. Most NewVersion invocations skip this step because the user
has already provided a specific change description.

- Same dispatch contract as FromScratch Step 4.
- **Inputs additionally consumed**: `<design-dir>/README.md` (existing module index + status),
  `<design-dir>/REVISIONS.md` (revision history, for version continuity context).
- **When PRD-based**: also consumes the new PRD `README.md` to enumerate evolved features.

### Step 6 — Planner (sub-agent dispatch)

The planner in NewVersion mode reads the full existing design to understand what exists, then
reads the change description to derive the minimal delta at MODULE granularity.

**Inputs consumed by sub-agent**:
- `round-<K+1>/input.md` (change description, possibly pointing to evolved PRD)
- OR `round-<K+1>/clarification/<ts>.yml` (if Step 5 ran)
- `<design-dir>/README.md` (module index, Feature-Module matrix, current state)
- `<design-dir>/REVISIONS.md` (revision history — if present)
- `<design-dir>/modules/M-*.md` (ALL existing module files — planner reads every one)
- `<design-dir>/api/API-*.md` (ALL existing API files — if present)
- If PRD-based: new PRD `README.md` + evolved `features/F-*.md` files

**Plan shape** (written to `round-<K+1>/plan.md`):

```yaml
mode: new-version
delivery_id: <N+1>
round: <K+1>

plan:
  delete:
    - path: "modules/M-003-old-slug.md"
      reason: "Feature F-005 deprecated in evolved PRD; responsibilities absorbed by M-002."
    - path: "api/API-002-old-slug.md"
      reason: "API endpoint removed in PRD evolution."

  modify:
    - path: "README.md"     # always in modify — matrix + module index change with every delta
      description: "Update Feature-Module matrix, Module Index (remove M-003, add M-007), Module Interaction Protocols (remove M-003 rows), REVISIONS.md link."
    - path: "modules/M-002-auth.md"
      description: "Add responsibility for F-005 (absorbed from deleted M-003); update Source Features, Interfaces, Deps."
    - path: "api/API-001-core.md"
      description: "Update Request schema for F-007 new field; update Response and Status codes."

  add:
    - path: "modules/M-007-new-slug.md"
      template: "common/templates/module-template.md"
      description: "New module for F-009 (added in PRD evolution). Owns data ingestion pipeline."

  keep:
    - path: "modules/M-001-users.md"
    - path: "modules/M-004-events.md"
    # ... all other unchanged modules
```

**Classification rules for planner**:
- `delete`: module whose source PRD features were entirely deprecated in the evolved PRD, AND
  whose responsibilities are fully absorbed by other modules. Never delete a module with `Impl:
  Done` or `Impl: In progress` without user confirmation at the HITL gate (Step 7).
- `modify`: module whose source PRD features changed, whose interfaces are referenced by a
  changed module, or whose Deps/Protocols entries need updating due to other modules' changes.
  `README.md` is ALWAYS in `modify`.
- `add`: new module for newly-introduced PRD features with no existing module to absorb them.
- `keep`: module whose source features, interfaces, deps, and protocols are all unaffected.
  Do NOT re-author keep modules — they are passed through unchanged.

**Dispatches**: `generate/planner-subagent.md`
**Outputs written**: `round-<K+1>/plan.md`

### Step 7 — HITL: Plan Approval Gate

The orchestrator presents `plan.md` to the user. The gate is mandatory — the user must see the
delete/modify/add/keep breakdown before any files are removed or re-authored.

Escalate and require explicit confirmation if the plan contains:
- Any `delete` entry for a module with `Impl: Done` or `Impl: In progress` (as detected from the
  existing `README.md` Module Index `Impl` column).
- Any `delete` entry that would leave a PRD feature without module coverage (feature coverage gap
  — check the Feature-Module matrix).
- More than half the existing modules in `modify` or `delete` (large-blast-radius changes warrant
  explicit sign-off).

Wait for user response:
- **approve** → continue to Step 8
- **revise** (or `/revise <feedback>`) → re-dispatch planner with feedback appended; loop Steps 6–7
- **abort** → exit this skill

### Step 8 — Apply Deletes (orchestrator action)

For each path in `plan.delete`:

```bash
git rm <design-dir>/<path>
```

The orchestrator executes these removals directly (not via sub-agent). Records removed paths in
`<design-dir>/.review/state.yml` under `deleted_in_round_<K+1>`.

**Important**: only `modules/M-*.md` and `api/API-*.md` files appear here. README.md is always
in `plan.modify`, never in `plan.delete`. Never git-rm the `.review/` directory.

### Step 9 — Writer Fan-out (parallel sub-agent dispatch)

Fan-out writers for ALL files in `plan.modify` + `plan.add`. Files in `plan.keep` are never
dispatched — they are untouched on disk.

- **Dispatches**: `generate/writer-subagent.md` (one per modify/add file)
- **Inputs for `modify` files**: existing `<design-dir>/<file>` is passed as context alongside
  the change description + plan entry + corresponding template (module-template or
  api-template or design-readme-template)
- **Inputs for `add` files**: plan entry + corresponding template (no existing file)
- **Same output contract as FromScratch Step 8** — each writer produces:
  1. Updated artifact at `<design-dir>/<path>`
  2. Self-review at `<design-dir>/.review/round-<K+1>/self-reviews/<trace_id>.md`

### Step 10 — Structural Lint Pre-Pass (script)

```bash
scripts/run-checkers.sh <design-dir>/ round-<K+1>
```

Run against **ALL leaves** in the design directory — not just modified files. Deletes and
modifications can break cross-module references that were valid in the previous delivery (e.g.,
a Module Interaction Protocols row in README.md still referencing a deleted module, or an X2
cross-check failing because a modified api/ file changed an endpoint literal that another module
still references under the old name).

- **Outputs**: issue files under `<design-dir>/.review/round-<K+1>/issues/<issue-id>.md` per
  structural failure (13 domain lint checks: L1..L5 + X1..X8). Issue IDs follow `R<K+1>-<seq>`.
- **Orchestrator**: if critical/error LINT issues found → dispatch per-issue revisers
  (`revise/per-issue-reviser-subagent.md`) before proceeding to Step 11. Re-run
  `scripts/run-checkers.sh` until clean. Proceed to Step 11 only when the lint gate passes.

**Do not dispatch LLM reviewers until the structural lint gate is clean.** Mechanical gaps that
reach the cross-reviewer inflate finding counts, drown out real semantic blockers, and guarantee
an extra revise cycle.

### Step 11 — Cross-Reviewer + Adversarial-Reviewer (parallel sub-agent dispatch)

**Forced full review on first round of a new delivery** (guide §10.2): both reviewers read ALL
design leaves (modules/ + api/ + README.md) regardless of which files were modified or added.
This is mandatory because delete + modify operations can introduce regressions in untouched
modules (e.g., a keep module's Boundary Enforcement rule referencing a deleted module's
interface).

Subsequent rounds within the same delivery scope review to modified/added files only.

**Cross-Reviewer**:
- **Dispatches**: `review/cross-reviewer-subagent.md`
- Applies LLM-type CRs from `common/review-criteria.md` (script-type CRs are already handled by
  Step 10 and are NOT re-applied by the cross-reviewer).
- **Outputs**: `round-<K+1>/issues/<issue-id>.md` per issue found (issue IDs follow `R<K+1>-V-<seq>`).

**Adversarial-Reviewer** (dispatched in parallel with cross-reviewer):
- **Dispatches**: `review/adversarial-reviewer-subagent.md`
- Attacks the updated design: NFR violations (latency budgets, scale limits), race conditions,
  missing failure modes, security holes (authz boundaries, secret-handling), missing
  observability, untested error paths, and regressions introduced by the delta (e.g., an added
  module that bypasses an existing Boundary Enforcement rule).
- **Outputs**: `round-<K+1>/issues/<issue-id>.md` per adversarial finding (issue IDs follow `R<K+1>-V-<seq>-ADV`).

### Step 12 — Summarizer (sub-agent dispatch)

- **Dispatches**: `shared/summarizer-subagent.md`
- **System-design-specific output**: summarizer appends a **REVISIONS.md entry** (NOT a new
  CHANGELOG section). REVISIONS.md format follows `common/templates/revision-entry-template.md`:
  date, delivery ID, modules touched (from `plan.modify` + `plan.add` + `plan.delete` lists),
  summary of changes. Creates REVISIONS.md if this is the first NewVersion run.
- Also writes `round-<K+1>/index.md` and `.review/versions/<K+1>.md` (converged version
  summary for future planner reads).

### Step 13 — Judge (sub-agent dispatch)

- **Dispatches**: `shared/judge-subagent.md`
- **Outputs written**: `round-<K+1>/verdict.yml`
- **Orchestrator action on ACK**:
  - `verdict: converged` → delivery commit (`scripts/commit-delivery.sh`) with tag
    `delivery-<N+1>-{slug}` where N = previous delivery ID.
  - `verdict: progressing` → increment round to K+2, loop from Step 9 (writer fan-out on
    modified files only — no new deletes in subsequent rounds of the same delivery).
  - `verdict: stalled` → surface to user; request human intervention.

---

## Round Numbering Example

```
Delivery 1: round-1 (initial design, FromScratch) → tag delivery-1-{slug}
Delivery 2: round-2 (NewVersion — PRD evolution)  → tag delivery-2-{slug}
Delivery 3: round-3 (NewVersion — module refactor), round-4 (converged) → tag delivery-3-{slug}
```

- Delivery-2 planner reads `versions/1.md` (the delivery-1 converged summary from FromScratch).
  It writes `round-2/plan.md`. Writers write to `round-2/self-reviews/`.
- Delivery-3 planner reads `versions/2.md`. It writes `round-3/plan.md`. If Judge returns
  `progressing`, writers continue in `round-4/`.
- All round numbers are cross-delivery monotonic — no reuse of round numbers across deliveries.

---

## Post-Delivery Cascade Notification

After the delivery commit, check for downstream implementation state (read `README.md` `Design
Input > Status` field) and print applicable guidance:

**If Status is `Implementing` or `Implemented`** (modules were previously handed to autoforge):

```
Design updated: {design-dir}

The following modules changed in this delivery:
  Modified: {plan.modify list, excluding README.md}
  Added:    {plan.add list}
  Deleted:  {plan.delete list}

Implementation exists for this design. Re-run autoforge for affected modules:
  /cofounder:autoforge {design-dir}
```

**If Status is `Draft` or `Finalized`** (no implementation exists yet):

```
Design updated: {design-dir}

Next steps:
  /cofounder:autoforge {design-dir}
```

---

## Notes

- `new-version.md` is not a sub-agent prompt; it does not carry the Snippet D fingerprint.
- `plan.keep` files are never dispatched to writers and never touched on disk.
- The orchestrator MUST NOT read any artifact leaf other than `plan.md` (Step 7) and
  `verdict.yml` (Step 13). For all other routing decisions, rely on ACK fields alone.
- When the change description points to an evolved PRD, the planner reads the new PRD; this file
  does not change the orchestrator's dispatch logic — the planner is the only agent that reads
  PRD content.
- `REVISIONS.md` tracks in-design revision history (human-readable, referenced from README's
  References section). It is distinct from the `.review/versions/<N>.md` files (machine-readable
  converged-version summaries used by the planner in subsequent deliveries).
- The two-phase quality gate (structural lint → LLM review) is the same pattern as FromScratch.
  The only difference is that structural lint here runs over a mixed set of old (keep) + updated
  (modify) + new (add) leaves, whereas in FromScratch it runs over all-new leaves only.
