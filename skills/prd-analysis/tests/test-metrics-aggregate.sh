#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/metrics-aggregate.sh"

# metrics-aggregate.sh is a complex script that joins harness JSONL with
# orchestrator dispatch-log JSONL. Test only the documented surface
# (CLI flags, arg validation, dry-run, no-data behavior) — actual aggregation
# is exercised in lib/aggregate.py (which has its own pinned test fixtures
# upstream).

write_dispatch_log() {
    local round="$1"
    local trace_id="$2"
    mkdir -p "$FIXTURE/.review/traces/round-$round"
    cat >> "$FIXTURE/.review/traces/round-$round/dispatch-log.jsonl" <<EOF
{"event": "launched", "trace_id": "$trace_id", "role": "writer", "reviewer_variant": null, "tier": "balanced", "model": "claude-sonnet-4-5", "delivery_id": 1, "dispatched_at": "2026-04-29T10:00:00Z", "prompt_hash": "sha256:abc", "linked_issues": []}
{"event": "completed", "trace_id": "$trace_id", "role": "writer", "ack_status": "OK", "linked_issues": [], "returned_at": "2026-04-29T10:01:00Z", "self_review_status": "FULL_PASS", "fail_count": 0}
EOF
}

test_case "exit 1 with usage on no args"
run_command "$CHECK"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"

test_case "--help exits 0"
run_command "$CHECK" --help
[ "$LAST_EXIT" = "0" ] && _record_pass || _record_fail "expected 0 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q "Usage" && _record_pass || _record_fail "no Usage in help"

test_case "exit 1 when --diagnose missing"
run_command "$CHECK" --round 1 --review-dir "/tmp/nonexistent"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"

test_case "exit 2 when --review-dir does not exist"
run_command "$CHECK" --diagnose --round 1 --review-dir "/tmp/totally-nonexistent-xyz-$$"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 1 on conflicting scopes (--round + --delivery)"
setup_fixture
mkdir -p "$FIXTURE/.review/traces/round-1"
run_command "$CHECK" --diagnose --round 1 --delivery 1 --review-dir "$FIXTURE/.review"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
teardown_fixture

test_case "--dry-run with valid round writes nothing"
setup_fixture
write_dispatch_log 1 "R1-W-001"
run_command "$CHECK" --diagnose --round 1 \
    --review-dir "$FIXTURE/.review" \
    --harness-dir "/tmp/no-harness-$$" \
    --dry-run
# Either succeeds (exit 0) writing to stdout, or fails with input/parse error
# (no harness JSONLs present); both are acceptable. The contract is "no file
# is written".
[ ! -d "$FIXTURE/.review/metrics" ] && _record_pass || _record_fail "metrics dir created despite --dry-run"
teardown_fixture

end_tests
