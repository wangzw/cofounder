#!/usr/bin/env bash
# run-tests.sh — zero-deps test harness
# Usage: ./run-tests.sh [--unit | --bootstrap | --all]
# Env: REGEN=1 to rewrite expected/ golden files (not yet wired)
set -euo pipefail
MODE="${1:---unit}"
HERE="$(cd "$(dirname "$0")" && pwd)"

case "$MODE" in
  --unit|unit)
    echo "=== Unit tests ==="
    FAIL=0
    for t in "$HERE"/unit/test-*.sh; do
      [ -x "$t" ] || { echo "SKIP: $t not executable"; continue; }
      if "$t"; then
        :
      else
        FAIL=1
      fi
    done
    [ "$FAIL" = "0" ] && echo "=== ALL UNIT TESTS PASSED ===" || { echo "=== UNIT TEST FAILURES ==="; exit 1; }
    ;;

  --bootstrap|bootstrap)
    echo "=== Bootstrap test ==="
    echo "  bootstrap harness pending: requires \`claude --plugin-dir\` + skill-forge installed"
    echo "  see tests/bootstrap/input.md for the fixture prompt"
    echo "  manual validation:"
    echo "    1. Install: cd /Users/wangzw/workspace/cofounder-skill-forge && claude --plugin-dir ."
    echo "    2. Run:     /cofounder:skill-forge \"<paste fixture prompt>\""
    echo "    3. Verify:  assertions in tests/bootstrap/input.md"
    exit 0
    ;;

  --all|all)
    "$0" --unit && "$0" --bootstrap
    ;;

  *)
    echo "Usage: $0 [--unit | --bootstrap | --all]" >&2
    exit 2
    ;;
esac
