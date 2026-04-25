#!/usr/bin/env bash
# check-skill-structure.sh — CR-S03 (directory-skeleton) + CR-S04 (subagent-file-inventory)
# Usage: check-skill-structure.sh <target-skill-dir>
# Output contract §12.4: stdout=JSON array of issues; exit 0=pass, 1=issues, 2=error
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

python3 - "$TARGET" <<'PYEOF'
import sys, json, os

target = sys.argv[1]
issues = []

# CR-S03: required directories
REQUIRED_DIRS = ["generate", "review", "revise", "shared", "common", "scripts"]
for d in REQUIRED_DIRS:
    if not os.path.isdir(os.path.join(target, d)):
        issues.append({
            "criterion_id": "CR-S03",
            "file": d + "/",
            "severity": "critical",
            "description": f"Required directory '{d}/' is missing from skill root",
            "suggested_fix": f"Create the '{d}/' directory at the skill root"
        })

# CR-S04: required sub-agent files (7 standalone; orchestrator is inline in SKILL.md)
REQUIRED_SUBAGENTS = [
    "generate/domain-consultant-subagent.md",
    "generate/planner-subagent.md",
    "generate/writer-subagent.md",
    "review/cross-reviewer-subagent.md",
    "review/adversarial-reviewer-subagent.md",
    "revise/per-issue-reviser-subagent.md",
    "shared/summarizer-subagent.md",
    "shared/judge-subagent.md",
]
for f in REQUIRED_SUBAGENTS:
    if not os.path.isfile(os.path.join(target, f)):
        issues.append({
            "criterion_id": "CR-S04",
            "file": f,
            "severity": "critical",
            "description": f"Required sub-agent prompt '{f}' is missing",
            "suggested_fix": f"Create '{f}' with the sub-agent prompt content"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
