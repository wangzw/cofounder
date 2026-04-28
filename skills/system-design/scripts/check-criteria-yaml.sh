#!/usr/bin/env bash
# check-criteria-yaml.sh — CR-S07 (criteria-yaml-shape)
# Usage: check-criteria-yaml.sh <target-skill-dir>
# Parses YAML code blocks in common/review-criteria.md; validates each entry has required fields.
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
    issues.append({
        "criterion_id": "CR-S07",
        "file": "common/review-criteria.md",
        "severity": "error",
        "description": "common/review-criteria.md not found",
        "suggested_fix": "Create review-criteria.md with YAML-block criterion definitions"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(criteria_path, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S07",
        "file": "common/review-criteria.md",
        "severity": "error",
        "description": f"Cannot read review-criteria.md: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

REQUIRED_FIELDS = ["id", "name", "version", "checker_type", "severity"]
VALID_CHECKER_TYPES = {"script", "llm", "hybrid"}

# Extract all ```yaml blocks
yaml_blocks = re.findall(r'```yaml\s*\n(.*?)```', content, re.DOTALL)
if not yaml_blocks:
    issues.append({
        "criterion_id": "CR-S07",
        "file": "common/review-criteria.md",
        "severity": "error",
        "description": "No YAML code blocks found in review-criteria.md",
        "suggested_fix": "Add criterion definitions as ```yaml code blocks"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

for idx, block in enumerate(yaml_blocks):
    block = block.strip()
    if not block.startswith("- id:") and not block.startswith("-\n"):
        # Not a list item block — skip (may be example or config block)
        continue
    # Extract field values; id is on the "- id: ..." line (no leading spaces),
    # other fields are indented. Allow zero or more leading whitespace chars.
    fields = {}
    for field in REQUIRED_FIELDS:
        m = re.search(rf'^[- ]*{field}\s*:\s*(.+)$', block, re.MULTILINE)
        if m:
            fields[field] = m.group(1).strip().strip('"\'')

    block_id = fields.get("id", f"block-{idx+1}")
    for field in REQUIRED_FIELDS:
        if field not in fields:
            issues.append({
                "criterion_id": "CR-S07",
                "file": "common/review-criteria.md",
                "severity": "error",
                "description": f"Criterion '{block_id}' is missing required field: '{field}'",
                "suggested_fix": f"Add '{field}: ...' to the criterion YAML block"
            })

    if "checker_type" in fields and fields["checker_type"] not in VALID_CHECKER_TYPES:
        issues.append({
            "criterion_id": "CR-S07",
            "file": "common/review-criteria.md",
            "severity": "error",
            "description": f"Criterion '{block_id}' has invalid checker_type: '{fields['checker_type']}'",
            "suggested_fix": "checker_type must be one of: script, llm, hybrid"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
