---
id: R6-V003-003
round: 7
file: scripts/check-scripts-inventory.sh
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V003-003 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is review-criteria.md script_path declaration vs inventory checker — broader cross-reference consistency than the narrow conflicts_with pair check): check-scripts-inventory.sh REQUIRED_SCRIPTS list omitted `check-skill-md-sections.sh` (CR-S15 checker).

Round-7 verification: script now AUTO-DERIVES CR-bound scripts from `<target>/common/review-criteria.md` `script_path:` values (lines 53-67) using a regex `^\s*script_path:\s*scripts/(\S+\.sh)\s*$`. Any newly-declared script_path automatically propagates to the inventory check; explicit hard-coded list is collapsed to genuine infrastructure-only scripts (INFRA_SCRIPTS, lines 33-52) plus auto-derived (cr_bound). check-skill-md-sections.sh is now picked up via CR-S15's declaration. CR-L11 cross-artifact consistency restored.
