#!/usr/bin/env bash
# check-checker-implementations.sh — CR-S17 (checker-implements-declared-cr)
# Usage: check-checker-implementations.sh <target-skill-dir>
# For each script-tier criterion in <target>/common/review-criteria.md that
# declares a `script_path:`, verify the target's script at that path contains
# the literal CR-ID string. Catches the case where skill-forge's canonical
# checker was updated to implement a new CR but the target's stale copy did
# not pick up the change — a silent gap that lets Phase B return [] even
# though violations exist.
#
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues, 2=error
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi
TARGET="${TARGET%/}"

python3 - "$TARGET" <<'PYEOF'
import sys, json, os, re

target = sys.argv[1]
issues = []

criteria_path = os.path.join(target, "common", "review-criteria.md")
if not os.path.isfile(criteria_path):
    # CR-S07 reports missing review-criteria.md; we silently no-op here
    # to avoid double-reporting.
    print("[]")
    sys.exit(0)

with open(criteria_path, encoding="utf-8") as f:
    text = f.read()

# Extract YAML blocks; for each block that has both `id: CR-Sxx` and
# `script_path: scripts/...`, record the (cr_id, script_path) pair.
blocks = re.findall(r"```yaml\s*\n(.*?)\n```", text, re.DOTALL)
pairs = []
for blk in blocks:
    m_id = re.search(r"^\s*-?\s*id:\s*(CR-S[A-Z0-9]+)\s*$", blk, re.MULTILINE)
    m_sp = re.search(r"^\s*script_path:\s*(\S+)\s*$", blk, re.MULTILINE)
    if m_id and m_sp:
        pairs.append((m_id.group(1), m_sp.group(1)))

# A single script_path may implement multiple CR-IDs (e.g. check-skill-structure.sh
# covers CR-S03 + CR-S04 + CR-S16). Group pairs by script and verify each CR-ID
# appears in the script's text.
from collections import defaultdict
script_to_crs = defaultdict(list)
for cr, sp in pairs:
    script_to_crs[sp].append(cr)

for script_path, cr_list in script_to_crs.items():
    full_path = os.path.join(target, script_path)
    if not os.path.isfile(full_path):
        # CR-S05 (scripts-inventory) catches missing scripts; skip here.
        continue
    try:
        with open(full_path, encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        issues.append({
            "criterion_id": "CR-S17",
            "file": script_path,
            "severity": "error",
            "description": f"Could not read {script_path}: {e}",
            "suggested_fix": f"Verify {script_path} is a readable text file.",
        })
        continue
    for cr in cr_list:
        if cr not in content:
            issues.append({
                "criterion_id": "CR-S17",
                "file": script_path,
                "severity": "error",
                "description": (
                    f"{cr} declares script_path '{script_path}' but the "
                    f"script does not contain the literal '{cr}' string. "
                    f"The target's copy is likely stale relative to skill-forge's "
                    f"canonical version. Phase B will return [] for this CR even "
                    f"if violations exist."
                ),
                "suggested_fix": (
                    f"Sync {script_path} from skill-forge's canonical copy "
                    f"(selective re-scaffold), OR remove the {cr} entry from "
                    f"common/review-criteria.md if {cr} is obsolete in this skill."
                ),
            })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
