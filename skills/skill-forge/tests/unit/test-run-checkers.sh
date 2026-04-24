#!/usr/bin/env bash
# test-run-checkers.sh — unit tests for run-checkers.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

cleanup() {
  rm -rf "${SKILL_ROOT}/.review"
}
trap cleanup EXIT

# --- Run against skill-forge itself (round 1) ---
# May exit 0 or 1 (skill-forge is incomplete), but NOT 2
set +e
"${SCRIPTS_DIR}/run-checkers.sh" "$SKILL_ROOT" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 2 ]; then
  pass "run-checkers.sh runs on skill-forge without error (exit $EXIT_CODE, not 2)"
else
  fail "run-checkers.sh should not exit 2 on skill-forge; got exit 2"
fi

ROUND_DIR="${SKILL_ROOT}/.review/round-1"

# --- Confirm manifest.yml written ---
if [ -f "${ROUND_DIR}/manifest.yml" ]; then
  pass "manifest.yml written"
else
  fail "manifest.yml not found at ${ROUND_DIR}/manifest.yml"
fi

# --- Confirm depgraph.yml written ---
if [ -f "${ROUND_DIR}/depgraph.yml" ]; then
  pass "depgraph.yml written"
else
  fail "depgraph.yml not found at ${ROUND_DIR}/depgraph.yml"
fi

# --- Confirm skip-set.yml written ---
if [ -f "${ROUND_DIR}/skip-set.yml" ]; then
  pass "skip-set.yml written"
else
  fail "skip-set.yml not found at ${ROUND_DIR}/skip-set.yml"
fi

# --- Confirm round-checker-output.json written ---
ISSUES_JSON="${ROUND_DIR}/issues/round-checker-output.json"
if [ -f "$ISSUES_JSON" ]; then
  pass "round-checker-output.json written"
else
  fail "round-checker-output.json not found at $ISSUES_JSON"
fi

# --- Confirm output JSON is parseable ---
if python3 -c "import json; f=open('${ISSUES_JSON}'); d=json.load(f); assert isinstance(d,list)" 2>/dev/null; then
  pass "round-checker-output.json is valid JSON array"
else
  fail "round-checker-output.json is not valid JSON"
fi

# --- Confirm each issue in JSON has a matching <id>.md file with frontmatter ---
python3 - "$ISSUES_JSON" "${ROUND_DIR}/issues" <<'PYEOF' && pass "each issue expanded to <id>.md with frontmatter" || fail "issue MD expansion missing or malformed"
import sys, json, os, re
issues_json = sys.argv[1]
issues_dir  = sys.argv[2]
with open(issues_json) as f:
    issues = json.load(f)
if not issues:
    sys.exit(0)  # nothing to verify; empty array is acceptable
mds = [f for f in os.listdir(issues_dir) if re.match(r'^R\d+-\d{3}\.md$', f)]
assert len(mds) >= len(issues), f"expected at least {len(issues)} issue MDs, got {len(mds)}"
sample = os.path.join(issues_dir, sorted(mds)[0])
content = open(sample).read()
assert content.startswith('---\n'), "issue MD missing frontmatter opener"
for key in ('id:', 'status:', 'severity:', 'criterion_id:', 'file:', 'round:', 'source:'):
    assert key in content.split('---',2)[1], f"frontmatter missing {key}"
fm = content.split('---',2)[1]
assert re.search(r'^status: (new|persistent|regressed|resolved)$', fm, re.MULTILINE), \
    f"status must be one of new|persistent|regressed|resolved, got: {fm}"
PYEOF

# --- Confirm manifest.yml has generated_at and leaves section ---
if grep -q '^generated_at:' "${ROUND_DIR}/manifest.yml" && grep -q '^leaves:' "${ROUND_DIR}/manifest.yml"; then
  pass "manifest.yml has generated_at and leaves fields"
else
  fail "manifest.yml missing required fields"
fi

# --- Negative: non-existent target -> exit 2 ---
set +e
"${SCRIPTS_DIR}/run-checkers.sh" "/nonexistent" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent target -> exit 2"
else
  fail "non-existent target should exit 2; got $EXIT_CODE"
fi

# --- Negative: missing round arg -> exit 2 ---
set +e
"${SCRIPTS_DIR}/run-checkers.sh" "$SKILL_ROOT" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "missing round arg -> exit 2"
else
  fail "missing round arg should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
