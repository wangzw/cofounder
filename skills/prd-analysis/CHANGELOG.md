# CHANGELOG

## [Unreleased]

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
