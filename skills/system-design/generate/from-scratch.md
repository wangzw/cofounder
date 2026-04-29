# generate/from-scratch.md — FromScratch Mode Entry

This file is loaded by the orchestrator when mode = Generate and no `--target` is provided. It is
**not** a sub-agent prompt. It defines the Round 0 dispatch sequence the orchestrator follows when
generating a fresh system design from a PRD (or draft input).

---

## Round 0 Sequence

The orchestrator executes these steps in order. Step 4 is conditional; Step 7 fans out in parallel.
All script calls are deterministic (no LLM dispatch). Only steps 4, 5, 7, 9, 10, 11 involve
sub-agent dispatch.

**Hard rule (system-design override):** Step 8 (structural lint) MUST complete and report zero
failures before Step 9 (LLM review) is dispatched. Mechanical findings — placeholder JSON,
missing per-endpoint blocks, unfilled Boundary Enforcement columns, dangling endpoint references,
reverse-layer imports — are never forwarded to the LLM reviewers.

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

- **Trigger condition**: always; first step in every Round 0 run.
- **Inputs**: cwd
- **Outputs**: exits 0 (repo ready) or non-zero
- **Orchestrator action**: if exit non-zero → stop, report error to user. Do not enter generate mode.

### Step 2 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<user-prompt>" <target>/.review
```

- **Trigger condition**: always; immediately after Step 1 exits 0.
- **Inputs**: raw user prompt string, optional `@refs` / URLs (PRD directory path, draft design doc,
  or free-form description)
- **Outputs**:
  - `<target>/.review/round-0/input.md` — normalized text
  - `<target>/.review/round-0/input-meta.yml` — `sparse_input` flag, `source_list`, detected
    `prd_path` (if an `@`-referenced directory contains `README.md` + `features/` or `journeys/`)
  - `<target>/.review/README.md` — bootstrapped from
    `common/templates/review-readme-template.md` (idempotent; skipped if already exists)
- **Orchestrator action**: read exit code only; do not read the written files.

### Step 3 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <target>/.review common/domain-glossary.md
```

- **Trigger condition**: always; immediately after Step 2.
- **Inputs**: `input.md`, `input-meta.yml`, `domain-glossary.md`
- **Outputs**: `<target>/.review/round-0/trigger-flags.yml`
  - Boolean flags: `glossary_hit`, `sparse_input`, `ambiguous_artifact_type`
  - System-design-specific flags: `has_prd` (true when `prd_path` is set in `input-meta.yml`),
    `has_apis` (true when PRD features reference external API contracts or the prompt mentions
    API surface generation), `output_dir_conflict` (true when `<target>/` is non-empty and
    not a prior system-design run)
- **Orchestrator action**: read exit code only; do not read the written file.
- **Note**: first arg is the `.review/` root; the script appends `round-0/` itself.

### Step 4 — Domain Consultant (conditional sub-agent dispatch)

**Condition**: dispatch if ANY of the following are true:
- `trigger-flags.yml` reports `glossary_hit: true`
- `trigger-flags.yml` reports `sparse_input: true`
- `trigger-flags.yml` reports `ambiguous_artifact_type: true`
- `trigger-flags.yml` reports `output_dir_conflict: true`
- user passed `--interactive`

Skip if none of the above apply AND `has_prd: true` (PRD fully resolved, no ambiguity).

**`--no-consultant` override**: skip unconditionally — even when triggers fire. The orchestrator
synthesizes a minimal `<target>/.review/round-0/clarification/<ISO-ts>.yml` locally using:
- `prd_path` from `input-meta.yml` (or slug-from-prompt fallback)
- `has_apis` flag from `trigger-flags.yml`
- Default `docs/raw/design/<slug>/` output directory
- Mark R-001..R-006 as `status: deferred`

System-design consultant clarifies:
1. **PRD path** — confirms the resolved `prd_path`; requests user correction if ambiguous
2. **has-APIs** — confirms whether API contract files (`api/API-*.md`) should be generated
3. **Output directory** — confirms or overrides `<target>/` path
4. Any other ambiguities (`ambiguous_artifact_type`, `output_dir_conflict`)

- **Dispatches**: `generate/domain-consultant-subagent.md`
- **Inputs consumed by sub-agent**: `round-0/input.md`, `round-0/input-meta.yml`,
  `round-0/trigger-flags.yml`, `common/domain-glossary.md`
- **Outputs written by sub-agent**: `<target>/.review/round-0/clarification/<ISO-timestamp>.yml`
- **Orchestrator action on ACK**: record `trace_id` in `state.yml`; if ACK is `FAIL` → apply §16
  retry policy; if user wrote `/abort` during dialogue → exit this skill.

### Step 5 — Planner (sub-agent dispatch)

- **Trigger condition**: always; after Step 4 (or Step 3 if Step 4 skipped).
- **Dispatches**: `generate/planner-subagent.md`
- **Inputs consumed by sub-agent**:
  - If consultant ran: `round-0/clarification/<ts>.yml`
  - If consultant skipped: `round-0/input.md` + `round-0/input-meta.yml` directly
  - PRD files (read-only): `<prd_path>/README.md`, `<prd_path>/features/*.md`,
    `<prd_path>/journeys/*.md`, `<prd_path>/architecture/*.md` (if `has_prd: true`)
- **Outputs written by sub-agent**: `<target>/.review/round-1/plan.md` containing:
  - Proposed module decomposition (name, type `backend`/`frontend`/`shared`, one-sentence
    responsibility, complexity estimate `S`/`M`/`L`/`XL`)
  - Feature-Module matrix (rows = modules, columns = PRD feature IDs; `✦` = modifies,
    `△` = read-only support)
  - Dependency layering (forward-only layer order; modules assigned to layers)
  - `plan.add` list — one entry per artifact to generate:
    `modules/M-NNN-<slug>.md`, `api/API-<slug>.md` (if `has_apis`), `README.md`
- **Orchestrator action on ACK**: record `trace_id`; proceed to Step 6.

### Step 6 — HITL: Plan Approval Gate

The orchestrator presents the plan to the user by reading `round-1/plan.md`. **This is the ONLY
artifact the orchestrator is permitted to read before the writer fan-out; it is a planning
document, not a generated artifact leaf.**

Wait for user response:
- **approve** (or `/approve`) → continue to Step 7
- **revise** (or `/revise <feedback>`) → re-dispatch planner with feedback appended; loop Step 5–6
- **abort** (or `/abort`) → exit this skill

### Step 7 — Writer Fan-out (parallel sub-agent dispatch)

Fan-out one writer sub-agent per file listed in `round-1/plan.md` `plan.add` list (typically
one entry per module + one per API file + one README; often 8–14 files total). All dispatched
in parallel.

- **Trigger condition**: immediately after user approves the plan in Step 6.
- **Dispatches**: `generate/writer-subagent.md` (N instances, one per file)
- **Inputs consumed by each sub-agent**:
  - `round-0/clarification/<ts>.yml` (most recent; or synthesized stub)
  - `round-1/plan.md`
  - Corresponding template from `common/templates/` (determined by target file type:
    `module-template.md`, `api-template.md`, or `design-readme-template.md`)
  - PRD source files (read-only) as specified in `plan.md` per-entry context
- **Outputs written by each sub-agent**:
  1. Target artifact file at `<target>/<relative-path>`
  2. `<target>/.review/round-1/self-reviews/<trace_id>.md`
- **Orchestrator action on all ACKs received**: collect `self_review_status` and `fail_count` per
  ACK. Proceed to Step 8 only after ALL writers have ACK'd (no partial fan-out).
- **Retry semantic**: on a `FAIL` ACK retry, the orchestrator MUST rename the prior self-review
  file from `<trace_id>.md` to `<trace_id>.failed-1.md` before re-dispatching, to avoid
  overwriting the failure record.

### Step 8 — Structural Lint Pre-pass (script)

```bash
scripts/run-checkers.sh <target>/ round-1
```

- **Trigger condition**: after ALL writer ACKs received in Step 7. MUST run before any LLM review
  dispatch (Step 9). This ordering is a hard system-design override — mechanical findings never
  reach the LLM reviewers.
- **Inputs**: all artifact files in `<target>/` (script reads directly)
- **Checks run**: per-file checks L1–L5 (file structure, required sections, placeholder detection,
  cross-reference validity, ID format) and cross-file checks X1–X8 (endpoint consistency between
  module API Surface tables and `api/API-*.md` files, reverse-layer import detection,
  Feature-Module matrix coverage, analytics event coverage, PRD `architecture/` convention
  enumeration, Module Interaction Protocols sync, single-source-of-truth violations, Boundary
  Enforcement column completeness)
- **Outputs**: issue files under `<target>/.review/round-1/issues/` (one file per blocker finding;
  severity: `blocker` | `warning`)
- **Orchestrator action**:
  - If any `blocker` issues found → spawn reviser sub-agents (one per affected file, from
    `revise/per-issue-reviser-subagent.md`), re-run `scripts/run-checkers.sh`, re-loop until zero blockers.
  - If only `warning` issues remain → proceed to Step 9.
  - `warning` issues are forwarded to Step 9 reviewers as context (not suppressed).

### Step 9 — Cross-Reviewer + Adversarial-Reviewer (parallel sub-agent dispatch)

Both reviewers are dispatched simultaneously after Step 8 reports zero blocker issues.

**Issue ID pre-allocation (collision prevention)**: The orchestrator MUST pre-allocate
non-overlapping issue ID sequence ranges for the two parallel reviewer dispatches and include
them in each dispatch header. Sub-agents MUST use only their assigned range and MUST NOT glob
the issues directory to determine the next ID:
- Cross-Reviewer: `id_seq_start: 1`, `id_seq_end: 50`
- Adversarial-Reviewer: `id_seq_start: 51`, `id_seq_end: 100`

If a future round adds a third parallel reviewer, extend the range table here.

**Cross-Reviewer**:
- **Dispatches**: `review/cross-reviewer-subagent.md`
- **Inputs consumed**: all target artifact leaves + non-blocker issue files from Step 8
- **Outputs**: additional semantic issue files under `<target>/.review/round-1/issues/`
- **Scope**: semantic correctness only — responsibility scoping, error-handling depth, NFR
  decomposition correctness, risk coverage, testability, interface completeness. Script-type
  findings (L1–L5, X1–X8) that Step 8 has already resolved are filtered from scope.

**Adversarial-Reviewer**:
- **Dispatches**: `review/adversarial-reviewer-subagent.md`
- **Inputs consumed**: all target artifact leaves + non-blocker issue files from Step 8
- **Outputs**: additional adversarial issue files under `<target>/.review/round-1/issues/`
- **Scope**: failure modes, security edge cases, scalability cliffs, hidden coupling, unstated
  assumptions that could invalidate the design under adversarial or high-load conditions.

- **Orchestrator action on both ACKs received**: proceed to Step 10.

### Step 10 — Summarizer (sub-agent dispatch)

- **Trigger condition**: after both Step 9 reviewer ACKs received.
- **Dispatches**: `shared/summarizer-subagent.md`
- **Inputs consumed**: all issue files from `round-1/issues/`, all self-reviews from
  `round-1/self-reviews/`
- **Outputs written by sub-agent**:
  - `<target>/.review/round-1/index.md` — aggregated review summary
  - `CHANGELOG.md` entry for round-1
  - `<target>/.review/versions/<N>.md` — snapshot of round-1 state
- **Orchestrator action on ACK**: proceed to Step 11.

### Step 11 — Judge (sub-agent dispatch)

- **Trigger condition**: after Summarizer ACK received.
- **Dispatches**: `shared/judge-subagent.md`
- **Inputs consumed**: `round-1/index.md`, all `round-1/issues/` files, `round-1/self-reviews/`
- **Outputs written by sub-agent**: `<target>/.review/round-1/verdict.yml`
- **Orchestrator action on ACK** (read `verdict.yml`):
  - `verdict: converged` → proceed to Delivery Commit (below)
  - `verdict: progressing` → increment round counter; loop from Step 7 (writer fan-out on
    changed files only, as listed in `verdict.yml` `changed_files`)
  - `verdict: oscillating` → surface oscillation report to user; request human guidance before
    next round
  - `verdict: diverging` → surface divergence report to user; request human guidance before
    next round
  - `verdict: stalled` → surface stall report to user; request human intervention

### Delivery Commit

```bash
scripts/commit-delivery.sh <target>/ <delivery-id> <slug>
```

- **Trigger condition**: `verdict: converged` received from Judge.
- Creates annotated git tag `delivery-<N>-<slug>`.
- Sets `Design Input > Status` in `README.md` to `Finalized`.
- This skill exits cleanly after the commit completes.

---

## Notes

- **Round numbers** are cross-delivery monotonic. Round 1 in delivery 1 is round 1 globally;
  round numbers never reset between deliveries.
- **Orchestrator read discipline**: the orchestrator MUST NOT read any artifact leaf other than
  `round-1/plan.md` (Step 6) and `round-N/verdict.yml` (Step 11). For all other routing
  decisions, rely on ACK fields and exit codes alone.
- **Lint-before-review invariant**: the ordering Step 8 → Step 9 is a system-design-specific
  hard override of the generic skill-forge from-scratch sequence. It is never relaxed — not
  during re-loops, not during round-N iterations.
- **`from-scratch.md` is not a sub-agent prompt** — it does not carry the Snippet D fingerprint
  and is never dispatched as an agent.
- **PRD read-only**: no step in this sequence may write to the PRD directory. The PRD is consumed
  as an input source only.
