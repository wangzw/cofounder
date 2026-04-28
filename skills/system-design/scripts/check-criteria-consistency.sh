#!/usr/bin/env bash
# check-criteria-consistency.sh — §13.1 criteria self-consistency
# Usage: check-criteria-consistency.sh <target-skill-dir>
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues found, 2=error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

# Extract criteria first
CRITERIA_JSON=$("${SCRIPT_DIR}/extract-criteria.sh" "$TARGET" 2>/dev/null) || {
  echo "[]" >&2
  echo "ERROR: extract-criteria.sh failed for: ${TARGET}" >&2
  exit 2
}

python3 - "$TARGET" "$CRITERIA_JSON" <<'PYEOF'
import sys, json, os

target = sys.argv[1]
criteria_json = sys.argv[2]

try:
    criteria = json.loads(criteria_json)
except json.JSONDecodeError as e:
    sys.stderr.write(f"ERROR: failed to parse criteria JSON: {e}\n")
    sys.exit(2)

issues = []

VALID_SEVERITIES = {"critical", "error", "warning"}
VALID_CHECKER_TYPES = {"script", "llm", "hybrid"}

# 1. All id values unique
seen_ids = {}
for c in criteria:
    cid = c.get('id', '')
    if cid in seen_ids:
        issues.append({
            "criterion_id": cid,
            "file": "common/review-criteria.md",
            "severity": "error",
            "description": f"Duplicate criterion id: {cid}"
        })
    else:
        seen_ids[cid] = c

# 2. No mutual conflicts_with pair with different severities (§13.1)
id_map = {c['id']: c for c in criteria if 'id' in c}
for cid, c in id_map.items():
    conflicts = c.get('conflicts_with', []) or []
    for other_id in conflicts:
        if other_id not in id_map:
            continue
        other = id_map[other_id]
        other_conflicts = other.get('conflicts_with', []) or []
        if cid in other_conflicts:
            # Mutual conflict — check severity mismatch
            sev_a = c.get('severity', '')
            sev_b = other.get('severity', '')
            if sev_a != sev_b:
                issues.append({
                    "criterion_id": cid,
                    "file": "common/review-criteria.md",
                    "severity": "error",
                    "description": (
                        f"Mutual conflicts_with pair {cid}<->{other_id} has different severities "
                        f"({sev_a} vs {sev_b}); per §13.1 this causes oscillation"
                    )
                })

# 3. Every script-type criterion has script_path and that script exists
for c in criteria:
    cid = c.get('id', '?')
    if c.get('checker_type') == 'script':
        script_path = c.get('script_path', '')
        if not script_path:
            issues.append({
                "criterion_id": cid,
                "file": "common/review-criteria.md",
                "severity": "error",
                "description": f"{cid}: checker_type=script but script_path is missing"
            })
        else:
            full_path = os.path.join(target, script_path)
            if not os.path.isfile(full_path):
                issues.append({
                    "criterion_id": cid,
                    "file": "common/review-criteria.md",
                    "severity": "error",
                    "description": f"{cid}: script_path '{script_path}' does not exist under target"
                })

# 4. Every severity is valid
for c in criteria:
    cid = c.get('id', '?')
    sev = c.get('severity', '')
    if sev not in VALID_SEVERITIES:
        issues.append({
            "criterion_id": cid,
            "file": "common/review-criteria.md",
            "severity": "error",
            "description": f"{cid}: invalid severity '{sev}'; must be one of {sorted(VALID_SEVERITIES)}"
        })

# 5. Every checker_type is valid
for c in criteria:
    cid = c.get('id', '?')
    ct = c.get('checker_type', '')
    if ct not in VALID_CHECKER_TYPES:
        issues.append({
            "criterion_id": cid,
            "file": "common/review-criteria.md",
            "severity": "error",
            "description": f"{cid}: invalid checker_type '{ct}'; must be one of {sorted(VALID_CHECKER_TYPES)}"
        })

print(json.dumps(issues))
if any(i['severity'] in ('critical', 'error') for i in issues):
    sys.exit(1)
PYEOF
