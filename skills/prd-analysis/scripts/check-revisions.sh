#!/usr/bin/env bash
# check-revisions.sh — formal review of REVISIONS.md (version chain).
#
# Implements:
#   CR-PP05  version-chain-integrity   — Previous Version / Predecessor paths resolve
#   CR-PP04  no-tbd-remaining
#
# Usage: check-revisions.sh <prd-dir>
#
# Note: REVISIONS.md is OPTIONAL — it only exists after the first --revise
# pass. When absent, this script exits 0 (PASS) without complaint.

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-revisions.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, read_text, emit

findings: list[Finding] = []

revisions = read_text(os.path.join(prd_root, "REVISIONS.md"))
if revisions is None:
    emit([], scope_label="(no REVISIONS.md — optional)")

# CR-PP05: previous-version paths must resolve
path_re = re.compile(
    r"(?im)^\s*(?:Previous Version|Predecessor)\s*:\s*[`\'\"]?([^`\'\"\n]+)"
)
for m in path_re.finditer(revisions):
    path = m.group(1).strip()
    if not path:
        continue
    candidate = os.path.expanduser(path)
    if not os.path.isabs(candidate):
        candidate = os.path.normpath(os.path.join(prd_root, "..", candidate))
    if not os.path.exists(candidate):
        findings.append(Finding(
            criterion_id="CR-PP05",
            file="REVISIONS.md",
            severity="error",
            description=f"Previous Version path {path!r} does not resolve",
            suggested_fix=(
                "fix the path or remove the entry; relative paths are "
                "interpreted from the parent of the PRD directory"
            ),
        ))

# CR-PP04: no TBD/TODO/FIXME
forbidden = re.compile(r"\b(TBD|TODO|FIXME)\b")
for i, line in enumerate(revisions.splitlines(), 1):
    if forbidden.search(line):
        findings.append(Finding(
            criterion_id="CR-PP04",
            file="REVISIONS.md",
            severity="error",
            description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
            suggested_fix="replace with a concrete value or remove the section",
        ))
        break

emit(findings, scope_label="(REVISIONS.md)")
PYEOF
