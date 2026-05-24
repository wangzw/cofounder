#!/usr/bin/env bash
# Tests for scripts/snapshot-leaves.sh and scripts/compute-review-scope.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
SNAP="$REPO_SCRIPTS/snapshot-leaves.sh"
SCOPE="$REPO_SCRIPTS/compute-review-scope.sh"

# Build a minimal PRD bundle with given delivery_id at given round.
# build_bundle <delivery_id>
build_bundle() {
    local did="$1"
    write_file "README.md" "# Design"
    write_file "modules/M-001.md" "m1"
    write_file "modules/M-002-auth.md" "m2"
    write_file "api/API-001.md" "a1"
    write_file "api/API-002-login.md" "a2"
    write_file "architecture.md" "arch"
    mkdir -p "$FIXTURE/.review"
    cat > "$FIXTURE/.review/state.yml" <<EOF
current_round: 1
current_delivery: $did
mode: review
phase: review
EOF
}

# ─── snapshot-leaves.sh ───────────────────────────────────────────────

test_case "snapshot exit 2 on missing args"
run_command "$SNAP"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "snapshot exit 2 on bad bundle dir"
run_command "$SNAP" "/no/such/dir" 1
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "snapshot exit 2 on non-numeric round"
setup_fixture
run_command "$SNAP" "$FIXTURE" "abc"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"
teardown_fixture

test_case "snapshot writes manifest with sha256 per leaf"
setup_fixture
build_bundle 1
assert_exit 0 "$SNAP" "$FIXTURE" 1
assert_stdout_contains "PASS"
M="$FIXTURE/.review/round-1/leaves-manifest.yml"
[ -f "$M" ] && _record_pass || _record_fail "manifest not created at $M"
test_case "snapshot manifest lists all leaves"
grep -q "README.md" "$M" && grep -q "modules/M-001.md" "$M" \
    && grep -q "api/API-001.md" "$M" && grep -q "architecture.md" "$M" \
    && _record_pass || _record_fail "missing leaves"
test_case "snapshot manifest records sha256 entries"
[ "$(grep -c '    sha256:' "$M")" = "6" ] && _record_pass \
    || _record_fail "expected 6 sha256 lines got $(grep -c '    sha256:' "$M")"
test_case "snapshot manifest records delivery_id"
grep -q "^delivery_id: 1$" "$M" && _record_pass || _record_fail "delivery_id missing"
test_case "snapshot excludes .review/ and versions/"
mkdir -p "$FIXTURE/versions/v1"
echo x > "$FIXTURE/versions/v1/README.md"
assert_exit 0 "$SNAP" "$FIXTURE" 2
M2="$FIXTURE/.review/round-2/leaves-manifest.yml"
! grep -q "versions/" "$M2" && ! grep -q ".review/" "$M2" \
    && _record_pass || _record_fail "exclusions broken"
test_case "snapshot deterministic on identical content"
H1=$(grep "api/API-001.md" -A1 "$M" | tail -1)
H2=$(grep "api/API-001.md" -A1 "$M2" | tail -1)
[ "$H1" = "$H2" ] && _record_pass || _record_fail "sha256 not stable"
teardown_fixture

# ─── compute-review-scope.sh ──────────────────────────────────────────

test_case "scope exit 2 on missing args"
run_command "$SCOPE"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "scope exit 2 if current manifest absent"
setup_fixture
build_bundle 1
assert_exit 2 "$SCOPE" "$FIXTURE" 1
assert_stderr_contains "current round manifest missing"
teardown_fixture

test_case "scope first-round-of-delivery (no prior manifest)"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 1
assert_stdout_contains "mode=full"
assert_stdout_contains "first-round-of-delivery"
S="$FIXTURE/.review/round-1/review-scope.yml"
grep -q "^mode: full$" "$S" && _record_pass || _record_fail "mode line missing"
test_case "scope first-round changed_leaves = all current leaves"
n=$(awk '/^changed_leaves:/{f=1;next} f && /^[a-z_]/{f=0} f && /^  - /' "$S" | wc -l | tr -d ' ')
[ "$n" = "6" ] && _record_pass \
    || _record_fail "expected 6 changed leaves, got $n"
teardown_fixture

test_case "scope --full forces full mode"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
"$SCOPE" "$FIXTURE" 1 >/dev/null
"$SNAP" "$FIXTURE" 2 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 2 --full
assert_stdout_contains "mode=full"
assert_stdout_contains "--full-flag"
teardown_fixture

test_case "scope incremental mode on file modification"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
echo "MODIFIED" > "$FIXTURE/api/API-001.md"
"$SNAP" "$FIXTURE" 2 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 2
assert_stdout_contains "mode=incremental"
assert_stdout_contains "changed=1"
S="$FIXTURE/.review/round-2/review-scope.yml"
grep -q "api/API-001.md" "$S" && _record_pass \
    || _record_fail "changed leaf not listed"
teardown_fixture

test_case "scope incremental detects added leaf"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
write_file "api/API-003-new.md" "a3"
"$SNAP" "$FIXTURE" 2 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 2
assert_stdout_contains "mode=incremental"
assert_stdout_contains "changed=1"
teardown_fixture

test_case "scope incremental detects deleted leaf"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
rm "$FIXTURE/api/API-002-login.md"
"$SNAP" "$FIXTURE" 2 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 2
assert_stdout_contains "mode=incremental"
assert_stdout_contains "changed=1"
teardown_fixture

test_case "scope falls back to older surviving manifest after compaction"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
"$SNAP" "$FIXTURE" 2 >/dev/null
# Simulate compaction: round-2 dir vanished entirely.
rm -rf "$FIXTURE/.review/round-2"
"$SNAP" "$FIXTURE" 3 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 3
assert_stdout_contains "mode=incremental"
S="$FIXTURE/.review/round-3/review-scope.yml"
grep -q "^prior_round: 1$" "$S" && _record_pass \
    || _record_fail "prior_round did not fall back to round-1"
teardown_fixture

test_case "scope full when prior round is from different delivery"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
# Simulate next delivery: bump delivery_id in state.yml, then snapshot.
sed -e 's/current_delivery: 1/current_delivery: 2/' "$FIXTURE/.review/state.yml" \
    > "$FIXTURE/.review/state.yml.new"
mv "$FIXTURE/.review/state.yml.new" "$FIXTURE/.review/state.yml"
"$SNAP" "$FIXTURE" 2 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 2
assert_stdout_contains "mode=full"
assert_stdout_contains "first-round-of-delivery"
teardown_fixture

test_case "scope file includes category_clusters with categories from criteria"
setup_fixture
build_bundle 1
"$SNAP" "$FIXTURE" 1 >/dev/null
assert_exit 0 "$SCOPE" "$FIXTURE" 1
S="$FIXTURE/.review/round-1/review-scope.yml"
grep -q "^category_clusters:" "$S" && _record_pass \
    || _record_fail "category_clusters section missing"
grep -q "category: module-boundary" "$S" && _record_pass \
    || _record_fail "module-boundary cluster missing"
grep -q "CR-SD-DESIGN01" "$S" && _record_pass \
    || _record_fail "CR-SD-DESIGN01 not listed in category_clusters criteria"
teardown_fixture

end_tests
