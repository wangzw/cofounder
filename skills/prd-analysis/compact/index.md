# compact mode — retire intermediate review rounds of the current delivery

> Loaded by SKILL.md when the user invokes
> `/cofounder:prd-analysis --compact <prd-dir>`. This file is the only
> orchestration document loaded in compact mode.

## When to use

After many review/revise rounds (often 10+), the current delivery's PRD
bundle has converged (`verdict: converged`) but `.review/round-*/` is
heavy with intermediate per-round scaffolding. Before handing the PRD
off to the next pipeline stage (e.g. `/cofounder:system-design`), the
user runs `--compact` to:

1. Aggregate the intermediate rounds of the **current delivery** into a
   single `.review/round-<final>/compacted-history.md` summary.
2. Delete the intermediate `round-N/` directories and their matching
   `.review/traces/round-N/` subtrees.

Older deliveries (lower `delivery_id`) are out of scope here — they have
their own coarse-grained archival path.

## Scope

- **Read**: `.review/round-*/index.md`, `.review/round-*/verdict.yml`,
  `.review/round-*/issues/*.md` (frontmatter only).
- **Write**: `.review/round-<final>/compacted-history.md` (new file).
- **Delete**:
  - Every `.review/round-<N>/` of the current delivery EXCEPT the final
    converged round, AND the matching `.review/traces/round-<N>/` for
    each one.
  - Any `.review/traces/round-<N>/` whose round-N/ directory is already
    gone (orphans from older deliveries that were compacted in prior
    runs). Non-round entries under `traces/` (e.g. `metrics-cache/`)
    are left untouched. The final round's `traces/round-<final>/`
    survives as the converged-round audit snapshot.

The orchestrator delegates everything to deterministic scripts. No
sub-agent is dispatched in this mode.

## Steps

### Step 1 — Bootstrap precheck

Run `scripts/git-precheck.sh`. On non-zero exit, abort.

### Step 2 — Verify phase entry

```bash
scripts/verify-phase-entry.sh compact <prd-dir>
```

Refusal causes (script exits 1):

- No `.review/` directory.
- No round directory has a usable `delivery_id` in `verdict.yml` or
  `index.md` frontmatter.
- The current delivery's final round does not have `verdict: converged`.
- The current delivery has only one round (nothing to compact).

If the gate refuses, surface the script's stdout to the user and stop.

### Step 3 — Dry-run preview

```bash
scripts/compact-delivery.sh <prd-dir> --dry-run --force
```

`--force` here lets the dry-run run even when no `delivery-<N>-<slug>`
git tag exists yet (the actual destructive step in Step 5 re-evaluates
this). Output lists exactly which file would be written and which
directories would be removed.

Show the output to the user verbatim.

### Step 4 — HITL approval (mandatory, except in `--auto` flow)

Present the dry-run summary and ask the user to approve. Compaction is
destructive; if a `delivery-<N>-<slug>` git tag is missing, the warning
in Step 3 indicates the deleted rounds will not be recoverable from git
history.

Acceptable answers:

- `approve` → proceed to Step 5.
- `cancel` → exit 0 without modification.
- `commit-first` → instruct the user to run
  `scripts/commit-delivery.sh <prd-dir> <delivery-id> "<summary>"`
  themselves, then re-run `--compact`. Exit 0.

**`--auto` flow.** When this orchestration is invoked from the review
mode's auto-converged delivery sequence (review/index.md Step 9.4),
Steps 3 and 4 are skipped: the `delivery-<N>-<slug>` tag was just
created in Step 9.3 so the destructive guard is already satisfied, and
HITL approval is replaced by the global `--auto` contract from
SKILL.md. Step 5 runs `scripts/compact-delivery.sh <prd-dir>` directly
(no `--force`, no `--dry-run`).

### Step 5 — Apply

```bash
scripts/compact-delivery.sh <prd-dir> [--force]
```

Pass `--force` only if the user explicitly approved despite the missing
git tag warning. Otherwise omit it and let the script refuse if there
is no tag.

### Step 6 — Post-compact validation

```bash
scripts/run-checkers.sh <prd-dir>
```

The newly-written `compacted-history.md` is audited by
`check-compacted-history.sh` (CR-CH01, CR-CH02). Any non-zero exit means
the summary did not pass formal review — surface to the user.

### Step 7 — Optional commit

If the working tree is dirty after compaction (the deleted directories
and the new summary file), prompt the user to either:

- Commit the cleanup with a `chore(<skill>): compact delivery-<N>
  rounds` message, or
- Leave the workspace dirty for the user to inspect.

The orchestrator MUST NOT auto-commit without confirmation.

### Step 8 — Print next-step hint

```
Compact complete: delivery-<N> intermediate rounds retired.

Next steps:
  Interactive — /cofounder:system-design <prd-dir>
  Automated  — claude -p "generate system design based on <prd-dir>" --auto
```

## Failure handling

| Failure | Response |
|---------|----------|
| Step 2 gate fails | Surface stdout; do not proceed |
| Step 3 dry-run fails (exit 2) | Treat as script error; HITL |
| Step 5 refuses (no tag, no `--force`) | Re-prompt user with explicit warning; on approval re-run with `--force` |
| Step 6 reports CR-CH01/CR-CH02 | The summary file is malformed — this is a `compact-delivery.sh` bug; revert with `git checkout` and HITL |

## Forbidden actions

- Reading or rewriting any PRD content leaf (README.md, features/,
  journeys/, architecture/) — compact only touches `.review/`.
- Reading issue bodies (frontmatter aggregation only — done by the
  script, not by the orchestrator).
- Auto-running compact across multiple deliveries in a single
  invocation — one delivery per call.
- Running compact on a non-converged delivery, even with `--force`.
