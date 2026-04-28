---
id: R6-V004-002
round: 7
file: common/config.yml
criterion_id: CR-L11
severity: error
source: adversarial-reviewer
reviewer_variant: adversarial
status: resolved
---

# R6-V004-002 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is internal config-yaml key alignment, not the narrow conflicts_with pair check): config.yml `pricing.models` keys diverged from `model_mapping` values, so every cost lookup missed and `--diagnose` pricing column emitted 0 silently.

Round-7 verification: config.yml `model_mapping` (lines 22-25) emits `claude-opus-4-5`/`claude-sonnet-4-5`/`claude-haiku-4-5`; `pricing.models` (lines 30-45) keys are exactly `claude-opus-4-5`/`claude-sonnet-4-5`/`claude-haiku-4-5`. The two now match — pricing lookup will succeed for every dispatched tier. CR-L11 cross-reference consistency restored.
