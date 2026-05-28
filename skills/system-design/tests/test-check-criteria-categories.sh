#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-criteria-categories.sh"

CATS_MIN='# Categories

### `module-boundary`

**Included CR-IDs:** `CR-SD-DESIGN01`.

### `meta`

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.
'

CRIT_MIN='## CR-SD-DESIGN01 module-boundary-chain

```yaml
- id: CR-SD-DESIGN01
  name: "module-boundary-chain"
  checker_type: llm
  category: module-boundary
```

## CR-META-mechanize

```yaml
- id: CR-META-mechanize
  name: "x"
  checker_type: llm
  category: meta
```

## CR-META-adversarial

```yaml
- id: CR-META-adversarial
  name: "y"
  checker_type: llm
  category: meta
```
'

test_case "exit 2 on missing arg"
run_command "$CHECK"
[ "$LAST_EXIT" = "2" ] && _record_pass || _record_fail "expected 2 got $LAST_EXIT"

test_case "exit 0 + PASS when every llm CR has a category present in catalog"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" "$CRIT_MIN"
assert_exit 0 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "PASS"
teardown_fixture

test_case "exit 1 when llm CR has no category field"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" '## CR-SD-DESIGN02

```yaml
- id: CR-SD-DESIGN02
  name: "x"
  checker_type: llm
```
'
assert_exit 1 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "CR-SD-DESIGN02"
assert_stdout_contains "missing category"
teardown_fixture

test_case "exit 1 when CR references unknown category"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" '## CR-SD-DESIGN02

```yaml
- id: CR-SD-DESIGN02
  name: "x"
  checker_type: llm
  category: nonexistent
```
'
assert_exit 1 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "nonexistent"
teardown_fixture

test_case "exit 1 when category lists a CR-ID that is not in criteria"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" '### `module-boundary`

**Included CR-IDs:** `CR-SD-DESIGN01`, `CR-SD-DESIGN99`.

### `meta`

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.
'
write_file "common/review-criteria.md" "$CRIT_MIN"
assert_exit 1 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "CR-SD-DESIGN99"
teardown_fixture

test_case "script-type CR without category is OK"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" "$CRIT_MIN
## CR-SD01

\`\`\`yaml
- id: CR-SD01
  name: \"z\"
  checker_type: script
\`\`\`
"
assert_exit 0 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
