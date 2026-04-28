#!/usr/bin/env bash
# check-scripts-inventory.sh — CR-S05 (scripts-inventory)
# Usage: check-scripts-inventory.sh <target-skill-dir>
# Verifies all required scripts exist and are executable in <target>/scripts/.
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues, 2=error
#
# Required scripts come from TWO sources, unioned:
#  1. INFRA_SCRIPTS — hardcoded skill-forge infrastructure (no CR binding).
#  2. CR-bound scripts — auto-derived by parsing every `script_path:` value
#     from <target>/common/review-criteria.md. This makes new CR additions
#     (e.g. CR-S15's check-skill-md-sections.sh) propagate to the inventory
#     check without a manual REQUIRED_SCRIPTS sync.
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

# Infrastructure scripts not declared by any CR (skill-forge runtime plumbing).
# These MUST be present in every generated skill; no review-criteria.md entry
# binds them, so they cannot be auto-derived.
INFRA_SCRIPTS = [
    "git-precheck.sh",
    "prepare-input.sh",
    "glossary-probe.sh",
    "run-checkers.sh",
    "build-depgraph.sh",
    "commit-delivery.sh",
    "prune-traces.sh",
    "extract-criteria.sh",
    "metrics-aggregate.sh",
    # CR-bound but listed here too for completeness — review-criteria.md may
    # not declare an `script_path:` for the inventory checker itself in some
    # variants, but the inventory checker is unconditionally required.
    "check-scripts-inventory.sh",
    # Cross-reviewer consistency checks invoked by run-checkers.sh; not bound
    # to a single CR but mandatory infrastructure.
    "check-criteria-consistency.sh",
    "check-index-consistency.sh",
    "check-changelog-consistency.sh",
]

# Auto-derive CR-bound scripts from review-criteria.md `script_path:` values.
# Pattern: a YAML line of the form `  script_path: scripts/<name>.sh` inside a
# fenced code block. We do a simple line-grep — robust to either YAML block
# style — and strip the `scripts/` prefix to match basename storage in
# INFRA_SCRIPTS. Duplicate paths (same checker bound to multiple CRs) collapse
# via set semantics.
cr_bound = set()
criteria_path = os.path.join(target, "common", "review-criteria.md")
if os.path.isfile(criteria_path):
    with open(criteria_path, "r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^\s*script_path:\s*scripts/(\S+\.sh)\s*$", line)
            if m:
                cr_bound.add(m.group(1))
# If review-criteria.md is missing, only INFRA_SCRIPTS are checked. The
# missing-criteria condition is a separate CR (CR-S07) and reported there;
# this script does not double-report.

required = sorted(set(INFRA_SCRIPTS) | cr_bound)

scripts_dir = os.path.join(target, "scripts")
for script in required:
    fpath = os.path.join(scripts_dir, script)
    if not os.path.isfile(fpath):
        issues.append({
            "criterion_id": "CR-S05",
            "file": f"scripts/{script}",
            "severity": "critical",
            "description": f"Required script '{script}' not found in scripts/",
            "suggested_fix": f"Create scripts/{script} per guide §7.1",
        })
    elif not os.access(fpath, os.X_OK):
        issues.append({
            "criterion_id": "CR-S05",
            "file": f"scripts/{script}",
            "severity": "critical",
            "description": f"Script '{script}' exists but is not executable",
            "suggested_fix": f"Run: chmod +x scripts/{script}",
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
