# system-design

A generative skill that produces **AI-coding-ready System Design
documents** through an alternating write/read cycle with script-enforced
phase boundaries.

This README is for developers who want to **use**, **modify**, or
**audit** the skill. End-users typically just invoke
`/system-design` from Claude Code; the entry-point doc for
that flow is `SKILL.md`.

---

## What it produces

A **design bundle** — a multi-file directory consumable by downstream
coding agents (autoforge) and human reviewers:

```
docs/raw/design/YYYY-MM-DD-{product-slug}/
├── README.md                       # design overview, module index, feature-module mapping
├── REVISIONS.md                    # version history (after first --revise)
├── CHANGELOG.md                    # human-readable delivery summary
├── feature-module-map.yml          # machine-readable feature→module mapping (input for delta mode)
├── modules/M-NNN-{slug}.md         # per-module specs (responsibility, deps, contracts, failure modes)
└── api/API-NNN-{slug}.md           # per-API specs (endpoints, versioning, schemas)
```

The **feature-module-map.yml** is auto-generated during global mode and consumed
by `/system-design delta` and `/autoforge --feature`. It maps each PRD `F-NNN`
to its `writes` (✦) and `reads` (△) module sets in YAML format.

Plus a `.review/` audit trail (transient, not version-controlled) that
records every dispatch, every issue, and every state transition.

Upstream input: a **PRD bundle** under `docs/raw/prd/`. The bridge
between requirements and implementation is the **Feature-Module
mapping matrix** (PRD `F-NNN` × design `M-NNN`) embedded in the design
README, where `✦` marks a module that owns data for a feature and `△`
marks read-only support.

---

## Modes

| Command | Mode |
|---------|------|
| `/system-design` | Generate from latest PRD |
| `/system-design <prd-dir>` | Generate from a specific PRD bundle |
| `/system-design --review <design-dir>` | Read phase: cross-reviewer + judge |
| `/system-design --revise <design-dir>` | Write phase: per-issue fix loop |
| `/system-design --evolve <design-dir> [<prd-dir>]` | Iterate to a new version |
| `/system-design --compact <design-dir>` | Retire intermediate review rounds |
| `/system-design --diagnose [--round N \| --delivery N]` | Aggregate metrics from harness JSONL |

### Feature-level delta

| Command | Mode |
|---------|------|
| `/system-design delta <design-dir> F-NNN` | Single-feature delta analysis. Reads `feature-module-map.yml`, computes affected modules (writes ∪ reads), updates module specs in-place. Outputs affected module list + regression-test scope. |

`SKILL.md` "Mode Routing" has the full per-mode loaded-files map.

---

## Architecture: write/read phase contract

The skill alternates between two phase types, with **script-enforced
entry gates** at every phase boundary:

```
   ┌─── generate (initial) OR revise ──[write phase]
   │              │
   │              ▼  exit gate: formal PASS  ∧  no state:new
   │              │
   │              ▼
   │      review (read phase)
   │              │  entry gate: prior write ended cleanly + bundle is formally clean
   │              │
   │              ▼  produces issues in state:new
   │              │
   │              ▼  judge verdict
   │              │
   ├──progressing─┘   (loop back to revise)
   │
   └──converged──→ delivery (commit + tag)
```

The phase contract — including which script runs at each boundary — is
laid out in `SKILL.md` under "Phase Contract". The single mandatory
entry script is **`scripts/verify-phase-entry.sh <phase>`**, called as
the first action of every orchestration file.

Key invariants:
- A `state: new` issue **only exists** between read phase output and
  the immediately-following revise. It MUST never survive into the
  next read.
- A bundle that fails formal review **never** reaches LLM cross-reviewer
  dispatch (zero LLM tokens spent on structurally broken artifacts).
- Write phase **loops on its own scripts** until formal PASS — it does
  not escape to read with violations outstanding.

---

## Output: artifact ↔ script ↔ test mapping

Every artifact this skill produces has exactly one formal-review script
and one test runner. **~34 scripts / 23 test runners / 442 tests** (run
`bash tests/run-all.sh`).

### Design bundle (LLM-produced; user-visible)

| Artifact | Formal-review script | Test |
|----------|---------------------|------|
| `README.md` | `check-readme.sh` | `tests/test-check-readme.sh` |
| `README.md` (refs only) | `check-readme-references.sh` | *(covered in test-check-readme)* |
| `REVISIONS.md` | `check-revisions.sh` | `tests/test-check-revisions.sh` |
| `modules/M-NNN-{slug}.md` | `check-module.sh` | `tests/test-check-module.sh` |
| `api/API-NNN-{slug}.md` | `check-api.sh` | `tests/test-check-api.sh` |
| `CHANGELOG.md` | — *(human-readable; exempt per guide §3)* | — |

### Cross-bundle structural checks

| Script | Role | Test |
|--------|------|------|
| `check-feature-module-mapping.sh` | PRD-features ↔ design-modules matrix coverage | `tests/test-check-feature-module-mapping.sh` |
| `check-architecture-coverage.sh` | Every PRD architecture topic is reflected in design modules | *(integrated)* |
| `check-dependency-layering.sh` | Module Deps DAG has no unjustified reverse-layer edges | *(integrated)* |
| `check-single-source-of-truth.sh` | No duplicated truth across modules / data models | *(integrated)* |
| `check-analytics-coverage.sh` | Every PRD analytics event has an emitting module | *(integrated)* |
| `check-placeholder-json.sh` | No "TBD" / "TODO" / placeholder JSON in shipped specs | *(integrated)* |

### Audit artifacts (.review/, LLM-edited)

| Artifact | Formal-review script | Test |
|----------|---------------------|------|
| `.review/round-N/issues/I-NNN.md` | `check-issue.sh` | `tests/test-check-issue.sh` |
| `.review/round-0/clarification/<ts>.yml` | `check-clarification.sh` | *(integrated)* |
| `.review/round-N/plan.md` | `check-plan.sh` | `tests/test-check-plan.sh` |
| `.review/round-N/self-reviews/<trace_id>.md` | `check-self-review.sh` | `tests/test-check-self-review.sh` |
| `.review/round-N/reviewer-output/<trace_id>.json` | `check-reviewer-output.sh` | `tests/test-check-reviewer-output.sh` |
| `.review/round-N/index.md` | `check-round-index.sh` | `tests/test-check-round-index.sh` |
| `.review/round-N/verdict.yml` | `check-verdict.sh` | `tests/test-check-verdict.sh` |
| `.review/versions/<N>.md` | `check-version.sh` | `tests/test-check-version.sh` |

### Script-produced (no formal review needed; downstream catches bugs)

`state.yml`, `issues/summary.yml`, `issues/archive.yml`,
`traces/round-N/dispatch-log.jsonl`, `metrics/*.metrics.yml`,
`round-0/input.md`, `round-0/input-meta.yml`, `round-0/trigger-flags.yml`,
`.review/README.md`.

---

## Other scripts

### Phase gates (script-enforced boundaries)

| Script | Role |
|--------|------|
| `verify-phase-entry.sh <phase>` | **Mandatory first step of every phase**. Consolidates entry preconditions and refuses the phase on FAIL. Dispatches per-phase: `read` / `revise` / `generate-fresh` / `generate-evolve`. |
| `check-review-readiness.sh` | No `state: new` from prior rounds (read entry sub-check). |
| `check-revise-completeness.sh` | No `state: new` in current round (revise exit). |

### Aggregator + helpers

| Script | Role |
|--------|------|
| `run-checkers.sh` | Auto-discovers and dispatches every per-artifact `check-*.sh` (excluding phase gates). The formal-review aggregator. |
| `create-issues.sh` | Materializes per-issue `.md` files from LLM `reviewer-output/*.json`. Default mode reads from disk; `--stdin` for direct JSON pipe. |
| `update-summary.sh` | Refreshes `.review/issues/summary.yml` with current state-machine + history + recurrence counts. Read by cross-reviewer for fingerprint matching. |
| `synthesize-clarification.sh` | `--no-consultant` flow: writes a deferred-only `clarification/<ts>.yml` so the orchestrator stays pure-dispatch. |

### Generate-mode infrastructure

| Script | Role |
|--------|------|
| `git-precheck.sh` | Verifies git/bash/python versions; auto-init if not in a repo. |
| `prepare-input.sh` | Round-0 input normalization. Writes the raw user prompt verbatim to `input.md` (no `@path` / URL expansion — sub-agents fetch any referenced paths or URLs themselves via Read / WebFetch) and emits `input-meta.yml` (word/char counts, structural flags) for downstream sparse-input detection. Idempotently drops `.review/README.md` from the template on first bootstrap. |
| `glossary-probe.sh` | Round-0 trigger-flags (`glossary_hit`, `sparse_input`). |

### Delivery / metrics

| Script | Role |
|--------|------|
| `commit-delivery.sh` | On-converge: stages, commits, creates annotated `system-design-delivery-<N>-<slug>` tag. |
| `snapshot-leaves.sh` | At read-phase entry (review/index.md Step 1.5): writes `round-<N>/leaves-manifest.yml` (sha256 per leaf) for the next round's incremental-scope diff. |
| `compute-review-scope.sh` | At read-phase entry (review/index.md Step 1.6): emits `round-<N>/review-scope.yml` (`mode: full` or `mode: incremental` plus `changed_leaves[]`); honors a single-shot `--full` flag forwarded from the orchestrator. |
| `prune-traces.sh` | Retention policy on `.review/traces/round-N/*.yml` (audit `.jsonl` preserved). |
| `metrics-aggregate.sh` | `--diagnose` mode: JOINs harness JSONL + dispatch-log → `.review/metrics/<scope>.metrics.yml`. |

### Library

| File | Role |
|------|------|
| `scripts/lib/sd_lint.py` | Shared Finding dataclass, frontmatter parser, `emit()` per guide §9 contract. Imported by every per-artifact `check-*.sh`. |
| `scripts/lib/aggregate.py` | Pure-Python metrics aggregator backing `metrics-aggregate.sh`. |
| `scripts/lib/sd_emit.sh` | Shared §9 emitter for cross-bundle linters: normalises legacy `CR-X*/CR-L2` ids and `blocker/mechanical` severities to canonical `CR-SD14..19` and `sd_lint` severity vocabulary. |

---

## Issue lifecycle

Issues use a 5-state machine (guide §7.2):

```
                 reviser MUST act
                 ┌──────────────┐
[create-issues] ─┤              ▼
                 ▼          fixed (verify formal pass)
                new ──────► false-positive (dismissed_reason required)
                            deferred (defer_until + defer_reason required)
                            superseded (superseded_by required)
```

- Schema: `common/issue-schema.md`
- File path: `<artifact-root>/.review/round-<N>/issues/I-NNN.md`
- ID allocation: monotonic across all rounds (`create-issues.sh`
  scans existing files for `max(id) + 1`)
- Recurrence detection: `recurrence_of` + `recurrence_count` fields
  populated by `create-issues.sh` from `summary.yml`; HITL escalation
  fires at `recurrence_count >= 2` per guide §7.5.1

---

## Running tests

```bash
# Full suite (20 runners, ~7 seconds)
bash skills/system-design/tests/run-all.sh

# Single test runner
bash skills/system-design/tests/test-check-module.sh

# Test framework: bash + scripts/lib/test_helpers.sh
# Each test creates a tmp fixture, runs assertions, tears down.
```

The test framework lives at `tests/lib/test_helpers.sh`. Pattern:

```bash
test_case "well-formed module passes formal review"
setup_fixture
write_file "modules/M-001-auth.md" "$GOOD_MODULE_BODY"
assert_exit 0 "$REPO_SCRIPTS/check-module.sh" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture
```

---

## Adding a new artifact / CR

When adding a new artifact type or a new criterion:

1. **Write the per-artifact script** under `scripts/check-X.sh`. Follow
   guide §9 contract: 3-state returncode (0/1/2), stdout always
   restates meaning, idempotent, agent-actionable issues. Use
   `from sd_lint import Finding, emit` for the boilerplate.
2. **Write the test runner** under `tests/test-check-X.sh`. Cover
   pass-path + every CR's fail-path + idempotency.
3. **Declare the CR(s)** in `common/review-criteria.md`. Set
   `checker_type: script` and `script_path: scripts/check-X.sh` for
   formal CRs; `checker_type: llm` for substantive CR-SD-DESIGN ids.
4. **No registration step needed** — `run-checkers.sh` auto-discovers
   any `check-*.sh` in `scripts/` (except phase gates). `tests/run-all.sh`
   auto-discovers any `test-*.sh` in `tests/`.
5. **Update `SKILL.md`** "Configuration & Subagent Files" to add the
   new entry to the per-artifact table.

If the new artifact is **LLM-produced**, follow the patterns in
`check-issue.sh` (audit-side schema) or `check-module.sh` (design-bundle
content). If it's **script-produced**, no formal review is needed —
downstream consumers will surface producer bugs.

---

## Design references

| Document | Topic |
|----------|-------|
| `~/Documents/mind/raw/guide/生成式 Skill 设计指南.md` | Generative-skill methodology (8-role, pyramid index, script-first review) |
| `~/Documents/mind/raw/guide/生成式skill的审查设计.md` | Audit design: formal vs substantive review, state machine, phase gates |
| `SKILL.md` § Phase Contract | Write/read alternation + per-phase entry gates |
| `SKILL.md` § Configuration & Subagent Files | Full inventory of scripts, prompts, criteria |
| `common/issue-schema.md` | On-disk issue file format + LLM raw-output JSON + summary.yml shape |
| `common/review-criteria.md` | All CR-IDs (formal CR-SD01..19 + CR-SDFM01..03; substantive CR-SD-DESIGN01..08; meta CR-META-*) |
| `review/index.md`, `revise/index.md` | Read / write phase orchestration step-by-step |
| `generate/from-scratch.md`, `generate/new-version.md` | Generate-mode round-0 sequences |

---

## Stats

- **~34 scripts** (`scripts/*.sh` + 4 lib files)
- **23 test runners** (`tests/test-*.sh`)
- **442 tests passing** (`bash tests/run-all.sh`)
- **~22 CR-IDs** in `common/review-criteria.md` (CR-SD01..19, CR-SDFM01..03,
  CR-SD-DESIGN01..08, CR-META-mechanize, CR-META-adversarial, plus
  audit-side CR-CL/PL/SR/RO/RI/VD/VS/CH/RV families)
- **8 sub-agent prompts** (planner, writer, domain-consultant,
  cross-reviewer, adversarial-reviewer, per-issue-reviser,
  summarizer, judge)
- **4 modes** + 1 diagnostic mode + `--evolve` + delta mode

The redesign that produced this state ports the prd-analysis Phase
Contract, formal-vs-substantive split, and IPC `Direct Write + ACK`
model into the system-design domain. Domain mapping:
features (`F-NNN`) → modules (`M-NNN`); journeys (`J-NNN`) → APIs
(`API-NNN`); architecture topics → README.md sections.
