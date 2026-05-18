#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/run-state-init.sh"

start_test "init creates run-state.json with expected schema"
plan=$(mktempdir); mkdir -p "$plan"
# Module index JSON (the script's input contract — orchestrator emits this
# from the design README's Module Index table).
cat > "$plan/modules.json" <<'JSON'
[
  {"id": "M-001", "deps": []},
  {"id": "M-002", "deps": ["M-001"]}
]
JSON
bash "$SCRIPT" "$plan" "$plan/modules.json"
test -f "$plan/run-state.json" || fail "run-state.json not created"
out=$(python3 -c "
import json
s = json.load(open('$plan/run-state.json'))
assert s['version'] == 1
assert set(s['modules'].keys()) == {'M-001', 'M-002'}
assert s['modules']['M-002']['tier'] == 2
assert s['scheduler']['max_modules'] == 6
print('OK')
")
assert_stdout_contains "OK" "$out"

start_test "init refuses to overwrite an existing run-state.json"
plan=$(mktempdir); mkdir -p "$plan"
echo '{"version":1,"modules":{}}' > "$plan/run-state.json"
cat > "$plan/modules.json" <<'JSON'
[{"id":"M-001","deps":[]}]
JSON
set +e
out=$(bash "$SCRIPT" "$plan" "$plan/modules.json" 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

start_test "init rejects missing modules.json"
plan=$(mktempdir); mkdir -p "$plan"
set +e
out=$(bash "$SCRIPT" "$plan" "$plan/missing.json" 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

start_test "init rejects dep referencing unknown module"
plan=$(mktempdir); mkdir -p "$plan"
cat > "$plan/modules.json" <<'JSON'
[{"id":"M-001","deps":["M-999"]}]
JSON
set +e
out=$(bash "$SCRIPT" "$plan" "$plan/modules.json" 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

start_test "init rejects duplicate module ids"
plan=$(mktempdir); mkdir -p "$plan"
cat > "$plan/modules.json" <<'JSON'
[{"id":"M-001","deps":[]},{"id":"M-001","deps":[]}]
JSON
set +e
out=$(bash "$SCRIPT" "$plan" "$plan/modules.json" 2>&1)
rc=$?
set -e
assert_exit_code 2 "$rc" "$out"

summary
