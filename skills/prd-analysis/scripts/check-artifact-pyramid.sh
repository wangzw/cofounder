#!/usr/bin/env bash
# check-artifact-pyramid.sh — CR-S13 (artifact-pyramid)
# Usage: check-artifact-pyramid.sh <target-skill-dir>
# Checks common/templates/artifact-template.md exists and describes a multi-level structure.
# Heuristic: mentions "README.md" + at least one subdir path pattern.
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

template_path = os.path.join(target, "common", "templates", "artifact-template.md")
if not os.path.isfile(template_path):
    issues.append({
        "criterion_id": "CR-S13",
        "file": "common/templates/artifact-template.md",
        "severity": "error",
        "description": "common/templates/artifact-template.md not found",
        "suggested_fix": "Create artifact-template.md describing a multi-level index structure"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(template_path, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S13",
        "file": "common/templates/artifact-template.md",
        "severity": "error",
        "description": f"Cannot read artifact-template.md: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# Heuristic: must mention README.md AND at least one subdir path (word/word.md or word/F-NNN)
has_readme = "README.md" in content
has_subdir = bool(re.search(r'\b\w+/\w', content))

if not has_readme or not has_subdir:
    issues.append({
        "criterion_id": "CR-S13",
        "file": "common/templates/artifact-template.md",
        "severity": "error",
        "description": "artifact-template.md does not appear to describe a multi-level (README + subdirs) structure",
        "suggested_fix": "Ensure template shows README.md as index with subdirectory paths for artifact leaves"
    })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
