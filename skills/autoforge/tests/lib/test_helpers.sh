#!/usr/bin/env bash
# tests/lib/test_helpers.sh — minimal helpers for autoforge checker tests.
# Mirrors the prd-analysis pattern so contributors can switch between repos
# without re-learning the harness.

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_TEST=""

if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

start_test() {
  CURRENT_TEST="$1"
  printf '  %s ... ' "$CURRENT_TEST"
}

pass() {
  printf '%bPASS%b\n' "$GREEN" "$NC"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '%bFAIL%b\n    %s\n' "$RED" "$NC" "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_exit_code() {
  local expected="$1" actual="$2" detail="${3:-}"
  if [ "$expected" -eq "$actual" ]; then
    pass
  else
    fail "expected exit=$expected got exit=$actual; $detail"
  fi
}

assert_stdout_contains() {
  local needle="$1" haystack="$2"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass
  else
    fail "stdout did not contain: $needle"
  fi
}

summary() {
  echo
  if [ "$FAIL_COUNT" -eq 0 ]; then
    printf '%b%d passed, 0 failed%b\n' "$GREEN" "$PASS_COUNT" "$NC"
    exit 0
  fi
  printf '%b%d passed, %d failed%b\n' "$RED" "$PASS_COUNT" "$FAIL_COUNT" "$NC"
  exit 1
}

mktempdir() {
  mktemp -d "${TMPDIR:-/tmp}/autoforge-test.XXXXXX"
}

# Build the canonical autoforge fixture: a project repo with a stub plan
# file on a default branch plus an autoforge feature-branch worktree at
# `<root>-worktrees/<wt-subpath>`. Used by every checker that walks
# `git worktree list`. Plan file is always `plan-M-001.md` unless
# a different filename is supplied.
#
# Args:
#   1. root                 absolute path to the project repo (created)
#   2. default_branch       e.g. main / master / develop
#   3. feature_branch       e.g. autoforge/test-plan-aaaa
#   4. plan_dir_rel         e.g. docs/raw/plans/test-plan
#   5. wt_subpath           default: main
#   6. plan_filename        default: plan-M-001.md
make_autoforge_fixture() {
  local root="$1"
  local default_branch="$2"
  local feature_branch="$3"
  local plan_dir_rel="$4"
  local wt_subpath="${5:-main}"
  local plan_filename="${6:-plan-M-001.md}"
  local wt_root="$root-worktrees"

  mkdir -p "$root"
  (
    cd "$root"
    git init -q -b "$default_branch"
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p "$plan_dir_rel/plans"
    echo "stub" > "$plan_dir_rel/plans/$plan_filename"
    git add . >/dev/null
    git commit -q -m initial
    git branch "$feature_branch"
    mkdir -p "$wt_root"
    git worktree add -q "$wt_root/$wt_subpath" "$feature_branch"
  )
}
