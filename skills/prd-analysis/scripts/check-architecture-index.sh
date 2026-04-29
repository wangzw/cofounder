#!/usr/bin/env bash
# check-architecture-index.sh — formal review of architecture.md (PRD bundle
# architecture INDEX file).
#
# Implements:
#   CR-PP01  prd-directory-structure  — architecture.md OR architecture/ exists
#   CR-PP04  no-tbd-remaining
#
# Usage: check-architecture-index.sh <prd-dir>
#
# When neither architecture.md nor architecture/ exists, emits CR-PP01.
# When architecture.md exists but architecture/ has files, the index SHOULD
# link to each topic file (warning level — soft check).

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-architecture-index.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, read_text, list_dir, emit

findings: list[Finding] = []

arch_md = os.path.join(prd_root, "architecture.md")
arch_dir = os.path.join(prd_root, "architecture")
has_md = os.path.isfile(arch_md)
has_dir = os.path.isdir(arch_dir)

if not has_md and not has_dir:
    findings.append(Finding(
        criterion_id="CR-PP01-ARCH",
        file="architecture",
        severity="error",
        description="neither architecture.md nor architecture/ directory exists",
        suggested_fix=(
            "create architecture.md (index) and architecture/ topic files per "
            "common/templates/architecture-template.md"
        ),
    ))
    emit(findings, scope_label="(architecture.md)")

if not has_md:
    # architecture/ exists but no index — only emit a warning since a single
    # consolidated architecture.md is valid (the alternative shape).
    emit(findings, scope_label="(architecture.md absent — using architecture/ topic files)")

text = read_text(arch_md)
if text is None:
    emit(findings, scope_label="(architecture.md unreadable)")

# CR-PP04: no TBD/TODO/FIXME in the index
forbidden = re.compile(r"\b(TBD|TODO|FIXME)\b")
for i, line in enumerate(text.splitlines(), 1):
    if forbidden.search(line):
        findings.append(Finding(
            criterion_id="CR-PP04",
            file="architecture.md",
            severity="error",
            description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
            suggested_fix="replace with a concrete value or remove the section",
        ))
        break

# Soft check: every architecture/*.md should be linked from the index.
# Severity: warning (the index can legitimately omit highly internal topic
# files, e.g. drafts).
if has_dir:
    topic_files = [
        f for f in list_dir(prd_root, "architecture")
        if f.endswith(".md")
    ]
    for fname in topic_files:
        if f"architecture/{fname}" not in text and f"({fname})" not in text:
            findings.append(Finding(
                criterion_id="CR-PP03",
                file="architecture.md",
                severity="warning",
                description=(
                    f"architecture topic {fname} not referenced from architecture.md"
                ),
                suggested_fix=(
                    f"add a link to architecture/{fname} in the index"
                ),
            ))

emit(findings, scope_label="(architecture.md)")
PYEOF
