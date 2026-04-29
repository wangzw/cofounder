#!/usr/bin/env bash
# check-verdict.sh — formal review of .review/round-<N>/verdict.yml
#
# Produced by judge subagent. Required schema (per shared/judge-subagent.md):
#   round (int), delivery_id (int)
#   verdict: converged | progressing | oscillating | diverging | stalled
#   next_action: delivery | revise | hitl
#   evidence: { ... } block
#
# Implements:
#   CR-VD01  verdict-required-fields
#   CR-VD02  verdict-next-action-consistency
#
# Usage: check-verdict.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-verdict.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, parse_frontmatter, read_text, emit, find_round_dirs

findings: list[Finding] = []

VALID_VERDICTS = {"converged", "progressing", "oscillating", "diverging", "stalled"}
VALID_NEXT = {"delivery", "revise", "hitl"}
EXPECTED_NEXT = {
    "converged": "delivery",
    "progressing": "revise",
    "oscillating": "hitl",
    "diverging": "hitl",
    "stalled": "hitl",
}

files: list[tuple[str, str]] = []
for _, round_dir in find_round_dirs(prd_root):
    p = os.path.join(round_dir, "verdict.yml")
    if os.path.isfile(p):
        files.append((os.path.relpath(p, prd_root), p))

if not files:
    emit([], scope_label="(no verdict.yml files)")

for rel, full in files:
    text = read_text(full)
    if text is None:
        continue

    # verdict.yml is plain YAML, not frontmatter — parse top-level keys
    fm: dict[str, str] = {}
    for line in text.splitlines():
        if line.startswith((" ", "\t")) or not line.strip() or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
        if m:
            v = m.group(2).strip()
            if v.startswith('"') and v.endswith('"'):
                v = v[1:-1]
            fm[m.group(1)] = v

    for key in ("round", "delivery_id", "verdict", "next_action"):
        if key not in fm or not fm[key]:
            findings.append(Finding(
                criterion_id="CR-VD01", file=rel, severity="error",
                description=f"verdict missing required field: {key!r}",
                suggested_fix=f"add '{key}: <value>' to the YAML document",
            ))

    # round / delivery_id integers
    for k in ("round", "delivery_id"):
        if fm.get(k) and not fm[k].isdigit():
            findings.append(Finding(
                criterion_id="CR-VD01", file=rel, severity="error",
                description=f"{k!r} must be a non-negative integer (got {fm[k]!r})",
                suggested_fix=f"set {k!r} to an integer",
            ))

    if fm.get("verdict") and fm["verdict"] not in VALID_VERDICTS:
        findings.append(Finding(
            criterion_id="CR-VD01", file=rel, severity="error",
            description=f"verdict value {fm['verdict']!r} not in {sorted(VALID_VERDICTS)}",
            suggested_fix=f"set verdict to one of {sorted(VALID_VERDICTS)}",
        ))

    if fm.get("next_action") and fm["next_action"] not in VALID_NEXT:
        findings.append(Finding(
            criterion_id="CR-VD01", file=rel, severity="error",
            description=f"next_action value {fm['next_action']!r} not in {sorted(VALID_NEXT)}",
            suggested_fix=f"set next_action to one of {sorted(VALID_NEXT)}",
        ))

    # CR-VD02: verdict ↔ next_action mapping
    v = fm.get("verdict")
    n = fm.get("next_action")
    if v in EXPECTED_NEXT and n and n != EXPECTED_NEXT[v]:
        findings.append(Finding(
            criterion_id="CR-VD02", file=rel, severity="error",
            description=(
                f"verdict={v!r} expects next_action={EXPECTED_NEXT[v]!r}, got {n!r}"
            ),
            suggested_fix=(
                f"change next_action to {EXPECTED_NEXT[v]!r} or correct the verdict"
            ),
        ))

    # evidence block must exist (any field starting with 'evidence:' line)
    if not re.search(r"^evidence\s*:\s*$", text, re.M):
        findings.append(Finding(
            criterion_id="CR-VD01", file=rel, severity="error",
            description="verdict.yml missing 'evidence:' block",
            suggested_fix=(
                "add an 'evidence:' block with the count fields the judge "
                "considered (see shared/judge-subagent.md)"
            ),
        ))

emit(findings, scope_label=f"({len(files)} verdict.yml file(s))")
PYEOF
