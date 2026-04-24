#!/usr/bin/env bash
# test-run-checkers-forced-full.sh
# Verifies run-checkers.sh --full flag (guide §8.6 forced-full override):
#   - skip-set.yml has forced_full: true
#   - single_file_focus + cross_reviewer_focus each contain all leaves
#   - single_file_skip + cross_reviewer_skip each empty
#   - depgraph propagation short-circuited (doesn't matter when everything is focus)
# Contrast: same state WITHOUT --full produces normal incremental skip behavior.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_CHECKERS="$HERE/../../scripts/run-checkers.sh"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$TMP/common" "$TMP/generate" "$TMP/review" "$TMP/revise" "$TMP/shared" "$TMP/scripts"
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria
## CR-TEST-S01 t
```yaml
- id: CR-TEST-S01
  name: "t"
  version: 1.0.0
  checker_type: script
  script_path: scripts/noop.sh
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
EOF
echo "# a" > "$TMP/generate/a.md"
echo "# b" > "$TMP/generate/b.md"
echo "# c" > "$TMP/generate/c.md"

# Round 1: baseline (all new)
"$RUN_CHECKERS" "$TMP" round-1 >/dev/null 2>&1 || true

# Round 2: no changes, incremental — expect all skip
"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

# Round 3: no changes, --full — expect all focus, zero skip
"$RUN_CHECKERS" --full "$TMP" round-3 >/dev/null 2>&1 || true

# Round 4: touch a.md only, no --full — expect 1 file in single_file_focus
echo "# a modified" > "$TMP/generate/a.md"
"$RUN_CHECKERS" "$TMP" round-4 >/dev/null 2>&1 || true

# Round 5: touch a.md again, --full — expect all 3 in focus, zero skip
echo "# a modified again" > "$TMP/generate/a.md"
"$RUN_CHECKERS" --full "$TMP" round-5 >/dev/null 2>&1 || true

python3 - "$TMP" <<'PYEOF'
import re, sys
tmp = sys.argv[1]

def parse(path):
    txt = open(path).read()
    def sect(key):
        m = re.search(rf'{key}: \[\]', txt)
        if m: return []
        m = re.search(rf'{key}:\n((?:  -.*\n)+)', txt)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []
    return {
        'forced_full': 'forced_full: true' in txt,
        'sf_focus': sect('single_file_focus'),
        'sf_skip': sect('single_file_skip'),
        'cr_focus': sect('cross_reviewer_focus'),
        'cr_skip': sect('cross_reviewer_skip'),
    }

r2 = parse(f"{tmp}/.review/round-2/skip-set.yml")
r3 = parse(f"{tmp}/.review/round-3/skip-set.yml")
r4 = parse(f"{tmp}/.review/round-4/skip-set.yml")
r5 = parse(f"{tmp}/.review/round-5/skip-set.yml")

# Round 2: incremental, no changes → all skip
TOTAL = 4  # 3 generate/*.md + 1 common/review-criteria.md
assert r2['forced_full'] is False, "round-2 should not be forced_full"
assert len(r2['sf_focus']) == 0, f"round-2 sf_focus should be empty: {r2['sf_focus']}"
assert len(r2['sf_skip']) == TOTAL, f"round-2 sf_skip should have all {TOTAL}: {r2['sf_skip']}"
print("PASS round-2 (incremental, no changes → all skip)")

# Round 3: forced-full, no changes → all focus despite no changes
assert r3['forced_full'] is True, "round-3 should be forced_full"
assert len(r3['sf_focus']) == TOTAL, f"round-3 sf_focus should have all {TOTAL}: {r3['sf_focus']}"
assert len(r3['sf_skip']) == 0, f"round-3 sf_skip should be empty: {r3['sf_skip']}"
assert len(r3['cr_focus']) == TOTAL, f"round-3 cr_focus should have all {TOTAL}: {r3['cr_focus']}"
assert len(r3['cr_skip']) == 0, f"round-3 cr_skip should be empty: {r3['cr_skip']}"
print("PASS round-3 (--full, no changes → all focus)")

# Round 4: incremental, 1 touched file → exactly 1 in sf_focus
assert r4['forced_full'] is False
assert r4['sf_focus'] == ['generate/a.md'], f"round-4 sf_focus should be [a.md]: {r4['sf_focus']}"
print("PASS round-4 (incremental, 1 touched → 1 focus)")

# Round 5: --full overrides the 1-touched-only behavior → all files in focus
assert r5['forced_full'] is True
assert len(r5['sf_focus']) == TOTAL, f"round-5 sf_focus should have all {TOTAL} (--full): {r5['sf_focus']}"
assert len(r5['sf_skip']) == 0, f"round-5 sf_skip should be empty (--full): {r5['sf_skip']}"
print("PASS round-5 (--full overrides incremental)")
PYEOF

echo "PASS test-run-checkers-forced-full.sh"
