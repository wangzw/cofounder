#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/phase-audit.sh"

# Shorthand to keep call sites compact.
fixture() {
  make_autoforge_fixture "$1" main "$2" docs/raw/plans/test-plan
}

# --- baseline: clean autoforge worktree → PASS ----------------------------
clean=$(mktempdir)
fixture "$clean/proj" "autoforge/run-aaaa/main"
start_test "all worktrees clean -> exit 0"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$clean/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"
start_test "  stdout says PASS"
assert_stdout_contains "PASS" "$out"

# --- CR-AF30: dirty file in an autoforge worktree -------------------------
dirty=$(mktempdir)
fixture "$dirty/proj" "autoforge/run-bbbb/main"
# Simulate a crashed Module Agent: untracked + modified files left behind.
echo "in-flight edit" >> "$dirty/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-001.md"
echo "untracked draft" > "$dirty/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-002.md"
start_test "dirty autoforge worktree -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$dirty/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF30"
assert_stdout_contains "CR-AF30" "$out"
start_test "  cites the modified file"
assert_stdout_contains "plan-M-001.md" "$out"
start_test "  cites the untracked file"
assert_stdout_contains "plan-M-002.md" "$out"
start_test "  severity error (not critical)"
assert_stdout_contains "\"severity\": \"error\"" "$out"

# --- CR-AF30: untracked-only is also caught -------------------------------
untracked_only=$(mktempdir)
fixture "$untracked_only/proj" "autoforge/run-uuuu/main"
echo "lone draft" > "$untracked_only/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-003.md"
start_test "untracked-only dirty -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$untracked_only/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  cites plan-M-003.md"
assert_stdout_contains "plan-M-003.md" "$out"

# --- non-autoforge worktree dirty: NOT a CR-AF30 finding -----------------
# (That case is CR-AF29's territory; CR-AF30 must not double-report.)
non_af=$(mktempdir)
fixture "$non_af/proj" "autoforge/run-cccc/main"
echo "polluted on main" >> "$non_af/proj/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "dirty main worktree alone -> CR-AF30 silent (CR-AF29 territory)"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$non_af/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- CR-AF31: stale module branch, no worktree, not merged ----------------
stale=$(mktempdir)
fixture "$stale/proj" "autoforge/run-dddd/main"
(
  cd "$stale/proj-worktrees/main"
  # Create a module branch off the feature branch + add an unmerged commit
  git checkout -q -b autoforge/run-dddd/p4/M-007-storage-migrations
  echo "module work" > module-work.txt
  git add module-work.txt
  git commit -q -m "feat(M-007): module work"
  # Switch the worktree back to the feature branch so the module branch
  # has no worktree (the failure mode we want to detect).
  git checkout -q autoforge/run-dddd/main
)
start_test "stale unmerged module branch -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$stale/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF31"
assert_stdout_contains "CR-AF31" "$out"
start_test "  cites the orphan branch"
assert_stdout_contains "autoforge/run-dddd/p4/M-007-storage-migrations" "$out"
start_test "  mentions it is not an ancestor of the feature branch"
assert_stdout_contains "not an ancestor" "$out"

# --- CR-AF31: merged module branch is NOT a finding -----------------------
merged=$(mktempdir)
fixture "$merged/proj" "autoforge/run-eeee/main"
(
  cd "$merged/proj-worktrees/main"
  git checkout -q -b autoforge/run-eeee/p1/M-001-foo
  echo "merged module work" > merged-module-work.txt
  git add merged-module-work.txt
  git commit -q -m "feat(M-001): work that will be merged"
  git checkout -q autoforge/run-eeee/main
  git merge -q --ff-only autoforge/run-eeee/p1/M-001-foo
  # Branch remains (skip `git branch -d` to simulate the cleanup step
  # being skipped) — but since it is now an ancestor of main, the audit
  # should treat it as merged-noise and pass.
)
start_test "merged module branch still around -> CR-AF31 silent"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$merged/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- CR-AF31: orphan branch with no resolvable feature branch ------------
# Construct a module branch whose `{run_prefix}/main` ref does not exist,
# so the script's primary lookup misses. (The fallback to bare-`{run_prefix}`
# is unreachable in practice because git's ref-namespacing rules forbid
# `autoforge/X` and `autoforge/X/p1/M-…` from coexisting — every real
# autoforge run uses the `/main` suffix.)
no_feat=$(mktempdir)
mkdir -p "$no_feat/proj"
(
  cd "$no_feat/proj"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p docs/raw/plans/test-plan/plans
  echo "stub" > docs/raw/plans/test-plan/plans/plan-M-001.md
  git add . >/dev/null
  git commit -q -m initial
  # Module branch only — feature branch was already deleted (cleanup
  # ordering bug). The audit must still flag the orphan.
  git branch autoforge/run-zzzz/p2/M-005-bar
)
start_test "orphan module branch, no resolvable feature branch -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$no_feat/proj" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  notes that no feature branch was found"
assert_stdout_contains "no feature branch found" "$out"

# --- CR-AF31: detached-HEAD worktree pinned to a module-branch tip --------
# Regression test for the false-positive where a module agent's worktree
# went detached (e.g. `git checkout <sha>` inside the worktree). The
# branch's tip SHA is still held by a live worktree, so CR-AF31 must NOT
# flag it as orphan even though the worktree has no `branch:` field.
det_mb=$(mktempdir)
fixture "$det_mb/proj" "autoforge/run-jjjj/main"
(
  cd "$det_mb/proj-worktrees/main"
  # Create a module branch with one commit
  git checkout -q -b autoforge/run-jjjj/p5/M-011-active
  echo "module work in progress" > work.txt
  git add work.txt
  git commit -q -m "feat(M-011): wip"
  module_tip=$(git rev-parse HEAD)
  # Move the feature-branch worktree back so the module branch is the
  # only thing in this fixture that knows about its tip via a branch ref.
  git checkout -q autoforge/run-jjjj/main
  # Create a SEPARATE worktree, detached at the module branch's tip
  # (simulates a module agent's worktree that lost its branch attachment).
  git worktree add -q --detach "$det_mb/proj-worktrees/p5-detached" "$module_tip"
)
start_test "detached-HEAD worktree on a module-branch tip -> CR-AF31 silent"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$det_mb/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- detached HEAD on an autoforge path is skipped ------------------------
det=$(mktempdir)
fixture "$det/proj" "autoforge/run-gggg/main"
(
  cd "$det/proj-worktrees/main"
  initial_sha=$(git rev-parse HEAD)
  git worktree add -q --detach "$det/proj-worktrees/detached" "$initial_sha"
)
# Pollute the detached worktree
echo "in detached" >> "$det/proj-worktrees/detached/docs/raw/plans/test-plan/plans/plan-M-001.md"
start_test "detached HEAD worktree is skipped (no false positive)"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$det/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- idempotence: two runs produce identical stdout ----------------------
idem=$(mktempdir)
fixture "$idem/proj" "autoforge/run-hhhh/main"
echo "x" >> "$idem/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-001.md"
out1=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$idem/proj-worktrees/main" 2>&1 || true)
out2=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$idem/proj-worktrees/main" 2>&1 || true)
start_test "idempotent — same input yields identical stdout"
if [ "$out1" = "$out2" ]; then pass; else fail "outputs differ"; fi

# --- both CR-AF30 and CR-AF31 fire in the same run -----------------------
combo=$(mktempdir)
fixture "$combo/proj" "autoforge/run-iiii/main"
echo "in-flight" >> "$combo/proj-worktrees/main/docs/raw/plans/test-plan/plans/plan-M-001.md"
(
  cd "$combo/proj-worktrees/main"
  git checkout -q -b autoforge/run-iiii/p3/M-009-tenancy
  echo "module work" > m.txt
  git add m.txt
  git commit -q -m "feat(M-009): work"
  # Move HEAD back so the branch has no worktree
  git checkout -q autoforge/run-iiii/main
)
start_test "both CR-AF30 and CR-AF31 in same run -> exit 1"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$combo/proj-worktrees/main" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  reports CR-AF30"
assert_stdout_contains "CR-AF30" "$out"
start_test "  reports CR-AF31"
assert_stdout_contains "CR-AF31" "$out"

# --- argument errors -----------------------------------------------------
start_test "missing plan-dir arg -> exit 2"
out=$("$SCRIPT" 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

start_test "non-existent --source-root -> exit 2"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "/nonexistent/path" 2>&1) && rc=0 || rc=$?
assert_exit_code 2 "$rc"

# --- non-git source-root -> graceful PASS (matches CR-AF29 behaviour) ----
nogit=$(mktempdir)
mkdir -p "$nogit/notarepo/docs/raw/plans/test-plan"
start_test "non-git source-root -> exit 0"
out=$("$SCRIPT" "docs/raw/plans/test-plan" --source-root "$nogit/notarepo" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

summary
