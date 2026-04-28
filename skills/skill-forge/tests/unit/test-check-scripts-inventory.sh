#!/usr/bin/env bash
# test-check-scripts-inventory.sh — unit tests for check-scripts-inventory.sh (CR-S05)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-scripts-inventory.sh"
SKILL_FORGE="$HERE/../.."

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

run_json() {
  python3 -c "import sys, json; json.loads(sys.stdin.read())" <<< "$1" \
    || { echo "FAIL: output is not valid JSON"; exit 1; }
}

# Test 1: skill-forge itself — will have missing scripts (not all 24 are authored yet).
# We just verify: output is valid JSON, exit is 0 or 1, each issue has CR-S05 criterion_id.
OUT=$("$SKILL_FORGE/scripts/check-scripts-inventory.sh" "$SKILL_FORGE" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
# All issues must reference CR-S05
BAD=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any(i['criterion_id']!='CR-S05' for i in d))" <<< "$OUT")
[ "$BAD" = "False" ] || { echo "FAIL: non-CR-S05 issues found"; exit 1; }

# Test 2: empty scripts dir — all scripts missing, expect many CR-S05 issues, exit 1
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/empty-scripts/scripts"
OUT=$("$SCRIPT" "$TMP/empty-scripts" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for empty scripts dir"; exit 1; }
COUNT=$(python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" <<< "$OUT")
[ "$COUNT" -gt 10 ] || { echo "FAIL: expected >10 issues for empty scripts dir, got $COUNT"; exit 1; }

# Test 3: script present but not executable — expect CR-S05 issue
mkdir -p "$TMP/not-exec/scripts"
touch "$TMP/not-exec/scripts/git-precheck.sh"
chmod -x "$TMP/not-exec/scripts/git-precheck.sh"
OUT=$("$SCRIPT" "$TMP/not-exec" 2>/dev/null) || CODE=$?
CODE=${CODE:-0}
run_json "$OUT"
[ "$CODE" -eq 1 ] || { echo "FAIL: exit $CODE (expected 1) for non-executable script"; exit 1; }
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('git-precheck' in i.get('file','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || { echo "FAIL: non-executable script not flagged"; exit 1; }

# Test 4: non-existent dir — exit 2
"$SCRIPT" /nonexistent/path 2>/dev/null && { echo "FAIL: expected exit 2"; exit 1; } || CODE=$?
[ "$CODE" -eq 2 ] || { echo "FAIL: exit $CODE (expected 2)"; exit 1; }

# Test 5: CR-bound scripts MUST be auto-derived from review-criteria.md.
# Regression guard: when a new CR declares `script_path: scripts/X.sh`, the
# inventory check MUST include X.sh in its required set automatically — no
# manual sync of REQUIRED_SCRIPTS. Before this fix REQUIRED_SCRIPTS was
# hardcoded; CR-S15's `check-skill-md-sections.sh` was silently omitted, and
# review/run-checkers.sh would emit a CR-META-missing-checker issue while
# this script reported "no inventory issues" — contradictory signals.
#
# Fixture: scaffold a fake skill where review-criteria.md declares a CR with
# script_path: scripts/some-future-cr-checker.sh, but that script does NOT
# exist on disk. The inventory check MUST flag it as a CR-S05 issue.
TMP_DERIVED=$(mktemp -d); trap "rm -rf $TMP $TMP_DERIVED" EXIT
mkdir -p "$TMP_DERIVED/scripts" "$TMP_DERIVED/common"
# Provide all scripts the hardcoded list would have wanted, so the OLD
# implementation would report 0 issues. Touch + chmod +x each.
for s in git-precheck.sh prepare-input.sh glossary-probe.sh run-checkers.sh \
         check-frontmatter.sh check-mode-routing.sh check-skill-structure.sh \
         check-scripts-inventory.sh check-config-schema.sh check-criteria-yaml.sh \
         check-ipc-footer.sh check-dispatch-log-snippet.sh check-trace-id-format.sh \
         check-scaffold-sha.sh check-artifact-pyramid.sh check-dependencies.sh \
         check-criteria-consistency.sh check-index-consistency.sh \
         check-changelog-consistency.sh build-depgraph.sh commit-delivery.sh \
         prune-traces.sh extract-criteria.sh metrics-aggregate.sh; do
  touch "$TMP_DERIVED/scripts/$s"
  chmod +x "$TMP_DERIVED/scripts/$s"
done
# Write a review-criteria.md that declares a CR whose script_path is NOT
# present on disk. The auto-derive logic MUST pick this up.
cat > "$TMP_DERIVED/common/review-criteria.md" <<'EOF'
# Review Criteria — fixture for test 5

## CR-SX1 some-future-cr

```yaml
- id: CR-SX1
  name: "some-future-cr"
  version: 1.0.0
  checker_type: script
  script_path: scripts/some-future-cr-checker.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
EOF
set +e
OUT=$("$SCRIPT" "$TMP_DERIVED" 2>/dev/null)
CODE=$?
set -e
run_json "$OUT"
[ "$CODE" -eq 1 ] || {
  echo "FAIL: auto-derive expected exit 1 (CR-bound script missing), got $CODE"
  exit 1
}
FOUND=$(python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(any('some-future-cr-checker.sh' in i.get('file','') for i in d))" <<< "$OUT")
[ "$FOUND" = "True" ] || {
  echo "FAIL: CR-bound script 'some-future-cr-checker.sh' not auto-derived from review-criteria.md"
  echo "  output: $OUT"
  exit 1
}
echo "PASS: CR-bound scripts auto-derived from review-criteria.md"

echo "PASS test-check-scripts-inventory.sh"
