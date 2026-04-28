# Changelog

skill-forge release history. Versions follow semantic versioning per
[semver.org](https://semver.org/) and skill-forge's domain-glossary entry on
`version` (which lists the full alias set including `version`, `semver`,
`bump major`, `bump minor`, `release`, etc.).

---

## 0.3.0 — 2026-04-28

### Changed (behaviour, mode-boundary)

- **`--review` and `--revise` no longer auto-chain.** Prior to 0.3.0,
  three auto-chain entry points caused the orchestrator to silently
  cascade dispatches inside one `/skill-forge` invocation:

  1. `review/index.md` Step 7 verdict-routing: `progressing → Revise
     phase: load revise/index.md, increment round`.
  2. `review/index.md` Step 1 Phase-A exit-1: `Exit 1 with critical or
     error issues → skip Steps 2–4; jump directly to Revise Phase
     (load revise/index.md)`.
  3. `revise/index.md` Step 5 verdict-routing: `progressing → Increment
     round N; loop back to review/index.md Step 3 (cross-reviewer)`.

  Together these three meant a single `--review` could end up running
  review → revise → review → revise … until convergence, paying for
  opus-tier cross-reviewers and sonnet-tier revisers without operator
  visibility. The chain also produced an inconsistent post-state —
  revisers fix files but issue frontmatter still says `status: new`
  because only cross-reviewer transitions status — making any subsequent
  `--revise` re-invocation re-dispatch revisers for already-fixed issues
  (non-idempotent).

  As of 0.3.0, each top-level `/cofounder:skill-forge --<mode>` invocation
  runs exactly the phase named by its flag and exits at the verdict.
  The orchestrator updates `state.yml.mode_phase` to one of
  `idle-awaiting-review-round-<N+1>` or `idle-awaiting-revise-round-<N>`
  to signal the next step the operator should invoke. The operator
  decides whether to continue, inspect, override, or abort.

  In-generate review (dispatched by `generate/from-scratch.md` Phase 22
  and `generate/new-version.md` Step 11) is unaffected — that flow has
  its own internal review→revise iteration scoped to the generate
  invocation's lifecycle.

  The boundary fix lets `--review`/`--revise` remain idempotent across
  re-invocations: re-running a phase that already completed is a clean
  no-op (the orchestrator reads `mode_phase` and refuses to re-dispatch
  what's already been done in the current round).

  Propagated to all 4 skeleton variants (`code/`, `document/`, `hybrid/`,
  `schema/`) under `review/index.md` and `revise/index.md`.

### Tests

- New `tests/unit/test-mode-boundary-no-auto-chain.sh` greps the canonical
  + 4 skeleton variants of `review/index.md` Step 7 and `revise/index.md`
  Step 5, asserting that the new `MUST NOT auto-load` directive and
  `idle-awaiting-*` mode_phase signal are present, and that the legacy
  auto-chain wording is absent. 10 files checked total.

### Operator note

Targets currently in flight under 0.2.x (e.g. prd-analysis at delivery-3
round-8 with `mode_phase: idle-awaiting-review-round-9`) were already
operated against the auto-chain semantics — that's how the round-7 and
round-8 review→revise cascades happened. Going forward, the operator
must invoke `--review` and `--revise` separately. Existing in-flight
state is compatible: the `mode_phase` field already exists and the
orchestrator was already updating it correctly; 0.3.0 just removes the
auto-chain that was bypassing the boundary.

Re-scaffolding existing targets is required to propagate the updated
`review/index.md` and `revise/index.md` into their skeleton-owned
copies — `scripts/scaffold.sh` will detect the `scaffolder_version`
drift (0.2.2 → 0.3.0) and trigger auto-force-full on the next `--review`.

---

## 0.2.2 — 2026-04-28

### Fixed

- **Auto-force-full now actually fires for scaffolded targets** (corrects 0.2.1).
  The 0.2.1 release added an auto-force-full path on "reviewer version drift",
  but the resolution was wrong: `run-checkers.sh` read `$SCRIPT_DIR/../SKILL.md`
  to determine the "current reviewer version". Because `run-checkers.sh` is
  *copied into every scaffolded target* by `scaffold.sh`, `$SCRIPT_DIR/..`
  resolves to the **target itself** — yielding the target's own SKILL.md
  version, not the scaffolder's. Scaffolded targets don't bump their own
  version when skill-forge bumps; the comparison to `state.yml.reviewer_version_seen`
  was therefore always equal, and auto-force-full never triggered for any
  non-self-review target. The bug only worked accidentally for skill-forge
  reviewing skill-forge (where `$SCRIPT_DIR/..` truly is skill-forge), which
  is exactly why the 0.2.1 unit tests passed.

  The 0.2.2 fix decouples the two concepts:

  - `scaffold.sh` writes a top-level `scaffolder_version: "<X.Y.Z>"` field
    into `<target>/common/scaffold-provenance.yml` at scaffold and
    re-scaffold time, recording the version of whichever generator produced
    this skill (skill-forge today, but the field name is generator-agnostic
    to support the recursive case where an artifact-skill itself scaffolds
    sub-skills).

  - `run-checkers.sh` reads `scaffolder_version` from the target's provenance
    file as the "current reviewer version". For self-review of the generator
    (no provenance file because generators are not themselves scaffolded),
    it falls back to `$TARGET/SKILL.md`. The `$SCRIPT_DIR/..` resolution is
    gone.

  - The auto-force-full comparison is now: `state.yml.reviewer_version_seen`
    vs `scaffold-provenance.yml.scaffolder_version`. Drift means propagation
    has updated criteria/prompts in the target tree since the last round,
    and the incremental skip-set must be overridden.

  Propagated to all 4 skeleton variants. Existing scaffolded targets need
  one-time backfill of `scaffolder_version` in their `scaffold-provenance.yml`
  (re-running `scaffold.sh` does this; alternatively, hand-edit one line).

  Regression test: `tests/unit/test-run-checkers-version-drift.sh` rewritten
  with 6 sub-tests, including:
  - **Test 1 (regression guard for the 0.2.1 bug)**: scaffolded target where
    SKILL.md is unchanged, `scaffolder_version` advances 0.2.1 → 0.2.2 →
    must force-full. The original 0.2.1 tests never exercised this path.
  - **Test 6 (negative guard)**: target self-bumps its own SKILL.md without
    a scaffolder bump → must NOT force-full. Catches the inverse failure
    mode of the 0.2.1 bug.

---

## 0.2.1 — 2026-04-28 — *INCORRECT FIX, see 0.2.2*

### Fixed

- **Auto-force-full when reviewer version changes between rounds**. The
  incremental skip-set computed by `run-checkers.sh` previously considered
  only target-tree drift, missing leaves that pass under the old criteria
  but would fail under new criteria after a reviewer version bump. Same
  architecture as the round-6 stale-checker bug, but at the criteria/prompt
  level instead of script-content level.

  `run-checkers.sh` now reads `reviewer_version_seen` from `<target>/.review/state.yml`,
  compares to `$SCRIPT_DIR/../SKILL.md` version (the version of the skill that
  owns this run-checkers.sh — skill-forge for skill-forge, the generated
  target for any scaffolded skill), and auto-sets `FORCED_FULL=1` on
  mismatch. After successful skip-set write, state.yml's
  `reviewer_version_seen` is updated to the current version so the next
  round has a fresh baseline.

  The fix propagates to all 4 skeleton variants — every skill scaffolded
  by skill-forge from 0.2.1 onwards will auto-force-full when its own
  version bumps. Generated target skills can therefore self-detect when
  their own reviewer logic has changed and re-evaluate all artifacts.

  Regression test: `tests/unit/test-run-checkers-version-drift.sh`
  (5 sub-tests covering: matching version → no auto-force, drift → auto-force
  + stderr notice, state.yml update post-run, first-review-empty case,
  explicit `--full` still works regardless).

  Test suite: 39 unit-test files, all passing.

  > **Note**: The "$SCRIPT_DIR/../SKILL.md" resolution above resolves to the
  > target itself (not the scaffolder) because `run-checkers.sh` is copied
  > into every scaffolded target. This 0.2.1 fix therefore did not work for
  > any non-self-review target. Corrected in 0.2.2.

---

## 0.2.0 — 2026-04-28

### Added

- **`CR-L11 cross-reference-consistency`** (LLM-tier, severity error). Formalizes
  the broader cross-artifact-contract scope that round-6 cross-reviewers were
  squeezing into CR-L04. CR-L04 stays narrowly scoped to `conflicts_with` pairs
  inside `review-criteria.md`; CR-L11 covers the rest (script_path mismatches,
  dual-spec drift between mode files and their canonical counterparts, header
  comments contradicting execution paths, ID/count drift across files).
  Definition propagated to main + 4 skeleton variants. SKILL.md count bumped
  to 27 CR (16 script + 11 LLM).

- **`CR-S17 checker-implements-declared-cr`** (script-tier, severity error).
  For every `script_path:` declared in review-criteria.md, the target's script
  at that path MUST grep-contain the literal CR-ID string. Catches the silent
  stale-checker drift case — when skill-forge updates a checker upstream but
  the target's older copy doesn't pick up the change. Implemented by new
  `scripts/check-checker-implementations.sh` (5 copies). Auto-derived inventory
  inclusion via `check-scripts-inventory.sh` parsing of review-criteria.md.
  SKILL.md count bumped to 28 CR (17 script + 11 LLM).

- **`scripts/check-checker-implementations.sh`** (new, ~80 lines, 5 copies).
  Parses review-criteria.md for `script_path:` values, groups CR-IDs by script,
  and verifies each script grep-contains the CR-IDs it's declared for.

- **Reviewer-drift detection in `scripts/check-drift.sh`**. Reads
  `skill_forge_dir` from `<target>/.review/state.yml` and diffs the skill-forge
  tree against the same baseline tag. Same-repo: full diff; cross-repo: stderr
  warning + target-only fallback. Closes the bug where `--review` would
  short-circuit on a target whose reviewer logic (skill-forge itself) had
  changed since baseline.

- **Auto-derive CR-bound scripts in `check-scripts-inventory.sh`**.
  `REQUIRED_SCRIPTS` previously hardcoded; CR-S15's `script_path` was silently
  omitted causing the inventory check to disagree with `run-checkers.sh`'s
  missing-checker meta-issue. Now `INFRA_SCRIPTS` is hardcoded for plumbing
  scripts (12 of them) and CR-bound scripts come from parsing review-criteria.md
  `script_path:` values. Synced across main + 4 skeletons.

- **5 new regression tests** (~38 sub-tests total):
  - `tests/unit/test-criteria-references.sh` (5 sub-tests) — guards count-line
    consistency between SKILL.md, cross-reviewer-subagent.md, and
    review-criteria.md; catches stale `CR-L01..CR-L10` references.
  - `tests/unit/test-aggregate-trace-id-regex.sh` (4 sub-tests) — behavioural
    test of `lib/aggregate.py` `TRACE_ID_RE` canonical pattern.
  - `tests/unit/test-check-checker-implementations.sh` (7 sub-tests) — covers
    CR-S17 detection, false-positive guards, defer-to-CR-S05/CR-S07 cases.
  - `tests/unit/test-reviser-global-conflict.sh` (6 sub-tests) — anti-pattern
    phrase guard + required-phrase guard + adversarial-reviewer self-consistency.
  - `tests/unit/test-skeleton-identity.sh` extended to cover
    `common/review-criteria.md` and `scripts/check-checker-implementations.sh`
    in `VERBATIM_FILES`.

### Fixed

- **Skeleton `git-precheck.sh` bootstrap quoting bug**. All 4 skeleton variants
  shipped with `git -c user.name=this skill -c user.email=this skill@local`
  unquoted; bash word-split the embedded space, git aborted with
  `'skill' is not a git command`, and any freshly scaffolded skill landing in
  a non-git directory could never pass precheck. Fixed with single-token
  identity `skill-bootstrap`.

- **`lib/aggregate.py TRACE_ID_RE` canonical alphabet (R6-V003-004)**. Old
  regex `R\d+-[A-Za-z]-\d+` accepted invalid role letters (e.g. `R3-X-007`,
  lowercase `R3-w-007`) and unpadded sequences (`R3-W-7`, `R3-W-1234`),
  diverging from the canonical CR-S10 contract enforced by
  `check-trace-id-format.sh`. Tightened to `R\d+-[CPWVRSJ]-\d{3}(?!\d)`
  applied to all 5 copies; sha256 pin in `common/shared-scripts-manifest.yml`
  updated.

- **Reviser must NOT force-fix `global-conflict` in single-leaf scope (R7-V002-002)**.
  `revise/per-issue-reviser-subagent.md` instructed the reviser to "apply the
  fix as scoped to this leaf only" for `blocker_scope: global-conflict`
  issues — exactly the anti-pattern that
  `review/adversarial-reviewer-subagent.md` attack angle #6 was written to
  catch. Replaced with the canonical refuse + meta-issue + `FAIL ACK` pattern
  across main + 4 skeletons. Internal CR-L11 contradiction within skill-forge
  is now resolved.

### Changed

- **Drop `"硬修"` Chinese annotation from English contract text**. The phrase
  appeared in 26 files mixed into otherwise-English contracts where it added
  no semantic value. Replaced with bare English (`force-fix in-place`).
  Chinese aliases in `common/domain-glossary.md` are intentionally preserved —
  they map user-facing colloquial terms (生成式 skill, 工作流 skill, 叶子,
  制品, etc.) to canonical English so the domain-consultant can disambiguate.

### Notes

- Test suite: 38 unit-test files, all passing.
- prd-analysis (the first skill scaffolded by skill-forge) has been brought
  to delivery-3 round-7 post-revise convergence using these improvements;
  end-to-end review/revise cycle validated.

---

## 0.1.1 — earlier

Previous baseline. Includes the original 24 CR set (14 script + 10 LLM),
3-way LLM cross-review fan-out, dispatch-log v1, metrics-aggregate
`--diagnose` mode, 4 skeleton variants (code/document/hybrid/schema), and
prd-analysis as the bootstrap skill.
