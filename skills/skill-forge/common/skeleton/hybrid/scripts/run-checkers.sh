#!/usr/bin/env bash
# run-checkers.sh — master checker runner §12.5 Phase A + Phase B
# Usage: run-checkers.sh <target-skill-dir> <round-N>
# Writes: manifest.yml, depgraph.yml, skip-set.yml, issues/round-checker-output.json
# Exit: 0=no critical/error issues, 1=has critical/error issues, 2=script error
set -euo pipefail

# ====================================================================
# VARIANT: hybrid
# Phase B SHOULD route checkers by file type:
#   - markdown → run document checkers (existing check-*.sh)
#   - source code → run code variant checkers
#   - schemas → run schema variant checkers
#   - cross-type consistency: `documented API matches implementation`
# These dispatch rules are not wired for v1 — writer sub-agent adds them.
# ====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

if ! echo "$ROUND" | grep -qE '^round-[0-9]+$'; then
  echo "ERROR: round must be 'round-N' format; got '$ROUND'" >&2
  exit 2
fi

ROUND_NUM="${ROUND#round-}"
PREV_ROUND_NUM=$((ROUND_NUM - 1))
ROUND_DIR="${TARGET}/.review/${ROUND}"
PREV_ROUND_DIR="${TARGET}/.review/round-${PREV_ROUND_NUM}"

mkdir -p "${ROUND_DIR}/issues"

# ─────────────────────────────────────────────
# Phase A: manifest + depgraph + skip-set
# ─────────────────────────────────────────────

python3 - "$TARGET" "$ROUND_DIR" "$PREV_ROUND_DIR" <<'PYEOF'
import sys, os, hashlib, json
from datetime import datetime, timezone

target = sys.argv[1]
round_dir = sys.argv[2]
prev_round_dir = sys.argv[3]

def should_exclude(rel_path):
    parts = rel_path.replace('\\', '/').split('/')
    if parts[0] == '.review':
        return True
    if len(parts) >= 2 and parts[0] == 'common' and parts[1] == 'skeleton':
        return True
    return False

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

# Build manifest
leaves = {}
for dirpath, dirnames, filenames in os.walk(target):
    rel_dir = os.path.relpath(dirpath, target)
    if should_exclude(rel_dir):
        dirnames.clear()
        continue
    dirnames[:] = [d for d in dirnames if not d.startswith('.') and
                   not should_exclude(os.path.join(rel_dir, d).lstrip('./'))]
    for fname in filenames:
        fpath = os.path.join(dirpath, fname)
        rel_file = os.path.relpath(fpath, target).replace('\\', '/')
        if should_exclude(rel_file):
            continue
        try:
            sha = sha256_file(fpath)
            line_count = sum(1 for _ in open(fpath, 'rb'))
            leaves[rel_file] = {'sha256': sha, 'line_count': line_count}
        except OSError:
            pass

now_iso = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Write manifest.yml
manifest_path = os.path.join(round_dir, 'manifest.yml')
with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(f"generated_at: {now_iso}\n")
    f.write("leaves:\n")
    for rel_file in sorted(leaves.keys()):
        info = leaves[rel_file]
        f.write(f'  "{rel_file}":\n')
        f.write(f'    sha256: "{info["sha256"]}"\n')
        f.write(f'    line_count: {info["line_count"]}\n')

# Load previous manifest if exists
prev_manifest_path = os.path.join(prev_round_dir, 'manifest.yml') if prev_round_dir != os.path.join(os.path.dirname(round_dir), 'round-0') else ''
prev_leaves = {}
if os.path.isfile(prev_manifest_path):
    import re
    current_file = None
    with open(prev_manifest_path, 'r', encoding='utf-8') as f:
        for line in f:
            m_file = re.match(r'^\s+"([^"]+)":\s*$', line)
            m_sha = re.match(r'^\s+sha256:\s+"([^"]+)"', line)
            if m_file:
                current_file = m_file.group(1)
            elif m_sha and current_file:
                prev_leaves[current_file] = m_sha.group(1)

# Write unchanged files to skip-set
# (skip-set used by Phase B for per_file criteria)
unchanged = [f for f, info in leaves.items() if prev_leaves.get(f) == info['sha256']]

# We'll write skip-set after loading criteria (Phase B will use it)
# For now, emit as JSON for the Phase B python to read
state = {
    'leaves': leaves,
    'unchanged': unchanged,
    'manifest_path': manifest_path,
    'round_dir': round_dir
}
state_path = os.path.join(round_dir, '_phase_a_state.json')
with open(state_path, 'w') as f:
    json.dump(state, f)
print(f"OK manifest written: {manifest_path}")
PYEOF

# Run depgraph
"${SCRIPT_DIR}/build-depgraph.sh" "$TARGET" "$ROUND" >/dev/null 2>&1 || true

# ─────────────────────────────────────────────
# Phase B: extract criteria, run script checkers
# ─────────────────────────────────────────────

CRITERIA_JSON=$("${SCRIPT_DIR}/extract-criteria.sh" "$TARGET" 2>/dev/null) || {
  echo "ERROR: failed to extract criteria from target" >&2
  exit 2
}

set +e
SKILL_FORGE_SCRIPTS_DIR="$SCRIPT_DIR" python3 - "$TARGET" "$ROUND_DIR" "$CRITERIA_JSON" <<'PYEOF'
import sys, os, json, subprocess, re

target = sys.argv[1]
round_dir = sys.argv[2]
criteria_json = sys.argv[3]

try:
    criteria = json.loads(criteria_json)
except json.JSONDecodeError as e:
    sys.stderr.write(f"ERROR: bad criteria JSON: {e}\n")
    sys.exit(2)

# Load phase A state
state_path = os.path.join(round_dir, '_phase_a_state.json')
with open(state_path, 'r') as f:
    state = json.load(f)
leaves = state['leaves']
unchanged = state['unchanged']

# Build skip-set
per_file_skips = {}  # criterion_id -> list of files to skip
for c in criteria:
    cid = c.get('id', '')
    skip = c.get('incremental_skip', 'full_scan')
    if skip == 'per_file':
        per_file_skips[cid] = unchanged

# Write skip-set.yml
skip_set_path = os.path.join(round_dir, 'skip-set.yml')
with open(skip_set_path, 'w', encoding='utf-8') as f:
    f.write("per_file_skips:\n")
    for cid in sorted(per_file_skips.keys()):
        skipped = per_file_skips[cid]
        if skipped:
            f.write(f'  "{cid}":\n')
            for sf in sorted(skipped):
                f.write(f'    - "{sf}"\n')
        else:
            f.write(f'  "{cid}": []\n')

# Run script-type checkers
all_issues = []
scripts_dir = os.path.join(os.path.dirname(__file__) if '__file__' in dir() else os.getcwd())

# Resolve scripts dir from the script itself
scripts_dir = os.path.join(target, '..', '..', 'scripts')
# Actually use the skill-forge scripts dir
# We need to find the scripts dir relative to run-checkers.sh
# run-checkers.sh is in skills/skill-forge/scripts/ — same dir as the checkers
# Pass it as an env var
scripts_dir = os.environ.get('SKILL_FORGE_SCRIPTS_DIR', '')
if not scripts_dir or not os.path.isdir(scripts_dir):
    # Fallback: find scripts dir relative to target or via PATH
    scripts_dir = os.path.join(target, 'scripts')

for c in criteria:
    cid = c.get('id', '')
    checker_type = c.get('checker_type', '')
    script_path = c.get('script_path', '')
    incr_skip = c.get('incremental_skip', 'full_scan')

    # Only run script-type criteria
    if checker_type != 'script':
        continue

    if not script_path:
        continue

    # Resolve script path relative to target
    full_script = os.path.join(target, script_path)
    if not os.path.isfile(full_script):
        # Also try relative to scripts_dir (skill-forge's scripts)
        full_script = os.path.join(scripts_dir, os.path.basename(script_path))
    if not os.path.isfile(full_script):
        sys.stderr.write(f"WARNING: {cid} script not found: {script_path}\n")
        continue

    try:
        result = subprocess.run(
            [full_script, target],
            capture_output=True, timeout=60
        )
        if result.returncode == 2:
            stderr_snippet = result.stderr.decode("utf-8", errors="replace").strip()[:200]
            all_issues.append({
                "criterion_id": cid,
                "file": "scripts/" + script_path.rsplit("/", 1)[-1],
                "severity": "error",
                "description": f"{cid} checker script exited 2 (internal error); criterion not evaluated: {stderr_snippet}",
                "suggested_fix": f"inspect script {script_path} stderr for root cause"
            })
            continue
        stdout = result.stdout.decode("utf-8", errors="replace").strip()
        if stdout:
            try:
                checker_issues = json.loads(stdout)
                if isinstance(checker_issues, list):
                    all_issues.extend(checker_issues)
            except json.JSONDecodeError:
                sys.stderr.write(f"WARNING: {cid} produced non-JSON stdout: {stdout[:100]}\n")
    except subprocess.TimeoutExpired:
        sys.stderr.write(f"WARNING: {cid} timed out\n")
    except Exception as e:
        sys.stderr.write(f"WARNING: {cid} error: {e}\n")

# Write output
out_path = os.path.join(round_dir, 'issues', 'round-checker-output.json')
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(all_issues, f, indent=2)

print(f"OK checker output written: {out_path} ({len(all_issues)} issues)")

# Clean up temp state
try:
    os.remove(state_path)
except OSError:
    pass

has_blocking = any(i.get('severity') in ('critical', 'error') for i in all_issues)
if has_blocking:
    sys.exit(1)
PYEOF
EXIT_CODE=$?
set -e
if [ $EXIT_CODE -eq 1 ]; then
  echo "INFO: checkers found critical/error issues (exit 1)" >&2
fi
exit $EXIT_CODE
