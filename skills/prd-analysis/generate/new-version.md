# generate/new-version.md — NewVersion Mode Entry

This file is loaded by the orchestrator when mode = Generate and `--target skills/<name>` is
provided with a change description. It is **not** a sub-agent prompt. It defines the NewVersion
dispatch sequence.

---

## Key Differences from FromScratch

| Aspect | FromScratch | NewVersion |
|--------|-------------|------------|
| Scaffold | `scaffold.sh` runs on Round 0 | NOT re-run; `check-scaffold-sha.sh` verifies no drift |
| Consultant | Conditional (glossary_hit or sparse_input) | Typically skipped (user has specific change) |
| Planner inputs | clarification.yml or input.md | Also reads existing README.md, CHANGELOG.md, versions/<N-1>.md |
| Plan shape | `add` only (all new) | `{delete, modify, add, keep}` |
| Writer fan-out | All `add` files | Only `modify` + `add` files |
| Cross-review | All target leaves | Forced full review on first round (§10.2) regardless of modified-file count |
| Round numbering | Starts at 1 | Continues from last delivery (cross-delivery monotonic §10.5) |

---

## NewVersion Round Sequence

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

- **Orchestrator**: if exit non-zero → stop. Same as FromScratch.

### Step 2 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<change-description>" <target>/.review
```

- **Outputs**: `<target>/.review/round-<K+1>/input.md`, `input-meta.yml`
  where K = last completed round from previous delivery.

### Step 3 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <target>/.review/round-<K+1> common/domain-glossary.md
```

- **Outputs**: `round-<K+1>/trigger-flags.yml`

### Step 4 — Scaffold Drift Check (script)

```bash
scripts/check-scaffold-sha.sh <target>/ (manifest-pinned scripts enforced via CR-S12 on this skill's own common/shared-scripts-manifest.yml)
```

- Verifies that boilerplate files in `<target>/` have not drifted from the skeleton SHA pins.
- If drift detected → report which files drifted; prompt user to decide: restore skeleton or accept drift as intentional.

### Step 5 — Domain Consultant (usually skipped)

**Condition**: dispatch ONLY if `trigger-flags.yml` reports `glossary_hit: true` OR user explicitly
passed `--interactive`. Most NewVersion invocations skip this step.

- Same dispatch contract as FromScratch Step 4.
- **Inputs additionally consumed**: `<target>/README.md` (for variant-replay summary).

### Step 6 — Planner (sub-agent dispatch)

The planner in NewVersion mode reads:
- `round-<K+1>/input.md` (or clarification.yml if Step 5 ran)
- `<target>/README.md`
- `<target>/CHANGELOG.md`
- `<target>/.review/versions/<N-1>.md` (last converged version summary)

- **Dispatches**: `generate/planner-subagent.md`
- **Outputs written**: `round-<K+1>/plan.md` with `mode: new-version` and four lists: `delete`, `modify`, `add`, `keep`

### Step 7 — HITL: Plan Approval Gate

Same as FromScratch Step 6. Orchestrator presents `plan.md` to user; waits for approve/revise/abort.

### Step 8 — Apply Deletes (script or orchestrator action)

For each path in `plan.delete`:
```bash
git rm <target>/<path>
```
Orchestrator executes these removals directly (not via sub-agent). Records removed paths in `state.yml`.

### Step 9 — Writer Fan-out (parallel sub-agent dispatch)

Fan-out writers for ALL files in `plan.modify` + `plan.add`. Files in `plan.keep` are skipped.

- **Dispatches**: `generate/writer-subagent.md` (one per modify/add file)
- **Inputs for `modify` files**: existing `<target>/<file>` is passed as context alongside clarification.yml + plan.md + template
- **Same output contract as FromScratch Step 8**

### Step 10 — Script-Type Checks (script)

Same as FromScratch Step 9. Runs against ALL target leaves (not just modified), per §10.2.

### Step 11 — Cross-Reviewer (sub-agent dispatch)

**Forced full review on first round of a new delivery** (guide §10.2): reviewer reads ALL target
leaves regardless of which files were modified. This catches regressions from the delete/modify
operations.

Subsequent rounds within the same delivery review only changed files.

### Step 12 — Summarizer (sub-agent dispatch)

Same as FromScratch Step 11. Summarizer also appends a new entry to `CHANGELOG.md`.

### Step 13 — Judge (sub-agent dispatch)

Same as FromScratch Step 12. Delivery commit creates tag `delivery-<N+1>-<slug>`.

---

## Round Numbering Example

```
Delivery 1:  round-1 (plan), round-2, round-3 (converged) → tag delivery-1-foo
Delivery 2:  round-4 (plan), round-5 (converged)          → tag delivery-2-foo
```

Delivery-2 planner reads `versions/3.md` (the delivery-1 converged summary). It writes
`round-4/plan.md`. Writers write to round-4 self-reviews. All monotonic — no reuse of round numbers.

---

## Notes

- `new-version.md` is not a sub-agent prompt; it does not carry the Snippet D fingerprint.
- `plan.keep` files are never dispatched to writers; `check-scaffold-sha.sh` already verified them.
- The orchestrator must not read `<target>/<file>` content when deciding which files need writers — rely on `plan.modify` + `plan.add` lists in `plan.md` only.
