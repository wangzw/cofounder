#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/git-precheck.sh"

# git-precheck.sh runs in cwd. We isolate by cd-ing to a temp dir before each test.

test_case "exit 0 in an existing git repo"
setup_fixture
( cd "$FIXTURE" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -m init -q )
run_command bash -c "cd '$FIXTURE' && '$CHECK'"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
teardown_fixture

test_case "auto-init when cwd is not a git repo"
setup_fixture
run_command bash -c "cd '$FIXTURE' && '$CHECK'"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
[ -d "$FIXTURE/.git" ] && _record_pass || _record_fail "git init did not run"
echo "$LAST_STDERR" | grep -q "not a git repo" && _record_pass || _record_fail "missing INFO message about auto-init"
teardown_fixture

test_case "creates initial empty commit on auto-init"
setup_fixture
run_command bash -c "cd '$FIXTURE' && '$CHECK'"
( cd "$FIXTURE" && git log --oneline ) > /tmp/test-precheck-log.$$ 2>&1
grep -q "skill bootstrap" /tmp/test-precheck-log.$$ && _record_pass || _record_fail "no bootstrap commit"
rm -f /tmp/test-precheck-log.$$
teardown_fixture

test_case "is idempotent — second run on same repo also passes"
setup_fixture
run_command bash -c "cd '$FIXTURE' && '$CHECK'"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "first call failed"
run_command bash -c "cd '$FIXTURE' && '$CHECK'"
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "second call failed"
teardown_fixture

end_tests
