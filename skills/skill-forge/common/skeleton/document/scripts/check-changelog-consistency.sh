#!/usr/bin/env bash
# check-changelog-consistency.sh — §10.4 CHANGELOG ↔ .review/versions/ alignment
# Usage: check-changelog-consistency.sh <target-skill-dir>
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

changelog_path = os.path.join(target, 'CHANGELOG.md')
versions_dir = os.path.join(target, '.review', 'versions')

changelog_exists = os.path.isfile(changelog_path)
versions_exists = os.path.isdir(versions_dir)

# If neither exists: target hasn't converged yet — OK
if not changelog_exists and not versions_exists:
    print("[]")
    sys.exit(0)

# Parse CHANGELOG.md delivery entries: ## Delivery <N> — ...
changelog_ids = {}  # delivery_id (int) -> line number
if changelog_exists:
    with open(changelog_path, 'r', encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            m = re.match(r'^##\s+Delivery\s+(\d+)\s*[—\-]', line.strip())
            if m:
                did = int(m.group(1))
                changelog_ids[did] = lineno

# Parse .review/versions/<N>.md files and extract delivery_id
versions_ids = {}  # delivery_id (int) -> filename
if versions_exists:
    try:
        for fname in os.listdir(versions_dir):
            m = re.match(r'^(\d+)\.md$', fname)
            if m:
                file_num = int(m.group(1))
                fpath = os.path.join(versions_dir, fname)
                # Extract delivery_id from file content
                with open(fpath, 'r', encoding='utf-8') as f:
                    content = f.read()
                did_match = re.search(r'delivery_id\s*:\s*(\d+)', content)
                if did_match:
                    file_did = int(did_match.group(1))
                    versions_ids[file_did] = fname
                    # Check file number matches delivery_id
                    if file_num != file_did:
                        issues.append({
                            "criterion_id": "CR-CHANGELOG",
                            "file": f".review/versions/{fname}",
                            "severity": "error",
                            "description": (
                                f"File {fname} has delivery_id={file_did} "
                                f"but filename implies delivery {file_num}"
                            )
                        })
                else:
                    # No delivery_id in file — use file number
                    versions_ids[file_num] = fname
    except OSError as e:
        sys.stderr.write(f"ERROR: cannot read versions dir: {e}\n")
        sys.exit(2)

# 1. For each CHANGELOG entry: confirm version file exists with matching delivery_id
for did in changelog_ids:
    if did not in versions_ids:
        issues.append({
            "criterion_id": "CR-CHANGELOG",
            "file": "CHANGELOG.md",
            "severity": "error",
            "description": (
                f"CHANGELOG.md has 'Delivery {did}' but "
                f".review/versions/{did}.md does not exist"
            )
        })

# 2. For each version file: confirm CHANGELOG has matching entry
for did in versions_ids:
    if did not in changelog_ids:
        issues.append({
            "criterion_id": "CR-CHANGELOG",
            "file": f".review/versions/{versions_ids[did]}",
            "severity": "error",
            "description": (
                f".review/versions/{versions_ids[did]} exists "
                f"but CHANGELOG.md has no 'Delivery {did}' entry"
            )
        })

# 3. delivery_id values must be monotonic (no gaps)
all_ids = sorted(set(list(changelog_ids.keys()) + list(versions_ids.keys())))
if all_ids:
    expected = list(range(1, len(all_ids) + 1))
    if all_ids != expected:
        issues.append({
            "criterion_id": "CR-CHANGELOG",
            "file": "CHANGELOG.md",
            "severity": "error",
            "description": (
                f"delivery_id sequence is not monotonic 1,2,3,...; "
                f"found: {all_ids}, expected: {expected}"
            )
        })

print(json.dumps(issues))
if any(i['severity'] in ('critical', 'error') for i in issues):
    sys.exit(1)
PYEOF
