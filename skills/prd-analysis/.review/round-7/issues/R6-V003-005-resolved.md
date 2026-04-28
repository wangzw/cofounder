---
id: R6-V003-005
round: 7
file: scripts/prune-traces.sh
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V003-005 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is config.yml key vs script grep cross-reference, not the narrow conflicts_with pair check): prune-traces.sh grepped `retention_rounds:` but config.yml defined `traces_retention_rounds:` — config-file lookup was dead code.

Round-7 verification: prune-traces.sh line 22 now greps `traces_retention_rounds` matching config.yml's actual key (line 67 in common/config.yml: `traces_retention_rounds: 20`). The config-file lookup path is now functional. CR-L11 cross-artifact consistency restored.
