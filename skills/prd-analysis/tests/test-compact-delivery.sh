#!/usr/bin/env bash
# Tests for scripts/compact-delivery.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
COMPACT="$REPO_SCRIPTS/compact-delivery.sh"

# ─── Fixture builder ──────────────────────────────────────────────────
# build_delivery <fixture> <delivery_id> <round_num> <verdict> [issues_count]
# Creates round-<N>/ with index.md, verdict.yml and optional issues.
build_round() {
    local fixture="$1" did="$2" rnum="$3" verdict="$4" iss="${5:-0}"
    mkdir -p "$fixture/.review/round-$rnum/issues"
    mkdir -p "$fixture/.review/traces/round-$rnum"
    cat > "$fixture/.review/round-$rnum/index.md" <<EOF
---
round: $rnum
delivery_id: $did
total_issues: $iss
new_count: 0
fixed_count: $iss
false_positive_count: 0
deferred_count: 0
superseded_count: 0
critical_count: 0
error_count: $iss
warning_count: 0
info_count: 0
recurrence_count: 0
---
# Round $rnum
EOF
    cat > "$fixture/.review/round-$rnum/verdict.yml" <<EOF
round: $rnum
delivery_id: $did
verdict: $verdict
next_action: $([ "$verdict" = "converged" ] && echo delivery || echo revise)
evidence:
  total: $iss
EOF
    local i=1
    while [ "$i" -le "$iss" ]; do
        cat > "$fixture/.review/round-$rnum/issues/I-$(printf '%03d' "$i").md" <<EOF
---
id: I-$(printf '%03d' "$i")
criterion_id: CR-PP01
file: README.md
severity: error
state: fixed
created_in_round: $rnum
fixed_in_round: $rnum
---
## Description
x
## Suggested fix
y
EOF
        i=$((i + 1))
    done
    echo "log-$rnum" > "$fixture/.review/traces/round-$rnum/dispatch-log.jsonl"
}

# ─── Tests ────────────────────────────────────────────────────────────

test_case "exit 2 on missing arg"
run_command "$COMPACT"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 1 when .review/ absent"
setup_fixture
assert_exit 1 "$COMPACT" "$FIXTURE" --force
assert_stdout_contains "no .review/"
teardown_fixture

test_case "exit 1 when no rounds have delivery_id"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1"
assert_exit 1 "$COMPACT" "$FIXTURE" --force
teardown_fixture

test_case "no-op when only one round in delivery"
setup_fixture
build_round "$FIXTURE" 1 1 converged 1
assert_exit 0 "$COMPACT" "$FIXTURE" --force
assert_stdout_contains "no-op"
teardown_fixture

test_case "REFUSE when final round not converged"
setup_fixture
build_round "$FIXTURE" 1 1 progressing 2
build_round "$FIXTURE" 1 2 progressing 2
assert_exit 1 "$COMPACT" "$FIXTURE" --force
assert_stdout_contains "need 'converged'"
teardown_fixture

test_case "REFUSE without git tag and without --force"
setup_fixture
( cd "$FIXTURE" && git init -q )
build_round "$FIXTURE" 1 1 progressing 1
build_round "$FIXTURE" 1 2 converged 0
assert_exit 1 "$COMPACT" "$FIXTURE"
assert_stdout_contains "REFUSE"
assert_stderr_contains "no git tag matches"
teardown_fixture

test_case "dry-run does not modify filesystem"
setup_fixture
build_round "$FIXTURE" 1 1 progressing 1
build_round "$FIXTURE" 1 2 progressing 1
build_round "$FIXTURE" 1 3 converged 0
assert_exit 0 "$COMPACT" "$FIXTURE" --dry-run --force
assert_stdout_contains "DRY-RUN"
[ -d "$FIXTURE/.review/round-1" ] && [ -d "$FIXTURE/.review/round-2" ] && _record_pass || _record_fail "intermediate rounds removed in dry-run"
[ ! -f "$FIXTURE/.review/round-3/compacted-history.md" ] && _record_pass || _record_fail "summary written in dry-run"
teardown_fixture

test_case "compact happy-path: deletes intermediates, writes summary"
setup_fixture
build_round "$FIXTURE" 1 1 progressing 2
build_round "$FIXTURE" 1 2 progressing 1
build_round "$FIXTURE" 1 3 converged 0
assert_exit 0 "$COMPACT" "$FIXTURE" --force
assert_stdout_contains "OK compacted delivery 1"
[ ! -d "$FIXTURE/.review/round-1" ] && _record_pass || _record_fail "round-1 not removed"
[ ! -d "$FIXTURE/.review/round-2" ] && _record_pass || _record_fail "round-2 not removed"
[ -d "$FIXTURE/.review/round-3" ] && _record_pass || _record_fail "round-3 (final) was removed"
[ -f "$FIXTURE/.review/round-3/compacted-history.md" ] && _record_pass || _record_fail "summary not written"
[ ! -d "$FIXTURE/.review/traces/round-1" ] && _record_pass || _record_fail "traces/round-1 not removed"
[ -d "$FIXTURE/.review/traces/round-3" ] && _record_pass || _record_fail "traces/round-3 was removed"
teardown_fixture

test_case "summary frontmatter has required fields"
setup_fixture
build_round "$FIXTURE" 2 1 progressing 1
build_round "$FIXTURE" 2 2 converged 0
assert_exit 0 "$COMPACT" "$FIXTURE" --force
SUMMARY="$FIXTURE/.review/round-2/compacted-history.md"
grep -q "^delivery_id: 2$" "$SUMMARY" && _record_pass || _record_fail "delivery_id missing"
grep -q "^final_round: 2$" "$SUMMARY" && _record_pass || _record_fail "final_round missing"
grep -q "^compacted_round_count: 1$" "$SUMMARY" && _record_pass || _record_fail "compacted_round_count missing"
grep -q "^total_issues_seen: " "$SUMMARY" && _record_pass || _record_fail "total_issues_seen missing"
grep -q "^generated_at: " "$SUMMARY" && _record_pass || _record_fail "generated_at missing"
teardown_fixture

test_case "only current delivery is compacted (older deliveries untouched)"
setup_fixture
# Older delivery: round 1, 2 (both progressing — but never compacted because
# they belong to delivery 1 which is no longer current)
build_round "$FIXTURE" 1 1 progressing 1
build_round "$FIXTURE" 1 2 converged 0
# Current delivery 2: rounds 3, 4
build_round "$FIXTURE" 2 3 progressing 1
build_round "$FIXTURE" 2 4 converged 0
assert_exit 0 "$COMPACT" "$FIXTURE" --force
[ -d "$FIXTURE/.review/round-1" ] && _record_pass || _record_fail "older delivery round-1 was deleted"
[ -d "$FIXTURE/.review/round-2" ] && _record_pass || _record_fail "older delivery round-2 was deleted"
[ ! -d "$FIXTURE/.review/round-3" ] && _record_pass || _record_fail "current delivery intermediate round-3 not deleted"
[ -f "$FIXTURE/.review/round-4/compacted-history.md" ] && _record_pass || _record_fail "summary at round-4 not written"
teardown_fixture

test_case "orphan trace dirs are cleaned (round dir already gone)"
setup_fixture
# Current delivery has rounds 5, 6 (5 intermediate, 6 converged)
build_round "$FIXTURE" 1 5 progressing 1
build_round "$FIXTURE" 1 6 converged 0
# Orphan traces from older deliveries — their round-N/ dirs no longer exist
# (e.g. were compacted in a prior --compact run). Should be removed.
mkdir -p "$FIXTURE/.review/traces/round-1"
mkdir -p "$FIXTURE/.review/traces/round-2"
echo "old log" > "$FIXTURE/.review/traces/round-1/dispatch-log.jsonl"
echo "old log" > "$FIXTURE/.review/traces/round-2/dispatch-log.jsonl"
# Also a non-round dir under traces/ that must NOT be touched
mkdir -p "$FIXTURE/.review/traces/metrics-cache"
echo "keep" > "$FIXTURE/.review/traces/metrics-cache/data"
assert_exit 0 "$COMPACT" "$FIXTURE" --force
[ ! -d "$FIXTURE/.review/traces/round-1" ] && _record_pass || _record_fail "orphan traces/round-1 not removed"
[ ! -d "$FIXTURE/.review/traces/round-2" ] && _record_pass || _record_fail "orphan traces/round-2 not removed"
[ ! -d "$FIXTURE/.review/traces/round-5" ] && _record_pass || _record_fail "intermediate traces/round-5 not removed"
[ -d "$FIXTURE/.review/traces/round-6" ] && _record_pass || _record_fail "final-round traces/round-6 must survive"
[ -d "$FIXTURE/.review/traces/metrics-cache" ] && _record_pass || _record_fail "non-round traces/ entry must not be touched"
teardown_fixture

end_tests
