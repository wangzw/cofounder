---
id: R7-V001-002
round: 8
file: SKILL.md
criterion_id: CR-L11
severity: critical
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolved_in_round: 8
---

# R7-V001-002 — RESOLVED

## Original finding (round-7)

SKILL.md Mode Routing table (line 20) for `--revise` pointed at the legacy `revise/revise-mode.md`
(467-line interactive flow with Clustering Subagent, Templates A/B, Pre-Answered Mode),
making the canonical generative-skill `revise/index.md` orchestration unreachable from
the user-facing entry point. Dual-spec drift (CR-L11), parallel to the round-6
review-mode dual-spec issue.

## Verification (round-8 state)

SKILL.md Mode Routing line 20 now reads:

> | revise | `/cofounder:prd-analysis --revise <prd-dir>` | `revise/index.md`, `common/parallel-dispatch.md`, `common/output-discipline.md` (+ `common/scope-reference.md` + `common/templates/review-checklist.md` on demand) | Per-issue revise loop driven by open issues from last review round; cascade re-review when scope changes |

The canonical `revise/index.md` is now the sole entry point loaded for `--revise`; the
legacy `revise/revise-mode.md` is no longer referenced from the mode-routing table.

A class-based grep across all seven focus leaves for `revise-mode.md` direct references
shows the file is no longer cross-referenced from any focus leaf as the canonical
`--revise` orchestration target. (Two stray prose mentions remain in
`common/parallel-dispatch.md` lines 4-5 — filed separately as R8-001, see body.)

The original CR-L11 critical violation (mode-routing pointing at legacy file → canonical
generative-skill orchestration unreachable) is no longer detectable in SKILL.md.

## Notes

`revise/revise-mode.md` itself still exists on disk in the `revise/` directory — it is on
the `cross_reviewer_skip` list this round and was not opened. R7-V001-002 was about the
SKILL.md cross-reference specifically; whether to retire/redirect/delete the legacy file
itself is a separate scaffolding decision outside this issue's scope.
