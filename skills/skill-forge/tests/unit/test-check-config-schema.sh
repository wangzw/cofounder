#!/usr/bin/env bash
# test-check-config-schema.sh — unit tests for check-config-schema.sh (CR-S06/S11)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-config-schema.sh"
SKILL_FORGE="$HERE/../.."  # skill-forge itself is the positive fixture

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — valid config, expect 0 issues, exit 0
OUT=$("$SCRIPT" "$SKILL_FORGE" 2>/dev/null)
CODE=$?
run_json "$OUT"
ISSUES=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$CODE" -eq 0 ] || { echo "FAIL: exit $CODE (expected 0) for skill-forge itself; issues=$ISSUES; out=$OUT"; exit 1; }
[ "$ISSUES" -eq 0 ] || { echo "FAIL: expected 0 issues, got $ISSUES; out=$OUT"; exit 1; }

# Test 2: truncated config (missing keys) — expect CR-S06 issues, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/bad-config/common"
cat > "$TMP/bad-config/common/config.yml" <<'YAML'
skill_version: 0.1.0
convergence:
  max_iterations: 5
YAML
OUT=$("$SCRIPT" "$TMP/bad-config" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for truncated config"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S06' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S06 not reported for truncated config"; exit 1; }

# Test 3: config with wrong user-interaction — expect CR-S11 issue, exit 1
mkdir -p "$TMP/bad-perms/common"
# Copy real config and change orchestrator to have user-interaction: true
python3 -c "
import re, pathlib
src = pathlib.Path('$SKILL_FORGE/common/config.yml').read_text()
bad = src.replace(
    'orchestrator:      {filesystem: \"read-all + write-state + write-dispatch-log\", network: false, execute: \"allow-scripts\", user-interaction: false}',
    'orchestrator:      {filesystem: \"read-all + write-state + write-dispatch-log\", network: false, execute: \"allow-scripts\", user-interaction: true}'
)
pathlib.Path('$TMP/bad-perms/common/config.yml').write_text(bad)
"
OUT=$("$SCRIPT" "$TMP/bad-perms" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for wrong user-interaction"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S11' for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: CR-S11 not reported for wrong user-interaction"; exit 1; }

# Test 4: missing config file — exit 1 with CR-S06
mkdir -p "$TMP/no-config/common"
OUT=$("$SCRIPT" "$TMP/no-config" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for missing config"; exit 1; }

# Test 5: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

echo "PASS test-check-config-schema.sh"
