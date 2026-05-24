#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
CHECK="$REPO_SCRIPTS/check-criteria-categories.sh"

CATS_MIN='# Categories

### `traceability`

**Included CR-IDs:** `CR-PP06`.

### `meta`

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.
'

CRIT_MIN='## CR-PP06 traceability-chain

```yaml
- id: CR-PP06
  name: "traceability-chain"
  checker_type: llm
  category: traceability
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
write_file "common/review-criteria.md" '## CR-PP07

```yaml
- id: CR-PP07
  name: "x"
  checker_type: llm
```
'
assert_exit 1 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "CR-PP07"
assert_stdout_contains "missing category"
teardown_fixture

test_case "exit 1 when CR references unknown category"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" '## CR-PP07

```yaml
- id: CR-PP07
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
write_file "common/criterion-categories.md" '### `traceability`

**Included CR-IDs:** `CR-PP06`, `CR-PP99`.

### `meta`

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.
'
write_file "common/review-criteria.md" "$CRIT_MIN"
assert_exit 1 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "CR-PP99"
teardown_fixture

test_case "script-type CR without category is OK"
setup_fixture
mkdir -p "$FIXTURE/common"
write_file "common/criterion-categories.md" "$CATS_MIN"
write_file "common/review-criteria.md" "$CRIT_MIN
## CR-PP01

\`\`\`yaml
- id: CR-PP01
  name: \"z\"
  checker_type: script
\`\`\`
"
assert_exit 0 "$CHECK" "$FIXTURE/common"
assert_stdout_contains "PASS"
teardown_fixture

end_tests
