# CHANGELOG

## Delivery 3 — 2026-04-28

- **Verdict**: converged after 5 rounds
- **Git SHA**: `<filled by commit-delivery>`
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
