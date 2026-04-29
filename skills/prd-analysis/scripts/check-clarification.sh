#!/usr/bin/env bash
# check-clarification.sh — formal review of .review/round-0/clarification/<ts>.yml
#
# Produced by domain-consultant subagent. Required keys (documented in
# generate/domain-consultant-subagent.md):
#   SKILL_NAME, SKILL_VERSION, SKILL_DESCRIPTION, ARTIFACT_ROOT — flat keys
#                                                                MUST appear
#                                                                first (before
#                                                                any nested
#                                                                block) so a
#                                                                line-scanner
#                                                                can read them
#                                                                without YAML
#   clarification_at — ISO timestamp
#   normalized_requirements: R-001..R-007 (nested)
#
# Implements:
#   CR-CL01  clarification-required-keys-present
#   CR-CL02  clarification-flat-keys-first
#
# Usage: check-clarification.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-clarification.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, read_text, emit

findings: list[Finding] = []

clar_dir = os.path.join(prd_root, ".review", "round-0", "clarification")
if not os.path.isdir(clar_dir):
    emit([], scope_label="(no clarification/ — round-0 may have skipped consultant)")

required_flat = ("SKILL_NAME", "SKILL_VERSION", "SKILL_DESCRIPTION", "ARTIFACT_ROOT")
required_nested_keys = tuple(f"R-00{i}" for i in range(1, 8))

count = 0
for fname in sorted(os.listdir(clar_dir)):
    if not fname.endswith(".yml"):
        continue
    count += 1
    rel = f".review/round-0/clarification/{fname}"
    full = os.path.join(clar_dir, fname)
    text = read_text(full)
    if text is None:
        findings.append(Finding(
            criterion_id="CR-CL01", file=rel, severity="error",
            description="cannot read clarification file",
            suggested_fix="ensure the file is readable",
        ))
        continue

    lines = text.splitlines()

    # CR-CL02: required_flat keys MUST appear at top before any indented block
    saw_flat: set[str] = set()
    bad_position: list[str] = []
    encountered_indented = False
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith((" ", "\t")):
            encountered_indented = True
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
        if not m:
            continue
        key = m.group(1)
        if key in required_flat:
            if encountered_indented:
                bad_position.append(key)
            saw_flat.add(key)

    missing_flat = [k for k in required_flat if k not in saw_flat]
    if missing_flat:
        findings.append(Finding(
            criterion_id="CR-CL01", file=rel, severity="error",
            description=f"missing required flat key(s): {', '.join(missing_flat)}",
            suggested_fix=(
                "add the missing flat keys at the top of the file, before any "
                "nested block"
            ),
        ))
    if bad_position:
        findings.append(Finding(
            criterion_id="CR-CL02", file=rel, severity="error",
            description=(
                f"flat keys appearing AFTER an indented block (they MUST come "
                f"first): {', '.join(bad_position)}"
            ),
            suggested_fix=(
                "move the flat keys to the top of the file before any "
                "nested block (line-scanner contract)"
            ),
        ))

    # CR-CL01: every R-001..R-007 must appear somewhere
    missing_R = [k for k in required_nested_keys if not re.search(rf"^\s+{k}\s*:", text, re.M)]
    if missing_R:
        findings.append(Finding(
            criterion_id="CR-CL01", file=rel, severity="error",
            description=(
                f"normalized_requirements missing key(s): {', '.join(missing_R)}"
            ),
            suggested_fix=(
                "add the missing R-NNN entries (each MUST have status: confirmed | deferred)"
            ),
        ))

emit(findings, scope_label=f"({count} clarification file(s))")
PYEOF
