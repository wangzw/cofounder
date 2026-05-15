#!/usr/bin/env bash
# tests/test-check-mermaid.sh — coverage for scripts/check-mermaid.sh
#
# Enforces CR-SD-MM01: every ```mermaid block in design leaves MUST satisfy
# three syntax constraints derived from observed renderer failures:
#   1. NO `\n` literal in node/edge/state labels (use `<br/>`).
#   2. Path labels starting with `/` MUST be quoted.
#   3. stateDiagram-v2 transition descriptions MUST NOT contain `:`
#      inside parentheses (use `=` or drop the parens). URL path-param
#      syntax `/sessions/:id` is excluded.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"

CHECK="$REPO_SCRIPTS/check-mermaid.sh"

# ─── Reusable fixture content ────────────────────────────────────────

CLEAN_README='# Clean Design

```mermaid
flowchart LR
  A["Line1<br/>Line2"] --> B
  C["/var/run/docker.sock"] --> D
  E[/parallelogram/] --> F
```
'

NEWLINE_LITERAL='# M-001

```mermaid
flowchart LR
  A[Header\nSubtitle] --> B
```
'

UNQUOTED_PATH='# M-002

```mermaid
flowchart LR
  Sock[/var/run/docker.sock] --> Daemon
```
'

COLON_IN_PARENS='# M-003

```mermaid
stateDiagram-v2
  running --> terminated : run.finished event (terminal_reason: finished)
```
'

URL_PATH_PRESERVED_BODY='# M-004

POST `/v1/sessions/:id` MUST stay verbatim outside mermaid blocks.

```mermaid
stateDiagram-v2
  running --> done : POST /v1/sessions/:id complete
```
'

MERMAID_COMMENT_TOLERATED='# M-005

```mermaid
flowchart LR
  %% \n and (key: value) in a comment must not fire CR-SD-MM01
  A[Plain] --> B
```
'

# ============================================================
test_case "PASS — clean mermaid blocks across leaf types"
setup_fixture
write_file "README.md" "$CLEAN_README"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "CR-SD-MM01 fires on \\n literal in flowchart label"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-001-newline.md" "$NEWLINE_LITERAL"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD-MM01"
assert_stdout_contains "M-001-newline.md"
assert_stdout_contains "\\\\n"
teardown_fixture

# ============================================================
test_case "CR-SD-MM01 fires on unquoted leading-/ label"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-002-path.md" "$UNQUOTED_PATH"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD-MM01"
assert_stdout_contains "M-002-path.md"
assert_stdout_contains "parallelogram"
teardown_fixture

# ============================================================
test_case "CR-SD-MM01 fires on : inside parens in stateDiagram-v2 transition"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-003-state.md" "$COLON_IN_PARENS"
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "CR-SD-MM01"
assert_stdout_contains "M-003-state.md"
assert_stdout_contains "terminal_reason: finished"
teardown_fixture

# ============================================================
test_case "PASS — URL path-param /:id is excluded from the : ban"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-004-url.md" "$URL_PATH_PRESERVED_BODY"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "PASS — \\n and (k: v) inside %% mermaid comments are tolerated"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-005-comment.md" "$MERMAID_COMMENT_TOLERATED"
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "PASS — valid parallelogram [/text/] is accepted as intentional"
setup_fixture
write_file "README.md" '# stub

```mermaid
flowchart LR
  P[/intentional parallelogram/] --> Q
```
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

# ============================================================
test_case "aggregates mermaid findings across multiple leaves"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-001-a.md" "$NEWLINE_LITERAL"
write_file "modules/M-002-b.md" "$UNQUOTED_PATH"
write_file "modules/M-003-c.md" "$COLON_IN_PARENS"
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q "M-001-a.md" && _record_pass || _record_fail "missing M-001"
echo "$LAST_STDOUT" | grep -q "M-002-b.md" && _record_pass || _record_fail "missing M-002"
echo "$LAST_STDOUT" | grep -q "M-003-c.md" && _record_pass || _record_fail "missing M-003"
teardown_fixture

# ============================================================
test_case "line numbers are distinct when the same defect repeats on consecutive lines"
setup_fixture
write_file "README.md" '# stub

```mermaid
flowchart LR
  A[Header\nSubtitle] --> B
  A[Header\nSubtitle] --> C
```
'
run_command "$CHECK" "$FIXTURE"
[ "$LAST_EXIT" = "1" ] && _record_pass || _record_fail "expected 1 got $LAST_EXIT"
echo "$LAST_STDOUT" | grep -q '"line 5:' && _record_pass || _record_fail "missing line 5 finding"
echo "$LAST_STDOUT" | grep -q '"line 6:' && _record_pass || _record_fail "missing line 6 finding (a stale `find()` bug would report both findings at line 5)"
teardown_fixture

# ============================================================
test_case "idempotent — same input twice yields identical stdout"
setup_fixture
write_file "README.md" "# stub"
write_file "modules/M-001.md" "$NEWLINE_LITERAL"
run_command "$CHECK" "$FIXTURE"
out1="$LAST_STDOUT"
run_command "$CHECK" "$FIXTURE"
out2="$LAST_STDOUT"
[ "$out1" = "$out2" ] && _record_pass || _record_fail "non-deterministic output"
teardown_fixture

end_tests
