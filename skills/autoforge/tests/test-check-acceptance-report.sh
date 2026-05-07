#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-acceptance-report.sh"

# --- happy: copy of template should be PASS ----------------------------
tmp=$(mktempdir)
cp "$DIR/../acceptance/report-template.md" "$tmp/acceptance.md"
start_test "report-template.md -> exit 0 PASS"
out=$("$SCRIPT" "$tmp/acceptance.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- missing required section -----------------------------------------
tmp2=$(mktempdir)
cat > "$tmp2/acceptance.md" <<'MD'
# Acceptance Report
## Summary
empty.
MD
start_test "missing required sections -> exit 1"
out=$("$SCRIPT" "$tmp2/acceptance.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF05"
assert_stdout_contains "CR-AF05" "$out"

# --- missing Negative-Path Coverage -----------------------------------
tmp3=$(mktempdir)
# Take template, strip the negative-path section
python3 - "$DIR/../acceptance/report-template.md" "$tmp3/acceptance.md" <<'PY'
import sys, re, pathlib
src = pathlib.Path(sys.argv[1]).read_text()
out = re.sub(r"##\s+Negative-Path Coverage[\s\S]*?(?=^## |\Z)", "", src, flags=re.MULTILINE)
pathlib.Path(sys.argv[2]).write_text(out)
PY
start_test "missing Negative-Path Coverage -> exit 1"
out=$("$SCRIPT" "$tmp3/acceptance.md" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  mentions Negative-Path"
assert_stdout_contains "Negative-Path" "$out"

summary
