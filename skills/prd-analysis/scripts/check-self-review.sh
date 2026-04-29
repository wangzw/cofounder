#!/usr/bin/env bash
# check-self-review.sh — formal review of .review/round-<N>/self-reviews/<trace_id>.md
#
# Produced by writer subagent. Required structure (per writer-subagent.md):
#   - "## Checklist" section with at least one PASS or FAIL row
#   - "## Summary" section containing FULL_PASS / fail_count
#   - PARTIAL status MUST come with at least one FAIL row
#   - FAIL rows MUST carry blocker_scope from the 4-value taxonomy
#
# Implements:
#   CR-SR01  self-review-required-sections
#   CR-SR02  self-review-fail-blocker-scope
#   CR-SR03  self-review-status-fail-consistency
#
# Usage: check-self-review.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-self-review.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, read_text, emit, find_round_dirs

findings: list[Finding] = []
VALID_BLOCKER_SCOPES = (
    "global-conflict", "cross-artifact-dep", "needs-human-decision", "input-ambiguity"
)

files: list[tuple[str, str]] = []
for _, round_dir in find_round_dirs(prd_root):
    sr_dir = os.path.join(round_dir, "self-reviews")
    if not os.path.isdir(sr_dir):
        continue
    for fname in sorted(os.listdir(sr_dir)):
        if fname.endswith(".md"):
            full = os.path.join(sr_dir, fname)
            files.append((os.path.relpath(full, prd_root), full))

if not files:
    emit([], scope_label="(no self-review files)")

for rel, full in files:
    text = read_text(full)
    if text is None:
        continue

    has_checklist = bool(re.search(r"^##\s+Checklist\b", text, re.M))
    has_summary = bool(re.search(r"^##\s+Summary\b", text, re.M))

    if not has_checklist:
        findings.append(Finding(
            criterion_id="CR-SR01", file=rel, severity="error",
            description="self-review missing '## Checklist' section",
            suggested_fix="add '## Checklist' with one CR row per applicable criterion",
        ))
    if not has_summary:
        findings.append(Finding(
            criterion_id="CR-SR01", file=rel, severity="error",
            description="self-review missing '## Summary' section",
            suggested_fix=(
                "add '## Summary' with FULL_PASS yes/no, fail_count, and "
                "Scope notes lines"
            ),
        ))

    # Extract FAIL rows from checklist (best-effort regex)
    fail_rows = re.findall(r"^\s*-\s+\S+.*?:\s*FAIL.*$", text, re.M)
    pass_rows = re.findall(r"^\s*-\s+\S+.*?:\s*PASS.*$", text, re.M)

    # Validate blocker_scope on each FAIL row
    for fr in fail_rows:
        m = re.search(r"blocker_scope\s*:\s*(\S+)", fr)
        if not m:
            findings.append(Finding(
                criterion_id="CR-SR02", file=rel, severity="error",
                description=f"FAIL row lacks blocker_scope: {fr.strip()[:120]!r}",
                suggested_fix=(
                    "every FAIL row MUST include 'blocker_scope: <value>' from "
                    f"{list(VALID_BLOCKER_SCOPES)}"
                ),
            ))
        else:
            scope_val = m.group(1).rstrip(",")
            if scope_val not in VALID_BLOCKER_SCOPES:
                findings.append(Finding(
                    criterion_id="CR-SR02", file=rel, severity="error",
                    description=(
                        f"FAIL row blocker_scope {scope_val!r} not in valid set"
                    ),
                    suggested_fix=(
                        f"set blocker_scope to one of {list(VALID_BLOCKER_SCOPES)}"
                    ),
                ))

    # CR-SR03: status / fail_count consistency
    summary_text = text[text.find("## Summary"):] if has_summary else ""
    full_pass_match = re.search(r"FULL_PASS\s*:\s*(yes|no|FULL_PASS|PARTIAL)", summary_text, re.I)
    fail_count_match = re.search(r"fail_count\s*:\s*(\d+)", summary_text)
    if full_pass_match and fail_count_match:
        status = full_pass_match.group(1).lower()
        fail_count = int(fail_count_match.group(1))
        n_fail_rows = len(fail_rows)
        if status in ("yes", "full_pass") and (fail_count > 0 or n_fail_rows > 0):
            findings.append(Finding(
                criterion_id="CR-SR03", file=rel, severity="error",
                description=(
                    f"FULL_PASS=yes but fail_count={fail_count} and "
                    f"{n_fail_rows} FAIL row(s) present"
                ),
                suggested_fix=(
                    "either set FULL_PASS to 'no' (PARTIAL) or remove the "
                    "FAIL rows"
                ),
            ))
        if status in ("no", "partial") and fail_count == 0 and n_fail_rows == 0:
            findings.append(Finding(
                criterion_id="CR-SR03", file=rel, severity="error",
                description="FULL_PASS=no/PARTIAL but no FAIL rows or fail_count=0",
                suggested_fix=(
                    "either record at least one FAIL row with blocker_scope, "
                    "or set FULL_PASS to 'yes' / fail_count to 0"
                ),
            ))

emit(findings, scope_label=f"({len(files)} self-review file(s))")
PYEOF
