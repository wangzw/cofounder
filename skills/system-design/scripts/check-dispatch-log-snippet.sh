#!/usr/bin/env bash
# check-dispatch-log-snippet.sh — CR-S09 (dispatch-log-snippet)
# Usage: check-dispatch-log-snippet.sh <target-skill-dir>
# Verifies SKILL.md contains the Snippet C fingerprint.
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues, 2=error
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

FINGERPRINT = "<!-- snippet-c-fingerprint: dispatch-log-v1 -->"
skill_md = os.path.join(target, "SKILL.md")

if not os.path.isfile(skill_md):
    issues.append({
        "criterion_id": "CR-S09",
        "file": "SKILL.md",
        "severity": "critical",
        "description": "SKILL.md not found; cannot verify dispatch-log snippet",
        "suggested_fix": "Create SKILL.md with the orchestrator body including Snippet C"
    })
else:
    try:
        content = open(skill_md, encoding="utf-8").read()
        if FINGERPRINT not in content:
            issues.append({
                "criterion_id": "CR-S09",
                "file": "SKILL.md",
                "severity": "critical",
                "description": "Snippet C fingerprint missing from SKILL.md orchestrator body",
                "suggested_fix": f"Add '{FINGERPRINT}' to the orchestrator dispatch section in SKILL.md"
            })
    except OSError as e:
        issues.append({
            "criterion_id": "CR-S09",
            "file": "SKILL.md",
            "severity": "critical",
            "description": f"Cannot read SKILL.md: {e}",
            "suggested_fix": "Ensure SKILL.md is readable"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
