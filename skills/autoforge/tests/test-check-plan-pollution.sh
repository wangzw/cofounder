#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-plan-pollution.sh"

# Adapter from the legacy positional contract used by the call sites
# below — (root, plan_dir, plan_filename, wt_subpath, feature_branch) —
# to the shared make_autoforge_fixture helper. Explicit named locals
# stop a silent mis-wire if either side's parameter order ever changes.
make_repo_with_worktree() {
  local root="$1" plan_dir_rel="$2" plan_filename="$3"
  local wt_subpath="$4" feature_branch="$5"
  make_autoforge_fixture \
    "$root" main "$feature_branch" "$plan_dir_rel" \
    "$wt_subpath" "$plan_filename"
}

# --- clean: main is clean, autoforge worktree has changes (legitimate) -----
clean=$(mktempdir)
make_repo_with_worktree "$clean/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-aaaa"
# Modify plan file on the autoforge worktree (legitimate)
echo "new content" >> "$clean/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "clean main + dirty autoforge worktree -> PASS"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$clean/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"
start_test "  stdout says PASS"
assert_stdout_contains "PASS" "$out"

# --- pollution: main worktree has uncommitted change under plan-dir --------
poll=$(mktempdir)
make_repo_with_worktree "$poll/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-bbbb"
# Pollute the main worktree's plan file
echo "polluted by misplaced Planner" >> "$poll/proj/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "polluted main + clean autoforge worktree -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$poll/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF29"
assert_stdout_contains "CR-AF29" "$out"
start_test "  cites the polluted file"
assert_stdout_contains "plan-M-001.md" "$out"
start_test "  cites the main worktree branch"
assert_stdout_contains "main" "$out"
start_test "  severity critical"
assert_stdout_contains "critical" "$out"

# --- new file on main worktree is also caught -----------------------------
poll2=$(mktempdir)
make_repo_with_worktree "$poll2/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-cccc"
echo "new plan" > "$poll2/proj/docs/raw/plans/test-plan/plans/plan-M-002.md"
start_test "new untracked plan file on main -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$poll2/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF29 for plan-M-002"
assert_stdout_contains "plan-M-002.md" "$out"

# --- detached HEAD is skipped (not main / master / autoforge) -------------
det=$(mktempdir)
make_repo_with_worktree "$det/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-dddd"
# Add a third worktree pointing at the initial commit (detached HEAD)
(
  cd "$det/proj"
  initial_sha=$(git rev-parse HEAD)
  git worktree add -q --detach "$det/proj-worktrees/detached" "$initial_sha"
)
# Pollute the detached worktree's plan-dir
echo "polluted on detached HEAD" >> "$det/proj-worktrees/detached/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "detached HEAD worktree is skipped (no false positive)"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$det/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- only the autoforge worktree exists (no main checkout) — also clean ---
solo=$(mktempdir)
mkdir -p "$solo/proj"
(
  cd "$solo/proj"
  git init -q -b autoforge/test-plan-eeee
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p "docs/raw/plans/test-plan/plans"
  echo "stub" > "docs/raw/plans/test-plan/plans/plan-M-001.md"
  git add . >/dev/null
  git commit -q -m initial
)
start_test "only-autoforge worktree -> PASS"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$solo/proj" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- pollution on `master` branch (not just `main`) ---------------------
master_repo=$(mktempdir)
mkdir -p "$master_repo/proj"
(
  cd "$master_repo/proj"
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p docs/raw/plans/test-plan/plans
  echo "stub" > docs/raw/plans/test-plan/plans/plan-M-001.md
  git add . >/dev/null
  git commit -q -m initial
  git branch autoforge/test-plan-1111
  mkdir -p "$master_repo/proj-worktrees"
  git worktree add -q "$master_repo/proj-worktrees/main" autoforge/test-plan-1111
)
echo "polluted on master" >> "$master_repo/proj/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "pollution on master branch -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$master_repo/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  cites master in finding"
assert_stdout_contains "master" "$out"

# --- pollution on a user feature branch (non-default, non-autoforge) ------
ub=$(mktempdir)
mkdir -p "$ub/proj"
(
  cd "$ub/proj"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p docs/raw/plans/test-plan/plans
  echo "stub" > docs/raw/plans/test-plan/plans/plan-M-001.md
  git add . >/dev/null
  git commit -q -m initial
  git branch feature/user-side-work
  git branch autoforge/test-plan-2222
  mkdir -p "$ub/proj-worktrees"
  git worktree add -q "$ub/proj-worktrees/user" feature/user-side-work
  git worktree add -q "$ub/proj-worktrees/main" autoforge/test-plan-2222
)
echo "polluted on user feature branch" >> "$ub/proj-worktrees/user/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "pollution on a user feature branch -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$ub/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  cites feature/user-side-work"
assert_stdout_contains "feature/user-side-work" "$out"

# --- two autoforge worktrees, both skipped -------------------------------
two=$(mktempdir)
mkdir -p "$two/proj"
(
  cd "$two/proj"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p docs/raw/plans/test-plan/plans
  echo "stub" > docs/raw/plans/test-plan/plans/plan-M-001.md
  git add . >/dev/null
  git commit -q -m initial
  git branch autoforge/run-a
  git branch autoforge/run-b
  mkdir -p "$two/proj-worktrees"
  git worktree add -q "$two/proj-worktrees/a" autoforge/run-a
  git worktree add -q "$two/proj-worktrees/b" autoforge/run-b
)
# Modify in both autoforge worktrees — both are legitimate locations
echo "work in a" >> "$two/proj-worktrees/a/docs/raw/plans/test-plan/plans/plan-M-001.md"
echo "work in b" >> "$two/proj-worktrees/b/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "two autoforge worktrees, both dirty -> PASS (both skipped)"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$two/proj-worktrees/a" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- file with a space in the path is still detected ---------------------
spc=$(mktempdir)
make_repo_with_worktree "$spc/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-gggg"
# Create a plan file whose name contains a space (forces git to quote it
# in porcelain output — the script must still extract the path correctly).
echo "spaced plan" > "$spc/proj/docs/raw/plans/test-plan/plans/plan with space.md"
start_test "pollution on a file with a space in path -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$spc/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  reports the spaced filename"
assert_stdout_contains "plan with space.md" "$out"

# --- idempotent: running twice produces identical stdout ------------------
poll3=$(mktempdir)
make_repo_with_worktree "$poll3/proj" "docs/raw/plans/test-plan" "plan-M-001.md" "main" "autoforge/test-plan-ffff"
echo "polluted again" >> "$poll3/proj/docs/raw/plans/test-plan/plans/plan-M-001.md"
out1=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$poll3/proj-worktrees/main" 2>&1 || true)
out2=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$poll3/proj-worktrees/main" 2>&1 || true)
start_test "idempotent — same input yields identical stdout"
if [ "$out1" = "$out2" ]; then pass; else fail "outputs differ"; fi

# --- argument errors ------------------------------------------------------
start_test "missing plan-dir arg -> exit 2"
out=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

start_test "non-existent --source-root -> exit 2"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "/nonexistent/path" 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

summary
