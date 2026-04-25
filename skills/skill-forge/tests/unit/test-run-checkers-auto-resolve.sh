#!/usr/bin/env bash
# test-run-checkers-auto-resolve.sh
# Verifies the carry-forward auto-resolve filter (commit c115c31): when a
# prior-round CR-S* (script-type) issue's (criterion_id, file) pair is NOT
# in the current round's findings, the issue is treated as resolved by the
# script and MUST NOT propagate as a carry-forward.
#
# Without this filter a fixed checker (e.g. CR-S10 placeholder false-positives)
# leaves phantom carry-forwards forever.
#
# Setup: round-1 finds a CR-S* issue on `generate/a.md`; we then synthesize a
# round-2 baseline where the same script run finds no issues for that file
# (mimicking either a script bugfix or a non-targeted edit incidentally
# satisfying the rule). The leaf is in cross_reviewer_skip both rounds because
# it remains byte-identical between rounds (no drift on the artifact itself —
# only the checker's verdict differs). The carry-forward block under the old
# behavior would propagate the issue; under the new behavior it must drop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_CHECKERS="$HERE/../../scripts/run-checkers.sh"
[ -x "$RUN_CHECKERS" ] || { echo "FAIL: $RUN_CHECKERS not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$TMP/common" "$TMP/generate" "$TMP/scripts"

# A criteria registry with a script-type CR pointing at a controllable checker.
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria
## CR-TEST-S01 fragile

```yaml
- id: CR-TEST-S01
  name: "fragile"
  version: 1.0.0
  checker_type: script
  script_path: scripts/fragile.sh
  severity: error
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
EOF

# A controllable checker. Mode is selected by the presence of a sentinel file:
# - sentinel absent → reports an issue on generate/a.md
# - sentinel present → reports nothing (mimics a bugfix that closed the issue)
cat > "$TMP/scripts/fragile.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-}"
if [ -f "$TARGET/.fragile-bugfixed" ]; then
  echo "[]"
  exit 0
fi
cat <<JSON
[
  {
    "criterion_id": "CR-TEST-S01",
    "file": "generate/a.md",
    "severity": "error",
    "description": "synthetic fragile-checker issue (round 1 only)",
    "suggested_fix": "n/a"
  }
]
JSON
exit 1
EOF
chmod +x "$TMP/scripts/fragile.sh"

echo "# a" > "$TMP/generate/a.md"

# Round 1 — checker fires; expect 1 new issue + corresponding R1-001.md.
"$RUN_CHECKERS" "$TMP" round-1 >/dev/null 2>&1 || true

R1_NEW=$(ls "$TMP/.review/round-1/issues/" 2>/dev/null | grep -c '^R1-' || true)
[ "$R1_NEW" -eq 1 ] || { echo "FAIL: round-1 expected 1 R1-* issue, got $R1_NEW"; exit 1; }
grep -q "criterion_id: CR-TEST-S01" "$TMP/.review/round-1/issues/R1-001.md" \
  || { echo "FAIL: round-1 R1-001 missing CR-TEST-S01"; exit 1; }
echo "PASS round-1 (CR-TEST-S01 issue filed against generate/a.md)"

# Flip the checker into bugfixed mode WITHOUT editing generate/a.md, so the
# leaf stays byte-identical and lands in cross_reviewer_skip on round 2.
touch "$TMP/.fragile-bugfixed"

# Round 2 — checker reports no issues. The leaf is unchanged (still in
# cross_reviewer_skip), but auto-resolve should drop the prior R1-001 carry.
OUT=$("$RUN_CHECKERS" "$TMP" round-2 2>&1 || true)

R2_NEW=$(grep -c "round-checker-output.json (0 issues)" <<< "$OUT" || true)
[ "$R2_NEW" -eq 1 ] || { echo "FAIL: round-2 expected 0 new issues line, got: $OUT"; exit 1; }
echo "PASS round-2 (script no longer reports CR-TEST-S01)"

# Auto-resolve announcement must fire; carry-forward must NOT propagate.
grep -q "auto-resolved: 1 stale script-type issues" <<< "$OUT" \
  || { echo "FAIL: missing auto-resolved announcement; output was: $OUT"; exit 1; }
echo "PASS round-2 reports 'auto-resolved: 1 stale script-type issues'"

R2_ISSUES=$(ls "$TMP/.review/round-2/issues/" 2>/dev/null | grep -c '^R2-' || true)
[ "$R2_ISSUES" -eq 0 ] || { echo "FAIL: round-2 should have 0 R2-* issue files (auto-resolved), got $R2_ISSUES"; exit 1; }
echo "PASS round-2 issues/ contains 0 carry-forwards (the stale CR-TEST-S01 was dropped)"

# Negative control: if we leave the bug in place across rounds, the carry-forward
# MUST still propagate (auto-resolve is conditional on the script no longer
# reporting it).
TMP2=$(mktemp -d)
trap "rm -rf $TMP $TMP2" EXIT
mkdir -p "$TMP2/common" "$TMP2/generate" "$TMP2/scripts"
cp "$TMP/common/review-criteria.md" "$TMP2/common/"
cp "$TMP/scripts/fragile.sh" "$TMP2/scripts/"
chmod +x "$TMP2/scripts/fragile.sh"
echo "# a" > "$TMP2/generate/a.md"
"$RUN_CHECKERS" "$TMP2" round-1 >/dev/null 2>&1 || true
# Do NOT touch the sentinel — checker keeps firing across rounds.
OUT2=$("$RUN_CHECKERS" "$TMP2" round-2 2>&1 || true)

# In the persistent-defect case the issue is re-detected this round, so the
# carry-forward block doesn't fire (the leaf is in single_file_focus because
# it was just re-evaluated). Verify there's no false auto-resolve announcement.
grep -q "auto-resolved" <<< "$OUT2" \
  && { echo "FAIL: persistent defect should NOT trigger auto-resolved; output: $OUT2"; exit 1; } \
  || true
echo "PASS persistent defect does not trigger false auto-resolve"

echo "=== PASS test-run-checkers-auto-resolve.sh (5 sub-tests) ==="
