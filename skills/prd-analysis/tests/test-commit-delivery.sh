#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/commit-delivery.sh"

setup_git_repo() {
    setup_fixture
    ( cd "$FIXTURE" && git init -q && \
        git -c user.email=t@t -c user.name=t commit --allow-empty -m init -q )
}

test_case "exit 2 on missing args"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-existent target"
run_command "$CHECK" "/nonexistent-xyz" 1 "summary"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"

test_case "exit 2 on non-integer delivery-id"
setup_git_repo
run_command "$CHECK" "$FIXTURE" "abc" "summary"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"
teardown_fixture

test_case "exit 2 on negative delivery-id"
setup_git_repo
run_command "$CHECK" "$FIXTURE" "-1" "summary"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2"
teardown_fixture

# commit-delivery.sh stages with `git add --all` then commits — it expects
# uncommitted changes in the working tree (i.e. the to-be-shipped delivery).
# Helper: leave a tracked modification staged but uncommitted.
stage_pending_change() {
    local n="$1"
    echo "delivery-$n content" > "$FIXTURE/file-$n.txt"
}

test_case "creates annotated git tag on success"
setup_git_repo
stage_pending_change 1
run_command "$CHECK" "$FIXTURE" "1" "initial release"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
( cd "$FIXTURE" && git tag --list | grep -q "^prd-analysis-delivery-1" )
[ $? = 0 ] && _record_pass || _record_fail "tag not created"
teardown_fixture

test_case "tag includes delivery id in slug"
setup_git_repo
stage_pending_change 5
run_command "$CHECK" "$FIXTURE" "5" "fix the thing"
( cd "$FIXTURE" && git tag --list ) | grep -q "^prd-analysis-delivery-5" && _record_pass || _record_fail "tag prd-analysis-delivery-5 not found"
teardown_fixture

test_case "exit 1 on tag collision (same delivery id + summary)"
setup_git_repo
stage_pending_change 1a
"$CHECK" "$FIXTURE" "1" "shared summary" >/dev/null 2>&1
stage_pending_change 1b
# Same delivery_id AND same summary → identical tag → collision detected
run_command "$CHECK" "$FIXTURE" "1" "shared summary"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 (collision) got $LAST_EXIT"
teardown_fixture

test_case "strips redundant 'delivery-N' prefix from summary"
setup_git_repo
stage_pending_change 2
run_command "$CHECK" "$FIXTURE" "2" "delivery-2: cleanup"
tag=$(cd "$FIXTURE" && git tag --list | head -1)
echo "$tag" | grep -qE "^prd-analysis-delivery-2-cleanup" && _record_pass || _record_fail "expected tag prefix 'prd-analysis-delivery-2-cleanup', got '$tag'"
teardown_fixture

test_case "strips redundant '<skill>-delivery-N' prefix from summary"
setup_git_repo
stage_pending_change 3
run_command "$CHECK" "$FIXTURE" "3" "prd-analysis-delivery-3: cleanup"
tag=$(cd "$FIXTURE" && git tag --list | head -1)
echo "$tag" | grep -qE "^prd-analysis-delivery-3-cleanup$" && _record_pass || _record_fail "expected tag 'prd-analysis-delivery-3-cleanup', got '$tag'"
teardown_fixture

# Regression: parallel work in the surrounding repo MUST NOT leak into the
# delivery commit. TARGET is the PRD bundle (a subdirectory); the caller
# may have unrelated edits sitting in the working tree or already staged.
# Bare `git add --all` is repo-wide; the script must scope it.

# Helper: init a repo at a parent dir, with TARGET as a subdirectory.
setup_parent_repo_with_subdir_target() {
    setup_fixture
    ( cd "$FIXTURE" && git init -q && \
        git -c user.email=t@t -c user.name=t commit --allow-empty -m init -q )
    TARGET_SUBDIR="$FIXTURE/prd"
    mkdir -p "$TARGET_SUBDIR"
    echo "delivery content" > "$TARGET_SUBDIR/file.txt"
}

test_case "scoped: unstaged parallel work outside TARGET is NOT committed"
setup_parent_repo_with_subdir_target
echo "parallel work" > "$FIXTURE/parallel.txt"
run_command "$CHECK" "$TARGET_SUBDIR" "10" "scoped commit"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
files_in_head=$(cd "$FIXTURE" && git show --name-only --pretty=format: HEAD)
echo "$files_in_head" | grep -q "prd/file.txt" \
    && _record_pass || _record_fail "delivery file not in commit; saw: $files_in_head"
echo "$files_in_head" | grep -q "^parallel.txt$" \
    && _record_fail "parallel file leaked into commit; saw: $files_in_head" \
    || _record_pass
( cd "$FIXTURE" && git status --porcelain parallel.txt | grep -q "^?? parallel.txt" )
[ $? = 0 ] && _record_pass || _record_fail "parallel file should still be untracked"
teardown_fixture

test_case "scoped: pre-staged parallel work outside TARGET is NOT committed"
setup_parent_repo_with_subdir_target
echo "parallel staged" > "$FIXTURE/parallel.txt"
( cd "$FIXTURE" && git add parallel.txt )
run_command "$CHECK" "$TARGET_SUBDIR" "11" "scoped commit"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
files_in_head=$(cd "$FIXTURE" && git show --name-only --pretty=format: HEAD)
echo "$files_in_head" | grep -q "^parallel.txt$" \
    && _record_fail "staged parallel file leaked into commit; saw: $files_in_head" \
    || _record_pass
# parallel.txt should remain staged (in index, not in HEAD)
( cd "$FIXTURE" && git status --porcelain parallel.txt | grep -q "^A  parallel.txt" )
[ $? = 0 ] && _record_pass || _record_fail "parallel file should still be staged, not committed"
teardown_fixture

end_tests
