# prd-analysis

A generative skill that produces **AI-coding-ready Product Requirements
Documents** through an alternating write/read cycle with script-enforced
phase boundaries.

This README is for developers who want to **use**, **modify**, or
**audit** the skill. End-users typically just invoke
`/prd-analysis` from Claude Code; the entry-point doc for that
flow is `SKILL.md`.

---

## What it produces

A **PRD bundle** — a multi-file directory consumable by downstream
coding agents (system-design, autoforge) and human reviewers:

```
docs/raw/prd/YYYY-MM-DD-{product-slug}/
├── README.md                # product overview + journey/feature index
├── REVISIONS.md             # version history (after first --revise)
├── CHANGELOG.md             # human-readable delivery summary
├── journeys/J-NNN-{slug}.md # per-persona user journeys
├── features/F-NNN-{slug}.md # self-contained feature specs (with BDD AC)
├── architecture.md          # architecture index (~50 lines)
└── architecture/{topic}.md  # tech-stack / design-tokens / security / …
```

Each **feature file** is self-contained — data models, conventions, design tokens,
and journey touchpoints are copied inline. A coding agent implements a feature
by reading only its feature file. See `common/templates/feature-template.md` for
the 17-section template.

Plus a `.review/` audit trail (transient, not version-controlled) that
records every dispatch, every issue, and every state transition.

---

## Modes

| Command | Mode |
|---------|------|
| `/prd-analysis` | Interactive from-scratch generation |
| `/prd-analysis path/to/notes.md` | Document-driven generation |
| `/prd-analysis --review <prd-dir>` | Read phase: cross-reviewer + judge |
| `/prd-analysis --revise <prd-dir>` | Write phase: per-issue fix loop |
| `/prd-analysis --evolve <prd-dir> [notes.md]` | Iterate to a new version |
| `/prd-analysis --compact <prd-dir>` | Retire intermediate review rounds |
| `/prd-analysis --diagnose [--round N \| --delivery N]` | Aggregate metrics from harness JSONL |

### Feature-level operations (concurrent, single-feature scope)

| Command | Mode |
|---------|------|
| `/prd-analysis modify <prd-dir> F-NNN "desc"` | Modify a single feature in-place. Only the target feature file, README index row, and CHANGELOG are touched. Other features untouched. |
| `/prd-analysis add <prd-dir> "desc"` | Add a new feature. Auto-assigns next available ID. Creates feature file + updates README + CHANGELOG. |
| `/prd-analysis deprecate <prd-dir> F-NNN ["reason"]` | Deprecate a feature. Creates tombstone file, moves feature to Deprecated Items index. Reports dependents for cascade update. |
| `/evolve F-NNN "desc"` | Unified cross-skill evolution. Auto-determines complexity (Trivial/Moderate/Complex), runs contract update → design delta → implementation in one flow, with adaptive approval gates. |
| `/evolve F-NNN "desc" --design` | Force design review gate insertion. |
| `/evolve F-NNN "desc" --full` | Force full triple-gate (contract + design + summary). |
| `/evolve F-NNN "desc" --prd-dir <dir> --design-dir <dir>` | Explicit directories (auto-discovered otherwise). |

Feature-level operations are **concurrency-safe**: concurrent modifies of different features
touch disjoint feature files and disjoint README rows. No file locking needed.

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
and one test runner. **29 scripts / 29 test runners / 470 tests** (run
`bash tests/run-all.sh`).

### PRD bundle (LLM-produced; user-visible)

| Artifact | Formal-review script | Test |
|----------|---------------------|------|
| `README.md` | `check-readme.sh` | `tests/test-check-readme.sh` |
| `REVISIONS.md` | `check-revisions.sh` | `tests/test-check-revisions.sh` |
| `journeys/J-NNN-{slug}.md` | `check-journey.sh` | `tests/test-check-journey.sh` |
| `features/F-NNN-{slug}.md` | `check-feature.sh` | `tests/test-check-feature.sh` |
| `architecture.md` (index) | `check-architecture-index.sh` | `tests/test-check-architecture-index.sh` |
| `architecture/{topic}.md` | `check-architecture-topic.sh` | `tests/test-check-architecture-topic.sh` |
| `CHANGELOG.md` | — *(human-readable; exempt per guide §3)* | — |

### Audit artifacts (.review/, LLM-edited)

| Artifact | Formal-review script | Test |
|----------|---------------------|------|
| `.review/round-N/issues/I-NNN.md` | `check-issue.sh` | `tests/test-check-issue.sh` |
| `.review/round-0/clarification/<ts>.yml` | `check-clarification.sh` | `tests/test-check-clarification.sh` |
| `.review/round-N/plan.md` | `check-plan.sh` | `tests/test-check-plan.sh` |
| `.review/round-N/self-reviews/<trace_id>.md` | `check-self-review.sh` | `tests/test-check-self-review.sh` |
| `.review/round-N/reviewer-output/<trace_id>.json` | `check-reviewer-output.sh` | `tests/test-check-reviewer-output.sh` |
| `.review/round-N/index.md` | `check-round-index.sh` | `tests/test-check-round-index.sh` |
| `.review/round-N/verdict.yml` | `check-verdict.sh` | `tests/test-check-verdict.sh` |
| `.review/versions/<N>.md` | `check-version.sh` | `tests/test-check-version.sh` |
| `.review/round-N/compacted-history.md` | `check-compacted-history.sh` | `tests/test-check-compacted-history.sh` |

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
| `verify-phase-entry.sh <phase>` | **Mandatory first step of every phase**. Consolidates entry preconditions and refuses the phase on FAIL. |
| `check-review-readiness.sh` | No `state: new` from prior rounds (read entry sub-check). |
| `check-revise-completeness.sh` | No `state: new` in current round (revise exit). |

### Aggregator + helpers

| Script | Role |
|--------|------|
| `run-checkers.sh` | Auto-discovers and dispatches every per-artifact `check-*.sh` (excluding phase gates). The formal-review aggregator. |
| `create-issues.sh` | Materializes per-issue `.md` files from LLM `reviewer-output/*.json`. Default mode reads from disk; `--stdin` for direct JSON pipe (also tolerates a leading non-JSON summary line, so `run-checkers \| create-issues --stdin` works directly). |
| `update-summary.sh` | Refreshes `.review/issues/summary.yml` with current state-machine + history + recurrence counts. Read by cross-reviewer for fingerprint matching. |
| `synthesize-clarification.sh` | `--no-consultant` flow: writes a deferred-only `clarification/<ts>.yml` so the orchestrator stays pure-dispatch. |

### Generate-mode infrastructure

| Script | Role |
|--------|------|
| `git-precheck.sh` | Verifies git/bash/python versions; auto-init if not in a repo. |
| `prepare-input.sh` | Round-0 input bootstrap: writes `input.md` (raw prompt) + `input-meta.yml` (word/char counts) + drops `.review/README.md` from template. |
| `glossary-probe.sh` | Round-0 trigger-flags (`glossary_hit`, `sparse_input`). |

### Delivery / metrics

| Script | Role |
|--------|------|
| `commit-delivery.sh` | On-converge: stages, commits, creates annotated `prd-analysis-delivery-<N>-<slug>` tag. |
| `compact-delivery.sh` | `--compact` mode: aggregates current delivery's intermediate rounds into `compacted-history.md`, then deletes those `round-N/` + `traces/round-N/` trees. Gated on `verdict: converged`. |
| `snapshot-leaves.sh` | At read-phase entry (review/index.md Step 1.5): writes `round-<N>/leaves-manifest.yml` (sha256 per leaf) for the next round's incremental-scope diff. |
| `compute-review-scope.sh` | At read-phase entry (review/index.md Step 1.6): emits `round-<N>/review-scope.yml` (`mode: full` or `mode: incremental` plus `changed_leaves[]`, and v1.4+ `category_clusters[]` — one entry per active LLM-criterion category for per-category reviewer fan-out); honors a single-shot `--full` flag forwarded from the orchestrator. |
| `prune-traces.sh` | Retention policy on `.review/traces/round-N/*.yml` (audit `.jsonl` preserved). |
| `metrics-aggregate.sh` | `--diagnose` mode: JOINs harness JSONL + dispatch-log → `.review/metrics/<scope>.metrics.yml`. |

### Library

| File | Role |
|------|------|
| `scripts/lib/prd_lint.py` | Shared Finding dataclass, frontmatter parser, `emit()` per guide §9 contract. Imported by every per-artifact `check-*.sh`. |
| `scripts/lib/aggregate.py` | Pure-Python metrics aggregator backing `metrics-aggregate.sh`. |

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
# Full suite (all 27 runners, ~7 seconds)
bash skills/prd-analysis/tests/run-all.sh

# Single test runner
bash skills/prd-analysis/tests/test-check-feature.sh

# Test framework: bash + scripts/lib/test_helpers.sh
# Each test creates a tmp fixture, runs assertions, tears down.
```

The test framework lives at `tests/lib/test_helpers.sh`. Pattern:

```bash
test_case "well-formed feature passes formal review"
setup_fixture
write_file "features/F-001-checkout.md" "$GOOD_FEATURE_BODY"
assert_exit 0 "$REPO_SCRIPTS/check-feature.sh" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture
```

---

## Adding a new artifact / CR

When adding a new artifact type or a new criterion:

1. **Write the per-artifact script** under `scripts/check-X.sh`. Follow
   guide §9 contract: 3-state returncode (0/1/2), stdout always
   restates meaning, idempotent, agent-actionable issues. Use
   `from prd_lint import Finding, emit` for the boilerplate.
2. **Write the test runner** under `tests/test-check-X.sh`. Cover
   pass-path + every CR's fail-path + idempotency.
3. **Declare the CR(s)** in `common/review-criteria.md`. Set
   `checker_type: script` and `script_path: scripts/check-X.sh`.
4. **No registration step needed** — `run-checkers.sh` auto-discovers
   any `check-*.sh` in `scripts/` (except phase gates). `tests/run-all.sh`
   auto-discovers any `test-*.sh` in `tests/`.
5. **Update `SKILL.md`** "Configuration & Subagent Files" to add the
   new entry to the per-artifact table.

If the new artifact is **LLM-produced**, follow the patterns in
`check-issue.sh` (audit-side schema) or `check-feature.sh` (PRD-bundle
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
| `common/review-criteria.md` | All 70+ CR-IDs with prose + YAML metadata |
| `review/index.md`, `revise/index.md` | Read / write phase orchestration step-by-step |
| `generate/from-scratch.md`, `generate/new-version.md` | Generate-mode round-0 sequences |

---

## Stats (as of 2026-05-06)

- **29 scripts** (`scripts/*.sh` + 2 lib files)
- **29 test runners** (`tests/test-*.sh`)
- **470 tests passing** (`bash tests/run-all.sh`)
- **72+ CR-IDs** in `common/review-criteria.md`
- **8 sub-agent prompts** (planner, writer, domain-consultant,
  cross-reviewer, adversarial-reviewer, per-issue-reviser,
  summarizer, judge)
- **4 modes** + 1 diagnostic mode + `--evolve` + 4 feature-level operations

The redesign producing this state was 21 commits since `4bce546`,
audited by three independent code-reviewer agent passes (25 findings
total, all resolved).
