#!/usr/bin/env bash
# test-check-drift.sh — smoke tests for scripts/check-drift.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-drift.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Test 1: missing/invalid target → exit 2
set +e
"$SCRIPT" /tmp/nonexistent-$$ >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "2" ] || { echo "FAIL: missing target expected exit 2, got $ec"; exit 1; }
echo "PASS: missing target exits 2"

# Test 2: non-git dir → exit 1 (not 2)
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
set +e
"$SCRIPT" "$TMP" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: non-git expected exit 1, got $ec"; exit 1; }
echo "PASS: non-git exits 1"

# Test 3: git repo with no delivery-* tags → exit 1
(cd "$TMP" && git init -q && echo SKILL > SKILL.md && git add . && git -c user.email=t@t -c user.name=t commit -q -m "init")
set +e
"$SCRIPT" "$TMP" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: no delivery tag expected exit 1, got $ec"; exit 1; }
echo "PASS: no delivery tag exits 1"

# Test 4: tagged + no drift → exit 0 with no-drift message
(cd "$TMP" && git tag -a delivery-1-init -m "d1" HEAD)
out=$("$SCRIPT" "$TMP" 2>/dev/null)
[ "$?" = "0" ] || true
echo "$out" | grep -q "no-drift since delivery-1-init" \
  || { echo "FAIL: expected no-drift message, got: $out"; exit 1; }
echo "PASS: tagged + no drift → no-drift message"

# Test 5: drift after tag → exit 1
(cd "$TMP" && echo "drift" >> SKILL.md && git add . && git -c user.email=t@t -c user.name=t commit -q -m "drift")
set +e
"$SCRIPT" "$TMP" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: drift expected exit 1, got $ec"; exit 1; }
echo "PASS: drift after tag exits 1"

# Regression tests for the working-tree drift fix (commit c115c31).
# Before the fix `git diff TAG HEAD` was used, which only saw committed drift.
# Review/revise cycles routinely modify the leaf without committing, so the
# short-circuit would falsely report no-drift on a locally-edited tree and
# skip the LLM review entirely.

# Fresh fixture for the working-tree tests
TMP2=$(mktemp -d)
trap "rm -rf $TMP $TMP2" EXIT
(cd "$TMP2" && git init -q \
    && echo SKILL > SKILL.md \
    && git add . \
    && git -c user.email=t@t -c user.name=t commit -q -m "init" \
    && git tag -a delivery-1-init -m "d1" HEAD)

# Test 6: uncommitted edit → drift detected (the original bug)
(cd "$TMP2" && echo "uncommitted change" >> SKILL.md)
set +e
"$SCRIPT" "$TMP2" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: uncommitted edit expected exit 1, got $ec"; exit 1; }
# Restore for next test
(cd "$TMP2" && git checkout -- SKILL.md)
echo "PASS: uncommitted edit triggers drift"

# Test 7: untracked file under target → drift detected
(cd "$TMP2" && touch new-leaf.md)
set +e
"$SCRIPT" "$TMP2" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: untracked file expected exit 1, got $ec"; exit 1; }
(cd "$TMP2" && rm new-leaf.md)
echo "PASS: untracked file triggers drift"

# Test 8: untracked file under .review/ → no drift (meta-archive excluded)
(cd "$TMP2" && mkdir -p .review && touch .review/round-1-junk.md)
set +e
out=$("$SCRIPT" "$TMP2" 2>/dev/null)
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: untracked under .review/ expected exit 0, got $ec"; exit 1; }
echo "$out" | grep -q "no-drift" || { echo "FAIL: expected no-drift message, got: $out"; exit 1; }
(cd "$TMP2" && rm -rf .review)
echo "PASS: untracked under .review/ does not trigger drift"

# Test 9: clean working tree (still byte-identical to tag) → no-drift
set +e
out=$("$SCRIPT" "$TMP2" 2>/dev/null)
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: clean tree expected exit 0, got $ec"; exit 1; }
echo "$out" | grep -q "no-drift since delivery-1-init" || { echo "FAIL: expected no-drift message, got: $out"; exit 1; }
echo "PASS: clean working tree → no-drift"

# Test 10: repo with target as a SUBDIR (mimics the production layout where
# the target is e.g. skills/prd-analysis inside a larger repo). Verify the
# .review/ exclusion still works when REL_TARGET is non-trivial.
TMP3=$(mktemp -d)
trap "rm -rf $TMP $TMP2 $TMP3" EXIT
(cd "$TMP3" && git init -q \
    && mkdir -p skill && echo SKILL > skill/SKILL.md \
    && git add . \
    && git -c user.email=t@t -c user.name=t commit -q -m "init" \
    && git tag -a delivery-1-sub -m "d1" HEAD)
# Untracked file inside the target's .review/ — must be excluded.
(cd "$TMP3" && mkdir -p skill/.review && touch skill/.review/junk.md)
set +e
out=$("$SCRIPT" "$TMP3/skill" 2>/dev/null)
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: subdir target with untracked under .review/ expected exit 0, got $ec"; exit 1; }
echo "$out" | grep -q "no-drift since delivery-1-sub" \
  || { echo "FAIL: expected no-drift message for subdir target, got: $out"; exit 1; }
# Untracked file OUTSIDE .review/ but inside target — must trigger drift.
(cd "$TMP3" && touch skill/new-leaf.md)
set +e
"$SCRIPT" "$TMP3/skill" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: subdir target with untracked outside .review/ expected exit 1, got $ec"; exit 1; }
echo "PASS: subdir target — .review/ exclusion + drift detection both work"

# Regression tests for the reviewer-drift fix.
# Before the fix, drift was computed only against the TARGET tree. If
# skill-forge itself (the reviewer logic — criteria, checkers, prompts) was
# modified after the baseline tag, the no-drift gate would still short-circuit
# the review, suppressing issues that the new reviewer logic would surface.
# The fix reads `skill_forge_dir` from <target>/.review/state.yml and includes
# its diff against the baseline tag in the drift computation.

# Helper: build a fixture repo with a target skill AND a sibling skill-forge
# directory, both committed at the baseline tag.
make_dual_repo() {
  local repo="$1"
  (cd "$repo" && git init -q \
      && mkdir -p target/.review skill-forge/scripts skill-forge/common \
      && echo "SKILL" > target/SKILL.md \
      && echo "criteria-v1" > skill-forge/common/review-criteria.md \
      && echo "#!/bin/sh" > skill-forge/scripts/check-drift.sh \
      && chmod +x skill-forge/scripts/check-drift.sh \
      && git add . \
      && git -c user.email=t@t -c user.name=t commit -q -m "init" \
      && git tag -a delivery-1-init -m "d1" HEAD)
  cat > "$repo/target/.review/state.yml" <<EOF
skill_forge_dir: $repo/skill-forge
delivery_id: 1
current_round: 1
EOF
}

# Test 11: skill-forge drift in same repo → drift detected (THE BUG)
TMP4=$(mktemp -d)
trap "rm -rf $TMP $TMP2 $TMP3 $TMP4" EXIT
make_dual_repo "$TMP4"
# Modify a reviewer-relevant file in skill-forge; target tree is untouched.
(cd "$TMP4" && echo "criteria-v2-new-rule" >> skill-forge/common/review-criteria.md)
set +e
"$SCRIPT" "$TMP4/target" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: skill-forge drift in same repo expected exit 1, got $ec"; exit 1; }
echo "PASS: skill-forge drift in same repo triggers drift"

# Test 12: clean target + clean skill-forge → no-drift (fix must not regress)
TMP5=$(mktemp -d)
trap "rm -rf $TMP $TMP2 $TMP3 $TMP4 $TMP5" EXIT
make_dual_repo "$TMP5"
set +e
out=$("$SCRIPT" "$TMP5/target" 2>/dev/null)
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: clean dual-repo expected exit 0, got $ec"; exit 1; }
echo "$out" | grep -q "no-drift since delivery-1-init" \
  || { echo "FAIL: expected no-drift message, got: $out"; exit 1; }
echo "PASS: clean target + clean skill-forge → no-drift"

# Test 13: skill-forge in different repo → warning, fallback to target-only check
TMP6_TARGET=$(mktemp -d)
TMP6_FORGE=$(mktemp -d)
trap "rm -rf $TMP $TMP2 $TMP3 $TMP4 $TMP5 $TMP6_TARGET $TMP6_FORGE" EXIT
(cd "$TMP6_TARGET" && git init -q \
    && mkdir -p .review \
    && echo "SKILL" > SKILL.md \
    && git add . \
    && git -c user.email=t@t -c user.name=t commit -q -m "init" \
    && git tag -a delivery-1-cross -m "d1" HEAD)
(cd "$TMP6_FORGE" && git init -q \
    && echo "criteria-v1" > review-criteria.md \
    && git add . \
    && git -c user.email=t@t -c user.name=t commit -q -m "init")
cat > "$TMP6_TARGET/.review/state.yml" <<EOF
skill_forge_dir: $TMP6_FORGE
delivery_id: 1
current_round: 1
EOF
# Even with skill-forge "drifted" (different repo, can't verify), target is clean
# → fall back to target-only check, exit 0, but emit a stderr warning.
set +e
out=$("$SCRIPT" "$TMP6_TARGET" 2>/tmp/cdrift-stderr-$$)
ec=$?
err=$(cat /tmp/cdrift-stderr-$$); rm -f /tmp/cdrift-stderr-$$
set -e
[ "$ec" = "0" ] || { echo "FAIL: cross-repo skill-forge expected exit 0 with target clean, got $ec"; exit 1; }
echo "$err" | grep -qi "skill-forge.*different repo\|cannot verify reviewer drift" \
  || { echo "FAIL: expected stderr warning about cross-repo skill-forge, got: $err"; exit 1; }
echo "PASS: cross-repo skill-forge → warning + target-only fallback"

# Test 14: state.yml missing skill_forge_dir → no skill-forge check, target-only
TMP7=$(mktemp -d)
trap "rm -rf $TMP $TMP2 $TMP3 $TMP4 $TMP5 $TMP6_TARGET $TMP6_FORGE $TMP7" EXIT
(cd "$TMP7" && git init -q \
    && mkdir -p .review \
    && echo "SKILL" > SKILL.md \
    && git add . \
    && git -c user.email=t@t -c user.name=t commit -q -m "init" \
    && git tag -a delivery-1-nostate -m "d1" HEAD)
# Empty state.yml — no skill_forge_dir key.
echo "delivery_id: 1" > "$TMP7/.review/state.yml"
set +e
out=$("$SCRIPT" "$TMP7" 2>/dev/null)
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: missing skill_forge_dir expected exit 0 (target-only), got $ec"; exit 1; }
echo "$out" | grep -q "no-drift since delivery-1-nostate" \
  || { echo "FAIL: expected no-drift, got: $out"; exit 1; }
echo "PASS: missing skill_forge_dir → target-only check"

echo "=== PASS test-check-drift.sh (14 sub-tests) ==="
