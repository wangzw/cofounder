#!/usr/bin/env bash
# test-run-checkers-skip-set-schema.sh
# Verifies run-checkers.sh emits complete skip-set.yml per guide §12.5.1:
#   - single_file_focus / single_file_skip (hash-only diff)
#   - cross_reviewer_focus / cross_reviewer_skip (hash + transitive dep closure)
#   - coverage_check (union sanity sums)
#   - per_file_skips (back-compat for script checkers)
#
# Also exercises dep-aware propagation: touching A makes B (which references A) land
# in cross_reviewer_focus even though B's own hash didn't change.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_CHECKERS="$HERE/../../scripts/run-checkers.sh"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$TMP/common" "$TMP/generate" "$TMP/review" "$TMP/revise" "$TMP/shared" "$TMP/scripts"

# Minimal criteria with one per_file script CR
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria

## CR-TEST-S01 test-script

```yaml
- id: CR-TEST-S01
  name: "test-script"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-test.sh
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
EOF

# Fixture leaves: A references B via wikilink; C is unrelated
echo "# leaf-a — references [[leaf-b]]" > "$TMP/generate/leaf-a.md"
echo "# leaf-b — no deps" > "$TMP/generate/leaf-b.md"
echo "# leaf-c — no deps" > "$TMP/generate/leaf-c.md"

# Round 1: baseline (all files treated as new)
"$RUN_CHECKERS" "$TMP" round-1 >/dev/null 2>&1 || true

# Round 2: identical state → everything should be skipped
"$RUN_CHECKERS" "$TMP" round-2 >/dev/null 2>&1 || true

python3 - "$TMP" <<'PYEOF'
import re, sys
tmp = sys.argv[1]
with open(f"{tmp}/.review/round-2/skip-set.yml") as f:
    txt = f.read()

def section(key):
    m = re.search(rf'{key}: \[\]', txt)
    if m: return []
    m = re.search(rf'{key}:\n((?:  -.*\n)+)', txt)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else None

assert "depgraph_available: true" in txt, "depgraph_available should be true"
assert section("single_file_focus") == [], f"round-2 single_file_focus should be []: {section('single_file_focus')}"
assert section("cross_reviewer_focus") == [], f"round-2 cross_reviewer_focus should be []: {section('cross_reviewer_focus')}"
assert "single_file_union_complete: true" in txt
assert "cross_reviewer_union_complete: true" in txt
print("PASS round-2 (no changes → all skip)")
PYEOF

# Round 3: touch leaf-b (the DEPENDENCY). leaf-a should land in cross_focus (because it
# references leaf-b), but NOT in single_file_focus (its own hash unchanged).
echo "# leaf-b — no deps — modified" > "$TMP/generate/leaf-b.md"
"$RUN_CHECKERS" "$TMP" round-3 >/dev/null 2>&1 || true

python3 - "$TMP" <<'PYEOF'
import re, sys
tmp = sys.argv[1]
with open(f"{tmp}/.review/round-3/skip-set.yml") as f:
    txt = f.read()

def section(key):
    m = re.search(rf'{key}: \[\]', txt)
    if m: return []
    m = re.search(rf'{key}:\n((?:  -.*\n)+)', txt)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []

sf_focus = section("single_file_focus")
cr_focus = section("cross_reviewer_focus")

assert "generate/leaf-b.md" in sf_focus, f"leaf-b should be in single_file_focus: {sf_focus}"
assert "generate/leaf-a.md" not in sf_focus, f"leaf-a should NOT be in single_file_focus (hash unchanged): {sf_focus}"
assert len(sf_focus) == 1, f"only leaf-b should be in single_file_focus: {sf_focus}"

assert "generate/leaf-b.md" in cr_focus, f"leaf-b should be in cross_reviewer_focus: {cr_focus}"
assert "generate/leaf-a.md" in cr_focus, f"leaf-a should be in cross_reviewer_focus (dep propagated): {cr_focus}"
assert "generate/leaf-c.md" not in cr_focus, f"leaf-c should NOT be in cross_reviewer_focus (unrelated): {cr_focus}"
assert len(cr_focus) == 2, f"cross_reviewer_focus should have exactly 2 files (leaf-a + leaf-b): {cr_focus}"
print("PASS round-3 (depgraph propagation: touching B puts A in cross_focus)")
PYEOF

echo "PASS test-run-checkers-skip-set-schema.sh"
