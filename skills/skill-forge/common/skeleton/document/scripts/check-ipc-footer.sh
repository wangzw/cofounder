#!/usr/bin/env bash
# check-ipc-footer.sh — CR-S08 (ipc-footer-present)
# Usage: check-ipc-footer.sh <target-skill-dir>
# Verifies all 8 sub-agent prompt files contain the Snippet D fingerprint.
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

FINGERPRINT = "<!-- snippet-d-fingerprint: ipc-ack-v1 -->"
SUBAGENTS = [
    "generate/domain-consultant-subagent.md",
    "generate/planner-subagent.md",
    "generate/writer-subagent.md",
    "review/cross-reviewer-subagent.md",
    "review/adversarial-reviewer-subagent.md",
    "revise/per-issue-reviser-subagent.md",
    "shared/summarizer-subagent.md",
    "shared/judge-subagent.md",
]

for f in SUBAGENTS:
    fpath = os.path.join(target, f)
    if not os.path.isfile(fpath):
        issues.append({
            "criterion_id": "CR-S08",
            "file": f,
            "severity": "critical",
            "description": f"Sub-agent file '{f}' not found; cannot verify IPC footer",
            "suggested_fix": "Create the sub-agent prompt file with Snippet D footer"
        })
        continue
    try:
        content = open(fpath, encoding="utf-8").read()
    except OSError as e:
        issues.append({
            "criterion_id": "CR-S08",
            "file": f,
            "severity": "critical",
            "description": f"Cannot read '{f}': {e}",
            "suggested_fix": "Ensure file is readable"
        })
        continue
    if FINGERPRINT not in content:
        issues.append({
            "criterion_id": "CR-S08",
            "file": f,
            "severity": "critical",
            "description": f"Snippet D fingerprint missing from '{f}'",
            "suggested_fix": f"Add '{FINGERPRINT}' to the sub-agent prompt"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
