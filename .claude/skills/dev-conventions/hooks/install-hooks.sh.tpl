#!/bin/sh
# Installer for native git hooks (no external tooling required).
# Run from the project root: bash scripts/install-hooks.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "ERROR: not inside a git repository." >&2
  exit 1
fi

HOOK_SRC="$REPO_ROOT/scripts/git-hooks/commit-msg.sh"
HOOK_DST="$REPO_ROOT/.git/hooks/commit-msg"

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: hook source not found at $HOOK_SRC" >&2
  echo "Make sure scripts/git-hooks/commit-msg.sh exists in the repository." >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/.git/hooks"
cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"

echo "Installed commit-msg hook → $HOOK_DST"
echo "Verify with: echo 'bad message' | .git/hooks/commit-msg /dev/stdin"
