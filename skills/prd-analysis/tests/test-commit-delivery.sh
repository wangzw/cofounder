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
( cd "$FIXTURE" && git tag --list | grep -q "^delivery-1" )
[ $? = 0 ] && _record_pass || _record_fail "tag not created"
teardown_fixture

test_case "tag includes delivery id in slug"
setup_git_repo
stage_pending_change 5
run_command "$CHECK" "$FIXTURE" "5" "fix the thing"
( cd "$FIXTURE" && git tag --list ) | grep -q "^delivery-5" && _record_pass || _record_fail "tag delivery-5 not found"
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
echo "$tag" | grep -qE "^delivery-2-cleanup" && _record_pass || _record_fail "expected tag prefix 'delivery-2-cleanup', got '$tag'"
teardown_fixture

end_tests
