#!/usr/bin/env bash
# check-mode-routing.sh — CR-S02 (mode-routing-complete)
# Usage: check-mode-routing.sh <target-skill-dir>
# Verifies SKILL.md has a ## Mode Routing section with a table covering all 4 base modes + --diagnose.
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
        "criterion_id": "CR-S02",
        "file": "SKILL.md",
        "severity": "error",
        "description": "SKILL.md not found; cannot check mode routing",
        "suggested_fix": "Create SKILL.md with a ## Mode Routing section"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(skill_md, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S02",
        "file": "SKILL.md",
        "severity": "error",
        "description": f"Cannot read SKILL.md: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# Find ## Mode Routing section
section_match = re.search(r'##\s+Mode Routing\s*\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
if not section_match:
    issues.append({
        "criterion_id": "CR-S02",
        "file": "SKILL.md",
        "severity": "error",
        "description": "No '## Mode Routing' section found in SKILL.md",
        "suggested_fix": "Add a '## Mode Routing' section with a markdown table"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

section = section_match.group(1)

# Check for markdown table (at least one pipe-delimited row)
table_rows = [l for l in section.splitlines() if l.startswith("|")]
if not table_rows:
    issues.append({
        "criterion_id": "CR-S02",
        "file": "SKILL.md",
        "severity": "error",
        "description": "Mode Routing section contains no markdown table",
        "suggested_fix": "Add a table with columns for mode, loaded files, description"
    })

# Check required modes — only scan table rows to avoid false positives in prose
table_text = "\n".join(table_rows)
REQUIRED_MODES = [
    ("generate", [r'generate', r'no args', r'\(default\)']),
    ("--review", [r'--review']),
    ("--revise", [r'--revise']),
    ("--diagnose", [r'--diagnose']),
]
for mode_name, patterns in REQUIRED_MODES:
    found = any(re.search(p, table_text, re.IGNORECASE) for p in patterns)
    if not found:
        issues.append({
            "criterion_id": "CR-S02",
            "file": "SKILL.md",
            "severity": "error",
            "description": f"Mode '{mode_name}' not found in Mode Routing table",
            "suggested_fix": f"Add a row for '{mode_name}' mode in the Mode Routing table"
        })

# Check for 'Loaded Files' column header — search only in the table header row
# (table_rows[0] is the header; skip separator rows that start with |---)
header_rows = [r for r in table_rows if not re.match(r'^\|[-| ]+\|', r)]
header_text = header_rows[0] if header_rows else ""
if not re.search(r'[Ll]oaded\s+[Ff]iles', header_text):
    issues.append({
        "criterion_id": "CR-S02",
        "file": "SKILL.md",
        "severity": "error",
        "description": "Mode Routing table missing 'Loaded Files' column",
        "suggested_fix": "Add a 'Loaded Files' column header to the Mode Routing table"
    })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
