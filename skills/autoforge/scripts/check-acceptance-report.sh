#!/usr/bin/env bash
# check-acceptance-report.sh — verify the acceptance report conforms to
# acceptance/report-template.md.
#
#   CR-AF05  required-sections-present
#   CR-AF06  verdict-set (Verdict body contains PASS / PARTIAL / FAIL)
#
# Usage: check-acceptance-report.sh <report-file>

set -euo pipefail

REPORT="${1:-}"
if [ -z "$REPORT" ] || [ ! -f "$REPORT" ]; then
  echo "ERROR: report file not found: ${REPORT:-<empty>}" >&2
  echo "Usage: check-acceptance-report.sh <report-file>" >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$REPORT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys
report = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from autoforge_lint import (
    Finding, read_text, heading_set, emit, fail_with_script_error,
)

text = read_text(report)
if text is None:
    fail_with_script_error(f"cannot read {report}")

REQUIRED = {
    "Summary", "Input", "Feature Acceptance", "Journey E2E Scenarios",
    "Requirements Traceability Matrix", "E2E Traceability Matrix",
    "Negative-Path Coverage",
    "Failed Items", "Not Covered Items", "Outstanding Debt",
    "Orphan Tests", "Unmapped Acceptance Criteria",
    "Naming-vs-Content Mismatches", "Verdict",
}
findings: list[Finding] = []
rel = os.path.basename(report)
present = heading_set(text, level=2)
for s in sorted(REQUIRED - present):
    findings.append(Finding(
        criterion_id="CR-AF05",
        file=rel,
        severity="error",
        description=f"missing required `## {s}` section",
        suggested_fix=f"add a `## {s}` section per acceptance/report-template.md",
    ))

# CR-AF06: verdict body contains a verdict value.
if "Verdict" in present:
    capture = False
    body: list[str] = []
    for line in text.splitlines():
        if line.startswith("## Verdict"):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            body.append(line)
    body_text = "\n".join(body)
    if not re.search(r"\b(PASS|PARTIAL|FAIL)\b", body_text):
        findings.append(Finding(
            criterion_id="CR-AF06",
            file=rel,
            severity="error",
            description="Verdict section does not state PASS / PARTIAL / FAIL",
            suggested_fix="state the verdict explicitly in the Verdict section "
                          "(bold first line: **PASS** / **PARTIAL** / **FAIL**)",
        ))

emit(findings, scope_label=f"({rel})")
PYEOF
