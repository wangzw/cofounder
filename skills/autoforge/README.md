# autoforge

A generative skill that turns a finalized system design into tested,
PRD-validated code through a multi-role agent team (planners → developers →
testers → reviewers) with DAG-based event-driven execution.

This README is for developers who want to **use**, **modify**, or
**audit** the skill. End-users typically just invoke
`/autoforge` from Claude Code; the entry-point doc for
that flow is `SKILL.md`.

---

## What it does

Takes a **system design bundle** (`docs/raw/design/`) and produces working code
in the project source tree:

```
docs/raw/design/YYYY-MM-DD-{slug}/
├── README.md              # ← input: module index + feature-module mapping
├── feature-module-map.yml # ← input: machine-readable F-NNN → M-NNN mapping
├── modules/M-NNN-*.md     # ← input: per-module implementation specs
└── api/API-NNN-*.md       # ← input: per-API contracts

                    ↓ /autoforge

src/                       # ← output: implemented code
├── {module}/              # one directory per module
│   ├── *.ts / *.py / ...  # implementation files
│   └── __tests__/         # feature-specific + regression tests
└── ...
```

Plus a `docs/raw/plans/` directory with per-run plan artifacts.

---

## Modes

| Command | Mode |
|---------|------|
| `/autoforge <design-dir>` | Full flow: plan → execute → accept |
| `/autoforge --plan-only <design-dir>` | Generate plans only, stop for human review |
| `/autoforge --execute <plan-dir>` | Execute existing plans |
| `/autoforge --evolve <design-dir>` | In-place mutation following `system-design --evolve` |
| `/autoforge --evolve --plan-only <design-dir>` | Stop after evolution re-plan |
| `/autoforge --status <plan-dir>` | Show progress of a run |
| `/autoforge --cleanup <plan-dir>` | Abandon run: remove worktrees, branches |

### Feature-scope mode

| Command | Mode |
|---------|------|
| `/autoforge --feature F-NNN <design-dir>` | Single-feature implementation. Reads `feature-module-map.yml`, scopes planner and module agents to only the affected modules (writes ∪ reads). Runs feature-specific tests + regression tests for overlapping features. |
| `/autoforge --feature F-NNN --plan-only <design-dir>` | Generate feature-scoped plans only. |

Feature-scope mode includes built-in **reverse alignment detection**: after
implementation, it computes a checksum of the PRD feature file and stores it in
`.review/contract-checksums.yml`. On subsequent code changes, if the checksum
diverges without a corresponding `/prd-analysis modify`, the merge is blocked.

`SKILL.md` "Mode Routing" has the full per-mode loaded-files map.

---

## Architecture: DAG event-driven execution

Autoforge uses a DAG-based scheduling model:

1. **Conventions bootstrap** runs first (one serialized step) to set up
   project scaffolding (lint config, CI, git hooks).
2. **Tier-1 Planners** run in foreground parallel — one planner per
   DAG-initial ready set (modules with no dependencies).
3. **Event-driven execution loop** saturates background agents (Planners +
   Module Agents) up to configured caps (`max_planners=3`, `max_modules=6`).
   Each module is scheduled as soon as its DAG ready-set is satisfied.

Each Planner receives only its **dependency closure** of already-completed plans,
keeping input size proportional to fan-in. A neighborhood-scope integration test
runs per module merge (not at phase boundaries). Plan revision signals
(`PLAN_REVISION_NEEDED`, `CONVENTION_CONFLICT`) trigger re-plan flows.

---

## Reverse Alignment Guarantee

The checksum system in feature-scope mode provides a bridge between code and contract:

```
PRD feature file (contract truth)
        │
        ├── checksum stored at implementation time
        │   (.review/contract-checksums.yml)
        │
        └── subsequent code changes → checksum mismatch detected
            → merge blocked → human must /prd-analysis modify to reconcile
```

The invariant: **PRD feature file checksum MUST match the stored checksum.**
Enforced at: end of `--feature` run, on merge to main (CI hook), and on
code changes in watched module directories.

---

## Running tests

```bash
# Full suite
bash skills/autoforge/tests/run-all.sh

# Single test runner
bash skills/autoforge/tests/test-check-plan.sh
```

---

## Design references

| Document | Topic |
|----------|-------|
| `SKILL.md` | Full mode routing, agent dispatch, model tiers |
| `feature-scope.md` | Single-feature implementation orchestration + reverse alignment |
| `generate/planner-subagent.md` | Planner agent prompt |
| `generate/module-agent-subagent.md` | Module developer agent prompt |
| `generate/tester-subagent.md` | Tester agent prompt |
| `generate/reviewer-subagent.md` | Reviewer agent prompt |
| `common/config.yml` | Model tier defaults, execution caps |

---

## Stats

- **8 modes** (default, plan-only, execute, evolve, evolve plan-only,
  evolve fresh, status, cleanup) + feature-scope mode
- Agent roles: planner, module developer, tester, reviewer
- DAG-based scheduling with configurable caps

---

## Pipeline Position

```
/prd-analysis  →  /system-design  →  /autoforge
                                      ↑
                        Feature-level: /prd-analysis modify → /system-design delta → /autoforge --feature
                                      ↑
                        Unified: /evolve "F-NNN description"
```
