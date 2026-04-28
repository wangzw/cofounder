---
id: R6-V003-001
round: 7
file: scripts/scaffold.sh
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
---

# R6-V003-001 — RESOLVED

Original round-6 issue (originally tagged CR-L04, re-tagged CR-L11 since this is broader cross-reference consistency, not the narrow conflicts_with check): scaffold.sh `--help` documentation had placeholder anchors over-substituted into literal target values.

Round-7 verification: scaffold.sh `usage()` now uses HEREDOC with `<<'EOF'` (single-quoted EOF prevents shell expansion), so placeholders like `{{SKILL_NAME}}`, `{{ARTIFACT_ROOT}}`, `{{SKILL_VERSION}}`, `{{SKILL_DESCRIPTION}}` appear verbatim in `--help` output. The script is now generic / tool-agnostic (line 32: "the generator is whatever meta-skill invokes this script"). CR-L11 cross-reference consistency restored — placeholder syntax in docs matches placeholder syntax expected by skeleton files.
