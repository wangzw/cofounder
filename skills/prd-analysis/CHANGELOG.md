# CHANGELOG

## [1.3.0] — 2025-05-22

**Feature-level concurrent pipeline.** Add single-feature operations
(modify/add/deprecate/evolve) that operate on individual features
instead of the full PRD bundle. Existing global modes unchanged.

- **`/prd-analysis modify <dir> F-NNN "desc"`** — in-place edit of one
  feature file + README index row + CHANGELOG entry. Other feature files
  untouched.
- **`/prd-analysis add <dir> "desc"`** — create single feature, auto-assign
  next available ID, update README index and CHANGELOG.
- **`/prd-analysis deprecate <dir> F-NNN`** — create tombstone, remove from
  active index, warn about dependent features.
- **`/evolve "F-NNN desc" [--design|--full]`** — unified cross-skill
  evolution with auto complexity determination (Trivial/Moderate/Complex)
  and adaptive approval gates.
- **Concurrency-safe:** different features touch disjoint files and
  README rows — no file locking needed.
- **New files:** `feature/modify.md`, `feature/add.md`, `feature/deprecate.md`,
  `feature/evolve.md`.

## [1.2.0] — 2026-05-08

**BREAKING — git tag rename.** The annotated tag created on converged
delivery is now `prd-analysis-delivery-<N>-<slug>` (was `delivery-<N>-<slug>`).

- **Why.** The old `delivery-*` namespace was shared with `system-design`,
  which also created `delivery-<N>-<slug>` tags. Symptoms ranged from
  cosmetic (`git tag -l 'delivery-*'` mixing PRD and design tags) to
  functional: `autoforge --evolve` resolves the design baseline via
  `git tag --list 'delivery-*' --merged HEAD --sort=creatordate` and
  defaults to the *earliest* match — when PRD tags were on the same
  repo, autoforge could pick a PRD tag as the design baseline. Each
  skill now owns its own `<skill>-delivery-*` namespace.
- **Scope of change.** `scripts/commit-delivery.sh` (`TAG=` line and
  redundant-prefix strip pattern), `scripts/compact-delivery.sh`
  (`tag --list` query and warning text), `tests/test-commit-delivery.sh`,
  and all docs that reference the tag form (`SKILL.md`, `README.md`,
  `compact/index.md`, `review/index.md`,
  `generate/from-scratch.md`, `generate/new-version.md`).
- **Migration.** A one-shot script renames pre-existing `delivery-<N>-<slug>`
  tags created by this skill to the new form. See repo-level
  `scripts/migrate-delivery-tags.sh` (run once per affected repo);
  it is idempotent and safe to re-run.
- **Strip-pattern extension.** `commit-delivery.sh`'s redundant-prefix
  strip now also recognises `<skill>-delivery-N:` forms, so summarizers
  that adopt the new convention won't produce double-prefixed tags.
- **Tests.** Added a regression case for the `<skill>-delivery-N:` strip path.

## [1.1.0] — 2026-05-07

Convergence release after rounds 5–10 of iterative audit. Skill now
reaches zero-findings state with mechanical guardrails
(`tests/test-cr-id-references.sh`) preventing the recurring failure
patterns that drove rounds 6–9 (fabricated CR-IDs; trace_id vs
on-disk issue-ID conflation in `linked_issues`).

### Changed since 1.0.0

- **fix: round-9 audit follow-up** —
  - `generate/new-version.md:65`: refuse-message guidance referenced a
    fabricated `--no-evolve` flag ("user should use `--no-evolve` or
    generate from scratch") that exists nowhere else in either skill;
    `system-design`'s sister file phrases the same exit as "user should
    generate from scratch". Dropped the `--no-evolve` clause to match.
  - `generate/evolve-mode.md`: the file's `## Evolve Step 1 — …` …
    `## Evolve Step 5 — …` headers framed it as an alternate
    orchestration sequence, contradicting `generate/new-version.md`
    (the canonical planner→writer dispatch flow declared in the
    Phase Contract at `SKILL.md:106`, in `generate/planner-subagent.md`,
    and in `scripts/check-plan.sh`'s `mode: new-version` enum).
    The "Step" sections are actually domain-content references that
    the planner / writer / reviewer sub-agents consult — not an
    alternate orchestration path. Renamed to non-orchestration
    headings ("Baseline Loading & Flattening", "Per-Phase Incremental
    Analysis Patterns", "Incremental File Generation Rules", "Evolve
    Review Checklist (Two-Layer)", "Commit Message & Post-Commit
    Cascade") and rewrote the preamble to point explicitly at
    `generate/new-version.md` for orchestration. Updated two stale
    cross-references that named "Evolve Step 4" / "Evolve Step 5"
    (`SKILL.md:18` mode-routing parenthetical, `SKILL.md:410` evolve
    cascade pointer).

- **fix: round-8 audit follow-up** —
  - Round-7 corrected `linked_issues: ["R3-012"]` → `["I-012"]` in
    `common/snippets.md` but missed three higher-traffic sites that
    propagate the same conflation between the dispatch `trace_id`
    namespace (`R<N>-<role>-<NNN>` like `R3-W-007`) and the on-disk
    issue-ID namespace (`I-NNN`, per `common/issue-schema.md`):
    - `SKILL.md:272` — `launched` JSONL example
    - `SKILL.md:296` — `completed` JSONL example
    - `generate/writer-subagent.md:66` — ACK envelope example
    These examples sit two lines below schema tables that document
    `linked_issues` as carrying issue-IDs, so the contradiction was
    actively misleading writer subagents. Updated all three to
    `I-012`; trace_id `R3-W-007` values preserved.
  - `tests/test-cr-id-references.sh`: added a second test that scans
    every auditable markdown file for `linked_issues` tokens (in
    JSONL, ACK envelope, and YAML forms) and asserts each matches
    `I-\d{3,}`. Mechanically rejects any future `R<N>-...` leakage
    into the issue-ID slot — ending the round-7 → round-8
    whack-a-mole cycle on this single conceptual error.

- **fix: round-7 audit follow-up** —
  - `common/snippets.md`: harness-event examples used
    `"linked_issues": ["R3-012"]` and `linked_issues=R3-012`, conflating
    the on-disk issue-ID format (`I-NNN`, per `common/issue-schema.md`
    and emitted by `scripts/create-issues.sh`) with the dispatch
    `trace_id` namespace (`R<N>-<role>-<NNN>`). Updated all three
    occurrences (lines ~55, ~79, ~166) to `["I-012"]` / `I-012`. The
    `trace_id` `R3-W-007` values are preserved — they correctly remain
    in the trace_id namespace, not the issue-ID namespace.

- **fix: round-6 audit follow-up** —
  - `generate/domain-consultant-subagent.md`: the GOOD-example heading
    cited fabricated `CR-L02 / CR-L06` ids (no `CR-L*` namespace exists
    in `common/review-criteria.md`); replaced with the canonical
    `CR-CL01 / CR-CL02` (clarification-required-keys-present /
    clarification-flat-keys-first).
  - `tests/test-cr-id-references.sh`: new programmatic guard rail that
    fails CI whenever any auditable markdown file (templates, subagent
    prompts, SKILL.md, mode-routing.md) cites a `CR-XXNN` token that is
    neither defined in `common/review-criteria.md` nor explicitly
    allowlisted (cross-skill refs, legacy emit-side ids). Catches the
    full class of bug uncovered across rounds 4–6 mechanically so
    future drift is rejected at test time rather than at human-audit
    time.

- **fix: round-5 audit follow-up** —
  - `common/templates/artifact-template.md`: rule #4 cited a non-existent
    `CR-L05 (artifact-template-self-contained)`; replaced with the
    canonical `CR-PP14 (self-containment)` (line 552 of
    `common/review-criteria.md`). Same failure mode that the round-4
    cross-reviewer fix addressed: a writer subagent looking up a
    fabricated CR-ID would either skip the rule or hallucinate it.

- **fix: round-4 audit follow-ups** —
  - `CHANGELOG.md`: switched the unreleased heading from `## Unreleased`
    to `## [Unreleased]` so it matches the keep-a-changelog convention
    used by the system-design skill (and is recognized by automated
    changelog parsers).
  - `review/cross-reviewer-subagent.md`: removed the false claim that
    `create-issues.sh` rejects unknown `criterion_id` values. The
    orchestrator only validates schema (required fields, severity enum,
    ≥5-char description / fix); criterion-id correctness is the
    reviewer's responsibility. Updated wording explicitly warns that
    hallucinated ids will silently produce malformed issue files.

- **fix: round-3 audit follow-ups** — added regression tests for the
  incremental-review snapshot script (`scripts/snapshot-leaves.sh`):
  empty-bundle handling, hash stability across calls, sensitivity to
  leaf content changes, and feature/journey leaf enumeration.

- **fix: SKILL.md drift and stale doc strings** —
  - `generate/document-mode.md`: parser-heuristics route for
    authorization content corrected from `architecture/authorization.md`
    to canonical `architecture/auth-model.md` (matches
    `architecture-template.md`; same class as the earlier `personas.md`
    fix). Prevents orphan files that bypass `check-architecture-coverage`.
  - `SKILL.md` Configuration & Subagent Files block: added a new
    "Pipeline-stage scripts" group listing five scripts that are
    invoked at runtime but were absent from the catalog
    (`prepare-input.sh`, `commit-delivery.sh`, `snapshot-leaves.sh`,
    `compute-review-scope.sh`, `prune-traces.sh`, plus
    `glossary-probe.sh`, `git-precheck.sh`, `metrics-aggregate.sh`).
  - `SKILL.md` Mode Routing: removed the stale parenthetical claiming
    `common/scope-reference.md` and `common/templates/review-checklist.md`
    are read by the writer subagent at self-audit time. The writer
    subagent's self-audit follows `generate/in-generate-review.md`;
    `review-checklist.md` is consumed only by `generate/evolve-mode.md`
    and `revise/revise-mode.md`.
  - `SKILL.md` Input Modes Summary: rephrased the `--revise` line so
    Mode Routing and Input Modes Summary describe the same loop ("per-issue
    revise loop with state-machine: new → fixed/false-positive/deferred/superseded").
  - `revise/per-issue-reviser-subagent.md`: corrected `revise/index.md
    Step 2` reference to `Step 3` (Step 2 builds the manifest;
    Step 3 fans out per-issue revisers).
  - `revise/revise-mode.md`: marked **DEPRECATED / NOT ROUTED**.
    File documents an earlier interactive change-management workflow
    that is no longer loaded by any SKILL.md mode (the active
    `--revise` flow lives in `revise/index.md`). Kept as design
    reference; not deleted.

- **breaking: prototypes → frontend draft** — Phase 5 is renamed from
  "Interactive Prototype" to "Frontend Draft" and now produces runnable
  frontend code (real code, not a low-fidelity throwaway) directly into the
  project source tree at the path recorded in `architecture/tech-stack.md` →
  "Frontend Implementation Path". The draft is **experience-validation only**:
  it confirms layout, navigation, state-machine reachability, and visual look
  with the user. Production hardening — full i18n library wiring, accessibility
  audit, test coverage, lint/coding-standard conformance, performance budgets —
  is **explicitly deferred** to the next two phases: system-design plans the
  promotion (Production Promotion Plan + per-module Promotion Requirements);
  autoforge executes it in place via Promote / Extend / Rewrite actions.
  Rationale: in the AI-coding era, the traditional "low-fidelity prototype →
  re-implement in production" loop is pure rework; design **is**
  implementation. Changes:
  - New "Frontend Implementation Path" subsection in
    `architecture/tech-stack.md` records the repo-relative path (e.g.
    `frontend/`, `web/`, `apps/web/`, `cmd/<app>/`) chosen by the user at
    Phase 5 entry. system-design and autoforge continue to evolve the code
    at the same path; there is no separate "production implementation" path.
  - Feature template's "Prototype Reference" section is renamed to
    "Frontend Draft Reference" and now records only draft path +
    `Confirmed (experience)` date (no prototype source path, no
    screenshots path).
  - PRD README's Feature Index "Prototype" column renamed to "UI" and links
    to the repo-relative draft directory (or `—` for backend-only
    features). The `prototypes/` directory disappears from both the standard
    and evolve directory trees; the "Interactive Prototypes" reference link
    is removed.
  - `revise-mode` "Prototype impact" dimension renamed to
    "Frontend draft impact" — invalidating the recorded confirmation,
    not regenerating prototype source/screenshots, and explicitly leaving
    production promotion of the affected code to system-design.
  - `evolve-mode` Phase 5 modifies the existing draft at the baseline's
    Frontend Implementation Path in place; no per-evolve `prototypes/`
    directory is produced.
  - Three review criteria removed entirely: **CR-PP35** (prototype-spec
    alignment), **CR-PP36** (prototype-feedback-incorporated), **CR-PP37**
    (prototype-archival-complete). Draft review responsibility shifts to
    system-design (promotion-plan completeness) and autoforge (promotion
    execution). The corresponding three rows are dropped from
    `review-checklist.md` (one Per-file row split is removed too) and the
    bullet from `cross-reviewer-subagent.md`.
  - `scope-reference.md` lists the Phase 5 deliverable as "Frontend draft
    produced into the project source tree per spec (experience-validation
    only)"; production promotion is explicitly out of scope at PRD level.
- **feat: incremental review + `--full` flag** — review rounds now write
  a sha256 leaves manifest (`scripts/snapshot-leaves.sh` →
  `round-<N>/leaves-manifest.yml`) and a per-round scope file
  (`scripts/compute-review-scope.sh` → `round-<N>/review-scope.yml`).
  Cross- and adversarial-reviewers consume `review-scope.yml` to decide
  whether each LLM criterion is full-scan (apply to every leaf) or
  per-file (apply only to leaves listed in `changed_leaves[]`). The
  `incremental_skip` annotations on every `checker_type: llm` criterion
  in `common/review-criteria.md` — previously orphan metadata — are now
  authoritative inputs to the scope computation. Decision tree: forced
  full review on the first round of a delivery (no prior manifest
  within `current_delivery`), on missing/corrupt prior manifest
  (safety fallback), or when a new `--full` CLI flag is passed (single
  invocation only — `--auto` drops it from subsequent rounds in the
  same loop). Otherwise incremental, diff-based. Reviewer prompts gain
  a top-level `scope_applied: full | incremental` audit field. Adds
  `scripts/snapshot-leaves.sh`, `scripts/compute-review-scope.sh`,
  `enumerate_leaves()` in `scripts/lib/prd_lint.py`, and 39 new tests.
- **feat: `--auto` auto-compaction** — when `--auto` reaches `converged`,
  the delivery sequence (`review/index.md` Step 9) now runs
  `compact-delivery.sh` automatically right after `commit-delivery.sh`
  creates the `delivery-<N>-<slug>` tag. Hand-off to the next pipeline
  stage no longer needs a manual `--compact` call. Interactive mode is
  unchanged (still surfaces a next-step hint).
- **feat: `--compact` mode** — new pure-script mode that aggregates the
  intermediate review rounds of the current delivery into a single
  `.review/round-<final>/compacted-history.md` summary and deletes the
  intermediate `round-N/` + `traces/round-N/` trees. Also sweeps any
  orphan `.review/traces/round-<N>/` whose source round dir is already
  gone (left over from prior compacted deliveries). Designed for the
  hand-off point between `prd-analysis` and the next pipeline stage
  (e.g. `system-design`) after many review/revise iterations. Gated on
  `verdict: converged` for the current delivery's final round; warns
  when no `delivery-<N>-<slug>` git tag exists (use `--force` or run
  `commit-delivery.sh` first). Adds `scripts/compact-delivery.sh`,
  `scripts/check-compacted-history.sh` (CR-CH01, CR-CH02), the
  `compact` phase in `verify-phase-entry.sh`, and `compact/index.md`
  orchestration. 67 new tests; 470 total.

## Delivery 3 — 2026-04-28

- **Verdict**: converged after 5 rounds
- **Git SHA**: `976c362`
- **Changes**: Forced-full cross-review triggered by skill-forge 0.2.2 drift (CR-S15 cost-control, CR-S16 skeleton conformance, CR-S17 checker-implementation, CR-L11 cross-reference consistency); 21 issues found in round 6; monotonic resolution across rounds 7–10 via cross-review + targeted revise cycles (6 → 2 → 1 → 0 convergence); skeleton-protected exception R6-V003-004 (scripts/lib/aggregate.py, warning) carried forward per revise-mode specification
- **Leaves affected**: 5 core leaves revised (SKILL.md, review/index.md, parallel-dispatch.md, 2 topic refinements); 65 scaffold-owned leaves verified byte-identical

## Delivery 2 — 2026-04-25

- **Verdict**: converged after 3 rounds
- **Git SHA**: `dd6107d`
- **Changes**: LLM-type cross-review via split-scope fan-out (3 sonnet reviewers by scope); 20 issues found and closed in revise cycle; 0 script-type issues post-convergence
- **Leaves affected**: 10 core leaves (SKILL.md, subagent spec, templates, topic files)

## Delivery 1 — 2026-04-25

- **Verdict**: converged after 2 rounds
- **Git SHA**: `e699468`
- **Changes**: Full skill regeneration using cost-optimized from-scratch generation with per-role model overrides; 18 writer dispatches recovered from transient API failures; 5 CR-META-missing-checker errors resolved in revise phase
- **Leaves affected**: 36 core leaves (SKILL.md, templates, topic files) + 41 scripts
