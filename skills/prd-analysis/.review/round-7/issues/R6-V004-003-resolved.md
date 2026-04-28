---
id: R6-V004-003
round: 7
file: revise/index.md
criterion_id: CR-L01
severity: critical
source: adversarial-reviewer
reviewer_variant: adversarial
status: resolved
---

# R6-V004-003 — RESOLVED

Original round-6 issue: revise/index.md Step 1-2 had the orchestrator reading issue files and grouping them by `file` field — semantic work that violated pure-dispatch (§5.1).

Round-7 verification: revise/index.md Step 1 (lines 11-47) now delegates to `bash scripts/group-revise-issues.sh <target> <N>`, which the orchestrator invokes WITHOUT inspecting issue file contents. The script reads frontmatter only, filters open statuses, skips skeleton-owned paths, and emits `revise-plan.yml` consumed verbatim. Lines 95-97 explicitly state: "The orchestrator MUST NOT evaluate issue status, group issues, or decide fan-out shape — all of this is delegated to scripts/group-revise-issues.sh". CR-L01 orchestrator-pure-dispatch now satisfied within revise/index.md.

(NOTE: a separate NEW issue is filed against revise/index.md under R7-V001-001 because the script `scripts/group-revise-issues.sh` it references does not actually exist on disk — that is a CR-L11 cross-reference issue, distinct from the CR-L01 pure-dispatch concern resolved here.)
