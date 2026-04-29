#!/usr/bin/env bash
# check-version.sh — formal review of .review/versions/<N>.md
#
# Produced by summarizer Phase 2 (on-converge). Required frontmatter fields
# (per shared/summarizer-subagent.md):
#   delivery_id, round, git_sha, verdict, rounds_to_convergence
#   quality_at_delivery: { ... } (nested block)
#   justified_regressions: [...] (list)
#
# Implements:
#   CR-VS01  version-required-frontmatter
#   CR-VS02  version-converged-only — verdict MUST be 'converged'
#
# Usage: check-version.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-version.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, parse_frontmatter, frontmatter_error, read_text, emit

findings: list[Finding] = []

versions_dir = os.path.join(prd_root, ".review", "versions")
if not os.path.isdir(versions_dir):
    emit([], scope_label="(no .review/versions/ directory yet)")

REQUIRED = ("delivery_id", "round", "git_sha", "verdict", "rounds_to_convergence")

files: list[tuple[str, str]] = []
for fname in sorted(os.listdir(versions_dir)):
    if fname.endswith(".md"):
        p = os.path.join(versions_dir, fname)
        files.append((os.path.relpath(p, prd_root), p))

if not files:
    emit([], scope_label="(no version files yet)")

for rel, full in files:
    text = read_text(full)
    if text is None:
        continue
    err = frontmatter_error(text)
    if err:
        findings.append(Finding(
            criterion_id="CR-VS01", file=rel, severity="error",
            description=err,
            suggested_fix="add a leading frontmatter block",
        ))
        continue

    fm, _ = parse_frontmatter(text)
    for key in REQUIRED:
        if not fm.get(key):
            findings.append(Finding(
                criterion_id="CR-VS01", file=rel, severity="error",
                description=f"required field missing: {key!r}",
                suggested_fix=f"add '{key}: <value>' to the frontmatter",
            ))

    if fm.get("verdict") and fm["verdict"] != "converged":
        findings.append(Finding(
            criterion_id="CR-VS02", file=rel, severity="error",
            description=(
                f"version files MUST have verdict=converged (got {fm['verdict']!r})"
            ),
            suggested_fix=(
                "version snapshots are written only on convergence; if this "
                "delivery did not converge it should not have a versions/<N>.md"
            ),
        ))

    # quality_at_delivery and justified_regressions blocks (presence only)
    if not re.search(r"^quality_at_delivery\s*:\s*$", text, re.M):
        findings.append(Finding(
            criterion_id="CR-VS01", file=rel, severity="error",
            description="missing 'quality_at_delivery:' block",
            suggested_fix=(
                "add a 'quality_at_delivery:' nested block with final issue counts"
            ),
        ))
    if not re.search(r"^justified_regressions\s*:", text, re.M):
        findings.append(Finding(
            criterion_id="CR-VS01", file=rel, severity="error",
            description="missing 'justified_regressions:' field",
            suggested_fix=(
                "add 'justified_regressions: []' (empty list when none) "
                "or list the deferred high-severity issues"
            ),
        ))

emit(findings, scope_label=f"({len(files)} version file(s))")
PYEOF
