#!/usr/bin/env bash
# check-plan.sh — formal review of .review/round-<N>/plan.md
#
# Produced by planner subagent. Required YAML block fields (documented in
# generate/planner-subagent.md):
#   mode (from-scratch | new-version)
#   delivery_id (integer)
#   round (integer)
#   plan: { add: [...], modify: [...], delete: [...], keep: [...] }
#   rationale (non-empty prose)
#
# Each entry in `add` and `modify` MUST have: path, template, description.
#
# Implements:
#   CR-PL01  plan-required-fields
#   CR-PL02  plan-add-modify-entry-shape
#
# Usage: check-plan.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-plan.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from sd_lint import Finding, read_text, emit, find_round_dirs

findings: list[Finding] = []

plan_files: list[tuple[str, str]] = []  # (rel, full)
for _, round_dir in find_round_dirs(prd_root):
    plan_path = os.path.join(round_dir, "plan.md")
    if os.path.isfile(plan_path):
        plan_files.append((os.path.relpath(plan_path, prd_root), plan_path))

if not plan_files:
    emit([], scope_label="(no plan.md files)")

required_top = ("mode", "delivery_id", "round", "plan", "rationale")
valid_modes = ("from-scratch", "new-version")

for rel, full in plan_files:
    text = read_text(full)
    if text is None:
        continue

    # Extract YAML block (between ```yaml and ```)
    yaml_match = re.search(r"```yaml\n(.*?)\n```", text, re.S)
    if not yaml_match:
        findings.append(Finding(
            criterion_id="CR-PL01", file=rel, severity="error",
            description="plan.md missing fenced ```yaml ... ``` block",
            suggested_fix=(
                "wrap the plan body in a fenced ```yaml code block per the "
                "planner-subagent.md schema"
            ),
        ))
        continue
    yaml_body = yaml_match.group(1)

    # Required top-level keys (line starts at column 0 with key:)
    for key in required_top:
        if not re.search(rf"^{key}\s*:", yaml_body, re.M):
            findings.append(Finding(
                criterion_id="CR-PL01", file=rel, severity="error",
                description=f"plan YAML missing required top-level key: {key!r}",
                suggested_fix=f"add '{key}: <value>' at the top level of the YAML block",
            ))

    # mode value validation
    m_mode = re.search(r"^mode\s*:\s*(\S+)", yaml_body, re.M)
    if m_mode and m_mode.group(1) not in valid_modes:
        findings.append(Finding(
            criterion_id="CR-PL01", file=rel, severity="error",
            description=f"mode value {m_mode.group(1)!r} not in {valid_modes}",
            suggested_fix="set mode to 'from-scratch' or 'new-version'",
        ))

    # delivery_id and round must be integers
    for numeric_key in ("delivery_id", "round"):
        m = re.search(rf"^{numeric_key}\s*:\s*(\S+)", yaml_body, re.M)
        if m and not m.group(1).isdigit():
            findings.append(Finding(
                criterion_id="CR-PL01", file=rel, severity="error",
                description=f"{numeric_key} must be an integer (got {m.group(1)!r})",
                suggested_fix=f"set {numeric_key} to a non-negative integer",
            ))

    # plan.add and plan.modify entries — each must have path/template/description
    # Match each top-level item under plan.add or plan.modify (heuristic — line
    # starting with two-space indent + dash, then nested fields with four-space indent)
    for section in ("add", "modify"):
        section_match = re.search(
            rf"^  {section}\s*:\s*\n((?:    [-\s].*\n?)*)",
            yaml_body,
            re.M,
        )
        if not section_match:
            continue
        # Split into entries (each starts with `    - `)
        entries_text = section_match.group(1)
        entries = re.split(r"^    - ", entries_text, flags=re.M)[1:]
        for idx, entry in enumerate(entries, 1):
            for required in ("path", "template", "description"):
                if not re.search(rf"^\s+{required}\s*:", entry, re.M) and \
                   not entry.startswith(f"{required}:"):
                    # Also check if it appears on the same `- ` line
                    if not re.match(rf"\s*{required}\s*:", entry):
                        findings.append(Finding(
                            criterion_id="CR-PL02", file=rel, severity="error",
                            description=(
                                f"plan.{section} entry #{idx} missing field {required!r}"
                            ),
                            suggested_fix=(
                                f"add '{required}: <value>' to the entry "
                                f"(see planner-subagent.md schema)"
                            ),
                        ))

emit(findings, scope_label=f"({len(plan_files)} plan.md file(s))")
PYEOF
