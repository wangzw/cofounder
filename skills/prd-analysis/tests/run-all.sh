#!/usr/bin/env bash
# tests/run-all.sh — runs every test-*.sh in this directory.
#
# Each per-artifact check-X.sh script has a sibling test-check-X.sh runner.
# This script enumerates them, runs each, and aggregates pass / fail counts.
#
# Exit codes:
#   0  every test runner reported all-pass
#   1  one or more test runners reported failures

set -uo pipefail
TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

total_pass=0
total_fail=0
failed_runners=()

for test_file in "$TESTS_ROOT"/test-*.sh; do
    [ -x "$test_file" ] || chmod +x "$test_file"
    name="$(basename "$test_file")"
    output=$(bash "$test_file" 2>&1)
    last_line=$(echo "$output" | tail -1)
    # Format from test_helpers.sh end_tests: "<P> passed, <F> failed (<T> total)"
    if echo "$last_line" | grep -qE '^[0-9]+ passed, [0-9]+ failed \([0-9]+ total\)$'; then
        passed=$(echo "$last_line" | sed -E 's/^([0-9]+) passed.*/\1/')
        failed=$(echo "$last_line" | sed -E 's/.*, ([0-9]+) failed.*/\1/')
        total_pass=$((total_pass + passed))
        total_fail=$((total_fail + failed))
        if [ "$failed" -gt 0 ]; then
            failed_runners+=("$name ($failed failed)")
            printf '  ✗ %-45s  %s\n' "$name" "$last_line"
            echo "$output" | sed 's/^/    /' | head -50
        else
            printf '  ✓ %-45s  %s\n' "$name" "$last_line"
        fi
    else
        # Test runner crashed or didn't print summary
        total_fail=$((total_fail + 1))
        failed_runners+=("$name (runner crashed or no summary)")
        printf '  ✗ %-45s  ABORTED\n' "$name"
        echo "$output" | sed 's/^/    /' | tail -10
    fi
done

echo
total=$((total_pass + total_fail))
echo "=== TOTAL: $total_pass passed, $total_fail failed ($total tests across $(ls "$TESTS_ROOT"/test-*.sh | wc -l | tr -d ' ') runner files) ==="
if [ "$total_fail" -gt 0 ]; then
    echo "Failed runners:"
    for r in "${failed_runners[@]}"; do
        echo "  - $r"
    done
    exit 1
fi
exit 0
