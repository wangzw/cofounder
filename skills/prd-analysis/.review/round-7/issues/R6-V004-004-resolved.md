---
id: R6-V004-004
round: 7
file: review-mode.md
criterion_id: CR-L11
severity: critical
source: adversarial-reviewer
reviewer_variant: adversarial
status: resolved
---

# R6-V004-004 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is dual-spec drift cross-reference, the canonical CR-L11 example pattern from review-criteria.md): two conflicting review specs at top-level `review-mode.md` (legacy) vs `review/index.md` (canonical generative-skill) describing different orchestration models.

Round-7 verification: top-level `review-mode.md` no longer exists at the skill root (CR-S16 stray-file fix moved/removed it). SKILL.md mode-routing for `--review` now points exclusively to `review/index.md` (line 19). The skill ships a single canonical review orchestration spec. CR-L11 cross-reference consistency restored.

(NOTE: an analogous problem still exists for revise — a NEW R7-V001-002 issue is filed against SKILL.md / revise-mode.md for the same dual-spec drift pattern in revise mode.)
