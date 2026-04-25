#!/usr/bin/env bash
# git-precheck.sh — bootstrap precheck per guide §21.0 + §8.3
# Verifies: git ≥ 2.0, bash ≥ 4.0, python3 ≥ 3.8
# Then: ensures cwd is a git repo (auto-init on first run)
# Exit codes: 0 = precheck passed; 1 = dependency missing or repo init failed
set -euo pipefail

# §21.0: three hard dependencies
command -v git >/dev/null 2>&1 || { echo "FATAL: git not installed" >&2; exit 1; }

GIT_VER=$(git --version | awk '{print $3}')
GIT_MAJOR="${GIT_VER%%.*}"
[ "$GIT_MAJOR" -ge 2 ] 2>/dev/null \
  || { echo "FATAL: git ≥ 2.0 required, found $GIT_VER" >&2; exit 1; }

[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] \
  || { echo "FATAL: bash ≥ 4.0 required, found $BASH_VERSION (macOS default is 3.2; brew install bash)" >&2; exit 1; }

python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null \
  || { echo "FATAL: python3 ≥ 3.8 required" >&2; exit 1; }

# §8.3: ensure a git repo exists. Use --allow-empty so we do NOT stage cwd contents
# (if the user runs this skill in a non-repo dir like $HOME, we must not accidentally
# track their files). The user can commit real content later.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "INFO: not a git repo; auto-running 'git init' + empty bootstrap commit" >&2
  git init >&2 || { echo "FATAL: git init failed" >&2; exit 1; }
  git -c user.name=this skill -c user.email=this skill@local \
    commit --allow-empty -m "init: this skill bootstrap" >&2 \
    || { echo "FATAL: initial commit failed" >&2; exit 1; }
fi

PY_VER=$(python3 --version | awk '{print $2}')
echo "OK precheck passed (git $GIT_VER, bash $BASH_VERSION, python3 $PY_VER)"
