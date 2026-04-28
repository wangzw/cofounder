---
id: R6-V003-002
round: 7
file: scripts/git-precheck.sh
criterion_id: CR-L11
severity: critical
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V003-002 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is contract-vs-implementation cross-reference, not the narrow conflicts_with pair check): git-precheck.sh used `git -c user.name=this skill` with an unquoted multi-word value, breaking the bootstrap commit.

Round-7 verification: line 28 now uses `git -c user.name=skill-bootstrap -c user.email=skill-bootstrap@local commit --allow-empty -m "init: skill bootstrap"` — single-token name and email, no word-splitting. The header comment "§8.3: ensure a git repo exists. Use --allow-empty so we do NOT stage cwd contents" matches actual implementation. Bootstrap commit now succeeds. CR-L11 contract-vs-implementation consistency restored.
