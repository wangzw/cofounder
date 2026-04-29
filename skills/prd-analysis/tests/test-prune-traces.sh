#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/prune-traces.sh"

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 2 on non-existent dir"
run_command "$CHECK" "/nonexistent-prd-xyz"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 when no traces dir"
setup_fixture
assert_exit 0 "$CHECK" "$FIXTURE"
teardown_fixture

test_case "exit 0 when traces under retention"
setup_fixture
mkdir -p "$FIXTURE/.review/traces/round-1" "$FIXTURE/.review/traces/round-2"
write_file ".review/traces/round-1/dispatch-log.jsonl" '{"event":"x"}'
write_file ".review/traces/round-2/dispatch-log.jsonl" '{"event":"x"}'
assert_exit 0 "$CHECK" "$FIXTURE" "5"
[ -d "$FIXTURE/.review/traces/round-1" ] && _record_pass || _record_fail "round-1 deleted prematurely"
teardown_fixture

test_case "prunes .yml files from old rounds; keeps .jsonl"
setup_fixture
for i in 1 2 3 4 5 6 7; do
  mkdir -p "$FIXTURE/.review/traces/round-$i"
  write_file ".review/traces/round-$i/dispatch-log.jsonl" '{"event":"x"}'
  write_file ".review/traces/round-$i/transcript.yml" "round: $i"
done
assert_exit 0 "$CHECK" "$FIXTURE" "3"
# With retention=3, cutoff = 7-3 = 4. Rounds 1..4 prune .yml; rounds 5..7 keep all.
[ ! -f "$FIXTURE/.review/traces/round-1/transcript.yml" ] && _record_pass || _record_fail "round-1 .yml should be pruned"
[ ! -f "$FIXTURE/.review/traces/round-4/transcript.yml" ] && _record_pass || _record_fail "round-4 .yml should be pruned"
[ -f "$FIXTURE/.review/traces/round-7/transcript.yml" ] && _record_pass || _record_fail "round-7 .yml should be kept"
[ -f "$FIXTURE/.review/traces/round-1/dispatch-log.jsonl" ] && _record_pass || _record_fail "round-1 .jsonl should NOT be pruned (audit trail)"
teardown_fixture

test_case "respects config.yml traces_retention_rounds"
setup_fixture
write_file "common/config.yml" "traces_retention_rounds: 2"
for i in 1 2 3 4 5; do
  mkdir -p "$FIXTURE/.review/traces/round-$i"
  write_file ".review/traces/round-$i/dispatch-log.jsonl" '{"event":"x"}'
  write_file ".review/traces/round-$i/transcript.yml" "round: $i"
done
assert_exit 0 "$CHECK" "$FIXTURE"
# retention=2, cutoff=5-2=3. Rounds 1,2,3 prune .yml; 4,5 keep all.
[ ! -f "$FIXTURE/.review/traces/round-1/transcript.yml" ] && _record_pass || _record_fail "round-1 .yml should be pruned"
[ -f "$FIXTURE/.review/traces/round-5/transcript.yml" ] && _record_pass || _record_fail "round-5 .yml should be kept"
teardown_fixture

test_case "exit 2 on invalid retention value"
setup_fixture
run_command "$CHECK" "$FIXTURE" "abc"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

end_tests
