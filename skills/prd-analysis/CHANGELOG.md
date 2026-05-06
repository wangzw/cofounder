# CHANGELOG

## Unreleased

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
