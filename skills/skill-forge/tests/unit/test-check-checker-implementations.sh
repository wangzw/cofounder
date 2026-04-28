#!/usr/bin/env bash
# test-check-checker-implementations.sh — unit tests for CR-S17 checker.
# CR-S17 verifies that for every CR-Sxx with a script_path declared in
# review-criteria.md, the target's script at that path grep-contains the
# CR-ID string. Catches stale checker drift (R6-V003-004 + meta-bug audit).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-checker-implementations.sh"
SKILL_FORGE="$HERE/../.."

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON: $1"; exit 1; }
}

# Helper: run script, capture stdout + exit code WITHOUT leaking previous values
run_check() {
  set +e
  OUT=$("$SCRIPT" "$1" 2>/dev/null)
  CODE=$?
  set -e
}

# Test 1: skill-forge itself — every CR-Sxx checker should grep-contain its CR-ID
run_check "$SKILL_FORGE"
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: skill-forge expected exit 0, got $CODE"; echo "$OUT"; exit 1; }
[ "$OUT" = "[]" ] || { echo "FAIL: skill-forge expected [], got $OUT"; exit 1; }
echo "PASS: skill-forge canonical — all CR-Sxx checkers implement their declared CR"

# Test 2: stale-checker fixture — declares CR-SX1 but script does NOT contain it
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/common" "$TMP/scripts"
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria — fixture

## CR-SX1 some-criterion

```yaml
- id: CR-SX1
  name: "some-criterion"
  version: 1.0.0
  checker_type: script
  script_path: scripts/some-checker.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
EOF
cat > "$TMP/scripts/some-checker.sh" <<'EOF'
#!/usr/bin/env bash
# stale checker — does not reference the criterion it claims to implement
echo "[]"
exit 0
EOF
chmod +x "$TMP/scripts/some-checker.sh"

run_check "$TMP"
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: stale fixture expected exit 1, got $CODE"; echo "$OUT"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']=='CR-S17' and 'CR-SX1' in i['description'] for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: expected CR-S17 issue mentioning CR-SX1, got: $OUT"; exit 1; }
echo "PASS: stale-checker fixture flagged correctly"

# Test 3: well-formed checker — script DOES contain CR-ID — no issue
cat > "$TMP/scripts/some-checker.sh" <<'EOF'
#!/usr/bin/env bash
# good checker — implements CR-SX1
echo "implementing CR-SX1 here"
echo "[]"
exit 0
EOF
chmod +x "$TMP/scripts/some-checker.sh"
run_check "$TMP"
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: well-formed fixture expected exit 0, got $CODE"; echo "$OUT"; exit 1; }
[ "$OUT" = "[]" ] || { echo "FAIL: well-formed fixture expected [], got $OUT"; exit 1; }
echo "PASS: well-formed checker — no issue raised"

# Test 4: missing script — CR-S05 territory — CR-S17 silently skips
rm "$TMP/scripts/some-checker.sh"
run_check "$TMP"
run_json "$OUT"
[ "$CODE" -eq 0 ] || { echo "FAIL: missing-script fixture expected exit 0 (CR-S05 owns this), got $CODE"; echo "$OUT"; exit 1; }
[ "$OUT" = "[]" ] || { echo "FAIL: missing-script — expected [] (skip to avoid double-report with CR-S05), got $OUT"; exit 1; }
echo "PASS: missing script — no CR-S17 issue (deferred to CR-S05)"

# Test 5: multiple CRs sharing one script_path — all must be present
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria — fixture

## CR-SX1 first

```yaml
- id: CR-SX1
  name: "first"
  version: 1.0.0
  checker_type: script
  script_path: scripts/multi-checker.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-SX2 second

```yaml
- id: CR-SX2
  name: "second"
  version: 1.0.0
  checker_type: script
  script_path: scripts/multi-checker.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
EOF
# Script implements only CR-SX1; CR-SX2 should be flagged
cat > "$TMP/scripts/multi-checker.sh" <<'EOF'
#!/usr/bin/env bash
# implements CR-SX1 — does not implement the other criterion
echo "[]"
exit 0
EOF
chmod +x "$TMP/scripts/multi-checker.sh"
run_check "$TMP"
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: multi-CR fixture expected exit 1, got $CODE"; echo "$OUT"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(sum(1 for i in d if i['criterion_id']=='CR-S17'))" <<< "$OUT")
[ "$FOUND" = "1" ] || { echo "FAIL: expected exactly 1 CR-S17 issue (for CR-SX2), got $FOUND"; echo "$OUT"; exit 1; }
echo "PASS: multi-CR script — partial implementation flagged for missing CRs only"

# Test 6: missing review-criteria.md → no-op exit 0
TMP2=$(mktemp -d); trap "rm -rf $TMP $TMP2" EXIT
run_check "$TMP2"
[ "$CODE" -eq 0 ] || { echo "FAIL: missing review-criteria.md expected exit 0 (CR-S07 owns), got $CODE"; exit 1; }
[ "$OUT" = "[]" ] || { echo "FAIL: missing review-criteria.md expected [], got $OUT"; exit 1; }
echo "PASS: missing review-criteria.md — no-op (deferred to CR-S07)"

# Test 7: nonexistent target — exit 2
run_check "/nonexistent/path"
[ "$CODE" -eq 2 ] || { echo "FAIL: nonexistent target expected exit 2, got $CODE"; exit 1; }
echo "PASS: nonexistent target → exit 2"

echo "=== PASS test-check-checker-implementations.sh (7 sub-tests) ==="
