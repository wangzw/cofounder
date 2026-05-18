---
name: autoforge
version: 1.6.1
description: "Use when the user has a finalized system design (system-design skill output) and wants to automatically implement it as working code, including evolving an already-implemented design after `system-design --evolve`. Triggers: /autoforge, 'implement the design', 'start development', 'auto implement', 'build the modules', 'evolve the implementation', '--evolve'."
---

# Autoforge — Multi-Role Automated Development

Orchestrate agent teams to turn a system design into tested, PRD-validated code. Modules are planned **phase by phase** — phases run sequentially so upstream plans are finalized first, but Planners within a phase run in parallel (same-phase modules are independent by construction). Each Planner receives only its **dependency closure** of already-completed plans instead of every prior plan, keeping input size proportional to fan-in. Execution then runs modules in parallel with isolated git worktrees; each module gets a team (Developer, Tester, Reviewer). Fully automated with adaptive iteration — human intervenes only at explicit approval gates or when the agent has exhausted reasonable approaches and needs a trade-off decision.

## Input Modes

```
/autoforge docs/raw/design/2026-04-09-agent-team/              # full flow (plan → execute → accept)
/autoforge --plan-only docs/raw/design/2026-04-09-agent-team/   # generate plans only, stop for human review
/autoforge --execute docs/raw/plans/2026-04-09-agent-team-a3f1/     # execute existing plans (reads design/PRD paths from plan README)
/autoforge --evolve docs/raw/design/2026-04-09-agent-team/      # follow a `system-design --evolve` delivery: in-place mutate the
                                                                #   prior plan dir, re-plan only impacted modules, re-execute
/autoforge --evolve --plan-only docs/raw/design/2026-04-09-agent-team/   # stop after evolution re-plan, before execution
/autoforge --evolve --from docs/raw/plans/<plan-dir>/ docs/raw/design/<design-dir>/   # explicit prior plan dir (skip auto-discovery)
/autoforge --evolve --fresh docs/raw/design/2026-04-09-agent-team/       # escape hatch: NEW plan dir instead of in-place evolve
/autoforge --status docs/raw/plans/2026-04-09-agent-team-a3f1/      # show progress
/autoforge --cleanup docs/raw/plans/2026-04-09-agent-team-a3f1/     # abandon run: remove worktrees, branches, optionally plans
```

## Mode Routing

Detect the mode first. Read the routing files for that mode only — do not load the others.

| Mode | Trigger | Read These Files |
|------|---------|------------------|
| **Default** | `/autoforge <dir>` | Load per-step as needed (see loading notes in Steps 1–3 below) |
| **Plan only** | `--plan-only` | Same — stops after Step 1; only planner files are ever loaded |
| **Execute** | `--execute <plan-dir>` | Same — skip planner files unless re-plan is triggered |
| **Evolve** | `--evolve <design-dir>` | Load `--evolve Mode` section; same step files as Default but driven by Steps E0–E6 (planner + module-agent + execution prompts; same templates) |
| **Evolve plan-only** | `--evolve --plan-only` | Same as Evolve — stops after Step E4 |
| **Evolve fresh** | `--evolve --fresh` | Falls through to Default with a forced new plan directory; not the recommended path |
| **Status** | `--status <plan-dir>` | No additional files (read-only query) |
| **Cleanup** | `--cleanup <plan-dir>` | No additional files |

## Model Tiers

Abstract: `heavy` / `balanced` / `light`. Mapping in `common/config.yml` (`model_tier_defaults` + `model_mapping`).

### Per-dispatch model override (MANDATORY for cost control)

When the orchestrator dispatches a sub-agent via the Claude Code Agent tool, it **MUST** pass the `model` parameter to override the default (parent-session inheritance). Without this override, all sub-agents run on the parent session's model — typically `opus` — which costs 5–25× the configured tier rate. Per the `model_tier_defaults` section of `common/config.yml`:

| Role | Default tier | Agent-tool `model` value | Why |
|------|------|------|------|
| Planner | `heavy` | `"opus"` | Architecture decisions, cross-module consistency, most reasoning-heavy role in the pipeline |
| Bootstrap | `balanced` | `"sonnet"` | Mechanical project scaffolding from a tech-stack spec |
| Module Agent (2nd-level orchestrator) | `balanced` | `"sonnet"` | Flow control + state updates; escalates only on Replan/Diagnosis |
| Developer (initial + retry) | `balanced` | `"sonnet"` | Implementing code from a detailed plan |
| Developer (Replan Mode — Variant 4) | `heavy` | `"opus"` | New-strategy design after the current approach stalled |
| Tester | `balanced` | `"sonnet"` | Test authoring from spec acceptance criteria is mechanical |
| Reviewer | `balanced` | `"sonnet"` | Spec-compliance checking; escalate to `heavy` after repeated REJECT pattern |
| Integration Tester | `balanced` | `"sonnet"` | Phase-level test authoring + execution |
| Acceptance Tester | `balanced` | `"sonnet"` | E2E tests + traceability matrix; escalate to `heavy` for ambiguity classification |

**Escalation rule** (declared in `common/config.yml#escalation`): when Replan / Diagnosis triggers (Module Agent stalled ≥3 non-progress rounds), the next Developer spawn uses `heavy`. After one heavy-backed Replan attempt, revert. For the Acceptance Tester: after classifying a failure as PRD-ambiguity, the next ambiguity-classification pass uses `heavy`; revert once resolved.

**Why not heavy everywhere:** the heavy tier is ~5× balanced on input and ~15× on cache_read. Autoforge's inner loop (Developer → Tester → Reviewer) runs dozens of times per module across many modules — a mis-tiered default multiplies across the whole run. Balanced is the right default; heavy is a targeted escalation, not a baseline.

## Process Overview

```mermaid
flowchart TD
  S0[Step 0: Prep<br/>+ Skeleton + DAG]
  G0{G0: Phase breakdown<br/>human approve}
  G1{G1: Skeleton review<br/>human approve}
  BOOT[Conventions bootstrap<br/>serial: M-001 Planner foreground]
  T1P[Tier-1 Planners<br/>foreground parallel]
  T1G[Tier-1 auto checker<br/>--scope=tier-1]
  LOOP[Event loop starts<br/>max_planners=3, max_modules=6]
  BG[(Background Agents<br/>Planner / Module / Integration)]
  EVT{Completion notification}
  REV{PLAN_REVISION?}
  DEC{DECISION_REQUEST?}
  CONV{CONVENTION_CONFLICT?}
  DONE{ready & inflight empty?}
  ACC[Step 3: Acceptance Tester]
  G3{G3: Final acceptance}
  MAIN[Step 4: Merge to main]

  S0 --> G0 --> G1 --> BOOT --> T1P --> T1G --> LOOP
  LOOP --> BG --> EVT
  EVT --> REV
  REV -- yes --> FREEZE[Freeze → Cancel inflight → Re-plan → R4 diff review] --> LOOP
  REV -- no --> DEC
  DEC -- yes --> HUMAN[Human picks option] --> LOOP
  DEC -- no --> CONV
  CONV -- yes --> CONFLICT[Human resolves conflict] --> LOOP
  CONV -- no --> DONE
  DONE -- no --> LOOP
  DONE -- yes --> ACC --> G3 --> MAIN
```

## Step 0 — Initialization

1. **Read design input** — read design README.md (module index, dependency graph, Feature-Module mapping, interaction protocols, test strategy) + all module specs (`modules/*.md`) + API contracts (`api/*.md` if present)
2. **Read project coding standards** — gather conventions from three sources in priority order:
   - **(a) CLAUDE.md and AGENTS.md** (if they exist) from the project root — project-specific overrides; highest priority
   - **(b) Design README's Implementation Conventions and Key Technical Decisions** — design-level conventions translated from the PRD
   - **(c) PRD architecture.md developer convention sections** — follow the design README's `Design Input > Source` to the PRD directory, then read `architecture.md` for: Coding Conventions, Test Isolation, Development Workflow, Security Coding Policy, Backward Compatibility, Git & Branch Strategy, Code Review Policy, Observability Requirements, Performance Testing, AI Agent Configuration, Deployment Architecture (environments, local dev setup, config management, CD pipeline, environment isolation)
   
   Merge these into a unified `project_coding_standards` context: (a) overrides (b) overrides (c). Pass relevant sections to all sub-agents throughout the pipeline.
3. **Locate PRD** — follow `Design Input > Source` to find the PRD directory. Read: `README.md` (feature index only). Do NOT read journeys/ or architecture topic files upfront — they are not needed for planning. Individual module Planners and Developers will read specific feature files (and the frontend draft files referenced via `Frontend Draft Reference`) on demand when they need acceptance criteria, interaction design details, or existing-code context.
4. **Build dependency graph** — from Module Index `Deps` column, construct a DAG. Topologically sort into phases: Phase 1 = modules with no dependencies, Phase 2 = modules whose deps are all in Phase 1, etc.
5. **Detect project state** — check if project has existing source code (package manifests, src directories). If so, note this — Planners must account for existing code structure
6. **Determine output paths**:
   - Plan output: `docs/raw/plans/{design-dir-name}-{hash4}/` where `{design-dir-name}` comes from the design directory name (e.g. `2026-04-09-agent-team`) and `{hash4}` = `$(git rev-parse --short=4 HEAD)`
   - Feature branch: `autoforge/{design-dir-name}-{hash4}`
   - Worktree root: `{project-root}/../{project-dirname}-worktrees/autoforge-{design-dir-name}-{hash4}/` — sibling to the project directory, one subdirectory per autoforge run
7. **Create feature branch and primary worktree** — the main project directory stays on its current branch throughout the autoforge run. All autoforge work happens in worktrees:
   ```
   git branch autoforge/{design-dir-name}-{hash4}
   git worktree add {worktree_root}/main autoforge/{design-dir-name}-{hash4}
   ```
   The **primary worktree** (`{worktree_root}/main/`) is used for all non-module work: planning, bootstrap, integration tests, acceptance tests, and status updates. Module-specific work uses separate per-module worktrees (see Step 2).
7a. **Switch Orchestrator cwd to the primary worktree (MANDATORY)** — every subsequent Bash, Read, Write, Edit, and `Agent` spawn the Orchestrator makes MUST run with cwd = `{worktree_root}/main`. Sub-agents inherit the parent's cwd, so this is the single defensive measure that keeps Planner / Bootstrap / Integration / Acceptance sub-agents from accidentally writing to the main project directory when their prompt uses a relative path (the observed failure mode: a Planner whose prompt accidentally omits "all paths resolve inside the worktree" wording falls back to the parent cwd and writes plan files to the project root on `main`).
   ```
   cd {worktree_root}/main
   git rev-parse --abbrev-ref HEAD   # MUST print autoforge/{design-dir-name}-{hash4}
   pwd                                # MUST print {worktree_root}/main
   ```
   If either verification fails, abort with HITL — do NOT continue. After this point, the Orchestrator MUST NOT `cd` back to the main project directory for any operation until Step 4 (Merge to Main).
8. **Build Module Index JSON** — extract every module from the design README's Module Index table into `<plan-dir>/modules.json`:
   ```json
   [
     {"id": "M-001", "deps": []},
     {"id": "M-002", "deps": ["M-001"]}
   ]
   ```
   Use this JSON as the source of truth for the scheduler — the table in
   the design README is human-readable; this file is machine-readable.

9. **Initialize run-state.json:**
   ```
   bash skills/autoforge/scripts/run-state-init.sh \
        <plan-dir> <plan-dir>/modules.json
   ```
   Confirm the file appeared and reports the expected module count.

10. **Compute and present the DAG + tier breakdown** — show the user:
    - Module count, tier breakdown (Tier 1: [M-001, M-005, M-007], Tier 2: [M-002], ...)
    - DAG visualization (mermaid)
    - Branch and worktree-root paths
    - Scheduler caps (`max_planners`, `max_modules`) from config.yml

11. **G0 — Phase breakdown gate (human approve)** — user confirms tier breakdown, branch naming, output paths.

12. **G1 — Skeleton review gate (human approve)** — present a short skeleton document containing:
    - Module list with one-line purpose each (from design README)
    - DAG mermaid (re-shown)
    - Module Interaction Protocols — the contracts between modules (copy verbatim from design README)
    - Key Technical Decisions summary (3-5 bullets)
    Do **not** include detailed per-module plans here. User approves before any Planner runs.

    On approval:
    ```
    bash skills/autoforge/scripts/run-state-update.sh \
         <plan-dir> gate-approve G1_skeleton_approved
    ```

## Step 1 — Conventions Bootstrap + Tier-1 Plans (foreground)

> **Load now:** `planning/planner-prompt.md`, `planning/plan-readme-template.md`, `planning/module-plan-template.md`

The event-driven scheduler needs a starting state with:
1. `conventions.md` written (so subsequent Planners share a base).
2. Every tier-1 module's plan written (so tier-1 Module Agents have ready
   plans, and tier-2 Planners have their dependency-closure inputs).

These two are produced **in the foreground** (not via the event loop) so
the human review gate stays simple. Once tier-1 plans pass the automated
checker, control passes to Step 2's event loop.

### Conventions Bootstrap (single serialized step)

Spawn the **lowest-M-id tier-1 Planner** alone in the foreground (NOT
background). Its job: produce `conventions.md` AND its own
`plan-M-{id}.md`. Use the standard Planner prompt; the only special input
is `is_first_module=true`.

```
Agent({
  description: "Planner for M-{id} (conventions bootstrap)",
  prompt: <fill in planning/planner-prompt.md;
           is_first_module=true,
           dependency_closure_plan_paths=[],
           worktree_path={worktree_root}/main>,
  model: "opus",
  mode: "auto"
})
```

After return: verify `plans/conventions.md` and `plans/plan-M-{id}.md`
exist. Update run-state:
```
bash skills/autoforge/scripts/run-state-update.sh \
     <plan-dir> set-plan-status M-{id} planned
```

### Tier-1 Planners (foreground, parallel)

Identify all other tier-1 modules (closure is empty). Spawn them all in
**one message with multiple `Agent` tool calls in parallel** (still
foreground — `run_in_background: false`, default). After all return,
update each via `run-state-update.sh ... set-plan-status M-{id} planned`.

### Conventions rolling-merge (during foreground tier-1)

The Planners write `conventions-additions/M-{id}.md` files. As each
Planner returns, before spawning the next round (or before proceeding to
the auto-checker step), merge them:

For each `conventions-additions/M-*.md` file:
1. Read the addition.
2. Compare against `conventions.md`. If purely additive → append.
3. If a **semantic conflict** with existing rules is detected → STOP and
   route to `CONVENTION_CONFLICT` revision (§5 revision flow).
4. Commit: `docs(plan): merge conventions additions from M-{id}`.
5. Delete the addition file.

The Orchestrator is the single writer of `conventions.md`; no race
because Planners only write to their own per-module files.

### Tier-1 auto-checker (replaces G2)

Once all tier-1 plans are written and conventions are merged, run:

```
bash skills/autoforge/scripts/run-checkers.sh <plan-dir> \
     --source-root <worktree_root>/main \
     --phase=plan --scope=tier-1 --json-only
```

Routing:
- All PASS → proceed to Step 2.
- `error` / `critical` findings → re-dispatch the corresponding tier-1
  Planner with the findings JSON. Bounded to 3 auto-fix rounds before
  escalating to a DECISION_REQUEST to the human.
- `warning` only → log to `revisions/auto-warnings.md` and proceed.

This is the autonomous safeguard that replaces the prior G2 (tier-1
detailed plan review). Per the design's D5 decision, the human is not
interrupted for tier-1 plans — they are gated by the checker.

**Step 1 → Step 2 gate:** Tier-1 auto-checker PASS (or 3 auto-fix rounds
exhausted, in which case the failure becomes a DECISION_REQUEST).

## Step 1.5 — Project Bootstrap (New Projects Only)

**Skip this step** if Step 0 detected an existing codebase (package manifests, src directories, build config). Proceed directly to Step 2.

This step only applies when creating a new project from scratch. It initializes the project in the primary worktree so all module worktrees inherit a working baseline.

1. **Read tech stack** — from design README.md (Tech Stack, Test Strategy sections)
2. **Spawn Bootstrap agent** in the primary worktree:
   ```
   Agent({
     description: "Project bootstrap",
     model: "sonnet",
     prompt: "Your first action MUST be:

         cd {worktree_path}
         pwd                                # MUST print {worktree_path}
         git rev-parse --abbrev-ref HEAD    # MUST start with autoforge/
         git rev-parse --show-toplevel      # MUST equal {worktree_path}

       If any check fails, abort with a FAIL message naming the discrepancy — do
       NOT proceed. Sub-agents inherit cwd from the parent; if you skip this check
       and the parent cwd is the project root, every relative-path Write / Bash
       command below lands on the project's default branch working tree.

       Then initialize project based on tech stack: {tech stack details}.
       Read the conventions file at {conventions_path} — it defines the expected
       directory structure, file naming, test organization, and shared types.
       Set up the project to match these conventions exactly:
       directory structure, dependency installation, build config, test framework, linter.
       Then scaffold CLAUDE.md based on AI Agent Configuration from the PRD architecture.md:
       generate a minimal CLAUDE.md with project overview placeholder, key commands
       from Development Workflow (build, test, lint), and references to convention
       files that the Development Infrastructure module will generate. Keep it
       concise (~200 lines or less) as a index file, not a monolithic document.
       Also scaffold deployment files based on Deployment Architecture from the PRD:
       environment variable template (.env.example with documented defaults from
       PRD config management policy) and local development setup script referenced
       in Development Workflow.
       Verify: project compiles, test command runs (0 tests), lint passes.
       Commit with message: 'chore: initialize project'",
     mode: "auto"
   })
   ```
   Substitute `{worktree_path}` with the absolute primary-worktree path (`{worktree_root}/main`).

## Step 2 — Event-driven Execution Loop

> **Load now:** `module/agent-prompt.md`, `module/developer-prompt.md`, `module/tester-prompt.md`, `module/reviewer-prompt.md`, `integration/tester-prompt.md`

After Step 1 hands over, the Orchestrator enters an event-driven loop. It
saturates two background-agent caps (Planners, Module Agents) plus
neighborhood Integration Testers, processing completion notifications as
they arrive.

### Loop body

```
loop:
  ready_plan = ready_set_planning(state)    # tier-2+ Planners
  ready_exec = ready_set_execution(state)   # any tier whose closure is merged

  while |inflight.planners| < scheduler.max_planners and ready_plan:
    M = pop ready_plan          # priority: lower tier first, then revising > pending
    spawn_planner(M, run_in_background=true)
    run-state-update.sh ... set-plan-status M planning
    run-state-update.sh ... inflight-add planners M

  while |inflight.modules| < scheduler.max_modules and ready_exec:
    M = pop ready_exec          # priority: needs_patch > lower tier > higher tier
    spawn_module_agent(M, run_in_background=true)
    run-state-update.sh ... set-exec-status M running
    run-state-update.sh ... inflight-add modules M

  if nothing in-flight and queues empty and human_gates.G3 not pending:
    break   # go to Step 3

  await any background-agent completion notification
    OR scheduler.idle_timeout_minutes elapsed

  process_result(returned_agent)   # see "Result handling" below
```

### Result handling

When a **Planner** returns:
- Check the plan file is present and well-formed (`run-checkers.sh ... --phase=plan --scope=module-M-{id}`).
- If checker has `error`/`critical` findings: auto-re-dispatch up to 3 rounds; on 3rd failure, route to DECISION_REQUEST.
- If conventions-additions present: rolling-merge it; if conflict detected, route to `CONVENTION_CONFLICT` revision.
- `run-state-update.sh ... set-plan-status M-{id} planned`
- `run-state-update.sh ... inflight-remove planners M-{id}`

When a **Module Agent** returns:
- `inflight-remove modules M-{id}`
- On STATUS = APPROVE: ff-merge the module branch, update `set-exec-status M-{id} integrating`, spawn neighborhood Integration Tester for M-{id} in background.
- On STATUS = CANCELLED (during freeze): `set-exec-status M-{id} cancelled`; record commit chain in `revisions/{seq}/cancelled-modules.json`.
- On STATUS = DECISION_REQUEST: pause loop, present to human, apply choice, re-dispatch.
- On STATUS = PLAN_REVISION_NEEDED: enter §5 revision flow.

When an **Integration Tester** returns:
- On PASS: `set-exec-status M-{id} merged` — this unblocks downstream modules.
- On FAIL: classify (own bug / upstream bug / design gap) and run the corresponding fix path:
  - **Own bug:** Spawn Developer in M's worktree (preserved from `integrating`). After fix, re-run Integration Tester with `is_rerun: true`.
  - **Upstream bug:** Mark the upstream module `set-exec-status M-{upstream} needs_patch`. Touch ready set — downstreams become non-ready. Re-open upstream worktree, spawn Module Agent in `needs_patch` mode. Cascade.
  - **Design gap:** Trigger `PLAN_REVISION_NEEDED` per §5.
- Bounded to 10 fix rounds, then DECISION_REQUEST.

### Neighborhood Integration Tester spawn

When spawning the Integration Tester:
```
Agent({
  description: "Neighborhood Integration Tester for M-{id}",
  prompt: <fill in integration/tester-prompt.md>,
  model: "sonnet",
  mode: "auto",
  run_in_background: true
})
```

Parameters:
- `target_module`: M-{id}
- `closure_module_ids`: state['modules'][M]['closure']
- `neighborhood_design_paths`: design specs for {M} ∪ closure
- `already_merged_modules`: all merged modules NOT in closure (informational)
- `worktree_path`: {worktree_root}/main
- `conventions_path`, `project_coding_standards`, `is_rerun`: as before
- `discipline_path`: absolute path to `skills/autoforge/delivery-discipline.md`

The Integration Tester writes its report to `reports/integration-M-{id}.md`.

### Idle-timeout handling

When the loop wakes from `idle_timeout_minutes` without a completion notification:
1. Run `bash skills/autoforge/scripts/check-idle-timeout.sh <plan-dir>`.
2. If CR-AF32 fires: present the dump to the human with three options:
   - "Investigate this inflight agent" (gives Orchestrator commands to inspect specific worktree)
   - "Force-remove from inflight" (removes the entry; next loop iteration respawns)
   - "Terminate run"
3. Continue loop after human input.

### Status updates on cadence

The Orchestrator commits `run-status.md` + DAG mermaid on the configured cadence (`scheduler.status_commit_every_k` transitions or `scheduler.status_commit_every_seconds` seconds, whichever comes first). Plan-state-internal events (single `set-plan-status` calls) update the file but do not necessarily commit each time.

Implementation: a counter in the orchestrator's session; when threshold met, `git add run-status.md README.md && git commit -m "docs(plan): update run-status"`.

### Session resume

If this Orchestrator session dies and is restarted with the same plan-dir:
1. `run-state.json` already exists. Read it.
2. Every entry in `inflight.*` is by definition orphaned (the harness does not reconnect to dead agents). For each:
   - Modules → `set-exec-status M-{id} cancelled`. Append a `resumed-from-orphan` marker to `revisions/auto-warnings.md`. Next loop iteration will respawn from ready set.
   - Planners → `set-plan-status M-{id} pending`. (Plan file may or may not exist; the next Planner spawn will overwrite as needed.)
   - Integration Testers → simply `inflight-remove`; next module-merge event will respawn.
3. Resume the main loop normally.

### Termination

When the loop breaks:
- All modules: `plan_status=planned` AND `exec_status=merged`.
- All inflight buckets empty.
- No revision in progress.

Run `bash skills/autoforge/scripts/run-checkers.sh <plan-dir> --source-root <worktree-root>/main --phase=execute --json-only`. Resolve any `error`/`critical` findings before proceeding to Step 3.

**Step 2 → Step 3 gate:** Loop terminated cleanly (no outstanding revision; `check-scheduler-state.sh` PASS).

## Step 3 — PRD Acceptance Validation

> **Load now:** `acceptance/tester-prompt.md`, `acceptance/report-template.md`

After all phases complete, validate against the original PRD.

### Acceptance Tester Role

> **Mandatory subagent boundary (delivery-1 / delivery-2 retro).** The
> Orchestrator is **structurally forbidden** from hand-writing
> `reports/acceptance.md` or `reports/traceability.json`. Both files
> MUST be produced by a fresh Acceptance Tester subagent spawned in
> this step. The subagent's report carries a sentinel
> `<!-- generated-by: acceptance-tester-subagent; version: N -->` as
> its first non-blank line; `check-acceptance-report.sh` (CR-AF24)
> refuses any acceptance.md missing the sentinel, and the
> `--gate=delivery-tag` mode of `run-checkers.sh` refuses to authorize
> tag creation in that case.
>
> If you ever feel the temptation as Orchestrator to "just write a
> short acceptance report myself", that is exactly the soft-pass
> failure mode that produced the d1 / d2 incidents. Spawn the
> subagent. No exceptions.

Spawn the Acceptance Tester agent in the primary worktree:

```
Agent({
  description: "Acceptance Tester",
  prompt: <fill in acceptance/tester-prompt.md with parameters below>,
  model: "sonnet",
  mode: "auto"
})
```

**Acceptance Tester parameters:**

| Parameter | Source |
|-----------|--------|
| `feature_branch` | `autoforge/{design-dir-name}-{hash4}` |
| `prd_path` | PRD directory path from Step 0.2 |
| `design_readme_path` | Design README.md path from Step 0 |
| `report_dir` | `docs/raw/plans/{plan-dir}/reports/` |
| `conventions_path` | `docs/raw/plans/{plan-dir}/plans/conventions.md` |
| `project_coding_standards` | Unified project conventions (same as passed to Module Agents) |
| `acceptance_threshold` | From plan README Design Input table (default: 80) |
| `is_rerun` | `false` on first run; `true` when re-running after fix cycle |
| `previous_report_path` | `docs/raw/plans/{plan-dir}/reports/acceptance.md` — only when `is_rerun = true` |
| `discipline_path` | Absolute path to `skills/autoforge/delivery-discipline.md` (the shared delivery-discipline ruleset; same value passed to every sub-agent) |

See `acceptance/tester-prompt.md` for the complete prompt template. The Acceptance Tester reads all PRD feature specs and journey specs, writes E2E tests, builds a requirements traceability matrix, and determines the verdict (PASS / PARTIAL / FAIL) based on the acceptance threshold.

**Structural acceptance gate (mandatory before declaring PASS).** After the Acceptance Tester writes its report and `traceability.json`, the Orchestrator runs:

```
bash skills/autoforge/scripts/run-checkers.sh {plan_dir} \
     --source-root {worktree_root}/main \
     --phase=accept
```

`--phase=accept` enables the full default check set: the always-on plan / module / pollution checks (`check-plan-readme.sh`, `check-module-plan.sh`, `check-plan-pollution.sh`), the discipline scan over the source tree (`check-discipline-scan.sh`), AND the acceptance-time checks (`check-acceptance-report.sh`, `check-traceability.sh`, `check-e2e-coverage.sh`). At this phase, `reports/acceptance.md` and `reports/traceability.json` are this delivery's own (the Acceptance Tester just wrote them) so gating against them is correct.

**Any `error`/`critical` finding (especially CR-AF09 orphan tests, CR-AF10 unmapped AC, CR-AF21 happy-path-only journeys, CR-AF20 "no error == success" assertions, CR-AF22 dependency-abandonment markers) blocks PASS** — treat these as acceptance failures and route through the fix cycle below. Warnings are listed in the report but do not block. This replaces the prior LLM-grep heuristics and matches the contract in delivery-discipline §F / §H / §M / §N.

### Acceptance Fix Cycle

If acceptance report shows failures:

1. **Classify each failure** — the Orchestrator analyzes the acceptance report and categorizes each failed criterion:

   | Failure Type | Example | Resolution path |
   |-------------|---------|----------------|
   | **Implementation bug** | Code has a logic error; fix is local to one module | Developer fix on feature branch |
   | **Cross-module issue** | Modules work individually but feature workflow breaks across boundaries | Developer fix with access to ALL involved modules' design specs |
   | **Design gap** | The design didn't specify how to handle this scenario; no module is responsible | **Return to re-planning** (Step 1) — design needs enhancement |
   | **PRD ambiguity** | Acceptance criterion is unclear, contradictory, or untestable as written | **Present to human** — PRD clarification needed (outside autoforge scope) |

2. **Handle implementation bugs and cross-module issues** — fixes run in the **primary worktree** (`{worktree_root}/main/`) on the feature branch. All module code is already merged here, and acceptance fixes are sequential. Pass `{worktree_path}` (= `{worktree_root}/main`) explicitly so the Developer's Setup step can `cd` into it; without this guard, the Developer could commit source-tree fixes to the project's default branch and CR-AF29 would not catch it (CR-AF29 only scans plan-dir). For each failure, spawn a Developer agent:

   ~~~~
   You are a Developer fixing acceptance test failures.

   ## Setup (MANDATORY — do this before reading anything)

   ```
   cd {worktree_path}
   pwd                                # MUST print {worktree_path}
   git rev-parse --abbrev-ref HEAD    # MUST start with "autoforge/" (the feature branch)
   git rev-parse --show-toplevel      # MUST equal {worktree_path}
   ```

   If any check fails, abort with a FAIL message naming the discrepancy. Do
   NOT proceed: relative-path Writes and commits below would land on the
   project's default branch, and the source-tree pollution would not be
   caught by CR-AF29.

   ## Failed Criteria
   {paste failed items from acceptance report: criterion reference, expected, actual, fix suggestion}

   ## Your Task
   - Read the relevant module design specs: {all module_design_paths for modules involved in the failure}
   - Read the failing acceptance tests to understand what's expected
   - For cross-module issues: read the Module Interaction Protocols from the design README
   - Fix the source code to satisfy the acceptance criteria
   - Do NOT modify the acceptance test files
   - Run all tests to verify your fix doesn't break anything
   - Commit with message: "fix(M-{id}): {acceptance criterion description}"

   ## Inputs
   - Project conventions: {conventions_path}

   ## Rules
   - Fix only the specific issues listed — do not add features or refactor
   - If multiple criteria fail for the same root cause, fix them together in one commit
   - If you cannot fix the issue because the design doesn't support it, report it rather than implementing an ad-hoc workaround

   ## Project Coding Standards

   {project_coding_standards}
   ~~~~

3. **Handle design gaps** — if any failures are classified as design gaps:
   - These cannot be fixed by code changes alone
   - **Return to Step 1 (Re-planning)** with the acceptance failure evidence, same as PLAN_REVISION_NEEDED (significant) handling
   - Re-planning will produce revised plans that address the design gap
   - Human reviews revised plans before resuming execution

4. **Handle PRD ambiguities** — if any failures are classified as PRD issues:
   - Present to human with the specific acceptance criteria that are problematic
   - Human can: clarify the criterion (Orchestrator updates the acceptance test), waive the criterion (mark as NOT_COVERED with reason), or adjust the acceptance threshold

5. **Re-run acceptance tests** — Acceptance Tester re-runs full suite (with `is_rerun: true`, `previous_report_path: {report_dir}/acceptance.md`)
6. **Continue up to a ceiling** — repeat fix cycles while failing test count decreases, up to a maximum of **10 fix rounds**. If stalled for 3 consecutive rounds without progress, re-analyze and try a different approach. If still blocked after 10 rounds or after exhausting reasonable approaches, present the residual failures to the user per PARTIAL Verdict Handling below. Follow the same autonomous-first principle as module-level iteration.

### PARTIAL Verdict Handling

When the acceptance fix cycle stabilizes at PARTIAL (no further progress but some non-critical failures remain), present the acceptance report to the user with options:
- **(a) Merge with PARTIAL verdict** — accept the remaining gaps as known limitations; proceed to Step 4
- **(b) Continue fixing with user guidance** — user provides priorities or hints on which failures to focus on; resume fix cycle
- **(c) Abort and return to design phase** — the gaps indicate a design-level issue; return to re-planning (Step 1)

### After Acceptance

1. **Commit final report** — `docs/raw/plans/{plan-dir}/reports/acceptance.md`, commit: `docs(plan): add acceptance report`
2. **Update all statuses** — plan README status tables + design doc Impl columns (all modules `Done`, design-level Status → `Implemented`)
3. **Final commit** — `docs(plan): mark implementation complete`

## Step 4 — Merge to Main

Executed when acceptance verdict is PASS, or when the user explicitly chooses to merge with a PARTIAL verdict (see Acceptance Fix Cycle — PARTIAL Verdict Handling, option a).

0. **Pre-merge delivery gate (MANDATORY).** Before any rebase or merge,
   run the same gate the evolution-mode Step E6 mandates:

   ```bash
   bash skills/autoforge/scripts/run-checkers.sh \
     docs/raw/plans/{plan-dir}/ \
     --source-root {worktree_root}/main \
     --gate=delivery-tag
   ```

   The exit code is the authorization signal. Exit 0 → proceed. Exit
   1 → DO NOT merge; route blocking findings through the Acceptance
   Fix Cycle. This is identical to Step E6's gate and applies to
   delivery-1 (default mode) as well — the d1 / d2 retros showed both
   modes were vulnerable to the same self-attestation soft-pass.

1. **Rebase feature branch** onto latest main (in the primary worktree, which is on the feature branch):
   ```
   cd {worktree_root}/main
   git rebase main
   ```
2. **Remove primary worktree** — frees the feature branch for merge:
   ```
   git worktree remove {worktree_root}/main
   ```
3. **Fast-forward merge** (in the main project directory, which is on `main`):
   ```
   cd {project-root}
   git merge --ff-only autoforge/{design-dir-name}-{hash4}
   ```
4. **Cleanup** — delete feature branch + worktree root:
   ```
   git branch -d autoforge/{design-dir-name}-{hash4}
   rm -rf {worktree_root}
   ```
5. **Report** — print summary: modules implemented, tests passing, acceptance pass rate

If rebase has conflicts, pause and present to human for resolution.

## --execute Mode

> **Load on entry:** `module/agent-prompt.md`, `module/developer-prompt.md`, `module/tester-prompt.md`, `module/reviewer-prompt.md`, `integration/tester-prompt.md`, `acceptance/tester-prompt.md`, `acceptance/report-template.md`
> **Load only if re-plan triggered:** `planning/planner-prompt.md`, `planning/plan-readme-template.md`, `planning/module-plan-template.md`

When invoked with `--execute docs/raw/plans/{plan-dir}/`:

1. **Read plan README** — extract Source Design, Source PRD, Feature Branch, and **Worktree Root** from the Design Input table
2. **Recover or create worktrees** — use the plan README's `Worktree Root` field as the authoritative source for the worktree root path. Do not derive it from the branch name (the branch name `autoforge/{design-dir-name}-{hash4}` uses a slash while the worktree directory uses a hyphen: `autoforge-{design-dir-name}-{hash4}`). Check for existing worktrees:
   ```
   git worktree list   # check for stale worktrees under {worktree_root}
   ```
   - Primary worktree (`{worktree_root}/main/`): if exists and on feature branch → reuse; if missing → create
   - Module worktrees: handle based on module status (see step 4)
   - Stale worktrees (no matching status entry): remove with `git worktree remove`
2.5. **Resume Protocol — audit-driven reconciliation (MANDATORY when resuming).** Before trusting the README status tables, run the phase audit to surface anything the prior session left behind:

   ```
   bash skills/autoforge/scripts/run-checkers.sh {plan_dir} \
        --source-root {worktree_root}/main \
        --phase=execute \
        --json-only
   ```

   `--json-only` is recommended whenever the agent will parse the result — stdout becomes a pure JSON document (`{"issues": [...]}`) consumable by `json.load(sys.stdin)`, no skip-line / `2>&1` dance.

   For each finding, reconcile by **what is on disk**, not by what the status table says (status tables are written by the Orchestrator and lag actual progress when a session crashes mid-step):

   | Finding | What it means | Reconciliation |
   |---------|--------------|----------------|
   | CR-AF30 in `p{n}-M-{id}-{slug}/` + module's `module-state-M-{id}.json` says `developer_complete` or later | Agent finished its work but the orchestrator did not capture the return — the prior session was killed during the `Agent({Module Agent})` await | Read the worktree commits + dirty files. If commits match the expected `feat(M-{id})` / `test(M-{id})` / `docs(M-{id})` chain AND the dirty files are obviously continuations of that work → re-dispatch a Module Agent "finishing pass" to commit them and emit STATUS. If the dirty files look unrelated → escalate. |
   | CR-AF30 in `p{n}-M-{id}-{slug}/` + no `module-state-M-{id}.json` OR state says `not_started` | Crashed Module Agent on its first attempt | Read dirty files; `git stash push -u -m "rescued from initial attempt"`; restart Module Agent from scratch (Variant 1). |
   | CR-AF30 in `{worktree_root}/main/` | Pending Integration / Acceptance / orchestrator-level artifact | Inspect the diff. If it is a report the prior session generated but did not commit → commit with the documented message. If it is a partial fix → restart that step. |
   | CR-AF31 (orphan module branch) | Either: (a) prior phase's cleanup step crashed after merge, leaving the branch behind; (b) prior phase was abandoned before merge | Run `git log <branch> --not autoforge/<run>/main --oneline`. Empty = case (a), safe to `git branch -d <branch>` (plain `-d`). Non-empty = case (b), present to the human with the unmerged commit list. |

   **Never auto-discard.** No `git checkout --`, `git reset --hard`, or `git branch -D` without explicit human confirmation — the dirty files / unmerged commits may be the only record of work the prior agent completed before crashing. The audit script never deletes anything; the Orchestrator must not either.

   Re-run the audit after every reconciliation step. Proceed to step 3 only when it emits PASS, OR when the only remaining findings are tied to modules whose status will be re-driven anyway in step 6 (entry point determination).
3. **Read design and PRD** — same as Step 0.1 and 0.2, using paths from the plan README
4. **Detect current state** — read plan README status tables and determine state per module:

   | Module Status | Interpretation | Action | Worktree handling |
   |--------------|----------------|--------|------------------|
   | Merged = `Yes` | Fully complete | Skip | Remove worktree + branch if still present |
   | Dev/Test/Review all `—` | Not started | Execute from beginning | Create fresh worktree |
   | Dev = `Done` or `Retry`, Merged ≠ `Yes` | In progress or failed | Re-execute | Reuse existing worktree if present; create fresh if missing |
   | Any column = `Revision` | Plan being revised | Read `reports/plan-revision-M-{id}.md` for issue details; re-plan then re-execute | Clean up old worktree; create fresh after re-plan |
   | Any column = `Decision` | Waiting for human decision | Read `reports/decision-request-M-{id}.md` for diagnosis + options; present to user | Reuse existing worktree (has partial work for inspection) |
   | Any column = `Skipped` | Human chose to skip | Skip | Remove worktree + branch if still present |

   For phase status:
   - Phase is **complete** if all its modules are `Merged = Yes` and Integration Test = `Pass`
   - Phase is **in progress** if any module is started but phase is not complete
   - Phase is **pending** if no modules have started

5. **Detect bootstrap status** — check if the feature branch contains a commit with message `chore: initialize project`. If yes, bootstrap is complete. If the design's project state was "existing source code" (Step 0.5), bootstrap was skipped and is considered complete.

6. **Determine entry point**:
   - If no phases started and bootstrap not complete → start at Step 1.5
   - If bootstrap complete but no modules executed → start at Step 2, Phase 1
   - If some phases complete → start at the first incomplete phase
   - If all phases complete but no acceptance → start at Step 3
   - If acceptance ran but failed → start at acceptance fix cycle

7. **Resume execution** — follow Step 1.5 → Step 2 → Step 3 → Step 4 from the determined entry point, skipping completed work

This mode is useful for:
- Resuming after an interruption
- Executing plans that were generated with `--plan-only`
- Retrying after human-resolved decision requests

## --evolve Mode

> **Load on entry:** `planning/planner-prompt.md`, `planning/plan-readme-template.md`, `planning/module-plan-template.md`, `module/agent-prompt.md`, `module/developer-prompt.md`, `module/tester-prompt.md`, `module/reviewer-prompt.md`, `integration/tester-prompt.md`, `acceptance/tester-prompt.md`, `acceptance/report-template.md`

When invoked with `--evolve docs/raw/design/<design-dir>/ [--from <plan-dir>] [--plan-only] [--fresh]`:

The design directory has been evolved in place by `system-design --evolve` and now carries a new `system-design-delivery-<N>-<slug>` annotated tag (see system-design `SKILL.md` Phase Contract: design history is preserved via tags + `.review/versions/<N>.md` + the design `CHANGELOG.md`). autoforge follows the same convention on the implementation side: **the existing plan directory is mutated in place** — `--evolve` does NOT create a new plan directory. Plan history is preserved via:

- Annotated git tag `autoforge-delivery-<N>-<slug>` at each delivery's converged commit on the feature branch
- Per-delivery summary file `docs/raw/plans/{plan-dir}/versions/<N>.md`
- `docs/raw/plans/{plan-dir}/CHANGELOG.md` author-curated change log
- `docs/raw/plans/{plan-dir}/README.md` "Evolution History" section

This symmetry means the design directory and the plan directory have a 1:1 relationship across all deliveries, and any past delivery's plan + code can be reproduced via `git checkout autoforge-delivery-<N>-<slug>`.

### Why in-place (not a new plan dir)

1. **Symmetry with system-design** — system-design already mutates the design dir in place; mirroring it on the implementation side keeps a 1:design × 1:plan mapping and avoids an N×M discovery problem on subsequent evolutions.
2. **Plan ↔ code coupling** — the implementation lives on the feature branch and evolves on a child branch; the plan files are the design intent for that code. Decoupling them into separate directories per delivery would force readers to reconcile two trees during code review.
3. **Kept-module noise minimisation** — most evolutions touch a small subset of modules. Copying every `kept` module's plan into a new directory creates churn that doesn't reflect any real design change.
4. **Conventions accumulate** — `conventions.md` is already designed for in-place incremental updates via the `conventions-additions/` flow. Plan files follow the same model.
5. **History via tags, not via directory forks** — the same convention system-design uses; readable with standard `git log --oneline autoforge-delivery-1-foo..autoforge-delivery-2-bar`.

If a particular evolution is so heavy that in-place mutation would be misleading (e.g. >70% of modules `revised` plus large convention overhaul), the user can opt into `--evolve --fresh`, which falls back to Default mode with a new plan directory; this is an explicit user choice, never the default.

### Step E0 — Locate Prior Delivery and Plan

1. **Find the prior plan directory** — look for `docs/raw/plans/{design-dir-name}-*/` directories whose `README.md` `Source Design` field matches `<design-dir>`. Pick the one with the highest `Autoforge Delivery` field; treat an absent field as `0` (a legacy plan dir created before --evolve was introduced — the migration in Step E0.5 below will backfill it). If `--from <plan-dir>` is supplied, use it explicitly. Refuse if none matches: "no prior autoforge delivery for this design — run `/autoforge <design-dir>` from scratch first".

2. **Read the plan README** — extract the Design Input table fields:
   - `Source Design` (verify equals `<design-dir>`)
   - `Source PRD`
   - `Feature Branch Family` (e.g. `autoforge/{design-dir-name}-{hash4}`) — falls back to the older `Feature Branch` field on legacy READMEs
   - `Worktree Root`
   - `Current Design Delivery` (e.g. `system-design-delivery-2-tooling`) — the **baseline design tag**; may be absent on legacy READMEs (handled in Step E0.5)
   - `Autoforge Delivery` (integer; this is delivery `N-1`; the new delivery is `N`); may be absent on legacy READMEs (handled in Step E0.5)
   - `Acceptance Threshold`

   If any of `Feature Branch Family`, `Current Design Delivery`, `Autoforge Delivery`, or the `## Evolution History` section are absent, this is a legacy plan dir — proceed to Step E0.5 to backfill before continuing. Otherwise skip E0.5.

3. **Step E0.5 — Backfill legacy plan README (only when needed).** Triggered by E0.2 when the plan README pre-dates --evolve. The goal is to put the README into the schema described in `planning/plan-readme-template.md` so the rest of E0–E6 can run unchanged. Do **not** touch module status tables (other than reconciling orphan rows in sub-step 4), dependency graphs, or any data outside the listed fields.

   1. **Infer values:**
      - `Feature Branch Family` ← existing `Feature Branch` value
      - `Autoforge Delivery` ← `1` (the existing implementation is the first delivery)
      - `Current Design Delivery` ← run `git tag --list 'system-design-delivery-*' --merged HEAD --sort=creatordate` in the design's repo. Recommended default = the **earliest** delivery tag reachable from the design's HEAD (the design state the implementation was originally written against — subsequent design tags are evolutions to migrate toward). If no `system-design-delivery-*` tag exists, refuse: "design has no `system-design-delivery-*` tag yet — run `system-design --evolve` first to establish a baseline".
   2. **Confirm with user (mandatory):** present the inferred baseline alongside *all* candidate `system-design-delivery-*` tags (with their commit short-hashes and dates) via `AskUserQuestion` so the user can override. The plan's `Date` field is unreliable on its own — the legacy plan may have been written against a design that was tagged retroactively. The user's selection becomes `Current Design Delivery`.
   3. **Backfill the README** (Design Input + Evolution History only):
      - Insert `Feature Branch Family`, `Current Design Delivery`, `Autoforge Delivery`, and `Autoforge Delivery Tag` rows into the Design Input table per the template (keep `Feature Branch` as well — leave existing rows untouched). `Autoforge Delivery Tag` ← `—` (no tag was created at delivery-1's converged commit).
      - Add a `## Evolution History` section before `## Phase Status`, populated with one row for delivery-1: Baseline `—`, Target = the chosen `Current Design Delivery`, Autoforge Tag `—`, Modules `— / {total-from-Module-Index} / — / —`, Verdict = the existing Acceptance row's verdict (e.g. `Pass (90.4%)`), Summary `Legacy delivery (pre-evolve)`.
   4. **Reconcile orphan plan files (CR-AF16).** Run `bash skills/autoforge/scripts/run-checkers.sh {plan_dir} --phase=plan` and inspect any `CR-AF16` findings of the form *"plan exists for M-{id} but no row in Module Status"*. `--phase=plan` is required here because the legacy plan-dir already carries `reports/acceptance.md` and `reports/traceability.json` from the pre-evolve delivery-1 run; without the flag they would trigger E6-time gates (CR-AF09 / CR-AF10 / CR-AF23) against pre-evolve content that this reconciliation step is not responsible for fixing. E0.5 has not yet written any `.evolve-N/impact.md` marker, so the auto-detect fallback does not fire — pass the flag explicitly. These are plan files added outside the autoforge run (typically post-acceptance hotfixes — look for a `Source Issue` / `Source ADR` / `Hotfix on top of Phase N` marker in the file's Context table). For each:
      - **If the plan file looks like merged hotfix work** (has a `Source Issue`/`Source ADR` field, references existing modules as deps, and the file is reachable from `main` per `git log --all -- <plan-path>`): append a row to `## Module Status` with `Plan=Done · Dev=Done · Test=Done · Review=Approved · Merged=Yes` and the Notes column citing the source issue/ADR (e.g. `manual hotfix · issue #21`). Also append a corresponding row to `## Module Plans` so the index stays complete; mark the Phase column as `Hotfix` (not a numbered phase, since these landed outside the planned phase order).
      - **If the plan file is unrecognised** (no source-issue marker, never made it to `main`, or the user can't classify it): present the file path and the first 30 lines to the user via `AskUserQuestion` and ask whether to (a) add as completed hotfix, (b) drop the file (`git rm`), or (c) abort the migration so the user can resolve manually.
      - These reconciliation edits go into the same migration commit — no separate commit per orphan.
   5. **Commit on the branch the plan dir currently lives on (typically `main`):** `docs(plan): backfill evolve-mode fields for legacy delivery-1`. The commit covers backfilled fields + Evolution History + any orphan-row reconciliations from sub-step 4.
   6. **Resume Step E0** at sub-step 4 below; the now-backfilled README has all fields E1–E6 require, and `run-checkers.sh` returns clean.

   The ID-collision check between the design's `added` modules and the plan dir's existing `M-{id}` plans is **not** part of E0.5 — it runs in Step E1 sub-step 2.5 below, where `added` is first identified. E0.5 itself only handles README schema and orphan rows.

4. **Resolve the design's target delivery tag** — list `system-design-delivery-*` annotated tags reachable from the design dir's HEAD commit (`git tag --list 'system-design-delivery-*' --merged HEAD --sort=-creatordate`); the most recent one is the **target design tag**. Refuse if it equals the baseline (nothing to evolve).

5. **Refuse on dirty / mid-flight states** (same gate as Step 0):
   | Condition | Action |
   |-----------|--------|
   | Working tree has uncommitted changes | Refuse; ask user to commit/stash |
   | Prior plan dir has any module not in `Merged = Yes` / `Skipped` and no acceptance verdict | Refuse; tell user to resume with `--execute` first |
   | `target == baseline` | Refuse; "no design changes since last autoforge delivery" |

### Step E1 — Compute the Affected Module Set

system-design's evolution emits four file-level lists (`delete | modify | add | keep`) inside `<design-dir>/.review/round-K+1/plan.md`, but those classify **design files**. autoforge translates them into **module impact classes**, which is broader because cross-module interface effects propagate downstream.

1. **Read the design diff inputs**:
   - `<design-dir>/.review/versions/<N>.md` — change summary written by `system-design --evolve` (contains the planner's delete/modify/add/keep lists for the new delivery)
   - `<design-dir>/CHANGELOG.md` — human-readable timeline
   - `git diff <baseline-design-tag>..<target-design-tag> -- <design-dir>` — concrete file diff
   - The prior `Module Index` in the plan README (so we know which modules existed and their `Deps`)

2. **Classify each module** — output `docs/raw/plans/{plan-dir}/.evolve-N/impact.md`:

   | Class | Source signal | Implementation action |
   |-------|---------------|----------------------|
   | **removed** | `modules/M-xxx-*.md` deleted in the design diff | Delete plan file, delete owned source files, drop from Module Index |
   | **added** | `modules/M-xxx-*.md` newly added | Plan from scratch, execute as a new module |
   | **revised (direct)** | `modules/M-xxx-*.md` modified, OR a consumed `api/*.md` modified, OR a Module Interaction Protocol section in the design README that names this module modified, OR a Tech Stack change forces this module to switch frameworks/libraries | Re-plan in place, re-execute in evolution mode |
   | **revised (downstream)** | M is in `closure(N)` for some `revised (direct)` or `added` N whose **public interface or data model** changed semantically | Same as direct revised |
   | **kept** | None of the above | Plan unchanged; module code inherited from the parent feature-branch commit; participates in phase integration test + acceptance |

2.5. **ID-collision check on `added` modules.** For each module classified `added` (a `modules/M-{id}-{slug}.md` file present at the target tag and absent at the baseline tag): if the plan dir already has a `plans/plan-M-{id}-*.md` file (regardless of whether it came from the original autoforge run or from the legacy E0.5 hotfix reconciliation), the design has reused an ID that the implementation already burned for unrelated work.

   This is a **hard refusal**. Print:

   ```
   Refused: M-{id} ID collision.
     Design (target tag) adds:    modules/M-{id}-<design-slug>.md
     Plan dir already owns:        plans/plan-M-{id}-<plan-slug>.md
                                   (status: {Module Status row}, owner: {Notes column})
   ```

   Provide the user with two remediation paths and exit:
   - **Renumber on the design side** — re-run `system-design --evolve` against the original target, asking the planner to allocate a free ID (e.g. M-{first-free}). Re-tag, then retry `--evolve`.
   - **Renumber on the plan side** — only if the existing M-{id} plan file is genuinely retired (not depended on by other modules). Rename `plans/plan-M-{id}-<plan-slug>.md` → `plans/plan-M-{first-free}-<plan-slug>.md`, update Module Status / Module Plans rows + dependency graph + any cross-references, commit, then retry `--evolve`.

   Do NOT auto-renumber — it requires user judgement on which side legitimately owns the ID. The collision check is independent of the legacy/non-legacy state of the plan dir; it runs on every `--evolve` run.

3. **Compute the downstream closure** — for each `revised (direct)` and `added` module, dispatch a small `sonnet` subagent to compare the module spec's `## Public Interfaces` and `## Data Models` sections between the baseline and target design tags and decide whether the change is *semantic* (signature, type, semantics, error contract) or *cosmetic* (typo, doc rewording). Mark every module N in the DAG with `M ∈ closure(N)` as `revised (downstream)` only when at least one upstream change is semantic. This avoids churning every transitive consumer when an upstream module only updated its prose.

4. **Refresh conventions baseline** — re-read the design README's `Implementation Conventions` and `Key Technical Decisions`, plus the PRD's `architecture.md` developer convention sections. Diff against the current `plans/conventions.md`. Emit any added/changed convention text as `plans/conventions-additions/_evolve-{N}.md`, to be merged after re-planning (Step E4.1).

5. **Detect zero-impact target.** If after sub-steps 2–4 the impact set is empty (`semantic-revised = 0`, `added = 0`, `removed = 0`, with all `revised (direct)` modules downgraded to `kept` because every change was cosmetic, AND `conventions-additions/_evolve-{N}.md` is empty or absent), the chosen target tag introduces no semantic work. This is *not* the same as `target == baseline` — the diff is non-empty but consists entirely of doc-quality refreshes (URL formatting, table fill-ins, prose rewording). Stop and surface this explicitly to the user via `AskUserQuestion`:

   - **Option A — Switch target tag.** List every other `system-design-delivery-*` tag reachable from the design's HEAD that is more recent than the chosen target, plus HEAD itself if untagged. Common cause: the user picked a label like `system-design-delivery-3-foo` that is chronologically older than `system-design-delivery-2-bar`, because tag names don't always sort with commit graph order. Re-run sub-steps 1–4 with the chosen tag.
   - **Option B — Tag-bump-only delivery.** Treat the cosmetic refresh as a real (but module-execution-free) delivery: skip Steps E2–E5 entirely, write `versions/{N}.md` describing the doc-only refresh, append the Evolution History row with `Modules: — / — / — / 44`, and create the `autoforge-delivery-{N}-{slug}` annotated tag on the *current* feature branch tip (no new branch, since no source code changed). Run acceptance only as a regression check (Step E6 sub-step 1 with `is_rerun: true`). Useful when the user wants delivery-tag continuity without re-executing modules.
   - **Option C — Abort the evolve run.** Leave the migration commit (Step E0.5) in place as a useful schema upgrade and stop. The user can re-run `--evolve` later when delivery state is clearer.

   Do NOT silently proceed to E2 with an empty impact set — the user gets no value from a no-op branch + worktree creation, and `versions/{N}.md` becomes meaningless.

6. **Present impact summary to user** — non-empty case only. Table per module (class + reason), cross-module interface deltas, conventions diff, removed-module fallout (orphaned consumers from `kept` modules — these are surfaced as "downgrade-blocking" and force the consumer into `revised`). The user may explicitly downgrade an `auto-revised (downstream)` module to `kept` (with rationale captured in `versions/<N>.md`) or upgrade a `kept` to `revised`. Approval gate before proceeding.

### Step E2 — Create Evolution Branch

Each evolution gets a fresh feature branch — `autoforge/<design-dir-name>-<hash4>` from the original delivery is typically already merged to main and has been deleted. Naming preserves the family root for traceability:

```
N = autoforge delivery counter for this run (e.g. 2 for the second delivery)
new_feature_branch  = autoforge/{design-dir-name}-{hash4}-d{N}
new_worktree_root   = {project-root}/../{project-dirname}-worktrees/autoforge-{design-dir-name}-{hash4}-d{N}
```

Branch from the most recent ancestor that contains the prior delivery's code. Pick whichever case is true for this plan dir — they are mutually exclusive:

```bash
# Case A — prior delivery's code is on main (the common case after --merge,
#          AND the only case for legacy delivery-1 plans backfilled in Step E0.5
#          where no autoforge-delivery-1 tag exists):
git branch {new_feature_branch} main

# Case B — prior delivery has not been merged yet (rare; --evolve usually follows merge):
git branch {new_feature_branch} autoforge-delivery-{N-1}-<prev-slug>

git worktree add {new_worktree_root}/main {new_feature_branch}
```

A missing `autoforge-delivery-{N-1}-<slug>` tag is **not** a refusal trigger. For legacy plan dirs (N-1 = 1) Case A always applies: the original feature branch has been merged and deleted, the converged commit lives on `main`, and the migration row in `Evolution History` already records `Autoforge Tag = —`. The new branch and worktree replace the original ones for this delivery; original worktrees (if any) were cleaned up at the end of delivery N-1 (`Step 4 — Merge to Main`).

### Step E3 — Apply Removals (Pre-Replan)

For each module classified `removed`:

1. `git rm docs/raw/plans/{plan-dir}/plans/plan-M-{id}-{slug}.md` (in primary worktree)
2. `git rm` the module's owned source files. Owned files are listed in the prior plan's `## Files Created` / `## Public Interfaces` sections; the design module file is gone but the prior plan still records exact paths.
3. Update `README.md`: drop the row from Module Index, Module Status, Phase Breakdown, dependency graph mermaid block (also delete dangling edges into removed module from sibling rows).
4. Single commit: `chore(plan): remove modules in delivery-{N} — {removed-module-list}`

If removing a module would break the build (orphan imports from a `kept` consumer), upgrade that consumer to `revised` instead and **defer the source file deletion** until after Step E5; the revised plan must include a "rewire/replace consumer of removed M-xxx" step.

### Step E4 — Re-Plan Affected Modules (In Place)

Restricted form of Step 1: only `revised` and `added` modules are re-planned. `kept` plans stay verbatim.

1. **Conventions update** — if Step E1.4 produced `_evolve-{N}.md`, merge it into `conventions.md` first via a single `sonnet` subagent, then `git rm` the addition file. Commit: `docs(plan): refresh conventions for delivery-{N}`.
2. **Re-build phase order** — recompute the topological sort over the post-removal DAG (added modules joined; removed modules dropped). Preserve prior phase numbering for any module whose phase didn't change; only re-stamp phases that genuinely shifted.
3. **Spawn Planners** — phase-by-phase with within-phase parallelism (same rules as Step 1). Each Planner receives the standard inputs PLUS:

   | Param | Source |
   |-------|--------|
   | `is_evolution` | `true` |
   | `previous_plan_path` | The existing `plan-M-{id}-{slug}.md` — for `revised` modules; omit for `added` |
   | `design_delta_summary_path` | `<design-dir>/.review/versions/<N>.md` |
   | `baseline_design_tag` / `target_design_tag` | For `git diff` / `git show` commands the Planner may need |
   | `removed_modules` | List of removed module IDs — Planner must not reference them |
   | `implemented_module_paths` | Source files for ALL modules in this module's dependency closure that are `kept` (already on the new feature branch — actual code is the source of truth, not the prior plan) |
   | `evolution_class` | `revised-direct` / `revised-downstream` / `added` |

   Planners overwrite (not append to) `plan-M-{id}-{slug}.md` for `revised` modules, and create new files for `added` modules. `kept` plan files are not opened.

4. **Update plan README** in the same commit window:
   - Set `Current Design Delivery` to the new target tag, increment `Autoforge Delivery` to `N`
   - Append a row to the `## Evolution History` table
   - Update Module Index, Module Status, Phase Breakdown for post-evolution state
   - For `kept` modules: keep `Merged = Yes` (they remain merged across the new branch since the branch is forked from a commit containing their code)
   - For `revised` and `added` modules: reset Plan/Dev/Test/Review/Merged to `—` (a fresh execution cycle will fill these)
   - For `removed` modules: drop the row (traceability lives in `versions/{N}.md`)

5. **Commit re-plan** — `docs(plan): re-plan for delivery-{N} — {target-design-tag}`

5.5. **Structural plan check (MANDATORY before human review)** — run

   ```bash
   bash skills/autoforge/scripts/run-checkers.sh {plan_dir} \
        --source-root {worktree_root}/main \
        --phase=plan
   ```

   `--phase=plan` is critical at E4 specifically because the plan-dir
   still carries `reports/acceptance.md` and `reports/traceability.json`
   from delivery N-1 (E6 sub-step 1 archives them later). Without
   `--phase=plan` the aggregator would dispatch
   `check-acceptance-report.sh` / `check-traceability.sh` /
   `check-e2e-coverage.sh` against the stale N-1 reports — the new
   design's AC set has changed but the N-1 traceability still reflects
   N-1, so CR-AF09 (orphan tests), CR-AF10 (unmapped AC), CR-AF26
   (frontend F-ID without e2e spec), and CR-AF23 (E2E command record
   outdated) would all fire on artifacts this step does not own.
   This is the "checker mode mismatch" the `--phase` flag was added to
   eliminate. If `run-checkers.sh` is invoked here without `--phase=plan`
   the auto-detect heuristic (presence of `.evolve-{N}/impact.md`
   without a paired `versions/{N}.md`) will fall back to `--phase=plan`
   semantics — but pass the flag explicitly so the intent is recorded
   in the dispatch log.

   Any `error` / `critical` finding fails the gate: re-dispatch the
   relevant Planner with the JSON output. Warnings flow into the human
   review summary below but do not block.

6. **Human review gate** — same review summary format as Step 1, with explicit "What changed and why" emphasis per module. The user can edit plans before execution.

7. **`--evolve --plan-only` exit** — if invoked, stop here. The plan dir is now in a coherent "delivery-{N} planned, awaiting execution" state and can later be resumed via `/autoforge --execute <plan-dir>`.

### Step E5 — Execute Affected Modules

Standard Step 2 flow with two adjustments:

1. **Module Agent receives `is_evolution: true`** — see "Evolution Mode in Module Agent" below. The agent starts from the existing module code (already present on the new feature branch via the parent commit) and applies the revised plan as a delta, not from scratch.
2. **Unaffected `kept` modules are NOT spawned** — their code is inherited from the parent commit. They DO participate in:
   - **Phase integration tests** — Integration Tester runs against the union of `revised + added + kept` modules in each phase; the integration test set itself may have been revised by Step E4 (the design's Test Strategy or interaction protocols changed)
   - **Acceptance** — full PRD acceptance validates the assembled system

   If a phase contains only `kept` modules (no revised, no added), skip module execution but still run the phase integration test (PRD acceptance criteria for that phase may have changed).

3. **Worktree lifecycle** is unchanged — per-module worktrees are created only for `revised + added` modules. After their Module Agent returns APPROVE, the standard merge sequence applies.

4. **Replan / Diagnosis Mode** — `revised` modules can still hit Replan Mode and Diagnosis Mode (and PLAN_REVISION_NEEDED) within their Module Agent loop. Those internal escalations are unchanged from the default flow.

### Step E6 — Acceptance, Versions File, Delivery Commit

1. **Acceptance** — Step 3 with `is_rerun: true`. Before the run:
   - Rename the prior `reports/acceptance.md` → `reports/acceptance-d{N-1}.md` (single commit: `docs(plan): archive delivery-{N-1} acceptance report`)
   - Pass `previous_report_path: reports/acceptance-d{N-1}.md`

2. **Write the delivery summary** — `docs/raw/plans/{plan-dir}/versions/{N}.md` capturing baseline tag, target tag, autoforge tag, branch, module impact table (including auto-revised → user-downgraded entries with rationale), conventions diff, acceptance verdict + delta vs prior run.

3. **Update CHANGELOG.md** — `docs/raw/plans/{plan-dir}/CHANGELOG.md` gets a new section header `## delivery-{N} — {YYYY-MM-DD} — {target-tag}` with bullet summary referencing `versions/{N}.md`.

4. **Pre-tag delivery gate (MANDATORY).** Before creating the annotated tag, run:

   ```bash
   bash skills/autoforge/scripts/run-checkers.sh \
     docs/raw/plans/{plan-dir}/ \
     --source-root {worktree_root}/main \
     --gate=delivery-tag
   ```

   The gate enforces, beyond the normal checker set:
   - `reports/acceptance.md` exists and carries the
     acceptance-tester-subagent sentinel (CR-AF24 / CR-AF27).
   - `reports/traceability.json` exists (CR-AF28).
   - The `## E2E Test Run` section in `acceptance.md` records a real
     command + exit code, OR a written `n/a — …` justification
     (CR-AF23).
   - Every frontend feature ID owned by a design module with
     `## UI Architecture` has at least one matching e2e spec file
     (CR-AF26).
   - Traceability closure is clean (no orphan tests, unmapped AC,
     PASS-without-test, NOT_COVERED-without-issue, naming-content
     mismatches, happy-only journeys).

   **The gate's exit code is the authorization signal.** Exit 0 →
   proceed to the tag command. Exit 1 → DO NOT create the tag; treat
   each blocking finding as a failed acceptance criterion and route
   through the Acceptance Fix Cycle. The d1 / d2 retros showed that
   self-attestation produced soft-pass deliveries; this gate is the
   structural counter-pressure.

5. **Commit-delivery** — single commit on the feature branch: `docs(plan): finalize autoforge delivery-{N}` and create annotated tag:

   ```bash
   git tag -a autoforge-delivery-{N}-<slug> -m "autoforge delivery {N}: {target-design-tag}"
   ```

   `<slug>` matches the design's `system-design-delivery-{N}-<slug>` slug for 1:1 traceability.

6. **Step 4 (Merge to main)** — runs as in the default flow, but on `{new_feature_branch}` instead of the original.

### Evolution Mode in Module Agent

When the Orchestrator spawns a Module Agent with `is_evolution: true`, the agent's behaviour changes in three places:

- **Setup** also reads the prior implementation from the parent commit (`git show {parent-commit}:src/...` for files the module owns per the prior plan), and assembles a brief "what's already there" summary.
- **First Developer spawn** uses **Variant 5 — Evolve from Existing Code** (see `module/developer-prompt.md`), not Variant 1. The Developer reads the revised plan + existing module source, identifies the deltas, applies them, and commits with `feat(M-{id}): evolve to delivery-{N} — {summary}`. Variants 2/3/4 (retry-from-Tester, retry-from-Reviewer, Replan) are reused unchanged after the first round.
- **Tester** is invoked with `is_rerun: true` (previous tests exist on the parent commit; review them against the revised plan, update or extend, then run the full suite). For `added` modules, `is_rerun: false` (no prior tests).

Reviewer behaviour is unchanged — it always reviews the current code against the current plan.

### Refusal Conditions Summary

| Condition | Reason |
|----------|--------|
| No prior plan directory matches the design | Run from scratch first (no `--evolve` baseline) |
| Prior plan directory is mid-execution | Resume the in-flight run with `--execute` first |
| Target design delivery tag equals the prior plan's recorded baseline | Nothing to evolve |
| Step E1 impact set is empty (all `revised (direct)` downgraded to `kept` after semantic check) | Not a hard refusal — Step E1 sub-step 5 routes to user decision (switch target / tag-bump-only / abort). Never silently proceed to E2 in this state. |
| Working tree is dirty | Same gate as default Step 0 |
| `--evolve --fresh` selected | Documented escape hatch — proceeds via Default Mode against a new plan directory |

## --status Mode

When invoked with `--status docs/raw/plans/{plan-dir}/`:

1. **Read plan README** — parse all status tables
2. **Read execution log** — parse `execution-log.md` for recent events
3. **Present summary**:
   - Phase progress: which phases complete, which in progress
   - Module status: per-module Dev/Test/Review state, retry counts
   - Integration test results: per-phase pass/fail
   - Acceptance status: if reached, show pass rate
   - Decision requests: any modules waiting for human decision
   - Recent events: last 10 entries from execution log
   - Estimated remaining: how many modules/phases left
4. **No modifications** — read-only mode

## --cleanup Mode

When invoked with `--cleanup docs/raw/plans/{plan-dir}/`:

Abandon the autoforge run and remove all artifacts. **This is destructive — confirm with user before proceeding.**

1. **Read plan README** — extract Feature Branch, Worktree Root
2. **Show current state** — run `--status` first so the user sees what will be lost
3. **Confirm** — ask user: "This will remove all worktrees, branches, and optionally plan files. Continue?"
4. **Remove all worktrees**:
   ```
   git worktree list   # find all worktrees under {worktree_root}
   # For each worktree:
   git worktree remove --force {path}
   ```
5. **Remove all module branches**:
   ```
   # For each module branch matching autoforge/{design-dir-name}-{hash4}/*:
   git branch -D {branch}
   ```
6. **Remove feature branch**:
   ```
   git branch -D autoforge/{design-dir-name}-{hash4}
   ```
7. **Remove worktree root directory**:
   ```
   rm -rf {worktree_root}
   ```
8. **Optionally remove plan files** — ask user:
   - "Keep plan files at `docs/raw/plans/{plan-dir}/` for reference?" (default: keep)
   - **Refuse to remove the plan directory** if any of the following exist (the plan has historical deliveries that would be destroyed):
     - One or more `versions/<N>.md` files
     - A `CHANGELOG.md`
     - One or more `autoforge-delivery-<N>-<slug>` annotated tags reachable from any preserved branch
     In those cases, reply: "this plan dir contains delivery history; refusing to remove. Use `git tag -d autoforge-delivery-*` and remove `versions/` manually if you genuinely want to discard the chain."
   - If user still says remove and no history exists: `git rm -rf docs/raw/plans/{plan-dir}/` + commit on current branch
9. **Report** — print what was cleaned up: worktrees removed, branches deleted, disk space freed

## Git Strategy

### Branch Naming

```
Feature branch (created by Orchestrator in Step 0 — initial delivery):
  autoforge/{design-dir-name}-{hash4}
  Example: autoforge/2026-04-09-agent-team-a3f1

Feature branch (created by Orchestrator in Step E2 — evolution delivery N≥2):
  autoforge/{design-dir-name}-{hash4}-d{N}
  Example: autoforge/2026-04-09-agent-team-a3f1-d2

Module branches (created by Orchestrator before spawning Module Agent):
  autoforge/{design-dir-name}-{hash4}/p{phase}/M-{id}-{slug}                  (delivery 1)
  autoforge/{design-dir-name}-{hash4}-d{N}/p{phase}/M-{id}-{slug}             (delivery N≥2)
  Example: autoforge/2026-04-09-agent-team-a3f1-d2/p1/M-001-task-split

Annotated tags (created on converged delivery commit):
  autoforge-delivery-{N}-{slug}
  Example: autoforge-delivery-2-cancel-flow
  The slug matches the design's system-design-delivery-{N}-{slug} for 1:1 traceability.
```

- `{design-dir-name}` = design directory name, directly traceable to `docs/raw/design/{name}/`
- `{hash4}` = `$(git rev-parse --short=4 HEAD)` at **initial plan creation** — prevents collision on first runs; **never bumped on `--evolve`** (the `-d{N}` suffix carries delivery identity)
- `-d{N}` = autoforge delivery counter (N≥2), introduced by `--evolve`
- `p{phase}` = phase number — groups modules by execution batch
- `M-{id}-{slug}` = module ID and slug — matches design document naming
- Module branches are forked from the feature branch

**Note:** If the PRD's Git & Branch Strategy defines a branch naming convention, autoforge's internal `autoforge/` prefix does not conflict — these are automation-scoped branches cleaned up after merge. For commit messages, if the PRD specifies a format (e.g., Conventional Commits with issue IDs), extend autoforge's commit templates accordingly.

### Commit Messages

```
chore: initialize project
docs(plan): add implementation plans for {project}
feat(M-001): implement {module} interfaces and core logic
feat(M-001): evolve to delivery-{N} — {summary}
test(M-001): add unit tests for {module}
test(M-001): add integration tests for {module}
fix(M-001): fix {test failure description}
fix(M-001): address review feedback
refactor(M-001): {new approach description after Replan}
state(M-001): update module state
test(p1): add phase-1 integration tests
fix(p1): resolve phase-1 integration issues
docs(plan): re-plan from phase {n} — {reason}
docs(plan): update status after phase-{n}
docs(design): update impl status after phase-{n}
test(e2e): add E2E acceptance tests
fix(M-001): {acceptance criterion description}
docs(plan): add acceptance report
docs(plan): mark implementation complete
log: {brief event description}

# --evolve specific:
chore(plan): remove modules in delivery-{N} — {removed-list}
docs(plan): refresh conventions for delivery-{N}
docs(plan): re-plan for delivery-{N} — {target-design-tag}
docs(plan): archive delivery-{N-1} acceptance report
docs(plan): finalize autoforge delivery-{N}
```

### Merge Rules

- **Prefer fast-forward merge; rebase only when fast-forward is not possible** — keep linear history
- **Only fast-forward merges** — `git merge --ff-only`; if ff not possible, rebase first
- **Module → feature branch**: sequential merge after each module completes within a phase
- **Feature → main**: only after full acceptance passes

**Canonical module-merge command sequence** (referenced from Step 2 — Phase Execution):

```bash
# 1. Try fast-forward merge from the primary worktree (feature branch checked out)
cd {worktree_root}/main
git merge --ff-only autoforge/{design-dir-name}-{hash4}/p{n}/M-{id}-{slug}

# 2. If ff-merge fails (concurrent changes landed on the feature branch), rebase
#    the module branch onto the current feature branch, then retry ff-merge:
cd {worktree_root}/p{n}-M-{id}-{slug}
git rebase autoforge/{design-dir-name}-{hash4}
cd {worktree_root}/main
git merge --ff-only autoforge/{design-dir-name}-{hash4}/p{n}/M-{id}-{slug}
```

If rebase produces conflicts (overlapping changes from modules in the same phase), pause and present the conflicts to the user for resolution — same as the feature-to-main conflict handling in Step 4.

Consider squashing `state()` commits during the merge to keep the feature branch history clean: `git merge --squash {module-branch}` followed by a single merge commit.

### Worktree Convention

```
Worktree root (sibling to project, one per autoforge feature branch):
  Initial delivery: {project-root}/../{project-dirname}-worktrees/autoforge-{design-dir-name}-{hash4}/
  Delivery N≥2:     {project-root}/../{project-dirname}-worktrees/autoforge-{design-dir-name}-{hash4}-d{N}/
  Example: ../myapp-worktrees/autoforge-2026-04-09-agent-team-a3f1-d2/

Primary worktree (feature branch — planning, bootstrap, integration, acceptance):
  {worktree-root}/main/

Per-module worktree (one per module during phase execution):
  {worktree-root}/p{phase}-M-{id}-{slug}/
```

Each delivery uses its own `worktree-root` so concurrent inspection of the prior delivery (via the persisted plan dir + tag) does not conflict with the in-flight evolution. After Step 4 (Merge to Main), the evolution worktree root is removed; the prior delivery's tag remains on main.

Worktrees are placed outside the project directory to avoid nesting. The **main project directory is never checked out to the feature branch** — it stays on its original branch, so other work can proceed in parallel.

### Worktree Lifecycle

Worktrees are managed by the Orchestrator:

| Event | Action |
|-------|--------|
| Autoforge starts | Create primary worktree: `git worktree add {worktree_root}/main {feature_branch}` |
| Phase starts | Create per-module worktrees: `git worktree add -b {branch} {path} {feature_branch}` |
| Module APPROVE | After merge: `git worktree remove {path}` + `git branch -d {branch}` |
| Module DECISION_REQUEST | Keep worktree + branch alive for human-assisted fix process |
| Module PLAN_REVISION_NEEDED (minor) | Keep worktree; revise plan and restart module in same worktree |
| Module PLAN_REVISION_NEEDED (significant) | Pause phase; merge unaffected APPROVE modules; clean up their worktrees. Keep affected worktrees until re-plan completes. After human approves revised plans: clean up old worktrees, create fresh ones for re-execution |
| Re-plan approved, resuming | Same as `--execute` mode: recover or recreate worktrees based on module status |
| All phases + acceptance complete | Remove worktree root: `rm -rf {worktree-root}` (verify with `git worktree list`) |

**Interruption recovery:** Worktrees and branches persist on disk across session interruptions. The `--execute` mode detects existing worktrees via `git worktree list` and handles each based on the module's status in the plan README. Stale worktrees with no matching status entry are removed.

## Status Tracking

Plan README.md maintains a live status table (updated after each phase):

```markdown
## Module Status

| Module | Phase | Plan | Dev | Test | Review | Merged | Notes |
|--------|-------|------|-----|------|--------|--------|-------|
| M-001  | 1     | Done | Done | Done | Approved | Yes | — |
| M-002  | 1     | Done | Retry 2 | — | — | — | Test failure: null check |
| M-003  | 2     | Done | — | — | — | — | Waiting for Phase 1 |

Legend: `—` = not started, `Done` = complete, `Retry {n}` = in retry cycle, `Replan {n}` = in replan mode (n = replan attempt), `Revision` = plan being revised, `Decision` = waiting for human decision, `Skipped` = human decided to skip, `Removed` = module deleted in this delivery (row dropped after delivery commit), `Kept` = unchanged this delivery, inherited from parent commit (only used during `--evolve`)

## Phase Status

| Phase | Modules | Completed | Integration Test | Status |
|-------|---------|-----------|-----------------|--------|
| 1     | 3       | 2/3       | —               | In Progress |
| 2     | 2       | 0/2       | —               | Waiting |

## Acceptance

| Feature | Criteria Total | Passed | Failed | Not Covered | Status |
|---------|---------------|--------|--------|-------------|--------|
| F-001   | 8             | 8      | 0      | 0           | Pass   |
| F-002   | 7             | 5      | 2      | 0           | Fail   |
```

## Execution Log

The Orchestrator maintains an append-only execution log at `docs/raw/plans/{plan-dir}/execution-log.md`. This is the **single source of truth** for understanding what happened, what decisions were made, and why things are the way they are.

### When to log

The Orchestrator appends an entry after every significant event:

| Event | What to record |
|-------|---------------|
| Phase started | Phase number, module list, worktree paths |
| Module Agent returned APPROVE | Module, total retries, test counts, commit hash |
| Module Agent returned DECISION_REQUEST | Module, diagnosis summary, proposed options |
| Module Agent returned PLAN_REVISION_NEEDED | Module, issue description, affected plans |
| Human decision made | Which option was chosen, rationale if provided |
| Plan revised | Which plans changed, what was corrected, downstream impact |
| Replan Mode entered (from Module Agent return) | Module, stall count, failure pattern, new strategy |
| Module retry with fix | Module, round number, what was fixed, test failure delta (e.g., 5→3) |
| Phase integration test result | Phase, pass/fail, test counts, failures if any |
| Phase merge completed | Modules merged, branch cleanup |
| Acceptance test result | Verdict, pass rate, failed criteria count |
| Acceptance fix dispatched | Module, which criteria being fixed |
| Infrastructure failure | Module, error type, action taken |

### Entry format

Each entry follows this structure:

```markdown
### {YYYY-MM-DD HH:MM} — {event summary}

**Context:** {module / phase / step}
**Event:** {what happened}
**Details:**
{key facts — test counts, failure descriptions, decisions, rationale}
**Outcome:** {what happens next as a result}
```

### Logging protocol

- The Orchestrator appends entries — sub-agents do NOT write to the log directly
- After appending, commit the log: `git add execution-log.md && git commit -m "log: {brief event description}"`
- Log commits are lightweight and frequent — one per event, not batched
- The log is append-only — never edit or remove previous entries
- Include quantitative data (test counts, failure deltas) so progress trends are visible

## Decision Request Protocol

When an agent has exhausted its autonomous options (Replan Mode tried, alternative approach also stalled, or hard ceiling reached), it enters **Diagnosis Mode** instead of giving up.

### Diagnosis Mode

The agent performs root cause analysis before requesting a human decision:

1. **Identify the pattern** — review all retry history:
   - Same test failing with same error → fundamental approach issue
   - Different tests failing each round → regression/side-effect pattern
   - Reviewer finding same issue repeatedly → spec interpretation disagreement
2. **Classify the root cause**:
   - **Design ambiguity** — spec doesn't clearly define expected behavior
   - **Plan error** — implementation steps don't achieve the spec's intent
   - **Missing capability** — the module needs something not available (external service, data, dependency)
   - **Conflicting constraints** — two requirements contradict each other
   - **Implementation complexity** — the approach is correct but execution has bugs
3. **Propose 2-3 concrete options**, each with:
   - What specifically to change (files, functions, approach)
   - Trade-offs and risks
   - Which tests/criteria would be affected

### How the Orchestrator handles DECISION_REQUEST

1. **Present** the diagnosis and options to human (other independent modules continue running)
2. **Human picks** an option — or provides a custom instruction
3. **Orchestrator spawns** a Developer agent in the module's worktree with the chosen option
4. **Verify** — spawn Tester to check the fix (Tester will review/update tests as needed)
5. **Continue** — if pass, proceed to Reviewer or merge; if fail, present an updated diagnosis with new options; repeat until resolved or human chooses to skip/abort

### Agent infrastructure failures

If an Agent tool call fails due to infrastructure issues (timeout, context overflow, tool error — as opposed to application-level test/review failures):

1. **First failure** — retry the same Agent call once (does not count toward retry tracking)
2. **Second failure** — present the infrastructure error to human with options: retry / skip module / abort
3. **Log** — record the infrastructure failure in the module's report directory for debugging

## Key Principles

- **Self-contained agents** — each agent receives all needed context; no agent needs to read prior conversation history
- **Phased-parallel planning, parallel execution** — phases plan sequentially (so upstream plans are final before downstream starts), Planners within a phase run in parallel, and each Planner reads only its dependency-closure of prior plans; within each execution phase, modules run in parallel
- **Fail fast, fix targeted** — test failures and review rejections are addressed by the responsible Developer, not by re-running the entire pipeline
- **Main stays clean** — all work happens on the feature branch; main is only touched at the very end after full acceptance
- **Design is the contract** — module design specs are the source of truth; Reviewer checks code against design, not against subjective standards
- **Status is visible** — plan README is updated after every phase; execution log records every decision and state change; design doc Impl columns reflect actual progress
- **Autonomous first** — continue iterating while progress is being made; when stalled, try alternative approaches before involving a human; request human decision only when reasonable options are exhausted and remaining choices involve quality trade-offs
- **Human decides trade-offs, agent decides implementation** — when genuinely stuck, the agent presents concrete options for human choice, then continues with the chosen approach — never dumps unstructured problems or gives up prematurely
- **In-place evolution mirrors system-design** — `--evolve` mutates the existing plan directory in place; per-delivery identity lives in `versions/<N>.md`, `CHANGELOG.md`, and the `autoforge-delivery-<N>-<slug>` annotated tag. Plan directories are 1:1 with design directories across all deliveries.
- **Evolution scope is module-level, not file-level** — system-design's `delete/modify/add/keep` is a *file* classification; autoforge translates it to a *module* classification, expanding the set via downstream-closure analysis on semantic interface changes. A typo fix in an upstream module does NOT cascade; a signature change does.

## Output Structure

```
docs/raw/plans/{design-dir-name}-{hash4}/
├── README.md                              # Dependency graph + phases + live status + Evolution History
├── CHANGELOG.md                           # Per-delivery curated changelog (added in delivery-2+)
├── execution-log.md                       # Chronological event log (append-only)
├── versions/                              # Per-delivery summaries (added in delivery-2+)
│   ├── 2.md
│   └── 3.md
├── .evolve-{N}/                           # Transient: per-evolution scratch (impact.md, classification rationale);
│                                          #   committed for traceability, not consumed by the runtime after E6
├── plans/
│   ├── conventions.md                     # Project-wide implementation conventions
│   ├── conventions-additions/             # Transient: per-module convention extensions,
│   │                                      #   merged into conventions.md and deleted
│   │                                      #   between phases (empty at end of planning).
│   │                                      #   Also receives `_evolve-{N}.md` during --evolve runs
│   ├── plan-M-001-{slug}.md               # Module implementation plan (mutated in place across deliveries)
│   ├── plan-M-002-{slug}.md
│   └── ...
├── reports/
│   ├── developer-notes-M-001.md           # Developer implementation notes
│   ├── test-report-M-001.md               # Module test report
│   ├── review-M-001.md                    # Module review result
│   ├── decision-request-M-001.md          # DECISION_REQUEST details (if stalled)
│   ├── plan-revision-M-001.md             # PLAN_REVISION_NEEDED details (if plan issue)
│   ├── module-state-M-001.json            # Module Agent state (retries, stall count, history)
│   ├── integration-phase-1.md             # Phase integration test report (overwritten per delivery;
│   │                                      #   archived as integration-phase-1-d{N-1}.md before reruns)
│   ├── integration-phase-2.md
│   ├── acceptance.md                      # Current delivery's PRD acceptance report
│   └── acceptance-d{N-1}.md               # Archived acceptance report from previous delivery
```

The plan directory name uses the **original** `{design-dir-name}-{hash4}` from the first delivery — `--evolve` does NOT bump `{hash4}`. `{hash4}` is a one-time collision-avoidance disambiguator, not a delivery counter; per-delivery identity lives in `versions/<N>.md` + the `autoforge-delivery-<N>-<slug>` git tag.

## Templates

- `delivery-discipline.md` — shared delivery-discipline ruleset (forbidden test patterns, write-path signal rules, wiring/registration, debt → issue, naming = contract, traceability closure, full local CI gate, flip-on-sight reflex, user-visible reporting, long-run re-anchor). Every sub-agent reads it before doing anything; every gate enforces it.
- `planning/plan-readme-template.md` — plan directory README with dependency graph, phase list, status tables
- `planning/planner-prompt.md` — Planner agent instructions (sequential planning with context accumulation)
- `planning/module-plan-template.md` — per-module implementation plan with atomic steps
- `module/agent-prompt.md` — Module Agent instructions (second-level orchestrator)
- `module/developer-prompt.md` — Developer sub-agent prompt variants (initial, retry-from-tester, retry-from-reviewer, replan, evolve-from-existing-code)
- `module/tester-prompt.md` — Tester sub-agent prompt
- `module/reviewer-prompt.md` — Reviewer sub-agent prompt
- `integration/tester-prompt.md` — Phase-level integration tester instructions
- `acceptance/tester-prompt.md` — PRD acceptance tester instructions
- `acceptance/report-template.md` — PRD acceptance report with traceability matrix

## Next Steps Hint

After completion, print:

```
Autoforge complete: all modules implemented and PRD acceptance passed.
  Feature branch merged to main.
  Acceptance report: docs/raw/plans/{plan-dir}/reports/acceptance.md
  Plan status: docs/raw/plans/{plan-dir}/README.md
```
