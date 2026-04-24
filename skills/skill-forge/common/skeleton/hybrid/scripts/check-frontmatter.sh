#!/usr/bin/env bash
# check-frontmatter.sh — CR-S01 (skill-md-frontmatter)
# Usage: check-frontmatter.sh <target-skill-dir>
# Verifies SKILL.md YAML frontmatter has name/version/description; description ≤ 1024 chars,
# starts with "Use when".
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
skill_md = os.path.join(target, "SKILL.md")

if not os.path.isfile(skill_md):
    issues.append({
        "criterion_id": "CR-S01",
        "file": "SKILL.md",
        "severity": "error",
        "description": "SKILL.md not found",
        "suggested_fix": "Create SKILL.md with YAML frontmatter between --- markers"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(skill_md, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S01",
        "file": "SKILL.md",
        "severity": "error",
        "description": f"Cannot read SKILL.md: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# Extract frontmatter block between first two --- markers
fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if not fm_match:
    issues.append({
        "criterion_id": "CR-S01",
        "file": "SKILL.md",
        "severity": "error",
        "description": "No YAML frontmatter block (--- delimiters) found in SKILL.md",
        "suggested_fix": "Add frontmatter between --- markers at the top of SKILL.md"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

fm_text = fm_match.group(1)

# Check required keys using simple regex (no pyyaml)
for key in ("name", "version", "description"):
    if not re.search(rf'^{key}\s*:', fm_text, re.MULTILINE):
        issues.append({
            "criterion_id": "CR-S01",
            "file": "SKILL.md",
            "severity": "error",
            "description": f"Frontmatter missing required key: '{key}'",
            "suggested_fix": f"Add '{key}: ...' to the SKILL.md frontmatter"
        })

# Extract description value (single-line or quoted)
desc_match = re.search(r'^description\s*:\s*(.+)$', fm_text, re.MULTILINE)
if desc_match:
    desc = desc_match.group(1).strip().strip('"\'')
    if len(desc) > 1024:
        issues.append({
            "criterion_id": "CR-S01",
            "file": "SKILL.md",
            "severity": "error",
            "description": f"description is {len(desc)} chars (limit 1024)",
            "suggested_fix": "Shorten the description to ≤ 1024 characters"
        })
    if not desc.startswith("Use when"):
        issues.append({
            "criterion_id": "CR-S01",
            "file": "SKILL.md",
            "severity": "error",
            "description": f"description must start with 'Use when', got: '{desc[:40]}...'",
            "suggested_fix": "Rewrite description to start with 'Use when'"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
