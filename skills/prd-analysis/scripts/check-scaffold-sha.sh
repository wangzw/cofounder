#!/usr/bin/env bash
# check-scaffold-sha.sh — CR-S12 (metrics-aggregate-verbatim)
# Usage: check-scaffold-sha.sh <target-skill-dir>
# Reads common/skeleton/shared-scripts-manifest.yml; computes sha256 of each listed file.
# If manifest absent, exits 0 (no-op for generated skills that haven't pinned yet).
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
import sys, json, os, re, hashlib

target = sys.argv[1]
issues = []

manifest_path = os.path.join(target, "common", "skeleton", "shared-scripts-manifest.yml")
if not os.path.isfile(manifest_path):
    # No manifest — no-op for generated skills
    print("[]")
    sys.exit(0)

try:
    content = open(manifest_path, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S12",
        "file": "common/skeleton/shared-scripts-manifest.yml",
        "severity": "critical",
        "description": f"Cannot read shared-scripts-manifest.yml: {e}",
        "suggested_fix": "Ensure manifest file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# Parse manifest: find file entries with sha256 values
# Format:
#   files:
#     scripts/foo.sh:
#       sha256: <hex>
file_blocks = re.findall(
    r'^\s{2}(\S[^\n:]+):\s*\n(?:\s+[^\n]+\n)*?\s+sha256:\s*([0-9a-f]{64})',
    content, re.MULTILINE
)
if not file_blocks:
    # Manifest exists but has no pinned files — that's OK
    print("[]")
    sys.exit(0)

for rel_path, expected_sha in file_blocks:
    rel_path = rel_path.strip()
    fpath = os.path.join(target, rel_path)
    if not os.path.isfile(fpath):
        issues.append({
            "criterion_id": "CR-S12",
            "file": rel_path,
            "severity": "critical",
            "description": f"Pinned file '{rel_path}' not found",
            "suggested_fix": f"Restore '{rel_path}' from the upstream snapshot"
        })
        continue
    try:
        data = open(fpath, "rb").read()
    except OSError as e:
        issues.append({
            "criterion_id": "CR-S12",
            "file": rel_path,
            "severity": "critical",
            "description": f"Cannot read '{rel_path}': {e}",
            "suggested_fix": "Ensure file is readable"
        })
        continue
    actual_sha = hashlib.sha256(data).hexdigest()
    if actual_sha != expected_sha:
        issues.append({
            "criterion_id": "CR-S12",
            "file": rel_path,
            "severity": "critical",
            "description": f"SHA256 mismatch for '{rel_path}': expected {expected_sha[:12]}..., got {actual_sha[:12]}...",
            "suggested_fix": "Restore the file verbatim from the upstream snapshot or update the manifest pin"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
