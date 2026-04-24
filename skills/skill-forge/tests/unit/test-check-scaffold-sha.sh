#!/usr/bin/env bash
# test-check-scaffold-sha.sh — unit tests for check-scaffold-sha.sh (CR-S12)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-scaffold-sha.sh"
SKILL_FORGE="$HERE/../.."

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — sha256 pins must match (positive fixture)
OUT=$("$SCRIPT" "$SKILL_FORGE" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for skill-forge; issues=$ISSUES; out=$OUT"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: no manifest — expect 0 issues (no-op), exit 0
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/no-manifest/common/skeleton"
OUT=$("$SCRIPT" "$TMP/no-manifest" 2>/dev/null)
CODE=$?
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for no-manifest"; exit 1; }

# Test 3: manifest with wrong sha256 — expect CR-S12, exit 1
mkdir -p "$TMP/wrong-sha/common/skeleton"
mkdir -p "$TMP/wrong-sha/scripts"
echo "dummy content" > "$TMP/wrong-sha/scripts/metrics-aggregate.sh"
cat > "$TMP/wrong-sha/common/skeleton/shared-scripts-manifest.yml" <<'YAML'
files:
  scripts/metrics-aggregate.sh:
    sha256: 0000000000000000000000000000000000000000000000000000000000000000
    upstream: fake
    snapshot_date: 2026-01-01
YAML
OUT=$("$SCRIPT" "$TMP/wrong-sha" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for wrong sha"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S12' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S12 not reported for wrong sha"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-scaffold-sha.sh"
