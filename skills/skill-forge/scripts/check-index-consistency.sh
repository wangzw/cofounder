#!/usr/bin/env bash
# check-index-consistency.sh — §7.5 leaves ↔ index.md alignment
# Usage: check-index-consistency.sh <target-skill-dir>
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues found, 2=error
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

def find_index_files(root):
    """Find all index.md files under root, excluding .review/ and common/skeleton/."""
    result = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune excluded dirs in-place
        rel = os.path.relpath(dirpath, root)
        parts = rel.split(os.sep)
        if '.review' in parts or (len(parts) >= 2 and parts[0] == 'common' and 'skeleton' in parts):
            dirnames.clear()
            continue
        # Also skip hidden dirs
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        if 'index.md' in filenames:
            result.append(dirpath)
    return result

def parse_linked_paths(index_path):
    """
    Extract linked paths from index.md.
    Supports:
      - Markdown links: [name](path.md)
      - Bullet list lines: - path.md or - ./path.md
    Returns a set of relative paths (lowercased filenames stripped of leading ./).
    """
    linked = set()
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Markdown links
    for m in re.finditer(r'\[(?:[^\]]*)\]\(([^)]+\.md[^)]*)\)', content):
        path = m.group(1).strip()
        # Strip anchors
        path = path.split('#')[0].strip()
        if path and not path.startswith('http'):
            linked.add(path.lstrip('./'))

    # Bullet list lines like "- path.md" or "  - ./sub/path.md"
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith('- ') or stripped.startswith('* '):
            candidate = stripped[2:].strip()
            # Strip markdown link syntax if present
            link_m = re.match(r'\[(?:[^\]]*)\]\(([^)]+\.md[^)]*)\)', candidate)
            if link_m:
                path = link_m.group(1).strip().split('#')[0].strip()
                if path and not path.startswith('http'):
                    linked.add(path.lstrip('./'))
            elif candidate.endswith('.md') and not candidate.startswith('http'):
                linked.add(candidate.lstrip('./'))

    return linked

index_dirs = find_index_files(target)

if not index_dirs:
    print("[]")
    sys.exit(0)

for dirpath in index_dirs:
    index_path = os.path.join(dirpath, 'index.md')
    rel_dir = os.path.relpath(dirpath, target)
    if rel_dir == '.':
        rel_dir = ''

    linked_paths = parse_linked_paths(index_path)

    # 1. For each linked path: confirm file exists
    for lp in linked_paths:
        full_path = os.path.join(dirpath, lp)
        if not os.path.isfile(full_path):
            rel_index = os.path.join(rel_dir, 'index.md') if rel_dir else 'index.md'
            issues.append({
                "criterion_id": "CR-INDEX",
                "file": rel_index,
                "severity": "error",
                "description": f"index.md links to '{lp}' but file does not exist"
            })

    # 2. For each .md file in same dir (not subdirs), confirm it's in index.md
    try:
        dir_files = [
            f for f in os.listdir(dirpath)
            if f.endswith('.md')
            and f not in ('index.md', 'README.md')
            and os.path.isfile(os.path.join(dirpath, f))
        ]
    except OSError:
        dir_files = []

    for fname in dir_files:
        # Check if fname appears in linked_paths (any case variant)
        fname_lower = fname.lower()
        found = any(lp.lower() == fname_lower or lp.lower().endswith('/' + fname_lower) for lp in linked_paths)
        if not found:
            rel_index = os.path.join(rel_dir, 'index.md') if rel_dir else 'index.md'
            issues.append({
                "criterion_id": "CR-INDEX",
                "file": rel_index,
                "severity": "error",
                "description": f"'{fname}' exists in same directory but is not listed in index.md"
            })

print(json.dumps(issues))
if any(i['severity'] in ('critical', 'error') for i in issues):
    sys.exit(1)
PYEOF
