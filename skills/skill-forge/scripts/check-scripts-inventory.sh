#!/usr/bin/env bash
# check-scripts-inventory.sh — CR-S05 (scripts-inventory)
# Usage: check-scripts-inventory.sh <target-skill-dir>
# Verifies all required scripts exist and are executable in <target>/scripts/.
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

REQUIRED_SCRIPTS = [
    "git-precheck.sh",
    "prepare-input.sh",
    "glossary-probe.sh",
    "run-checkers.sh",
    "check-frontmatter.sh",
    "check-mode-routing.sh",
    "check-skill-structure.sh",
    "check-scripts-inventory.sh",
    "check-config-schema.sh",
    "check-criteria-yaml.sh",
    "check-ipc-footer.sh",
    "check-dispatch-log-snippet.sh",
    "check-trace-id-format.sh",
    "check-scaffold-sha.sh",
    "check-artifact-pyramid.sh",
    "check-dependencies.sh",
    "check-criteria-consistency.sh",
    "check-index-consistency.sh",
    "check-changelog-consistency.sh",
    "build-depgraph.sh",
    "commit-delivery.sh",
    "prune-traces.sh",
    "extract-criteria.sh",
    "metrics-aggregate.sh",
]

scripts_dir = os.path.join(target, "scripts")
for script in REQUIRED_SCRIPTS:
    fpath = os.path.join(scripts_dir, script)
    if not os.path.isfile(fpath):
        issues.append({
            "criterion_id": "CR-S05",
            "file": f"scripts/{script}",
            "severity": "critical",
            "description": f"Required script '{script}' not found in scripts/",
            "suggested_fix": f"Create scripts/{script} per guide §7.1"
        })
    elif not os.access(fpath, os.X_OK):
        issues.append({
            "criterion_id": "CR-S05",
            "file": f"scripts/{script}",
            "severity": "critical",
            "description": f"Script '{script}' exists but is not executable",
            "suggested_fix": f"Run: chmod +x scripts/{script}"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
