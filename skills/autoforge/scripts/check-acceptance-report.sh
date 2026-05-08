#!/usr/bin/env bash
# check-acceptance-report.sh — verify the acceptance report conforms to
# acceptance/report-template.md.
#
#   CR-AF05  required-sections-present
#   CR-AF06  verdict-set (Verdict body contains PASS / PARTIAL / FAIL)
#   CR-AF24  acceptance-tester-sentinel-present (delivery-1/2 retro: the
#            Orchestrator must NOT hand-write acceptance.md; the file must
#            be produced by the Acceptance Tester subagent and carry the
#            sentinel `<!-- generated-by: acceptance-tester-subagent;
#            version: N -->` as its first non-blank line)
#   CR-AF25  e2e-run-block-present (the `## E2E Test Run` section must
#            list a Command line and an Exit Code, OR explicitly say
#            `n/a` with justification)
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
    "E2E Test Run", "Negative-Path Coverage",
    "Failed Items", "Not Covered Items", "Outstanding Debt",
    "Orphan Tests", "Unmapped Acceptance Criteria",
    "Naming-vs-Content Mismatches", "Verdict",
}
findings: list[Finding] = []
rel = os.path.basename(report)

# CR-AF24 — sentinel must be the first non-blank, non-whitespace line.
SENTINEL_RE = re.compile(
    r"^<!--\s*generated-by:\s*acceptance-tester-subagent\b.*?-->",
    re.IGNORECASE,
)
first_meaningful = ""
for raw in text.splitlines():
    line = raw.rstrip()
    if line.strip() == "":
        continue
    first_meaningful = line
    break
if not SENTINEL_RE.search(first_meaningful):
    findings.append(Finding(
        criterion_id="CR-AF24",
        file=rel,
        severity="critical",
        description=(
            "acceptance.md missing acceptance-tester-subagent sentinel as the "
            "first non-blank line"
        ),
        suggested_fix=(
            "respawn the Acceptance Tester subagent (autoforge SKILL.md Step 3 "
            "/ E6) so it (re)writes acceptance.md from scratch — the report "
            "MUST start with the sentinel `<!-- generated-by: "
            "acceptance-tester-subagent; version: 1 -->`. The Orchestrator is "
            "structurally forbidden from hand-writing this file (delivery-1/2 "
            "retro: writer = verdict caused soft-pass acceptance reports)."
        ),
    ))

present = heading_set(text, level=2)
for s in sorted(REQUIRED - present):
    findings.append(Finding(
        criterion_id="CR-AF05",
        file=rel,
        severity="error",
        description=f"missing required `## {s}` section",
        suggested_fix=f"add a `## {s}` section per acceptance/report-template.md",
    ))

# CR-AF25: E2E Test Run section must contain a Command line and an Exit
# Code line (or explicit `n/a` with a justification — substring "n/a"
# matches both `n/a` and `N/A`).
if "E2E Test Run" in present:
    capture = False
    e2e_body: list[str] = []
    for line in text.splitlines():
        if line.startswith("## E2E Test Run"):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            e2e_body.append(line)
    e2e_text = "\n".join(e2e_body)
    has_command = bool(re.search(r"\|\s*Command\s*\|", e2e_text, re.IGNORECASE))
    has_exit_code = bool(re.search(r"\|\s*Exit\s*Code\s*\|", e2e_text, re.IGNORECASE))
    has_na_marker = "n/a" in e2e_text.lower()
    if not (has_command and has_exit_code) and not has_na_marker:
        findings.append(Finding(
            criterion_id="CR-AF25",
            file=rel,
            severity="critical",
            description=(
                "E2E Test Run section is present but missing the mandatory "
                "Command and Exit Code rows (and is not marked `n/a` with "
                "justification)"
            ),
            suggested_fix=(
                "fill in the E2E Test Run table per acceptance/report-template.md: "
                "the Command, Working Dir, Exit Code, and Specs Passed/Failed "
                "rows MUST reflect the actual e2e command invocation. If the "
                "project has no e2e surface, set Command to "
                "`n/a — project has no E2E layer (justification: …)`."
            ),
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
