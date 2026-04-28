#!/usr/bin/env bash
# test-run-checkers-script-source-isolation.sh
# Verifies the reviewer/artifact disjoint-trees invariant in run-checkers.sh:
#   1. Per-criterion script_path resolves strictly via CHECKER_SCRIPTS_DIR
#      (the reviewer's scripts/), never via <target>/scripts/. A poisoned
#      copy in <target>/scripts/ MUST NOT be invoked.
#   2. When CHECKER_SCRIPTS_DIR resolves to a directory inside <target>,
#      run-checkers.sh refuses (exit 2) — that is the artifact-audits-itself
#      case (e.g. invoking the target's own run-checkers.sh on the target).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# ─────────────────────────────────────────────────────────────────────────
# Test 1: poisoned <target>/scripts/check-*.sh MUST NOT be invoked
# ─────────────────────────────────────────────────────────────────────────
TARGET1="$TMP/artifact1"
mkdir -p "$TARGET1/common" "$TARGET1/scripts"

# Plant a poisoned check-skill-structure.sh in target/scripts/. If
# run-checkers.sh used <target>/scripts/ as a fallback (the old, buggy
# behavior), this script would run and emit a POISON-marked issue.
cat > "$TARGET1/scripts/check-skill-structure.sh" <<'EOF'
#!/usr/bin/env bash
# POISON: the reviewer must NOT invoke this. CR-S03
echo '[{"criterion_id":"CR-S03","severity":"error","file":"POISON-MARKER","description":"target-side check-skill-structure.sh ran (rule-3 violation)","suggested_fix":"none"}]'
exit 1
EOF
chmod +x "$TARGET1/scripts/check-skill-structure.sh"

cat > "$TARGET1/SKILL.md" <<'EOF'
---
name: artifact1
version: 0.0.1
description: "Use when running script-source isolation tests."
---
EOF

cat > "$TARGET1/common/review-criteria.md" <<'EOF'
# Review Criteria

## CR-S03 skill-structure

```yaml
- id: CR-S03
  name: "skill-structure"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```
EOF

set +e
"${SCRIPTS_DIR}/run-checkers.sh" "$TARGET1" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e

OUT="$TARGET1/.review/round-1/issues/round-checker-output.json"
if [ -f "$OUT" ]; then
  pass "round-checker-output.json written for fixture target"
else
  fail "round-checker-output.json not written (run-checkers exit $EXIT_CODE)"
fi

if [ -f "$OUT" ]; then
  if python3 - "$OUT" <<'PYEOF'
import json, sys
issues = json.load(open(sys.argv[1]))
poisoned = [i for i in issues
            if i.get("file") == "POISON-MARKER"
            or "POISON" in i.get("description", "")
            or "rule-3 violation" in i.get("description", "")]
sys.exit(1 if poisoned else 0)
PYEOF
  then
    pass "reviewer used canonical scripts/, not target's poisoned copy"
  else
    fail "POISON marker found in output — target's check-skill-structure.sh was invoked (rule-3 violated)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────
# Test 2: CHECKER_SCRIPTS_DIR inside <target> MUST exit 2
# ─────────────────────────────────────────────────────────────────────────
# Simulate the artifact-audits-itself case by setting CHECKER_SCRIPTS_DIR
# to <target>/scripts. The bash wrapper exports its own SCRIPT_DIR on top
# of any pre-existing env var, so we exercise the Python guard directly by
# invoking it through `bash -c` with the override set up to defeat the
# wrapper. Strategy: create a fake reviewer skill at the same path as
# target/scripts (so SCRIPT_DIR == target/scripts) by symlinking
# run-checkers.sh into target/scripts/ and invoking via the symlink.
TARGET2="$TMP/artifact2"
mkdir -p "$TARGET2/common" "$TARGET2/scripts"
cp "$TARGET1/SKILL.md" "$TARGET2/SKILL.md"
cp "$TARGET1/common/review-criteria.md" "$TARGET2/common/review-criteria.md"
cp "$SCRIPTS_DIR/run-checkers.sh" "$TARGET2/scripts/run-checkers.sh"
cp "$SCRIPTS_DIR/extract-criteria.sh" "$TARGET2/scripts/extract-criteria.sh"
cp "$SCRIPTS_DIR/build-depgraph.sh" "$TARGET2/scripts/build-depgraph.sh"
chmod +x "$TARGET2/scripts/run-checkers.sh" "$TARGET2/scripts/extract-criteria.sh" "$TARGET2/scripts/build-depgraph.sh"

set +e
"$TARGET2/scripts/run-checkers.sh" "$TARGET2" round-1 >/dev/null 2>&1
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -eq 2 ]; then
  pass "scripts_dir inside <target> -> exit 2 (artifact-audits-itself rejected)"
else
  fail "scripts_dir inside <target> should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
