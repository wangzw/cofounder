#!/usr/bin/env bash
# tests/run-all.sh — executes every test-*.sh under this directory.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failures=0
for t in "$SCRIPT_DIR"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "== $(basename "$t") =="
  if ! bash "$t"; then
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "==> $failures test file(s) failed"
  exit 1
fi
echo "==> all autoforge checker tests passed"
