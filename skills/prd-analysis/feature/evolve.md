# feature/evolve.md — Unified Feature Evolution Orchestration

Loaded by the orchestrator when `/evolve F-NNN "description" [flags]` is provided.
This is the **unified entry point** for feature-level evolution. It orchestrates all three
skills (prd-analysis → system-design → autoforge) in a single flow, with automatic
complexity determination and adaptive approval gate insertion.

## Command Syntax

```
/evolve F-NNN "description"                                     # auto-determine, auto-discover dirs
/evolve F-NNN "description" --prd-dir <dir> --design-dir <dir>  # explicit directories
/evolve F-NNN "description" --design                            # force Design review gate
/evolve F-NNN "description" --full                              # force full triple-gate review
```

When `--prd-dir` and `--design-dir` are not specified, the orchestrator auto-discovers:
1. **PRD directory**: read the design README's "Design Input" section → "Source" link (e.g. `../../prd/YYYY-MM-DD-slug/`)
2. **Design directory**: most recent subdirectory under `docs/raw/design/` sorted by date prefix

## Orchestration Sequence

### Step 0 — Resolve paths and parse input

1. Resolve `<prd-dir>` from `--prd-dir` flag, or auto-discover from the design README's "Design Input" → "Source" link.
2. Resolve `<design-dir>` from `--design-dir` flag, or auto-discover from `docs/raw/design/` (most recent by date).
3. Extract the F-ID and change description from the input string.
4. Extract gate flags: `--design` (force design gate), `--full` (force dual gate).

### Step 1 — Read feature-module map

Read `{design-dir}/feature-module-map.yml` (resolved in Step 0).
Locate F-NNN's entry.

If F-NNN is not found, exit with error:

> F-{NNN} not found in feature-module-map.yml. If this is a new feature,
> run `/prd-analysis add` to create it first, then `/system-design <prd-dir>`
> to generate a full design with the feature-module mapping.

### Step 2 — Auto-determine complexity

Before executing, the orchestrator analyzes the change to determine complexity level.
The analysis runs AFTER reading the feature-module-map.yml to know the module scope.

**Analysis Inputs:**
1. The user's change description (natural language)
2. The target feature's `feature-module-map.yml` entry (writes/reads counts)
3. Whether the change mentions: new data entities, state machine changes, API contract changes

### Complexity Rules

| Complexity | Criteria | Gate Count | Gate Positions |
|-----------|----------|------------|----------------|
| **Trivial** | writes ≤ 1 module, no new entities, no state machine change | 1 | After all work done (summary gate) |
| **Moderate** | writes 2–3 modules, OR minor API contract changes | 1 | After design delta (design gate) |
| **Complex** | writes ≥ 4 modules, OR new data entities, OR state machine changes, OR cross-feature impact | 2 | After contract update + after design delta |

### Override Rules

| User Flag | Effect |
|-----------|--------|
| (none) | Use auto-determined complexity |
| `--design` | Force Moderate: insert gate after design delta |
| `--full` | Force Complex: insert gates after contract AND after design delta |

The `--design` and `--full` flags override the auto-determination.
The auto-determination result is always displayed to the user:

```
Complexity: Moderate (auto-determined)
  Reason: writes 2 modules, minor API contract change
  Gates: 1 (after design delta)
  Override: /evolve "..." --full for triple-gate review
```

### Step 3 — Execute contract update (always)

Run `/prd-analysis modify <prd-dir> F-NNN "<description>"`:

```
Updating contract for F-{NNN}...
```

Wait for completion. If this step fails, abort the entire flow.

### Step 3a — Contract gate (Complex only)

If complexity is **Complex** (auto-determined or `--full`):

Display the contract diff to the user:

```
Contract change for F-{NNN}:

  {diff of the feature file changes}

Approve this contract change? [yes / no / revise]
```

- **yes**: continue to Step 4
- **no**: abort
- **revise**: re-run Step 3 with updated description

For Trivial and Moderate flows, skip this gate.

### Step 4 — Execute design delta (always)

Run `/system-design delta <design-dir> F-{NNN}`:

```
Computing module impact for F-{NNN}...
```

Wait for completion. Extract:
- Affected modules list (writes + reads)
- Module spec changes summary
- Regression-test scope

### Step 4a — Design gate (Moderate and Complex)

If complexity is **Moderate** (or `--design`) or **Complex** (or `--full`):

Display the design delta summary:

```
Design delta for F-{NNN}:

  Affected modules: M-001, M-005, M-007
  Module changes:
    M-001 (User): add payment_method field
    M-005 (Payment): add one-step endpoint, remove confirm page
    M-007 (Order): add payment_confirmed state
  Regression scope: F-001, F-004, F-007

Approve this design change? [yes / no / revise]
```

- **yes**: continue to Step 5
- **no**: abort
- **revise**: go back to Step 3 (modify contract to address concerns)

For Trivial flow, skip this gate.

### Step 5 — Execute implementation

Run `/autoforge --feature F-NNN <design-dir>`:

```
Implementing F-{NNN} in affected modules...
```

Wait for completion. This step includes:
- Scoped planner
- Module agent dispatches
- Feature-specific tests
- Regression tests
- Reverse alignment checksum

### Step 5a — Summary gate (all flows)

**Always show this gate.** Present the final summary:

```
F-{NNN} evolution complete.

Contract: F-{NNN} modified → {summary of behavior change}
Design:   {count} modules updated → {list of module changes}
Code:     {count} files changed → {list of key files}
Tests:    {count} passed ({N} feature, {M} regression)
Checksum: aligned ✓

Approve and merge? [yes / no]
```

- **yes**: commit all changes and merge
- **no**: abort (changes remain staged, not committed)

### Step 6 — Commit

Commit with message:

```
feat(evolve): F-{NNN} — {short summary}

Complexity: {Trivial|Moderate|Complex}
Modules: {list}
```

## FORBIDDEN

- Skipping the summary gate (Step 5a) — it's always shown, even for Trivial
- Modifying code before contract is updated (Step 3 always runs first)
- Skipping auto-determination (Step 2) unless `--design` or `--full` override is provided
- Running without a feature-module-map.yml present
