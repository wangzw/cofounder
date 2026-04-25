#!/usr/bin/env bash
# build-depgraph.sh — §8.5 dependency graph builder
# Usage: build-depgraph.sh <target-skill-dir> <round-N>
# Writes <target>/.review/round-<N>/depgraph.yml
# Exit: 0=success, 2=error
set -euo pipefail

TARGET="${1:-}"
ROUND="${2:-}"

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi
if [ -z "$ROUND" ]; then
  echo "ERROR: round argument required (e.g. round-1)" >&2
  exit 2
fi

TARGET="${TARGET%/}"

python3 - "$TARGET" "$ROUND" <<'PYEOF'
import sys, os, re, json
from datetime import datetime, timezone

target = sys.argv[1]
round_name = sys.argv[2]

# Validate round name
if not re.match(r'^round-\d+$', round_name):
    sys.stderr.write(f"ERROR: round must be 'round-N' format; got '{round_name}'\n")
    sys.exit(2)

# Check config.yml for artifact_type / depgraph setting
config_path = os.path.join(target, 'common', 'config.yml')
artifact_type = 'document'
depgraph_enabled = True

if os.path.isfile(config_path):
    with open(config_path, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^\s*artifact_type\s*:\s*(.+)', line)
            if m:
                artifact_type = m.group(1).strip().strip('"').strip("'")
            m2 = re.match(r'^\s*depgraph\s*:\s*(.+)', line)
            if m2:
                val = m2.group(1).strip().lower()
                if val == 'off' or val == 'false':
                    depgraph_enabled = False

# Warn for non-document types
if artifact_type in ('code', 'schema'):
    sys.stderr.write(
        f"WARNING: depgraph building for code-type targets not implemented in v1; "
        f"emitting empty graph\n"
    )
    depgraph_enabled = False

# Create output directory
out_dir = os.path.join(target, '.review', round_name)
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, 'depgraph.yml')

EXCLUDE_PREFIXES = ['.review', os.path.join('common', 'skeleton')]

def should_exclude(rel_path):
    parts = rel_path.replace('\\', '/').split('/')
    if parts[0] == '.review':
        return True
    if len(parts) >= 2 and parts[0] == 'common' and parts[1] == 'skeleton':
        return True
    return False

graph = {}  # relative path -> list of referenced relative paths

if depgraph_enabled:
    for dirpath, dirnames, filenames in os.walk(target):
        # Prune excluded dirs
        rel_dir = os.path.relpath(dirpath, target)
        if should_exclude(rel_dir):
            dirnames.clear()
            continue
        # Prune hidden dirs and excluded dirs
        dirnames[:] = [
            d for d in dirnames
            if not d.startswith('.')
            and not should_exclude(os.path.join(rel_dir, d).lstrip('./'))
        ]

        for fname in filenames:
            if not fname.endswith('.md'):
                continue
            fpath = os.path.join(dirpath, fname)
            rel_file = os.path.relpath(fpath, target).replace('\\', '/')
            if should_exclude(rel_file):
                continue

            with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()

            # Extract [[wikilinks]]
            wikilinks = re.findall(r'\[\[([^\]|#]+?)(?:[|#][^\]]*)?\]\]', content)
            refs = []
            for wl in wikilinks:
                wl = wl.strip()
                # Try to resolve wikilink to a real file path
                # Search for a matching file anywhere under target
                wl_lower = wl.lower().replace(' ', '-')
                for search_dir, _, search_files in os.walk(target):
                    for sf in search_files:
                        if sf.endswith('.md'):
                            sf_base = os.path.splitext(sf)[0].lower()
                            if sf_base == wl_lower or sf == wl or sf_base == wl.lower():
                                sfpath = os.path.join(search_dir, sf)
                                rel_sf = os.path.relpath(sfpath, target).replace('\\', '/')
                                if not should_exclude(rel_sf) and rel_sf not in refs:
                                    refs.append(rel_sf)
            graph[rel_file] = refs

now_iso = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Write YAML manually (no pyyaml)
lines = [f"generated_at: {now_iso}", "graph:"]
for key in sorted(graph.keys()):
    refs = graph[key]
    if refs:
        lines.append(f'  "{key}":')
        for r in sorted(refs):
            lines.append(f'    - "{r}"')
    else:
        lines.append(f'  "{key}": []')

with open(out_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')

print(f"OK depgraph written: {out_path}")
PYEOF
