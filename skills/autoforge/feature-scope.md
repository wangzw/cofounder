# feature-scope.md — Single-Feature Implementation Orchestration

Loaded by the orchestrator when `--feature F-NNN <design-dir>` is provided.
Implements a single feature by modifying only the modules it affects, running
feature-specific tests, and running regression tests for overlapping features.

## Contract

- **Scope:** only modules listed in F-NNN's `writes` + `reads` in `feature-module-map.yml`
- **Input:** design directory (MUST contain `feature-module-map.yml`)
- **Planner:** scoped to the affected module set
- **Module agents:** dispatched only for affected modules, implementing only the
  changes related to F-NNN
- **Tests:** F-NNN's acceptance criteria tests + regression tests for overlapping features
- **Reverse alignment:** checksum-based detection that code matches contract (built-in)

## Precondition

The design directory MUST contain `feature-module-map.yml`:

```bash
test -f {design-dir}/feature-module-map.yml
```

If missing, exit with error and suggest running `/system-design <prd-dir>` first.

## Orchestration Sequence

### Step 0 — Git Precheck

```bash
scripts/git-precheck.sh
```

### Step 1 — Read feature-module map

Read `{design-dir}/feature-module-map.yml`. Locate F-NNN's entry:

```yaml
F-003:
  name: "Payment Flow"
  writes: [M-001, M-005, M-007]
  reads: [M-006]
```

If F-NNN is not found, exit with error.

The **implementation scope** = `writes ∪ reads`.

### Step 2 — Locate the PRD feature file

Read the design README's "Design Input" section to find the PRD directory path.
Derive the feature file path: `{prd-dir}/features/F-{NNN}-*.md`.
The orchestrator reads only the design README (an index file, permitted per
the orchestrator dispatch contract). The PRD feature file itself is read
by the planner sub-agent in Step 3.

### Step 3 — Dispatch scoped planner

- Dispatch: a planner agent (reuse existing planner prompt but with scope constraint)
- Inputs:
  - F-NNN's PRD feature file (the planner reads: ACs, API contracts, component
    contracts, data model, edge cases)
  - The affected module specs (M-001, M-005, M-007, M-006)
  - The design's conventions and tech stack
- Output: a **feature-scoped plan** containing:
  - Per-module: which files to create/modify, which interfaces to add/change
  - Test plan: which tests to write for F-NNN's ACs
  - Regression plan: which existing tests to run

The planner MUST limit its plan to the files owned by the affected modules.
It MUST NOT plan changes to modules outside the scope.

### Step 3a — HITL: Plan Approval Gate (optional)

Present the scoped plan to the user:

```
Feature-scope plan for F-{NNN} ({name})

Modules to change:
  M-001 (User): add payment_method field to User model
  M-005 (Payment): add one-step payment endpoint, remove confirmation page
  M-007 (Order): add payment_confirmed state transition
  M-006 (Notification): consume new PaymentConfirmed event

Files to modify: {list}
New files: {list}
Tests to add: {list}

Proceed? [yes / modify / abort]
```

### Step 4 — Dispatch module agents (parallel where possible)

For each module in the `writes` set, dispatch a module agent to implement the changes.
For modules in the `reads` set, dispatch only if the feature change requires updates
(e.g., consuming a new event or data model field).

Module agents receive:
- Their module spec (with changes from the delta)
- The feature plan
- The relevant PRD sections (ACs, contracts, etc.)

Modules with no dependency on each other can be dispatched in parallel.
Modules with dependencies must be dispatched sequentially (DAG order).

### Step 5 — Run F-NNN's tests

After all module changes are complete, run the tests corresponding to F-NNN's
acceptance criteria (dispatch tester agent(s) with the feature's ACs as test specs).

All ACs must pass. If any AC fails, loop back to the relevant module agent(s) for fixes.

### Step 6 — Run regression tests

Read the regression scope from the design's CHANGELOG (last `/system-design delta F-NNN`
entry). Dispatch tester agent(s) to run existing tests for all features in the
regression scope.

If any regression test fails, the merge is **blocked**. Report the failure with the
offending feature and test. The user must decide:
- Modify F-NNN's implementation to fix the regression
- Accept the regression and update the affected feature's contract
- Abort the feature implementation

Do NOT silently pass a failing regression test.

### Step 7 — Reverse Alignment Check (checksum)

After all implementation is complete and tests pass:

1. Compute the checksum of the F-NNN PRD feature file (SHA-256, stripping comments/frontmatter)
2. Store the checksum in a metadata file: `{design-dir}/.review/contract-checksums.yml`:

```yaml
F-003:
  checksum: "sha256:abc123def456..."
  verified_at: "2025-05-22T10:30:00Z"
  status: "aligned"
```

3. Compare the stored checksum against the PRD feature file's current checksum.
   - Match → `status: aligned` → continue
   - Mismatch → `status: diverged` → BLOCK merge, output "contract divergence" report

This check runs automatically at the end of every `--feature` implementation. It is also
triggered when code in affected modules changes without a corresponding `modify F-NNN`
operation (detected via git hooks or on merge).

### Step 8 — Commit

Commit with message:

```
feat(autoforge): implement F-{NNN} — {feature name}

Modules modified: M-{ids}
PRD: {prd-dir}/features/F-{NNN}-{slug}.md
Design: {design-dir}
```

### Step 9 — Report

```
F-{NNN} implemented successfully.

Modules modified: M-{ids}
Tests passed: {count} (feature) + {count} (regression)
Contract checksum: sha256:{checksum}

Next: verify in staging, then move to next feature
```

## Reverse Alignment Guarantee

The checksum in `.review/contract-checksums.yml` serves as the bridge between code
and contract. The invariant is:

> The PRD feature file's current checksum MUST match the stored checksum.
> If they diverge, either the PRD was modified (run `--feature` again) or the
> code was changed without updating the contract (run `/prd-analysis modify` to
> bring the contract in line).

This guarantee is enforced:
1. **At the end of every `--feature` run** (Step 7 above)
2. **On merge to main** (via CI hook that reads `contract-checksums.yml`)
3. **On code changes in watched module directories** (future: git hook)

## FORBIDDEN

- Modifying modules NOT in the feature's `writes ∪ reads` set
- Silently passing failing regression tests
- Skipping the checksum alignment check
- Planning changes outside the scoped module set
