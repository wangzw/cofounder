#!/usr/bin/env bash
# test-git-precheck.sh — unit tests for git-precheck.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/git-precheck.sh"

# Test 1: script exists + executable
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

# Test 2: checks all three of git/bash/python3
grep -q 'command -v git' "$SCRIPT" || { echo "FAIL: missing git check"; exit 1; }
grep -q 'BASH_VERSINFO' "$SCRIPT" || { echo "FAIL: missing bash ≥4 check"; exit 1; }
grep -q 'python3' "$SCRIPT" || { echo "FAIL: missing python3 check"; exit 1; }

# Test 3: dry-run in current repo succeeds (worktree is a git repo)
cd "$HERE/../.." && "$SCRIPT" >/dev/null 2>&1 \
  || { echo "FAIL: precheck failed in a valid git repo"; exit 1; }

echo "PASS test-git-precheck.sh"
