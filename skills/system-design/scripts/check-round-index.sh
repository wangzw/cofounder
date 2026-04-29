#!/usr/bin/env bash
# check-round-index.sh — formal review of .review/round-<N>/index.md
#
# Produced by summarizer Phase 1. Required frontmatter fields (per
# shared/summarizer-subagent.md):
#   round (int), delivery_id (int), total_issues, new_count, fixed_count,
#   false_positive_count, deferred_count, superseded_count,
#   critical_count, error_count, warning_count, info_count,
#   false_positive_ratio, deferred_ratio, recurrence_count,
#   justified_regressions_ok (bool)
#
# Implements:
#   CR-RI01  round-index-required-fields
#   CR-RI02  round-index-state-counts-sum-to-total
#
# Usage: check-round-index.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-round-index.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from sd_lint import (
    Finding, parse_frontmatter, frontmatter_error, read_text, emit, find_round_dirs,
)

findings: list[Finding] = []

REQUIRED_INT = (
    "round", "delivery_id",
    "total_issues",
    "new_count", "fixed_count", "false_positive_count",
    "deferred_count", "superseded_count",
    "critical_count", "error_count", "warning_count", "info_count",
    "recurrence_count",
)
REQUIRED_FLOAT = ("false_positive_ratio", "deferred_ratio")
REQUIRED_BOOL = ("justified_regressions_ok",)

files: list[tuple[str, str]] = []
for _, round_dir in find_round_dirs(prd_root):
    idx_path = os.path.join(round_dir, "index.md")
    if os.path.isfile(idx_path):
        files.append((os.path.relpath(idx_path, prd_root), idx_path))

if not files:
    emit([], scope_label="(no round-N/index.md files)")

for rel, full in files:
    text = read_text(full)
    if text is None:
        continue
    err = frontmatter_error(text)
    if err:
        findings.append(Finding(
            criterion_id="CR-RI01", file=rel, severity="error",
            description=err,
            suggested_fix="add a leading frontmatter block delimited by '---' lines",
        ))
        continue
    fm, _ = parse_frontmatter(text)

    for k in REQUIRED_INT:
        v = fm.get(k)
        if v is None or v == "":
            findings.append(Finding(
                criterion_id="CR-RI01", file=rel, severity="error",
                description=f"required integer field missing: {k!r}",
                suggested_fix=f"add '{k}: <int>' to the frontmatter",
            ))
        else:
            try:
                int(v)
            except ValueError:
                findings.append(Finding(
                    criterion_id="CR-RI01", file=rel, severity="error",
                    description=f"field {k!r} is not an integer (got {v!r})",
                    suggested_fix=f"set {k!r} to an integer value",
                ))

    for k in REQUIRED_FLOAT:
        v = fm.get(k)
        if v is None or v == "":
            findings.append(Finding(
                criterion_id="CR-RI01", file=rel, severity="error",
                description=f"required float field missing: {k!r}",
                suggested_fix=f"add '{k}: <0..1>' to the frontmatter",
            ))
        else:
            try:
                fv = float(v)
                if fv < 0 or fv > 1:
                    raise ValueError("out of [0,1]")
            except ValueError:
                findings.append(Finding(
                    criterion_id="CR-RI01", file=rel, severity="error",
                    description=f"field {k!r} not a float in [0,1] (got {v!r})",
                    suggested_fix=f"set {k!r} to a float between 0 and 1",
                ))

    for k in REQUIRED_BOOL:
        v = fm.get(k)
        if v not in ("true", "false", "True", "False"):
            findings.append(Finding(
                criterion_id="CR-RI01", file=rel, severity="error",
                description=f"required boolean field missing or invalid: {k!r} = {v!r}",
                suggested_fix=f"set {k!r} to true or false",
            ))

    # CR-RI02: state counts sum to total
    try:
        total = int(fm.get("total_issues", "0"))
        states_sum = sum(
            int(fm.get(f, "0") or "0")
            for f in (
                "new_count", "fixed_count", "false_positive_count",
                "deferred_count", "superseded_count",
            )
        )
        if total != states_sum:
            findings.append(Finding(
                criterion_id="CR-RI02", file=rel, severity="error",
                description=(
                    f"total_issues ({total}) does not equal sum of state "
                    f"counts ({states_sum})"
                ),
                suggested_fix=(
                    "ensure total_issues = new_count + fixed_count + "
                    "false_positive_count + deferred_count + superseded_count"
                ),
            ))
    except ValueError:
        pass  # already reported above as non-int field

emit(findings, scope_label=f"({len(files)} round-index file(s))")
PYEOF
