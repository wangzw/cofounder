#!/usr/bin/env bash
# prune-traces.sh — §8.8 retention-based trace pruning
# Usage: prune-traces.sh <target-skill-dir> [<retention-rounds>]
# Default retention: 20 (from config.yml or hardcoded default)
# Exit: 0=success, 2=error
set -euo pipefail

TARGET="${1:-}"
RETENTION="${2:-}"

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

# Determine retention: CLI arg > config.yml > default 20
if [ -z "$RETENTION" ]; then
  CONFIG_FILE="${TARGET}/common/config.yml"
  if [ -f "$CONFIG_FILE" ]; then
    RETENTION=$(grep -E '^\s*retention_rounds\s*:' "$CONFIG_FILE" | head -1 | sed 's/.*:\s*//' | tr -d ' "' || echo "")
  fi
  RETENTION="${RETENTION:-20}"
fi

# Validate retention is a positive integer
if ! echo "$RETENTION" | grep -qE '^[1-9][0-9]*$'; then
  echo "ERROR: retention must be a positive integer; got '${RETENTION}'" >&2
  exit 2
fi

python3 - "$TARGET" "$RETENTION" <<'PYEOF'
import sys, os, glob, re

target = sys.argv[1]
retention = int(sys.argv[2])

traces_dir = os.path.join(target, '.review', 'traces')

if not os.path.isdir(traces_dir):
    # No traces yet — nothing to prune
    print("OK pruned rounds <= 0 (no traces dir)")
    sys.exit(0)

# Find all round-N directories under traces/
round_dirs = []
for name in os.listdir(traces_dir):
    m = re.match(r'^round-(\d+)$', name)
    if m:
        rpath = os.path.join(traces_dir, name)
        if os.path.isdir(rpath):
            round_dirs.append((int(m.group(1)), rpath))

if not round_dirs:
    print("OK pruned rounds <= 0 (no round dirs in traces)")
    sys.exit(0)

current_round = max(n for n, _ in round_dirs)
cutoff = current_round - retention

if cutoff <= 0:
    print(f"OK pruned rounds <= {cutoff} (nothing to prune; current={current_round}, retention={retention})")
    sys.exit(0)

pruned_count = 0
for round_num, rpath in round_dirs:
    if round_num <= cutoff:
        for fname in os.listdir(rpath):
            if fname.endswith('.yml'):
                fpath = os.path.join(rpath, fname)
                try:
                    os.remove(fpath)
                    pruned_count += 1
                except OSError as e:
                    sys.stderr.write(f"WARNING: could not delete {fpath}: {e}\n")
            # KEEP dispatch-log.jsonl — never delete (audit trail)

print(f"OK pruned rounds <= {cutoff} ({pruned_count} yml files removed)")
PYEOF
