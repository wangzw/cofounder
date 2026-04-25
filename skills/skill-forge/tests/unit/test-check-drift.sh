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

echo "=== PASS test-check-drift.sh (10 sub-tests) ==="
