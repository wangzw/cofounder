#!/usr/bin/env bash
# check-journey.sh — formal review of journeys/J-NNN-{slug}.md leaves.
#
# Implements:
#   CR-PP02   id-format-monotonic — J-NNN format, no duplicates, no gaps
#   CR-PP04   no-tbd-remaining
#   CR-FM01   frontmatter-required-fields — id / title / persona
#
# Usage: check-journey.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-journey.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import (
    Finding, parse_frontmatter, list_dir, read_text, emit, JOURNEY_FILE_RE,
)

journeys_dir = os.path.join(prd_root, "journeys")
if not os.path.isdir(journeys_dir):
    emit([], scope_label="(no journeys/ directory)")

findings: list[Finding] = []

# ─── Collect journey files + parse IDs ────────────────────────────────
nums: list[tuple[int, str]] = []
bad_format: list[str] = []
for fname in list_dir(prd_root, "journeys"):
    if not fname.endswith(".md"):
        continue
    m = JOURNEY_FILE_RE.match(fname)
    if not m:
        bad_format.append(fname)
        continue
    nums.append((int(m.group(1)), fname))

for fname in bad_format:
    findings.append(Finding(
        criterion_id="CR-PP02",
        file=f"journeys/{fname}",
        severity="error",
        description=(
            f"journey filename {fname!r} does not match the required pattern "
            f"J-NNN[-slug].md"
        ),
        suggested_fix=(
            "rename to J-NNN[-slug].md with a zero-padded 3-digit id "
            "(e.g. J-001-onboarding.md)"
        ),
    ))

seen: set[int] = set()
for n, fname in sorted(nums):
    if n in seen:
        findings.append(Finding(
            criterion_id="CR-PP02",
            file=f"journeys/{fname}",
            severity="error",
            description=f"duplicate journey id J-{n:03d}",
            suggested_fix="rename one occurrence to a unique id",
        ))
    seen.add(n)

ids = sorted({n for n, _ in nums})
if ids:
    if ids[0] != 1:
        findings.append(Finding(
            criterion_id="CR-PP02",
            file="journeys/",
            severity="warning",
            description=f"journey ids start at J-{ids[0]:03d}, expected J-001",
            suggested_fix=(
                "renumber the first journey to J-001 unless prior versions "
                "are tombstoned"
            ),
        ))
    for i in range(len(ids) - 1):
        if ids[i + 1] - ids[i] > 1:
            missing = list(range(ids[i] + 1, ids[i + 1]))
            findings.append(Finding(
                criterion_id="CR-PP02",
                file="journeys/",
                severity="warning",
                description=(
                    "gap in journey ids: missing "
                    f"{', '.join(f'J-{m:03d}' for m in missing)}"
                ),
                suggested_fix=(
                    "either fill the gap or add tombstone entries explaining "
                    "the deprecated ids"
                ),
            ))

# ─── Per-file checks ──────────────────────────────────────────────────
forbidden_re = re.compile(r"\b(TBD|TODO|FIXME)\b")
required_fm = ("id", "title", "persona")

for _, fname in sorted(nums):
    rel = f"journeys/{fname}"
    text = read_text(os.path.join(prd_root, rel))
    if text is None:
        continue
    fm, body = parse_frontmatter(text)

    if not fm:
        findings.append(Finding(
            criterion_id="CR-FM01",
            file=rel,
            severity="error",
            description="journey file missing leading frontmatter block",
            suggested_fix=(
                "add a frontmatter block delimited by '---' lines with "
                "required fields: id, title, persona"
            ),
        ))
    else:
        missing = [k for k in required_fm if not fm.get(k)]
        if missing:
            findings.append(Finding(
                criterion_id="CR-FM01",
                file=rel,
                severity="error",
                description=f"frontmatter missing field(s): {', '.join(missing)}",
                suggested_fix="add the missing field(s) to the frontmatter block",
            ))

    for i, line in enumerate(text.splitlines(), 1):
        if forbidden_re.search(line):
            findings.append(Finding(
                criterion_id="CR-PP04",
                file=rel,
                severity="error",
                description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
                suggested_fix=(
                    "replace with a concrete value or remove the section "
                    "if not applicable"
                ),
            ))
            break

emit(findings, scope_label="(journeys/)")
PYEOF
