#!/usr/bin/env bash
# check-plan-readme.sh — verify a plan-dir README.md conforms to
# planning/plan-readme-template.md.
#
#   CR-AF15  required-sections-present
#   CR-AF16  module-status-rows-match-plans (every plan-M-NNN-*.md in
#            plans/ has a row in Module Status, and vice versa)
#
# Usage: check-plan-readme.sh <plan-dir>

set -euo pipefail

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan dir not found: ${PLAN_DIR:-<empty>}" >&2
  echo "Usage: check-plan-readme.sh <plan-dir>" >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PLAN_DIR" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys
plan_dir = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from autoforge_lint import (
    Finding, read_text, list_dir, heading_set, emit, fail_with_script_error,
    MODULE_PLAN_FILE_RE,
)

readme = os.path.join(plan_dir, "README.md")
text = read_text(readme)
if text is None:
    fail_with_script_error(f"README.md missing under {plan_dir}")

REQUIRED = {
    "Design Input", "Dependency Graph", "Phase Breakdown",
    "Module Plans", "Module Status", "Phase Status",
    "Acceptance", "Reports",
}
findings: list[Finding] = []
present = heading_set(text, level=2)
for s in sorted(REQUIRED - present):
    findings.append(Finding(
        criterion_id="CR-AF15",
        file="README.md",
        severity="error",
        description=f"missing required `## {s}` section",
        suggested_fix=f"add a `## {s}` section per planning/plan-readme-template.md",
    ))

# CR-AF16 — module-status rows match the plan files actually present.
plans_dir = os.path.join(plan_dir, "plans")
plan_module_ids: set[str] = set()
if os.path.isdir(plans_dir):
    for f in list_dir(plan_dir, "plans"):
        m = MODULE_PLAN_FILE_RE.match(f)
        if m:
            plan_module_ids.add(f"M-{int(m.group(1)):03d}")

# Extract M-NNN ids referenced in the Module Status section.
status_ids: set[str] = set()
if "Module Status" in present:
    capture = False
    for line in text.splitlines():
        if line.startswith("## Module Status"):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            for m in re.finditer(r"\bM-(\d{3,})\b", line):
                status_ids.add(f"M-{int(m.group(1)):03d}")

for missing in sorted(plan_module_ids - status_ids):
    findings.append(Finding(
        criterion_id="CR-AF16",
        file="README.md",
        severity="error",
        description=f"plan exists for {missing} but no row in Module Status",
        suggested_fix=f"add a row for {missing} to the Module Status table",
    ))
for extra in sorted(status_ids - plan_module_ids):
    findings.append(Finding(
        criterion_id="CR-AF16",
        file="README.md",
        severity="error",
        description=f"Module Status references {extra} but no plan file exists",
        suggested_fix=f"add plans/plan-{extra}-<slug>.md or remove the row",
    ))

emit(findings, scope_label=f"({plan_dir})")
PYEOF
