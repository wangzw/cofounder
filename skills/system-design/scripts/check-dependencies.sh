#!/usr/bin/env bash
# check-dependencies.sh — CR-S14 (git-precheck-dependencies)
# Usage: check-dependencies.sh <target-skill-dir>
# Verifies scripts/git-precheck.sh contains all three required dependency checks.
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
import sys, json, os, re

target = sys.argv[1]
issues = []

precheck_path = os.path.join(target, "scripts", "git-precheck.sh")
if not os.path.isfile(precheck_path):
    issues.append({
        "criterion_id": "CR-S14",
        "file": "scripts/git-precheck.sh",
        "severity": "error",
        "description": "scripts/git-precheck.sh not found",
        "suggested_fix": "Create scripts/git-precheck.sh with git/bash/python3 version checks"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(precheck_path, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S14",
        "file": "scripts/git-precheck.sh",
        "severity": "error",
        "description": f"Cannot read git-precheck.sh: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# Three required checks per guide §21.0
CHECKS = [
    ("command -v git", r'command\s+-v\s+git', "git presence check (command -v git)"),
    ("BASH_VERSINFO", r'BASH_VERSINFO', "bash ≥ 4.0 check (BASH_VERSINFO)"),
    ("python3 version", r"python3\s+-c\s+['\"]import sys", "python3 ≥ 3.8 check (python3 -c 'import sys')"),
]
for name, pattern, desc in CHECKS:
    if not re.search(pattern, content):
        issues.append({
            "criterion_id": "CR-S14",
            "file": "scripts/git-precheck.sh",
            "severity": "error",
            "description": f"Missing {desc} in git-precheck.sh",
            "suggested_fix": f"Add {name} dependency check per guide §21.0"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
