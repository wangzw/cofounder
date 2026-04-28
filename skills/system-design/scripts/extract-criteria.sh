#!/usr/bin/env bash
# extract-criteria.sh — parse YAML blocks from review-criteria.md
# Usage: extract-criteria.sh <target-skill-dir>
# Output: JSON array of criterion dicts to stdout
# Exit: 0=success, 2=missing/malformed file
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

python3 - "$TARGET" <<'PYEOF'
import sys, json, os, re

def parse_simple_yaml_scalar(val):
    """Parse a simple YAML scalar: unquoted, single-quoted, or double-quoted string, int, float."""
    val = val.strip()
    if (val.startswith('"') and val.endswith('"')) or \
       (val.startswith("'") and val.endswith("'")):
        return val[1:-1]
    # Remove inline comments
    val = re.sub(r'\s+#.*$', '', val)
    val = val.strip()
    if re.match(r'^-?\d+$', val):
        return int(val)
    try:
        return float(val)
    except ValueError:
        pass
    return val

def parse_inline_list(val):
    """Parse [] or [a, b, c] inline list."""
    val = val.strip()
    if val == '[]':
        return []
    inner = val[1:-1]
    if not inner.strip():
        return []
    items = [x.strip().strip('"').strip("'") for x in inner.split(',')]
    return items

def parse_yaml_block(block_text):
    """
    Mini YAML parser: handles the criterion dict format.
    Expects the block to start with '- id: ...' (list item with a mapping).
    Returns a dict or raises ValueError.
    """
    lines = block_text.strip().splitlines()
    result = {}
    i = 0
    # Strip the leading '- ' from first key
    while i < len(lines):
        line = lines[i]
        # Skip blank lines and comment lines
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            i += 1
            continue
        # Determine indent
        indent = len(line) - len(line.lstrip())
        # First line may start with '- '
        if stripped.startswith('- '):
            stripped = stripped[2:]
        if ':' in stripped:
            key, _, rest = stripped.partition(':')
            key = key.strip()
            rest = rest.strip()
            if rest.startswith('['):
                result[key] = parse_inline_list(rest)
            elif rest == '' or rest.startswith('#'):
                # block scalar — not used in our format
                result[key] = None
            else:
                result[key] = parse_simple_yaml_scalar(rest)
        i += 1
    return result

target = sys.argv[1]
criteria_file = os.path.join(target, "common", "review-criteria.md")

if not os.path.isfile(criteria_file):
    sys.stderr.write(f"ERROR: review-criteria.md not found: {criteria_file}\n")
    sys.exit(2)

with open(criteria_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Extract all ```yaml ... ``` blocks
blocks = re.findall(r'```yaml\s*\n(.*?)```', content, re.DOTALL)

criteria = []
errors = []
for i, block in enumerate(blocks):
    try:
        parsed = parse_yaml_block(block)
        if parsed and 'id' in parsed:
            criteria.append(parsed)
    except Exception as e:
        errors.append(f"Block {i+1}: {e}")

if errors:
    for err in errors:
        sys.stderr.write(f"WARNING: parse error in {err}\n")

print(json.dumps(criteria))
PYEOF
