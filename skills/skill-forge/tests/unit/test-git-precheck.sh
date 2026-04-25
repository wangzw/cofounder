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

# Test 4: --allow-empty bootstrap doesn't stage cwd contents (regression for 0638f6d).
# When skill-forge runs in a non-repo dir, git-precheck auto-`git init`s + makes
# an empty bootstrap commit. Earlier the commit was created without --allow-empty,
# which caused git to stage everything in cwd — if the user happened to be in
# $HOME or any populated dir, those files would land in the new repo's history.
# The fix uses `commit --allow-empty -m "init: skill-forge bootstrap"`.
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
# Populate the dir with files that MUST NOT be staged.
echo "secret-content" > "$TMP/secrets.env"
echo "irrelevant" > "$TMP/notes.txt"
mkdir -p "$TMP/sub" && echo "sub-data" > "$TMP/sub/data.md"
# Run precheck in the empty-of-git dir.
(cd "$TMP" && "$SCRIPT") >/dev/null 2>&1 \
  || { echo "FAIL: precheck failed to bootstrap in non-repo dir"; exit 1; }
# After bootstrap, the bootstrap commit MUST be empty — no cwd contents staged.
TRACKED=$(git -C "$TMP" ls-tree -r HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
[ "$TRACKED" = "0" ] || {
  echo "FAIL: bootstrap commit staged $TRACKED files from cwd (0638f6d regression)";
  echo "  tracked files:"; git -C "$TMP" ls-tree -r HEAD --name-only 2>&1 | sed 's/^/    /';
  exit 1;
}
# And the original files MUST still be on disk, just untracked.
[ -f "$TMP/secrets.env" ] && [ -f "$TMP/notes.txt" ] && [ -f "$TMP/sub/data.md" ] \
  || { echo "FAIL: precheck deleted cwd content"; exit 1; }
echo "PASS: bootstrap commit uses --allow-empty (0638f6d)"

echo "PASS test-git-precheck.sh"
