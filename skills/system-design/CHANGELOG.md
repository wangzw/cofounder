# CHANGELOG

## [1.1.0] — 2026-05-08

**BREAKING — git tag rename.** The annotated tag created on converged
delivery is now `system-design-delivery-<N>-<slug>` (was `delivery-<N>-<slug>`).

- **Why.** The old `delivery-*` namespace was shared with `prd-analysis`,
  causing cosmetic mixing in `git tag -l 'delivery-*'` and a functional
  hazard for downstream `autoforge --evolve`, which resolves the
  baseline design tag via `git tag --list 'delivery-*' --merged HEAD`
  and would have been ambiguous in repos containing PRD tags. Each
  skill now owns its own `<skill>-delivery-*` namespace; autoforge has
  been updated in lockstep to query `system-design-delivery-*`.
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

## [1.0.0] — 2026-05-07

First stable release. Convergence after rounds 5–10 of iterative
audit. Skill reaches zero-findings state with mechanical guardrails
(`tests/test-cr-id-references.sh`) preventing recurring failure
patterns from rounds 6–9 (fabricated CR-IDs; trace_id vs on-disk
issue-ID conflation in `linked_issues`).

### Fixed
- **Round-8 audit follow-ups**:
  - `SKILL.md:273, 297` — round-7 corrected `linked_issues:
    ["R3-012"]` → `["I-012"]` in `common/snippets.md` but missed the
    same `launched` / `completed` JSONL examples in SKILL.md, which
    sit two lines below schema tables documenting `linked_issues` as
    carrying on-disk issue-IDs (`I-NNN`, per `common/issue-schema.md`,
    not the dispatch `trace_id` `R<N>-<role>-<NNN>`).
  - `generate/writer-subagent.md:66` — same conflation in the ACK
    envelope example; updated to `linked_issues=I-012`. Trace_id
    `R3-W-007` preserved.
  - `tests/test-cr-id-references.sh`: added a second test that scans
    every auditable markdown file for `linked_issues` tokens (JSONL,
    ACK envelope, YAML forms) and asserts each matches `I-\d{3,}`.
    Mechanically rejects future `R<N>-...` leakage into the issue-ID
    slot — ending the round-7 → round-8 whack-a-mole cycle on this
    single conceptual error.

### Fixed
- **Round-7 audit follow-ups**:
  - `common/templates/revision-entry-template.md`: round-6 replaced the
    retired `REVIEW-001.md / LINT-001.md` naming with `R<N>-<seq>` /
    `R<N>-V-<seq>` — but that namespace is the dispatch `trace_id`
    (`R3-W-007`, `R3-V-001`), NOT the on-disk issue filename. The
    canonical issue-ID format is `I-\d{3,}` (e.g., `I-007`), enforced
    by `scripts/create-issues.sh` (`f"I-{n:03d}"`) and documented in
    `common/issue-schema.md:23,59`. Updated all four sites
    (placeholder description, example header, in-line Summary refs,
    Verification narrative) to `I-NNN`.
  - `common/domain-glossary.md`: three glossary entries propagated the
    same wrong claim — `structural-lint` ("issue IDs follow
    `R<N>-<seq>`"), `design-review` ("issue IDs follow `R<N>-V-<seq>`
    for cross-reviewer, `R<N>-V-<seq>-ADV` for adversarial"), and
    `REVISIONS.md` ("source issue IDs (e.g. `R<N>-<seq>`,
    `R<N>-V-<seq>`)"). Corrected to `I-\d{3,}` per
    `common/issue-schema.md`. The `design-review` entry now also
    clarifies that the dispatch `trace_id` is recorded inside the
    issue body, not used as the filename.
  - `common/snippets.md`: harness-event examples used
    `"linked_issues": ["R3-012"]` and `linked_issues=R3-012` (lines
    ~53, ~77, ~164), confusing trace_id with issue-ID. Updated to
    `["I-012"]` / `I-012`. Trace_id `R3-W-007` values preserved.
  - `compact/index.md:151`: forbidden-actions block enumerated PRD
    bundle dirs (`features/`, `journeys/`, `architecture/`) instead
    of design bundle dirs. Updated to `modules/, api/, architecture/`
    so the orchestrator's prompt names the actual content leaves a
    compact pass must not touch.

### Fixed
- **Round-6 audit follow-ups**:
  - `generate/domain-consultant-subagent.md`: three sites
    (lines ~149, ~202, ~206) cited the retired `CR-D01..CR-D10`
    namespace as the default "semantic review criteria" set; the
    canonical namespace today is `CR-SD01..CR-SD19` plus
    `CR-SDFM01..CR-SDFM03`. Updated the R-005 placeholder, the
    Q5-asked-rarely guidance, and the deferred-default narrative.
    The GOOD-example heading also cited fabricated `CR-L02 / CR-L06`;
    replaced with `CR-CL01 / CR-CL02` (the canonical clarification
    criteria).
  - `common/templates/revision-entry-template.md`: three sites used
    the retired `REVIEW-001.md, LINT-001.md` filename convention from
    the pre-`.review/` consolidation. Reworked the placeholder
    description, example header, and verification narrative to use
    the canonical issue IDs `R<N>-<seq>` (lint) and `R<N>-V-<seq>`
    (cross-reviewer) at `.review/round-<N>/issues/`.
  - `common/templates/design-readme-template.md`: cross-journey
    patterns commentary cited `PRD CR-PP07`; the actual
    traceability-chain criterion is `CR-PP06` (`CR-PP07` is
    `evidence-present`). Updated to `CR-PP06 (traceability-chain)`.
- **Test infrastructure**: added `tests/test-cr-id-references.sh`,
  a programmatic guard rail that fails CI whenever any auditable
  markdown file (templates, subagent prompts, SKILL.md,
  mode-routing.md) cites a `CR-XXNN` token that is neither defined
  in `common/review-criteria.md` nor explicitly allowlisted (PRD
  cross-skill refs `CR-PP06`, the in-skill `CR-SDFM01..03`, and
  legacy emit-side ids `CR-X3/X4/X6/X7/CR-L2` that
  `scripts/lib/sd_emit.sh` remaps at runtime). Catches the full
  class of bug uncovered across rounds 4–6 mechanically.

### Fixed
- **Round-5 audit follow-ups**:
  - `common/templates/design-readme-template.md`: removed the stale
    `CR-D07` reference in the cross-module interactions matrix
    commentary. `CR-D07` does not appear anywhere in
    `common/review-criteria.md`; reworded as descriptive text so writer
    subagents don't try to look up a non-existent criterion.
  - `scripts/lib/sd_emit.sh`: docstring still listed `readme-references`
    as a caller of this helper, and `CR_MAP` still carried the
    `CR-X8 → CR-SD18` remap; both are dead since the python3 port of
    `check-readme-references.sh` (912fb4e) emits `CR-SD18` directly via
    `sd_lint.emit()`. Removed the stale entries to avoid sending
    debuggers chasing a phantom emitter.

### Fixed
- **Round-4 audit follow-ups**:
  - `SKILL.md` Configuration & Subagent Files: `check-revisions.sh` was
    catalogued under "Pipeline-stage scripts" with the wrong description
    (`issue state transitions (CR-RI)`); moved to "Per-artifact
    formal-review scripts" and corrected to `REVISIONS.md version-chain
    integrity (CR-RV01, CR-SD03)`. The CR-RI ids belong to
    `check-round-index.sh` (already correct).
  - `SKILL.md` Configuration & Subagent Files: six per-artifact scripts
    were labelled with legacy CR-IDs (`CR-X3`, `CR-X4`, `CR-X6`, `CR-X7`,
    `CR-X8`, `CR-L2`) that no longer appear in
    `common/review-criteria.md`; replaced with the canonical
    `CR-SD14..CR-SD19` ids (the runtime CR_MAP in `scripts/lib/sd_emit.sh`
    continues to remap reviewer-output JSON, so this is purely a doc
    correction).
  - `review/cross-reviewer-subagent.md`: removed the false claim that
    `create-issues.sh` rejects unknown `criterion_id` values. The
    orchestrator only validates schema (required fields, severity enum,
    ≥5-char description / fix); criterion-id correctness is the
    reviewer's responsibility.
  - `tests/test-check-readme-references.sh`: added two regression tests
    for the previously-fixed silent-exit-1 bug (a README line containing
    `(` but no `]( … )` markdown link — e.g. `**Review Required**: Yes
    (pending formal pre-check)`. Verifies both PASS-without-violations
    and findings-still-emitted scenarios. Sibling scripts
    (`check-architecture-coverage.sh`, `check-analytics-coverage.sh`,
    `check-dependency-layering.sh`, `check-placeholder-json.sh`,
    `check-single-source-of-truth.sh`) audited and confirmed safe — they
    either don't use `grep -oE` or wrap it in `< <(...)` process
    substitution where `set -e` does not propagate.
- **Round-3 audit follow-ups**:
  - `review/cross-reviewer-subagent.md`: corrected stale LLM CR-ID range
    `CR-SD-DESIGN01..08` → `CR-SD-DESIGN01..11` and appended the bullet
    summaries for DESIGN09/10/11 so the cross-reviewer LLM actually
    enforces the three new criteria (previously silently unenforced).
  - `review/index.md`: the `auto_decision.failing_cr_ids` example used
    PRD-domain CR-IDs (`CR-PP02`, `CR-FM01`) carried over from a
    skill-fork; replaced with valid SD IDs (`CR-SD04`, `CR-SDFM02`).
  - `common/templates/module-template.md`: stale CR ref
    `CR-SD-ui-hardening-coverage` → canonical `CR-SD-DESIGN10`.
  - `SKILL.md`: Output Structure tree referenced `REVIEW-*.md`,
    `LINT-*.md`; corrected to the canonical `I-NNN.md per
    common/issue-schema.md`. Configuration & Subagent Files catalog
    extended with the previously-missing per-artifact formal-review
    scripts (`check-self-review`, `check-plan`, `check-clarification`,
    `check-version`, `check-round-index`, `check-placeholder-json`,
    `check-single-source-of-truth`) and a new "Helpers / bootstrap
    scripts" group (`glossary-probe`, `synthesize-clarification`,
    `git-precheck`).
- **`scripts/prune-traces.sh`**: was grepping for `retention_rounds:`
  but `common/config.yml` writes `retention.traces_retention_rounds:`,
  so the script always fell back to default 20 and never honored
  user-configured retention. Now matches the canonical key.
- **`scripts/metrics-aggregate.sh`**: added the `_set_scope` helper
  (already in prd-analysis) so passing two scope flags (e.g.
  `--round 1 --delivery 1`) exits 1 with a clear "scope flags are
  mutually exclusive" error instead of silently overwriting the first.

### Added
- **Test coverage parity with prd-analysis**: ported the
  `commit-delivery`, `git-precheck`, `glossary-probe`,
  `metrics-aggregate`, and `prune-traces` test runners from
  prd-analysis. New tests for `check-placeholder-json` and
  `check-single-source-of-truth` (the two SD-specific lint scripts).
  New `test-snapshot-leaves.sh` covering empty-bundle, hash stability
  across calls, content-change sensitivity, and module enumeration.
  Test count: 523 → 591 (+68).

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
- **Three new review criteria**:
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
- **`scripts/check-analytics-coverage.sh` (CR-X4 / CR-SD15) silent
  no-op** — section detector matched `^##[[:space:]]+Analytics`
  (level-2), but the PRD `feature-template.md` emits
  `### Analytics & Tracking` (level-3), so the parser entered the
  Analytics section on **zero** real PRD features and never reported a
  coverage gap. Updated entry/exit regex to level-3 (`^###` →
  `^####` for nested event headings) and added
  `tests/test-check-analytics-coverage.sh` (8 cases) covering the
  level-3 happy path, the missing-event blocker path, and a regression
  guard that verifies the legacy level-2 heading is **not** mistakenly
  parsed.
- **Test coverage for previously-untested lint scripts** — added
  `tests/test-check-architecture-coverage.sh` (7),
  `tests/test-check-readme-references.sh` (7), and
  `tests/test-check-dependency-layering.sh` (6). Each covers arg
  validation, the blocker path, the PASS path, and (where applicable)
  the skip-on-missing-source path.

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
  per-file (apply only to leaves listed in `changed_leaves[]`). All 13
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
