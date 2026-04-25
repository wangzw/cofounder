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

echo "=== PASS test-check-drift.sh (5 sub-tests) ==="
