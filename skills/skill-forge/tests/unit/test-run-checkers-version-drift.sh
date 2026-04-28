#!/usr/bin/env bash
# test-run-checkers-version-drift.sh — regression guard for the auto-force-full
# on reviewer version change.
#
# Bug: when skill-forge bumps version (new criteria, new prompts, new logic),
# run-checkers.sh would still produce an INCREMENTAL skip-set based on
# target-tree drift only, missing leaves that pass under old criteria but
# fail under new criteria. Same architecture as round-6 stale-checker bug,
# but at the criteria/prompt level.
#
# Fix: run-checkers.sh reads `reviewer_version_seen` from target's
# state.yml, compares to skill-forge's current SKILL.md version, and
# auto-forces --full when they differ. After successful run, updates
# state.yml's reviewer_version_seen.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/run-checkers.sh"
SKILL_FORGE="$(cd "$HERE/../.." && pwd)"

[ -x "$SCRIPT" ] || { echo "FAIL: run-checkers.sh not executable"; exit 1; }

# Build a minimal target fixture (just enough for run-checkers to produce skip-set)
build_fixture() {
  local target="$1"
  local seen_version="$2"
  mkdir -p "$target/scripts" "$target/common" "$target/.review"
  # Minimal review-criteria.md (no script_path declarations → Phase B is empty)
  cat > "$target/common/review-criteria.md" <<'EOF'
# Review Criteria — fixture

## CR-LX1 placeholder

```yaml
- id: CR-LX1
  name: "placeholder"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
EOF
  # Minimal manifest source
  cat > "$target/SKILL.md" <<'EOF'
---
name: fixture
version: 1.0.0
description: "Use when running tests."
---

# fixture
EOF
  cat > "$target/.review/state.yml" <<EOF
skill_forge_dir: $SKILL_FORGE
delivery_id: 1
current_round: 1
target: $target
EOF
  if [ -n "$seen_version" ]; then
    echo "reviewer_version_seen: \"$seen_version\"" >> "$target/.review/state.yml"
  fi
}

# Test 1: state.yml has matching reviewer_version_seen → no auto-force
TMP1=$(mktemp -d); trap "rm -rf $TMP1" EXIT
CURRENT_VERSION=$(grep -E '^version:' "$SKILL_FORGE/SKILL.md" | head -1 | sed -E 's/^version:[[:space:]]*//')
build_fixture "$TMP1" "$CURRENT_VERSION"
"$SCRIPT" "$TMP1" round-1 >/dev/null 2>&1 || true
SKIP_SET="$TMP1/.review/round-1/skip-set.yml"
[ -f "$SKIP_SET" ] || { echo "FAIL: skip-set.yml not written"; exit 1; }
FORCED=$(grep '^forced_full:' "$SKIP_SET" | awk '{print $2}')
[ "$FORCED" = "false" ] || { echo "FAIL: matching version expected forced_full: false, got $FORCED"; exit 1; }
echo "PASS: matching reviewer version → no auto-force-full"

# Test 2: state.yml has DIFFERENT reviewer_version_seen → auto-force-full
TMP2=$(mktemp -d); trap "rm -rf $TMP1 $TMP2" EXIT
build_fixture "$TMP2" "0.0.1-stale"
"$SCRIPT" "$TMP2" round-1 2>/tmp/r-c-stderr-$$ >/dev/null || true
SKIP_SET="$TMP2/.review/round-1/skip-set.yml"
FORCED=$(grep '^forced_full:' "$SKIP_SET" | awk '{print $2}')
[ "$FORCED" = "true" ] || {
  echo "FAIL: reviewer version drift expected forced_full: true, got $FORCED"
  cat /tmp/r-c-stderr-$$ >&2
  exit 1
}
# Stderr should mention the version drift
grep -qi 'reviewer version' /tmp/r-c-stderr-$$ \
  || { echo "FAIL: stderr should announce the version drift"; cat /tmp/r-c-stderr-$$; exit 1; }
rm -f /tmp/r-c-stderr-$$
echo "PASS: reviewer version drift → auto-force-full + stderr notice"

# Test 3: After successful run, state.yml's reviewer_version_seen is updated
SEEN_AFTER=$(grep -E '^reviewer_version_seen:' "$TMP2/.review/state.yml" | head -1 \
              | sed -E 's/^reviewer_version_seen:[[:space:]]*//' | sed -E 's/^"|"$//g')
[ "$SEEN_AFTER" = "$CURRENT_VERSION" ] || {
  echo "FAIL: state.yml reviewer_version_seen should be updated to $CURRENT_VERSION, got '$SEEN_AFTER'"
  exit 1
}
echo "PASS: state.yml reviewer_version_seen updated to current version"

# Test 4: state.yml has NO reviewer_version_seen (first review) → no auto-force
# (the regular forced_full_cross_review delivery rule covers this, not version drift).
TMP3=$(mktemp -d); trap "rm -rf $TMP1 $TMP2 $TMP3" EXIT
build_fixture "$TMP3" ""  # empty seen version
"$SCRIPT" "$TMP3" round-1 >/dev/null 2>&1 || true
SKIP_SET="$TMP3/.review/round-1/skip-set.yml"
FORCED=$(grep '^forced_full:' "$SKIP_SET" | awk '{print $2}')
[ "$FORCED" = "false" ] || { echo "FAIL: missing reviewer_version_seen expected forced_full: false (delivery rule applies); got $FORCED"; exit 1; }
# But the seen version should now be recorded for next round
SEEN_AFTER=$(grep -E '^reviewer_version_seen:' "$TMP3/.review/state.yml" | head -1 \
              | sed -E 's/^reviewer_version_seen:[[:space:]]*//' | sed -E 's/^"|"$//g')
[ "$SEEN_AFTER" = "$CURRENT_VERSION" ] || {
  echo "FAIL: first-review state.yml should record seen version; got '$SEEN_AFTER'"
  exit 1
}
echo "PASS: first review (no prior seen version) — no auto-force, but seen recorded for next round"

# Test 5: explicit --full still works regardless of version state
TMP4=$(mktemp -d); trap "rm -rf $TMP1 $TMP2 $TMP3 $TMP4" EXIT
build_fixture "$TMP4" "$CURRENT_VERSION"  # versions match
"$SCRIPT" --full "$TMP4" round-1 >/dev/null 2>&1 || true
SKIP_SET="$TMP4/.review/round-1/skip-set.yml"
FORCED=$(grep '^forced_full:' "$SKIP_SET" | awk '{print $2}')
[ "$FORCED" = "true" ] || { echo "FAIL: explicit --full expected forced_full: true; got $FORCED"; exit 1; }
echo "PASS: explicit --full still forces full regardless of version state"

echo "=== PASS test-run-checkers-version-drift.sh (5 sub-tests) ==="
