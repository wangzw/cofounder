---
id: R8-001-resolved
round: 9
file: common/parallel-dispatch.md
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolves: R8-001
---

# R8-001 resolved: parallel-dispatch.md introduction now uses canonical revise-mode terminology

## Verification

Round-8 reviser R8-R-001 rewrote the file's introductory paragraph (lines 1-5).
Current `common/parallel-dispatch.md` lines 1-5 now read:

```
# Parallel Dispatch Protocol

Shared dispatch rules for fan-out generation of feature/journey/architecture leaves (generation
Step 3), review subagents (review-mode Step 2), and per-issue reviser subagents (revise-mode
Step 2 fan-out). These rules take precedence over any per-mode wording that conflicts.
```

The two legacy references that R8-001 flagged are gone:

1. **"the clustering subagent (revise-mode Pre-Answered Mode)"** — DELETED. The
   introduction no longer references the legacy `revise/revise-mode.md` interactive
   change-gathering flow.

2. **"fix subagents (revise-mode Step 5)"** — REPLACED with "per-issue reviser subagents
   (revise-mode Step 2 fan-out)". This matches the canonical `revise/index.md` Step 2
   ("Fan-out Per-Issue-Reviser") that SKILL.md mode-routing line 20 points to.

The fix is exactly the rewrite R8-001 suggested. Line 134 of the same file now reads
`See `review/index.md` Step 2 and `revise/index.md` Step 2 (Fan-out) for the full templates`,
which is also consistent with the canonical orchestration.

R8-001's optional secondary suggestion (renaming "Fix subagent" usages on lines 22 and 48
for vocabulary consistency) was not adopted, but those usages are mode-agnostic
("Fix subagents across different file clusters are always independent" / "Fix subagents:
≤3 target files per cluster") and do not reintroduce the dual-spec drift. The CR-L11
issue is closed.

## Status

`resolved` — the legacy revise-mode dual-spec terminology in the parallel-dispatch.md
introduction is gone. No same-class regression detected in the round-9 class scan
(see R9-001 for a separate CR-L11 finding in `review/index.md` that is a different
class — stale CR-count ranges, not legacy mode terminology).
