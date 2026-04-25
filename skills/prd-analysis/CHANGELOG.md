# CHANGELOG

## Delivery 3 — 2026-04-25

- **Verdict**: pending (judge dispatch in progress)
- **Mode**: --review (fresh, .review/ history cleared)
- **Drift detected**: scripts/check-drift.sh + scripts/run-checkers.sh (post-delivery-2 fixes synced from skill-forge)
- **Script-type checks**: 0 issues after restoring versions/{1,2}.md from delivery-2 tag
- **Cross-reviewer**: SKIPPED (user-declined dispatch this session)
- **Carry-forward verified**: round-3's 26 stale CR-S10 phantoms correctly auto-resolved (0 carries in round-4)
- **Dispatches**: 1 summarizer, 1 judge — 0 reviewer dispatches

## Delivery 2 — 2026-04-25

- **Verdict**: pending (judge dispatch in progress)
- **Mode**: --review (script-type) + --revise (R2-R-001 sonnet)
- **Trigger**: defect-injection test — removed snippet-D fingerprint from generate/writer-subagent.md
- **Resolution**: 1 reviser dispatch closed CR-S08; round-3 re-check passed (0 new issues)
- **Carry-forward**: 26 stale CR-S10 false-positives from delivery-1 (underlying script bug fixed in skill-forge commit 8ee3497 — these no longer reproduce; tracked as known-stale).
- **Dispatches**: 1 reviser, 1 summarizer, 1 judge — 0 reviewer dispatches (focused test)

## Delivery 1 — 2026-04-25

- **Verdict**: pending (judge dispatch in progress)
- **Mode**: from-scratch (regeneration from skills/prd-analysis.backup/ baseline as input source for skill-forge end-to-end test)
- **Dispatches**: 1 planner, 15 writers (1 retry on R1-W-008), 1 summarizer, 1 judge — 0 opus dispatches via --no-consultant + reviewer defer
- **Leaves added**: SKILL.md, common/review-criteria.md, common/domain-glossary.md, generate/{domain-consultant,planner,writer}-subagent.md, review/{cross-reviewer,adversarial-reviewer}-subagent.md, revise/per-issue-reviser-subagent.md, shared/{summarizer,judge}-subagent.md, common/templates/{feature,journey,architecture,prd-readme}-template.md
- **Writer outcomes**: 15 FULL_PASS / 0 PARTIAL, fail_count: 0
- **Script-type checks**: 29 CR-S10 false-positives (placeholder syntax in IPC contract documentation, expected baseline pattern)
- **Cost optimizations active**: Tier-1.1 (per-role model override), Tier-2.4 (selective input compression — 83.5KB backup), Tier-3 (--no-consultant)
- **Notes**: Meta-skill generation from skill-forge baseline; LLM-type review (cross-reviewer, adversarial-reviewer) deferred per round-1 scope (scaffold-covered and writer self-reviews sufficient for META-target).
