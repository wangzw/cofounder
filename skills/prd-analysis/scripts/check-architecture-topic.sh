#!/usr/bin/env bash
# check-architecture-topic.sh — formal review of architecture/*.md topic files.
#
# Implements:
#   CR-PP04  no-tbd-remaining     — placeholder markers
#
# Topic files have no fixed schema (they're domain-specific). The formal check
# is therefore minimal — substantive coherence is the LLM reviewer's job.
#
# Usage: check-architecture-topic.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-architecture-topic.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, list_dir, read_text, emit

findings: list[Finding] = []

arch_dir = os.path.join(prd_root, "architecture")
if not os.path.isdir(arch_dir):
    emit([], scope_label="(no architecture/ directory)")

forbidden = re.compile(r"\b(TBD|TODO|FIXME)\b")

for fname in list_dir(prd_root, "architecture"):
    if not fname.endswith(".md"):
        continue
    rel = f"architecture/{fname}"
    text = read_text(os.path.join(prd_root, rel))
    if text is None:
        continue
    for i, line in enumerate(text.splitlines(), 1):
        if forbidden.search(line):
            findings.append(Finding(
                criterion_id="CR-PP04",
                file=rel,
                severity="error",
                description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
                suggested_fix="replace with a concrete value or remove the section",
            ))
            break

emit(findings, scope_label="(architecture/)")
PYEOF
