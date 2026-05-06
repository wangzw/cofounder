# CHANGELOG

## [Unreleased]

### Changed
- **PRD-draft → production hardening handoff (paradigm sync with prd-analysis)** —
  prd-analysis Phase 5 produces a frontend draft (experience-validation only) at
  the path recorded in PRD `architecture/tech-stack.md` → "Frontend Implementation
  Path". system-design now plans how that draft becomes production-deliverable
  rather than designing UI from scratch:
  - **Replaced** `## Prototype-to-Production Mapping` in
    `common/templates/design-readme-template.md` with `## Production Promotion
    Plan` — per-module table of `Module | Action | Draft Path | Hardening Scope`.
    Action values are **Promote / Extend / Rewrite** (replacing
    Reuse / Refactor / Rewrite); Promote/Extend keep the draft and harden it
    in place, Rewrite redoes from feature spec.
  - **Extended** `## View / Screen Index` table with two new columns:
    `Draft Path` and `Promotion Action`.
  - **Inverted** the semantics of `## UI Architecture` in
    `common/templates/module-template.md`: Component Tree / Routing / State
    Management / Key Interactions now describe the contracts the **existing
    draft must match** (divergences are draft gaps to fix during promotion),
    not a from-scratch design. Added `Draft path:` and `Promotion action:`
    header fields.
  - **Added** `### Promotion Requirements` subsection to the module template,
    required for every frontend module with Action = Promote/Extend. Covers
    five hardening categories: i18n integration, Accessibility, Performance,
    Tests, Coding-standard alignment. Each row records the current draft
    state and the hardening autoforge must add.

### Added
- **Two new review criteria**:
  - **CR-SD-DESIGN09 ui-promotion-action-set** (per_file, error) — every
    frontend module declares a Promotion action, has a Draft path, and is
    consistent with the README Production Promotion Plan and View/Screen
    Index. Replaces (at the design level) part of the responsibility removed
    when prd-analysis dropped CR-PP35.
  - **CR-SD-DESIGN10 ui-hardening-coverage** (per_file, warning) — every
    Promote/Extend module's Promotion Requirements subsection covers all
    five hardening categories (i18n / a11y / perf / tests / coding-standard);
    `N/A` rows include a one-line rationale.
  - **CR-SD-DESIGN11 cross-journey-coverage** (per_file, warning) — the
    new README `## Cross-Journey Patterns Coverage` table contains one row
    for every Cross-Journey Pattern listed in the source PRD's README
    (with source features, addressing modules, and realization mechanism).

### Fixed
- **Module template heading drift** — `common/templates/module-template.md`
  now uses the canonical CR-SD06 section names (`## Responsibilities`,
  `## Public Interfaces`, `## Dependencies`) that `scripts/check-module.sh`
  enforces. Previously the template shipped with `## Responsibility` /
  `## Interfaces` / `## Module Deps`, so any writer following the template
  produced bundles that failed formal review. Propagated rename to
  `generate/writer-subagent.md`, `generate/planner-subagent.md`,
  `review/cross-reviewer-subagent.md`, `common/domain-glossary.md`, and
  `common/templates/design-readme-template.md` README diagram commentary.
  Added template-vs-script consistency tests in
  `tests/test-check-module.sh` so future drift fails CI.
- **`SKILL.md` documentation drift** — corrected the per-artifact
  formal-review CR-ID map to match each `scripts/check-*.sh` header, listed
  `--evolve` in Input Modes (was contradicted by mode table), removed a
  stale reference to a non-existent `common/output-discipline.md` from the
  compact mode-routing row, replaced four named scripts that don't exist
  (`finalize-revisions.sh`, `judge-round.sh`, `summarize-round.sh`,
  `summarize-delivery.sh`) with the actual pipeline scripts, and updated
  the `R-001..R-006` and `CR-SD-DESIGN01..08` ranges to current values.

- **Incremental review + `--full` flag** — review rounds now write a
  sha256 leaves manifest (`scripts/snapshot-leaves.sh` →
  `round-<N>/leaves-manifest.yml`) and a per-round scope file
  (`scripts/compute-review-scope.sh` → `round-<N>/review-scope.yml`).
  Cross- and adversarial-reviewers consume `review-scope.yml` to decide
  whether each LLM criterion is full-scan (apply to every leaf) or
  per-file (apply only to leaves listed in `changed_leaves[]`). All 10
  `checker_type: llm` criteria in `common/review-criteria.md` now carry
  an authoritative `incremental_skip: full_scan | per_file` annotation
  (previously absent). Decision tree: forced full review on the first
  round of a delivery (no prior manifest within `current_delivery`), on
  missing/corrupt prior manifest (safety fallback), or when a new
  `--full` CLI flag is passed (single invocation only — `--auto` drops
  it from subsequent rounds in the same loop). Otherwise incremental,
  diff-based. Reviewer prompts gain a top-level
  `scope_applied: full | incremental` audit field. Adds
  `scripts/snapshot-leaves.sh`, `scripts/compute-review-scope.sh`,
  `enumerate_leaves()` (and `MODULE_FILE_RE` / `API_FILE_RE`) in
  `scripts/lib/sd_lint.py`, and 39 new tests.
- **`--compact` mode** — new pure-script mode that aggregates the
  intermediate review rounds of the current delivery into a single
  `.review/round-<final>/compacted-history.md` summary and deletes the
  intermediate `round-N/` + `traces/round-N/` trees. Also sweeps any
  orphan `.review/traces/round-<N>/` whose source round dir is already
  gone (left over from prior compacted deliveries). Designed for the
  hand-off point between `system-design` and the next pipeline stage
  (e.g. `autoforge`) after many review/revise iterations. Gated on
  `verdict: converged` for the current delivery's final round; warns
  when no `delivery-<N>-<slug>` git tag exists (use `--force` or run
  `commit-delivery.sh` first). Adds `scripts/compact-delivery.sh`,
  `scripts/check-compacted-history.sh` (CR-CH01, CR-CH02), the
  `compact` phase in `verify-phase-entry.sh`, and `compact/index.md`
  orchestration.
- **`--auto` auto-compaction** — when `--auto` reaches `converged`,
  the delivery sequence (`review/index.md` Step 9) now runs
  `compact-delivery.sh` automatically right after `commit-delivery.sh`
  creates the `delivery-<N>-<slug>` tag. Hand-off to the next pipeline
  stage no longer needs a manual `--compact` call. Interactive mode is
  unchanged (still surfaces a next-step hint).

### Changed
- Deprecate `.reviews/` (with-S) end-user review directory; consolidate all review and revise
  output to `.review/round-<N>/issues/<issue-id>.md` (no-S) per skill-forge harness convention.
- `--review` mode now writes issue files to `.review/round-<N>/issues/` instead of `.reviews/`.
- `--revise` mode now reads open issues from `.review/round-<N>/issues/` (filtering by
  `status: new | persistent | regressed`) instead of unapplied `.reviews/REVIEW-*.md`/`LINT-*.md`.
- Remove `.applied.md` rename step from revise flow; issue closure is now tracked via
  `status: resolved` frontmatter field in the issue file.
- Remove per-reviser REVISIONS.md append; REVISIONS.md update is now a summarizer concern.
- Remove direct `.reviews/LINT-NNN.md` file writes from individual check scripts; issue files
  are written exclusively by `run-checkers.sh` via JSON stdout aggregation.

## Delivery 1 — 2026-04-28 (In Progress)

- **Verdict**: Round 1 complete; not yet converged
- **Git SHA**: pending
- **Changes**: First-time generation (FromScratch mode) of system-design skill from legacy monolithic templates; 27 new files (SKILL.md, 9 subagent prompts, 4 artifact templates, 4 mode-routing overrides, 13 structural-lint scripts)
- **Writer Output**: 30 leaves generated by parallel writers; all passed self-review (zero self-review failures)
- **Review Findings**: 30 issues filed across 15 leaves (6 blockers CR-L11, 20 important, 4 suggestions); majority are cross-document inconsistencies between templates, criteria, and mode-routing files
- **Leaves affected**: SKILL.md, cross-reviewer-subagent.md, module-template.md, api-template.md, design-readme-template.md, from-scratch.md, new-version.md, domain-glossary.md, writer-subagent.md, adversarial-reviewer-subagent.md, review/index.md, revise/per-issue-reviser-subagent.md, common/review-criteria.md, generate/planner-subagent.md, 13x scripts/check-*.sh
