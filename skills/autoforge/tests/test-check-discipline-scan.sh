#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test_helpers.sh
source "$DIR/lib/test_helpers.sh"
SCRIPT="$DIR/../scripts/check-discipline-scan.sh"

# --- clean tree --------------------------------------------------------
clean=$(mktempdir)
cat > "$clean/ok.ts" <<'TS'
test("creates user", async () => {
  const res = await api.create({name:"a"});
  expect(res.status).toBe(201);
  expect(res.body.id).toMatch(/[a-f0-9-]{36}/);
});
TS
start_test "clean tree -> exit 0 PASS"
out=$("$SCRIPT" "$clean" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- soft-pass: status array contain ----------------------------------
sp=$(mktempdir)
cat > "$sp/soft.ts" <<'TS'
expect([200,400,403]).toContain(res.status);
TS
start_test "soft-pass status array -> CR-AF12"
out=$("$SCRIPT" "$sp" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF12"
assert_stdout_contains "CR-AF12" "$out"

# --- silent debt: bare TODO -------------------------------------------
sd=$(mktempdir)
cat > "$sd/debt.go" <<'GO'
// TODO: replace later
package main
GO
start_test "bare TODO -> CR-AF13"
out=$("$SCRIPT" "$sd" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF13"
assert_stdout_contains "CR-AF13" "$out"

# --- TODO with issue link is OK ---------------------------------------
sdok=$(mktempdir)
cat > "$sdok/debt.go" <<'GO'
// TODO(owner/repo#42): pending review
package main
GO
start_test "TODO with issue link -> exit 0"
out=$("$SCRIPT" "$sdok" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- skip without issue -----------------------------------------------
sk=$(mktempdir)
cat > "$sk/skip.ts" <<'TS'
test.skip("temporary", () => {});
TS
start_test "test.skip without issue -> CR-AF14"
out=$("$SCRIPT" "$sk" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF14"
assert_stdout_contains "CR-AF14" "$out"

# --- no-error-as-success ----------------------------------------------
ne=$(mktempdir)
cat > "$ne/ne.go" <<'GO'
func TestX(t *testing.T) {
    err := Create()
    assert.NoError(t, err)
}
GO
start_test "assert.NoError without follow-up -> CR-AF20"
out=$("$SCRIPT" "$ne" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF20"
assert_stdout_contains "CR-AF20" "$out"

# --- abandonment: stub for M-XXX --------------------------------------
ab=$(mktempdir)
cat > "$ab/ab.ts" <<'TS'
function getUser() {
  // stub for M-007
  return null;
}
TS
start_test "// stub for M-007 -> CR-AF22"
out=$("$SCRIPT" "$ab" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF22"
assert_stdout_contains "CR-AF22" "$out"

# --- abandonment: waiting on M-XXX ------------------------------------
ab2=$(mktempdir)
cat > "$ab2/ab.py" <<'PY'
# waiting on M-012
def x(): pass
PY
start_test "# waiting on M-012 -> CR-AF22"
out=$("$SCRIPT" "$ab2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF22 (py)"
assert_stdout_contains "CR-AF22" "$out"

# --- soft-pass: oneOf -------------------------------------------------
sp2=$(mktempdir)
cat > "$sp2/oneof.ts" <<'TS'
expect(res.body.kind).to.be.oneOf(["a","b","c"]);
TS
start_test "to.be.oneOf -> CR-AF12"
out=$("$SCRIPT" "$sp2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF12 (oneOf)"
assert_stdout_contains "CR-AF12" "$out"

# --- soft-pass: pending() with no assertion ---------------------------
sp3=$(mktempdir)
cat > "$sp3/pending.js" <<'JS'
it("creates user", function () {
  pending("waiting on backend");
});
JS
start_test "pending() body -> CR-AF12"
out=$("$SCRIPT" "$sp3" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

# --- §M.1: .not.toThrow() ---------------------------------------------
ne2=$(mktempdir)
cat > "$ne2/throw.ts" <<'TS'
expect(() => create()).not.toThrow();
TS
start_test ".not.toThrow() -> CR-AF20"
out=$("$SCRIPT" "$ne2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF20 (.not.toThrow)"
assert_stdout_contains "CR-AF20" "$out"

# --- §M.1: expect(err).toBeNull() -------------------------------------
ne3=$(mktempdir)
cat > "$ne3/null.ts" <<'TS'
const err = await runOp();
expect(err).toBeNull();
TS
start_test "expect(err).toBeNull -> CR-AF20"
out=$("$SCRIPT" "$ne3" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

# --- §M.1: pytest.raises body is pass ---------------------------------
ne4=$(mktempdir)
cat > "$ne4/raises.py" <<'PY'
def test_x():
    with pytest.raises(ValueError): pass
PY
start_test "pytest.raises:pass -> CR-AF20"
out=$("$SCRIPT" "$ne4" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"

# --- §N: BLOCKED on M-XXX in markdown ---------------------------------
ab3=$(mktempdir)
cat > "$ab3/STATUS.md" <<'MD'
| Module | Status |
|---|---|
| M-007 | BLOCKED on M-012 |
MD
start_test "BLOCKED on M-XXX -> CR-AF22"
out=$("$SCRIPT" "$ab3" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
start_test "  finds CR-AF22 (markdown)"
assert_stdout_contains "CR-AF22" "$out"

# --- exclusion: vendored dirs not scanned -----------------------------
exd=$(mktempdir)
mkdir -p "$exd/node_modules/foo" "$exd/.git"
cat > "$exd/node_modules/foo/bad.ts" <<'TS'
expect([200,400]).toContain(res.status);
TS
cat > "$exd/.git/bad.ts" <<'TS'
// stub for M-007
TS
start_test "node_modules and .git excluded -> exit 0"
out=$("$SCRIPT" "$exd" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- exclusion: markdown inside a SKILL.md directory is not scanned ----
sk=$(mktempdir)
mkdir -p "$sk/skills/example"
cat > "$sk/skills/example/SKILL.md" <<'MD'
# Example skill
MD
cat > "$sk/skills/example/tester-prompt.md" <<'MD'
Forbidden patterns to recognize:
- `expect([200, 400, 403]).toContain(res.status)`
- `// waiting on M-007 to land`
- `BLOCKED on M-012`
MD
start_test "markdown inside SKILL.md dir is skipped -> exit 0"
out=$("$SCRIPT" "$sk" 2>&1) && rc=0 || rc=$?
assert_exit_code 0 "$rc" "out=$out"

# --- but: code files inside a SKILL.md directory are still scanned ----
sk2=$(mktempdir)
mkdir -p "$sk2/skills/example/scripts"
cat > "$sk2/skills/example/SKILL.md" <<'MD'
# Example skill
MD
cat > "$sk2/skills/example/scripts/leak.ts" <<'TS'
expect([200, 400]).toContain(res.status);
TS
start_test "code inside SKILL.md dir is still scanned -> exit 1"
out=$("$SCRIPT" "$sk2" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
assert_stdout_contains "CR-AF12" "$out"

# --- markdown OUTSIDE any SKILL.md dir is still scanned ----
sk3=$(mktempdir)
cat > "$sk3/STATUS.md" <<'MD'
| Module | Status |
|---|---|
| M-009 | BLOCKED on M-014 |
MD
start_test "markdown outside SKILL.md dir is still scanned -> exit 1"
out=$("$SCRIPT" "$sk3" 2>&1) && rc=0 || rc=$?
assert_exit_code 1 "$rc"
assert_stdout_contains "CR-AF22" "$out"

summary
