#!/usr/bin/env bash
# check-reviewer-output.sh — formal review of
# .review/round-<N>/reviewer-output/<trace_id>.json
#
# Produced by cross-reviewer / adversarial-reviewer subagents. JSON schema
# documented in common/issue-schema.md (LLM raw-output schema).
#
# Implements:
#   CR-RO01  reviewer-output-json-valid
#   CR-RO02  reviewer-output-issue-fields    — each issue carries the 5
#                                              required fields
#
# Usage: check-reviewer-output.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-reviewer-output.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, json, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, emit, find_round_dirs

findings: list[Finding] = []
VALID_SEV = {"critical", "error", "warning", "info"}
REQUIRED = ("criterion_id", "file", "severity", "description", "suggested_fix")
VALID_VARIANTS = {"cross", "adversarial"}

files: list[tuple[str, str]] = []
for _, round_dir in find_round_dirs(prd_root):
    ro_dir = os.path.join(round_dir, "reviewer-output")
    if not os.path.isdir(ro_dir):
        continue
    for fname in sorted(os.listdir(ro_dir)):
        if fname.endswith(".json"):
            full = os.path.join(ro_dir, fname)
            files.append((os.path.relpath(full, prd_root), full))

if not files:
    emit([], scope_label="(no reviewer-output files)")

for rel, full in files:
    try:
        with open(full, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        findings.append(Finding(
            criterion_id="CR-RO01", file=rel, severity="error",
            description=f"cannot read reviewer output: {e}",
            suggested_fix="ensure the file is readable",
        ))
        continue

    try:
        doc = json.loads(text)
    except json.JSONDecodeError as e:
        findings.append(Finding(
            criterion_id="CR-RO01", file=rel, severity="error",
            description=f"invalid JSON: {e}",
            suggested_fix="fix the JSON syntax (valid JSON document required)",
        ))
        continue

    if not isinstance(doc, dict):
        findings.append(Finding(
            criterion_id="CR-RO01", file=rel, severity="error",
            description="root must be a JSON object, not array/scalar",
            suggested_fix='wrap content in {"round": N, "issues": [...]}',
        ))
        continue

    # round / reviewer_variant / trace_id are nice-to-have but not strict
    rv = doc.get("reviewer_variant")
    if rv is not None and rv not in VALID_VARIANTS:
        findings.append(Finding(
            criterion_id="CR-RO01", file=rel, severity="error",
            description=f"reviewer_variant {rv!r} not in {sorted(VALID_VARIANTS)}",
            suggested_fix="set reviewer_variant to 'cross' or 'adversarial'",
        ))

    issues = doc.get("issues", [])
    if not isinstance(issues, list):
        findings.append(Finding(
            criterion_id="CR-RO01", file=rel, severity="error",
            description="'issues' must be a list",
            suggested_fix="set 'issues' to a list of issue objects",
        ))
        continue

    for idx, it in enumerate(issues):
        if not isinstance(it, dict):
            findings.append(Finding(
                criterion_id="CR-RO02", file=rel, severity="error",
                description=f"issues[{idx}] is not an object",
                suggested_fix="each issue must be a JSON object",
            ))
            continue
        for f in REQUIRED:
            v = it.get(f, "")
            if v is None or (isinstance(v, str) and not v.strip() and f != "file"):
                findings.append(Finding(
                    criterion_id="CR-RO02", file=rel, severity="error",
                    description=f"issues[{idx}] required field empty/missing: {f!r}",
                    suggested_fix=f"set {f!r} to a non-empty value",
                ))
        if it.get("severity") and it["severity"] not in VALID_SEV:
            findings.append(Finding(
                criterion_id="CR-RO02", file=rel, severity="error",
                description=(
                    f"issues[{idx}].severity {it['severity']!r} not in {sorted(VALID_SEV)}"
                ),
                suggested_fix=f"set severity to one of {sorted(VALID_SEV)}",
            ))
        desc = it.get("description", "")
        if isinstance(desc, str) and 0 < len(desc.strip()) < 5:
            findings.append(Finding(
                criterion_id="CR-RO02", file=rel, severity="error",
                description=f"issues[{idx}].description shorter than 5 chars",
                suggested_fix="write a description of at least 5 chars",
            ))

emit(findings, scope_label=f"({len(files)} reviewer-output file(s))")
PYEOF
