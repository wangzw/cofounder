#!/usr/bin/env bash
# check-readme.sh — formal review of README.md (PRD bundle index).
#
# Implements:
#   CR-PP01  prd-directory-structure   — README.md exists at root
#   CR-PP03  readme-index-complete     — every leaf in journeys/ + features/
#                                        is referenced; every README link
#                                        resolves to a file
#   CR-PP04  no-tbd-remaining          — no TBD/TODO/FIXME tokens
#
# Usage: check-readme.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-readme.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import (
    Finding, list_dir, read_text, emit, JOURNEY_FILE_RE, FEATURE_FILE_RE,
)

findings: list[Finding] = []

# ─── CR-PP01: README.md must exist ───────────────────────────────────
readme_path = os.path.join(prd_root, "README.md")
readme = read_text(readme_path)
if readme is None:
    findings.append(Finding(
        criterion_id="CR-PP01",
        file="README.md",
        severity="critical",
        description="required top-level file missing: README.md",
        suggested_fix="create README.md from common/templates/prd-template.md",
    ))
    emit(findings, scope_label="(README.md)")

# ─── CR-PP03: index completeness vs leaves on disk ───────────────────
journey_files = [f for f in list_dir(prd_root, "journeys") if JOURNEY_FILE_RE.match(f or "")]
feature_files = [f for f in list_dir(prd_root, "features") if FEATURE_FILE_RE.match(f or "")]

for fname in journey_files:
    if f"journeys/{fname}" not in readme and f"({fname})" not in readme:
        findings.append(Finding(
            criterion_id="CR-PP03",
            file="README.md",
            severity="error",
            description=f"journey leaf {fname} not referenced from README.md",
            suggested_fix=f"add a link to journeys/{fname} in the journey index section",
        ))

for fname in feature_files:
    if f"features/{fname}" not in readme and f"({fname})" not in readme:
        findings.append(Finding(
            criterion_id="CR-PP03",
            file="README.md",
            severity="error",
            description=f"feature leaf {fname} not referenced from README.md",
            suggested_fix=f"add a link to features/{fname} in the feature index section",
        ))

# Reverse direction — links that don't resolve
for m in re.finditer(r"\(((?:journeys|features)/[^)]+\.md)\)", readme):
    rel = m.group(1)
    if not os.path.isfile(os.path.join(prd_root, rel)):
        findings.append(Finding(
            criterion_id="CR-PP03",
            file="README.md",
            severity="error",
            description=f"README link {rel!r} does not resolve to an existing file",
            suggested_fix=f"create the file at {rel} or remove the link",
        ))

# ─── CR-PP04: no TBD/TODO/FIXME ──────────────────────────────────────
forbidden_re = re.compile(r"\b(TBD|TODO|FIXME)\b")
for i, line in enumerate(readme.splitlines(), 1):
    if forbidden_re.search(line):
        findings.append(Finding(
            criterion_id="CR-PP04",
            file="README.md",
            severity="error",
            description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
            suggested_fix="replace with a concrete value or remove the section if not applicable",
        ))
        break

emit(findings, scope_label="(README.md)")
PYEOF
