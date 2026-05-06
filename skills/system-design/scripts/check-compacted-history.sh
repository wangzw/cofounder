#!/usr/bin/env bash
# check-compacted-history.sh — formal review of
# .review/round-<N>/compacted-history.md (produced by compact-delivery.sh).
#
# Implements:
#   CR-CH01  compacted-history-required-frontmatter
#            (delivery_id, final_round, compacted_round_count,
#             total_issues_seen, generated_at)
#   CR-CH02  compacted-history-final-round-monotonic
#            file lives under round-<N>/ where N == final_round
#
# Usage: check-compacted-history.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-compacted-history.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os
import re
import sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from sd_lint import Finding, parse_frontmatter, frontmatter_error, read_text, emit, find_round_dirs

findings: list[Finding] = []

REQUIRED = ("delivery_id", "final_round", "compacted_round_count",
            "total_issues_seen", "generated_at")

files: list[tuple[str, str, int]] = []
for round_num, round_dir in find_round_dirs(prd_root):
    p = os.path.join(round_dir, "compacted-history.md")
    if os.path.isfile(p):
        files.append((os.path.relpath(p, prd_root), p, round_num))

if not files:
    emit([], scope_label="(no compacted-history.md files)")

for rel, full, round_num in files:
    text = read_text(full)
    if text is None:
        continue
    err = frontmatter_error(text)
    if err:
        findings.append(Finding(
            criterion_id="CR-CH01", file=rel, severity="error",
            description=err,
            suggested_fix="add a leading frontmatter block",
        ))
        continue

    fm, _ = parse_frontmatter(text)
    for key in REQUIRED:
        if not fm.get(key):
            findings.append(Finding(
                criterion_id="CR-CH01", file=rel, severity="error",
                description=f"required field missing: {key!r}",
                suggested_fix=f"add '{key}: <value>' to the frontmatter",
            ))

    # CR-CH02: final_round must equal the round-<N>/ directory housing this file
    fr = fm.get("final_round", "")
    if fr and fr.isdigit():
        if int(fr) != round_num:
            findings.append(Finding(
                criterion_id="CR-CH02", file=rel, severity="error",
                description=(
                    f"final_round={fr} but file lives under round-{round_num}/"
                ),
                suggested_fix=(
                    "compacted-history.md must be written into the surviving "
                    "(final, converged) round directory; either fix final_round "
                    "or move the file"
                ),
            ))

    # Sanity: delivery_id must be a positive int
    di = fm.get("delivery_id", "")
    if di and not (di.isdigit() and int(di) >= 0):
        findings.append(Finding(
            criterion_id="CR-CH01", file=rel, severity="error",
            description=f"delivery_id must be a non-negative integer (got {di!r})",
            suggested_fix="set delivery_id to a non-negative integer",
        ))

emit(findings, scope_label=f"({len(files)} compacted-history.md file(s))")
PYEOF
