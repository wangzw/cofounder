# generate/from-scratch.md — FromScratch Mode Entry

This file is loaded by the orchestrator when mode = Generate and no `--target` is provided. It is
**not** a sub-agent prompt. It defines the Round 0 dispatch sequence the orchestrator follows.

---

## Round 0 Sequence

The orchestrator executes these steps in order. Steps 4 and 8 may be skipped per conditions below.
All script calls are deterministic (no LLM dispatch). Only steps 4, 5, 8, 10, 11, 12 involve
sub-agent dispatch.

### Step 1 — Git Precheck (script)

```bash
scripts/git-precheck.sh
```

- **Inputs**: cwd
- **Outputs**: exits 0 (repo ready) or non-zero (exits skill-forge)
- **Orchestrator**: if exit non-zero → stop, report error to user. Do not enter generate mode.

### Step 2 — Prepare Input (script)

```bash
scripts/prepare-input.sh "<user-prompt>" <target>/.review
```

- **Inputs**: raw user prompt string, optional `@refs` / URLs
- **Outputs**: `<target>/.review/round-0/input.md` (normalized text), `<target>/.review/round-0/input-meta.yml` (sparse_input flag, source list). Also drops `<target>/.review/README.md` from `common/templates/review-readme-template.md` on first bootstrap (idempotent — skipped if the file already exists so user edits survive delivery-N re-bootstrap).
- **Orchestrator**: read exit code only; do not read the written files.

### Step 3 — Glossary Probe (script)

```bash
scripts/glossary-probe.sh <target>/.review <skill-forge>/common/domain-glossary.md
```

- **Inputs**: `input.md`, `input-meta.yml`, `domain-glossary.md`
- **Outputs**: `<target>/.review/round-0/trigger-flags.yml` (boolean flags: `glossary_hit`, `sparse_input`, `ambiguous_artifact_type`)
- **Orchestrator**: read exit code only; do not read the written file.
- **Note**: first arg is the `.review/` root, not `.review/round-0/` — the script appends `round-0/` itself (or `--bootstrap-subdir` override).

### Step 4 — Domain Consultant (conditional sub-agent dispatch)

**Condition**: dispatch if `trigger-flags.yml` reports `glossary_hit: true` OR `sparse_input: true`
OR user passed `--interactive`. Skip otherwise.

- **Dispatches**: `generate/domain-consultant-subagent.md`
- **Inputs consumed by sub-agent**: `round-0/input.md`, `round-0/input-meta.yml`, `round-0/trigger-flags.yml`, `common/domain-glossary.md`
- **Outputs written by sub-agent**: `<target>/.review/round-0/clarification/<ISO-timestamp>.yml`
- **Orchestrator action on ACK**: record `trace_id` in `state.yml`; if ACK is `FAIL` → apply §16 retry policy; if user wrote `/abort` during dialogue → exit skill-forge.

### Step 5 — Planner (sub-agent dispatch)

- **Dispatches**: `generate/planner-subagent.md`
- **Inputs consumed by sub-agent**:
  - If consultant ran: `round-0/clarification/<ts>.yml`
  - If consultant skipped: `round-0/input.md` directly
- **Outputs written by sub-agent**: `<target>/.review/round-1/plan.md`
- **Orchestrator action on ACK**: record `trace_id`; proceed to Step 6.

### Step 6 — HITL: Plan Approval Gate

The orchestrator presents the plan to the user (read `round-1/plan.md` — **this is the ONLY
artifact the orchestrator is permitted to read**; it is a planning document, not a generated
artifact leaf).

Wait for user response:
- **approve** (or `/approve`) → continue to Step 7
- **revise** (or `/revise <feedback>`) → re-dispatch planner with feedback appended; loop Step 5–6
- **abort** (or `/abort`) → exit skill-forge

### Step 7 — Scaffold (script)

```bash
scripts/scaffold.sh <variant> <target>/ <target>/.review/round-0/clarification/<ts>.yml
```

- **Inputs**: variant name (from clarification.yml), target directory, clarification.yml
- **Outputs**: full skeleton tree at `<target>/` (copied from `common/skeleton/<variant>/`)
- **Orchestrator**: if exit non-zero → report error; halt.

### Step 8 — Writer Fan-out (parallel sub-agent dispatch)

Fan-out one writer sub-agent per file listed in `round-1/plan.md` `add:` list (typically 7–9 files).
All dispatched in parallel.

- **Dispatches**: `generate/writer-subagent.md` (N instances, one per file)
- **Inputs consumed by each sub-agent**:
  - `round-0/clarification/<ts>.yml` (most recent)
  - `round-1/plan.md`
  - Corresponding template from `common/templates/` (determined by target file type)
- **Outputs written by each sub-agent**:
  1. Target artifact file at `<target>/<relative-path>`
  2. `<target>/.review/round-1/self-reviews/<trace_id>.md`
- **Orchestrator action on all ACKs received**: collect `self_review_status` and `fail_count` per ACK. Proceed to Step 9.

### Step 9 — Script-Type Checks (script)

```bash
scripts/run-checkers.sh <target>/ round-1
```

- **Inputs**: all files in `<target>/` (script-accessible)
- **Outputs**: issue files under `<target>/.review/round-1/issues/` for any script-detected failures
- **Orchestrator**: if critical/error issues found → go to revise phase (Phase 22 / `revise/index.md`). Else → Step 10.

### Step 10 — Cross-Reviewer (sub-agent dispatch)

- **Dispatches**: `review/cross-reviewer-subagent.md`
- **Inputs consumed by sub-agent**: all target artifact leaves + issue files from Step 9
- **Outputs written by sub-agent**: additional issue files under `round-1/issues/`
- **Orchestrator action on ACK**: proceed to Step 11.

### Step 11 — Summarizer (sub-agent dispatch)

- **Dispatches**: `shared/summarizer-subagent.md`
- **Outputs written by sub-agent**: `round-1/index.md`, `CHANGELOG.md` entry, `.review/versions/<N>.md`
- **Orchestrator action on ACK**: proceed to Step 12.

### Step 12 — Judge (sub-agent dispatch)

- **Dispatches**: `shared/judge-subagent.md`
- **Outputs written by sub-agent**: `round-1/verdict.yml`
- **Orchestrator action on ACK**:
  - `verdict: converged` → proceed to delivery commit (`scripts/commit-delivery.sh`)
  - `verdict: progressing` → increment round, loop from Step 8 (writer fan-out on modified files only)
  - `verdict: stalled` → surface to user; request human intervention

### Delivery Commit

```bash
scripts/commit-delivery.sh <target>/ <delivery-id> <slug>
```

Creates annotated git tag `delivery-<N>-<slug>`. Skill-forge exits cleanly.

---

## Notes

- Round numbers are cross-delivery monotonic. Round 1 in delivery 1 is round 1 globally.
- The orchestrator MUST NOT read any artifact leaf other than `plan.md` (Step 6) and `verdict.yml` (Step 12 — exit-code equivalent). For all other routing decisions, rely on ACK fields alone.
- `from-scratch.md` is not a sub-agent prompt; it does not carry the Snippet D fingerprint.
