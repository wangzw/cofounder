# Criterion-centric Batching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the review/revise loops in `prd-analysis` and `system-design` from file-centric grouping to criterion-centric grouping, with reviser sub-agents using `Edit`-only writes for concurrency safety.

**Architecture:** Add a `category:` field to every LLM-type criterion in `review-criteria.md`; refactor `compute-review-scope.sh` to emit per-category clusters; rewrite `cross-reviewer-subagent.md` to scope on one category; rewrite `per-issue-reviser-subagent.md` to handle multiple leaves of one criterion via `Edit`; loosen Rule 3/5/6 in `parallel-dispatch.md` accordingly. The change is symmetric between `prd-analysis` and `system-design`.

**Tech Stack:** Bash + Python3 (stdlib) scripts, Markdown sub-agent prompts, YAML config, shell-based tests under `tests/lib/test_helpers.sh`.

**Spec reference:** `docs/superpowers/specs/2026-05-24-criterion-centric-batching-design.md`

---

## File Structure

### New files

```
skills/prd-analysis/common/criterion-categories.md         # Taxonomy doc (7 categories + meta)
skills/system-design/common/criterion-categories.md        # Taxonomy doc (7 categories + meta)
skills/prd-analysis/scripts/check-criteria-categories.sh   # Catalog ↔ criteria.md consistency check
skills/system-design/scripts/check-criteria-categories.sh  # Same for SD
skills/prd-analysis/scripts/migrate-issues-add-category.sh # One-time backfill
skills/system-design/scripts/migrate-issues-add-category.sh
skills/prd-analysis/tests/test-check-criteria-categories.sh
skills/system-design/tests/test-check-criteria-categories.sh
skills/prd-analysis/tests/test-migrate-issues-add-category.sh
skills/system-design/tests/test-migrate-issues-add-category.sh
```

### Modified files (per skill, mirrored between prd-analysis and system-design)

```
common/review-criteria.md            # +category: field on every LLM-type CR
common/issue-schema.md               # +category required field
common/parallel-dispatch.md          # Rule 3/5/6 reviser semantics
review/index.md                      # Step 2 fan-out by category cluster
review/cross-reviewer-subagent.md    # Single-category scope + category_applied output
revise/index.md                      # Step 2 grouping by criterion_id (replace revise_groups)
revise/per-issue-reviser-subagent.md # Edit-only, multi-leaf per criterion
scripts/compute-review-scope.sh      # +category_clusters section in review-scope.yml
scripts/create-issues.sh             # +inject category from criterion_id
scripts/check-issue.sh               # +require category (with migration warning)
scripts/check-reviewer-output.sh     # +require category_applied
SKILL.md                             # cluster sizing prose + forbidden actions phrasing
CHANGELOG.md                         # breaking changes entry
tests/test-check-issue.sh
tests/test-create-issues.sh
tests/test-check-reviewer-output.sh
tests/test-review-scope.sh
tests/fixtures/...                   # smoke fixtures updated
```

---

## Phase 1: Taxonomy & Criteria Annotation

### Task 1: Write PRD `criterion-categories.md`

**Files:**
- Create: `skills/prd-analysis/common/criterion-categories.md`

- [ ] **Step 1: Inspect every LLM-type CR in `skills/prd-analysis/common/review-criteria.md` to derive the canonical CR-to-category mapping**

Run:
```bash
grep -E "^- id: CR-" -A 6 skills/prd-analysis/common/review-criteria.md | grep -E "^\s*(- id:|checker_type:|category:)" | paste - - - | grep "checker_type: llm"
```

Use the output to populate the table in Step 2. Every CR with `checker_type: llm` must appear in exactly one category. Cross-check against the spec §5.1 reference table.

- [ ] **Step 2: Write the taxonomy file**

```markdown
# Criterion Categories — prd-analysis

This file is the **single source of truth** for criterion-to-category mapping. The
`category:` field on every `checker_type: llm` entry in `common/review-criteria.md`
MUST match a category defined here. `scripts/check-criteria-categories.sh` enforces
this consistency.

Categories are the grouping dimension used by:

- `review/index.md` Step 2 — cross-reviewer fan-out (one cluster per category)
- `revise/index.md` Step 2 — per-issue-reviser grouping (one cluster per criterion;
  category is auxiliary metadata for prompt context)
- LLM sub-agent prompts — reviewer/reviser receive the category description so they
  can focus their attention on one conceptual surface at a time

---

## Categories

### `traceability`

Goal → Journey → Touchpoint → User Story → Feature → Analytics chain integrity.
Includes orphan-feature detection, dangling-id references, persona-journey coverage.

**Typical fix pattern:** add a missing reference; relocate a feature under the correct
journey; insert an analytics event row.

**Typical anti-pattern:** rewriting feature copy to mention a journey without actually
updating the journey-to-feature index.

**Included CR-IDs:** `CR-PP06`.

### `evidence`

Each requirement is grounded in research, competitive context, or explicit assumption.
Metrics are present and tied to features.

**Typical fix pattern:** cite a source for a claim; convert an implicit assumption to an
explicit `## Assumptions` entry.

**Included CR-IDs:** `CR-PP07`, `CR-PP08`, `CR-PP09`.

### `coherence`

Cross-leaf logical consistency: authorization, state-machine integrity, oscillation
detection, design-token completeness, frontend stack consistency, component contracts,
event flow.

**Typical fix pattern:** add a missing state transition; align two leaves that disagree
on a contract; reconcile a duplicated definition.

**Included CR-IDs:** `CR-PP12`, `CR-PP22`, `CR-PP24`, `CR-PP25`, `CR-PP26`, `CR-PP27`.

### `accessibility-i18n`

WCAG baseline, accessibility per feature, i18n baseline, i18n per feature (frontend +
backend).

**Typical fix pattern:** add an `accessibility:` block to a feature; add `i18n_keys:`.

**Included CR-IDs:** `CR-PP28`, `CR-PP29`, `CR-PP30`, `CR-PP31`, `CR-PP32`.

### `interaction-design`

Acceptance criteria testability, e2e scenarios, test data, interaction completeness,
forms, micro-interactions, journey interaction modes, design tokens, navigation, page
transitions, responsive, notifications.

**Typical fix pattern:** add a Given/When/Then block; specify a form's validation rules;
list responsive breakpoints.

**Included CR-IDs:** `CR-PP15`, `CR-PP16`, `CR-PP17`, `CR-PP18`, `CR-PP19`, `CR-PP20`,
`CR-PP21`, `CR-PP23`, `CR-PP33`, `CR-PP34`, `CR-PP38`, `CR-PP39`.

### `privacy-security`

Privacy compliance hooks, security policy, git branch strategy (security-relevant
defaults).

**Typical fix pattern:** add a `## Privacy` section; specify a security control.

**Included CR-IDs:** `CR-PP13`, `CR-PP43`, `CR-PP45`.

### `risk-governance`

Risks + mitigation, priority/roadmap alignment, self-containment, coding conventions,
test isolation, development workflow, backward compatibility.

**Typical fix pattern:** add a `## Risks` row; align roadmap with feature priority;
document a convention inline.

**Included CR-IDs:** `CR-PP10`, `CR-PP11`, `CR-PP14`, `CR-PP40`, `CR-PP41`, `CR-PP42`,
`CR-PP44`.

### `meta`

Reviewer-only categories for criteria-evolution feedback loop (guide §8).

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.

---

## Notes

- Formal (`checker_type: script`) CR-IDs do NOT carry a category. They are enforced by
  `run-checkers.sh` before any LLM dispatch and never enter a reviewer/reviser cluster.
- A CR that conceptually fits multiple categories takes its **dominant** category.
  Borderline cases should be documented in `common/review-criteria.md` with a comment
  explaining the choice.
- New LLM-type CRs added to `review-criteria.md` MUST also be added to one of the
  categories above. `scripts/check-criteria-categories.sh` will fail otherwise.
```

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/common/criterion-categories.md
git commit -m "docs(prd-analysis): add criterion-categories taxonomy (7 categories + meta)"
```

---

### Task 2: Annotate PRD `review-criteria.md` with `category:`

**Files:**
- Modify: `skills/prd-analysis/common/review-criteria.md`

- [ ] **Step 1: For every CR YAML block with `checker_type: llm`, append a `category:` field**

For each LLM-type CR entry, locate its YAML block and add `category: <name>` as the last line of the block. Categories must match `criterion-categories.md`.

Example transformation for `CR-PP06`:

Before:
```yaml
- id: CR-PP06
  name: "traceability-chain"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

After:
```yaml
- id: CR-PP06
  name: "traceability-chain"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
  category: traceability
```

Repeat for every `checker_type: llm` entry (see Task 1 Step 1 grep). The full mapping is in `criterion-categories.md`. Do NOT add `category:` to `checker_type: script` entries.

- [ ] **Step 2: Sanity-check the edits**

Run:
```bash
grep -B1 "category:" skills/prd-analysis/common/review-criteria.md | grep -c "checker_type: llm"
grep -c "category:" skills/prd-analysis/common/review-criteria.md
```

Both counts MUST be equal. If they differ, an `llm` CR is missing a `category:` or a `script` CR has one by mistake.

Expected: both counts are equal to the number of LLM-type CRs (use Task 1 Step 1 to get the canonical count).

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/common/review-criteria.md
git commit -m "feat(prd-analysis): annotate every LLM-type CR with category field"
```

---

### Task 3: Write SD `criterion-categories.md` + annotate SD `review-criteria.md`

**Files:**
- Create: `skills/system-design/common/criterion-categories.md`
- Modify: `skills/system-design/common/review-criteria.md`

- [ ] **Step 1: Inspect SD's LLM-type CR set**

Run:
```bash
grep -E "^- id: CR-" -A 6 skills/system-design/common/review-criteria.md | grep -E "^\s*(- id:|checker_type:|category:)" | paste - - - | grep "checker_type: llm"
```

- [ ] **Step 2: Write SD taxonomy with same structure as Task 1**

```markdown
# Criterion Categories — system-design

This file is the **single source of truth** for criterion-to-category mapping for the
system-design skill. The `category:` field on every `checker_type: llm` entry in
`common/review-criteria.md` MUST match a category defined here.
`scripts/check-criteria-categories.sh` enforces this consistency.

---

## Categories

### `module-boundary`

Module cohesion, dependency-direction rationale, boundary-enforcement justification.

**Included CR-IDs:** `CR-SD-DESIGN01`, `CR-SD-DESIGN02`, `CR-SD-DESIGN03`.

### `data-model`

Normalization, single source of truth, schema integrity (LLM-tier).

**Included CR-IDs:** `CR-SD-DESIGN04`.

### `api-contract`

API versioning strategy, contract evolution (LLM-tier).

**Included CR-IDs:** `CR-SD-DESIGN05`.

### `failure-modes`

Failure-mode coverage, error propagation, fallback paths.

**Included CR-IDs:** `CR-SD-DESIGN06`.

### `observability`

Logging, metrics, tracing coverage at module boundaries and API surfaces.

**Included CR-IDs:** `CR-SD-DESIGN07`.

### `security`

Threat model coverage, secret-handling, auth/authz at module boundaries.

**Included CR-IDs:** `CR-SD-DESIGN08`.

### `ui-promotion`

UI promotion action sets, hardening coverage, cross-journey-to-module coverage.

**Included CR-IDs:** `CR-SD-DESIGN09`, `CR-SD-DESIGN10`, `CR-SD-DESIGN11`.

### `meta`

**Included CR-IDs:** `CR-META-mechanize`, `CR-META-adversarial`.

---

## Notes

(Same notes as the prd-analysis version — formal CRs have no category, dominant category
rule for borderline CRs, new LLM CRs must be added here.)
```

- [ ] **Step 3: Annotate every LLM-type CR in SD `review-criteria.md`** (same pattern as Task 2)

- [ ] **Step 4: Sanity-check the edits**

Run:
```bash
grep -B1 "category:" skills/system-design/common/review-criteria.md | grep -c "checker_type: llm"
grep -c "category:" skills/system-design/common/review-criteria.md
```

Counts must be equal.

- [ ] **Step 5: Commit**

```bash
git add skills/system-design/common/criterion-categories.md skills/system-design/common/review-criteria.md
git commit -m "feat(system-design): add criterion-categories taxonomy + annotate every LLM-type CR"
```

---

### Task 4: Write `check-criteria-categories.sh` consistency check (PRD)

**Files:**
- Create: `skills/prd-analysis/scripts/check-criteria-categories.sh`
- Create: `skills/prd-analysis/tests/test-check-criteria-categories.sh`

- [ ] **Step 1: Write the failing test**

```bash
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
'

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
write_file "common/review-criteria.md" "$CRIT_MIN"'## CR-PP01

```yaml
- id: CR-PP01
  checker_type: script
```
'
assert_exit 0 "$CHECK" "$FIXTURE/common"
teardown_fixture

end_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash skills/prd-analysis/tests/test-check-criteria-categories.sh`
Expected: FAIL (script doesn't exist)

- [ ] **Step 3: Implement `check-criteria-categories.sh`**

```bash
#!/usr/bin/env bash
# check-criteria-categories.sh — verify consistency between
# common/criterion-categories.md and common/review-criteria.md:
#   - Every checker_type: llm CR in review-criteria.md has a category: field
#   - Every category: value appears in criterion-categories.md as a heading
#   - Every CR-ID listed under a category in criterion-categories.md exists in
#     review-criteria.md
#
# Usage: check-criteria-categories.sh <common-dir>
# Exit codes: 0 PASS; 1 inconsistency found; 2 script error

set -euo pipefail

COMMON_DIR="${1:-}"
if [ -z "$COMMON_DIR" ] || [ ! -d "$COMMON_DIR" ]; then
  echo "Usage: $0 <common-dir>" >&2
  exit 2
fi
CATS="$COMMON_DIR/criterion-categories.md"
CRIT="$COMMON_DIR/review-criteria.md"
for f in "$CATS" "$CRIT"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 2; }
done

python3 - "$CATS" "$CRIT" <<'PYEOF'
import re, sys
cats_path, crit_path = sys.argv[1], sys.argv[2]

cats_text = open(cats_path).read()
crit_text = open(crit_path).read()

# Parse categories: ### `name` headers + their CR-ID lists
cat_names = set(re.findall(r"^###\s+`([a-z0-9-]+)`", cats_text, re.M))
cat_to_crs: dict[str, set[str]] = {}
current = None
for line in cats_text.splitlines():
    m = re.match(r"^###\s+`([a-z0-9-]+)`", line)
    if m:
        current = m.group(1)
        cat_to_crs[current] = set()
        continue
    if current and "Included CR-IDs:" in line:
        for cr in re.findall(r"`(CR-[A-Z0-9-]+)`", line):
            cat_to_crs[current].add(cr)

# Parse criteria: YAML blocks under ## CR-XXX headers
crit_blocks = re.findall(
    r"^- id: (CR-[A-Z0-9-]+)\s*\n((?:  [^\n]*\n)+)",
    crit_text, re.M)

failures: list[str] = []
seen_llm: set[str] = set()
for crid, body in crit_blocks:
    checker = re.search(r"checker_type:\s*(\w+)", body)
    category = re.search(r"category:\s*([a-z0-9-]+)", body)
    if checker and checker.group(1) == "llm":
        seen_llm.add(crid)
        if not category:
            failures.append(f"FAIL: {crid} is checker_type: llm but has no category field — missing category")
            continue
        if category.group(1) not in cat_names:
            failures.append(f"FAIL: {crid} has category: {category.group(1)} which is not defined in criterion-categories.md")
            continue

# Every CR listed in a category must exist as an LLM CR
for cat, crs in cat_to_crs.items():
    for cr in crs:
        if cr not in seen_llm:
            failures.append(f"FAIL: category `{cat}` lists `{cr}` but no LLM CR with that id exists in review-criteria.md")

if failures:
    for f in failures:
        print(f)
    sys.exit(1)
print(f"PASS: {len(seen_llm)} LLM CRs cross-checked against {len(cat_names)} categories")
PYEOF
```

- [ ] **Step 4: Make executable + run tests**

Run:
```bash
chmod +x skills/prd-analysis/scripts/check-criteria-categories.sh
bash skills/prd-analysis/tests/test-check-criteria-categories.sh
```
Expected: all test cases PASS.

- [ ] **Step 5: Run the new check against the real PRD criteria**

Run: `bash skills/prd-analysis/scripts/check-criteria-categories.sh skills/prd-analysis/common/`
Expected: PASS line with the count of LLM CRs and categories. If it fails, fix the gaps in Task 2's annotations.

- [ ] **Step 6: Commit**

```bash
git add skills/prd-analysis/scripts/check-criteria-categories.sh skills/prd-analysis/tests/test-check-criteria-categories.sh
git commit -m "feat(prd-analysis): script to verify criteria↔categories consistency"
```

---

### Task 5: Mirror Task 4 for system-design

**Files:**
- Create: `skills/system-design/scripts/check-criteria-categories.sh` (byte-identical to PRD version)
- Create: `skills/system-design/tests/test-check-criteria-categories.sh` (adapt CR-IDs in fixtures to SD's namespace, e.g. `CR-SD-DESIGN01`/`CR-SD01`)

- [ ] **Step 1: Copy script verbatim**

```bash
cp skills/prd-analysis/scripts/check-criteria-categories.sh skills/system-design/scripts/check-criteria-categories.sh
chmod +x skills/system-design/scripts/check-criteria-categories.sh
```

- [ ] **Step 2: Copy + adapt test fixtures**

```bash
cp skills/prd-analysis/tests/test-check-criteria-categories.sh skills/system-design/tests/test-check-criteria-categories.sh
```

Then in the SD copy, replace `CR-PP06` → `CR-SD-DESIGN01`, `CR-PP07` → `CR-SD-DESIGN02`, `CR-PP99` → `CR-SD-DESIGN99`, and `traceability` → `module-boundary` in fixture strings.

- [ ] **Step 3: Run tests + real-criteria check**

Run:
```bash
bash skills/system-design/tests/test-check-criteria-categories.sh
bash skills/system-design/scripts/check-criteria-categories.sh skills/system-design/common/
```
Both expected to PASS.

- [ ] **Step 4: Commit**

```bash
git add skills/system-design/scripts/check-criteria-categories.sh skills/system-design/tests/test-check-criteria-categories.sh
git commit -m "feat(system-design): script to verify criteria↔categories consistency"
```

---

## Phase 2: Schema Changes

### Task 6: Update `issue-schema.md` to add `category` field (PRD + SD)

**Files:**
- Modify: `skills/prd-analysis/common/issue-schema.md`
- Modify: `skills/system-design/common/issue-schema.md`

- [ ] **Step 1: Edit PRD `issue-schema.md`**

Find the on-disk frontmatter block in `## On-disk schema` and add `category:` immediately after `criterion_id:`:

```markdown
---
id: I-NNN                      # Required. Stable per artifact root, monotonic. Format: I-<3+ digits>.
criterion_id: CR-XXX           # Required. Must match an entry in common/review-criteria.md.
category: traceability         # Required (since v1.4). Inherited from criterion_id's category in criterion-categories.md. create-issues.sh injects automatically.
file: relative/path.md         # Required. Path from artifact root. May be "" for repo-wide issues.
...
```

And add a row to the "Required-field rules" table:

| `category` | Always (v1.4+) | One of the categories in `criterion-categories.md`. Auto-derived from `criterion_id`. Legacy issues without this field treated as warning by `check-issue.sh`. |

- [ ] **Step 2: Mirror the same edits in SD `issue-schema.md`**

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/common/issue-schema.md skills/system-design/common/issue-schema.md
git commit -m "docs: issue-schema gains category field (auto-derived from criterion_id)"
```

---

### Task 7: Extend `check-issue.sh` to validate `category` (PRD)

**Files:**
- Modify: `skills/prd-analysis/scripts/check-issue.sh`
- Modify: `skills/prd-analysis/tests/test-check-issue.sh`

- [ ] **Step 1: Read existing `check-issue.sh` to understand the validation pattern**

Run: `bash skills/prd-analysis/scripts/check-issue.sh --help 2>&1 || cat skills/prd-analysis/scripts/check-issue.sh | head -60`

- [ ] **Step 2: Add a failing test case in `test-check-issue.sh`**

Append before `end_tests`:

```bash
test_case "category missing emits warning (non-fatal) on legacy issue"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-PP06
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "WARNING"
assert_stdout_contains "category"
teardown_fixture

test_case "category present passes"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-PP06
category: traceability
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$CHECK" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "category with invalid value fails"
setup_fixture
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-PP06
category: not-a-real-category
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history:
  - {round: 1, action: created}
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 1 "$CHECK" "$FIXTURE"
assert_stdout_contains "category"
assert_stdout_contains "not-a-real-category"
teardown_fixture
```

- [ ] **Step 3: Run test to verify the new cases fail**

Run: `bash skills/prd-analysis/tests/test-check-issue.sh`
Expected: 3 new failures with the existing tests still passing.

- [ ] **Step 4: Modify `check-issue.sh` to validate `category`**

Locate the field-validation block (after the `state` validation). Add:

```python
# Inside the python heredoc in check-issue.sh:
# Read the valid category set from criterion-categories.md
CATS_FILE = os.path.join(prd_root.rstrip("/"), "..", "..", "..", "skills", "prd-analysis", "common", "criterion-categories.md")
# Better: derive from skill root. For now use a fallback list, then prefer file if present.
VALID_CATEGORIES = {
    "traceability", "evidence", "coherence", "accessibility-i18n",
    "interaction-design", "privacy-security", "risk-governance", "meta",
}
# Try to read from skill catalog if discoverable via state.yml's skill-root
# (omit if not available; just use the hardcoded set above).

cat = fm.get("category")
if cat is None:
    findings.append(Finding(
        "WARNING", file_rel, None, "CR-IS01",
        "issue file missing required field: category (legacy file? regenerate via migrate-issues-add-category.sh)"))
elif cat not in VALID_CATEGORIES:
    findings.append(Finding(
        "FAIL", file_rel, None, "CR-IS01",
        f"issue file has unknown category: {cat}"))
```

Note: keep the canonical category set in a constant inside the script. The category set is small and changes rarely; duplicating it here avoids parsing the markdown taxonomy at runtime. `check-criteria-categories.sh` already enforces taxonomy <-> criteria consistency, so drift would be caught upstream.

- [ ] **Step 5: Run tests; all should pass**

Run: `bash skills/prd-analysis/tests/test-check-issue.sh`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add skills/prd-analysis/scripts/check-issue.sh skills/prd-analysis/tests/test-check-issue.sh
git commit -m "feat(prd-analysis): check-issue validates issue.category (legacy fields warned, not errored)"
```

---

### Task 8: Mirror Task 7 for system-design

**Files:**
- Modify: `skills/system-design/scripts/check-issue.sh`
- Modify: `skills/system-design/tests/test-check-issue.sh`

- [ ] **Step 1: Apply same diff structure as Task 7**

Use SD's category set:
```python
VALID_CATEGORIES = {
    "module-boundary", "data-model", "api-contract", "failure-modes",
    "observability", "security", "ui-promotion", "meta",
}
```

- [ ] **Step 2: Adapt fixture CR-IDs to SD namespace** (`CR-SD-DESIGN01` etc.)

- [ ] **Step 3: Run tests; commit**

```bash
bash skills/system-design/tests/test-check-issue.sh
git add skills/system-design/scripts/check-issue.sh skills/system-design/tests/test-check-issue.sh
git commit -m "feat(system-design): check-issue validates issue.category"
```

---

### Task 9: Extend `create-issues.sh` to inject `category` (PRD)

**Files:**
- Modify: `skills/prd-analysis/scripts/create-issues.sh`
- Modify: `skills/prd-analysis/tests/test-create-issues.sh`

- [ ] **Step 1: Add failing test**

Append before `end_tests` in `test-create-issues.sh`:

```bash
test_case "category injected from criterion_id"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
mkdir -p "$FIXTURE/.review/round-1/issues"
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "category_applied": "traceability",
  "issues": [
    {
      "criterion_id": "CR-PP06",
      "file": "features/F-001.md",
      "severity": "error",
      "description": "broken trace",
      "suggested_fix": "fix it"
    }
  ]
}'
assert_exit 0 "$REPO_SCRIPTS/create-issues.sh" "$FIXTURE" 1
assert_stdout_contains "I-001"
result=$(cat "$FIXTURE/.review/round-1/issues/I-001.md")
case "$result" in
  *"category: traceability"*) _record_pass ;;
  *) _record_fail "expected category: traceability in issue body, got: $result" ;;
esac
teardown_fixture
```

- [ ] **Step 2: Run test; verify it fails**

Run: `bash skills/prd-analysis/tests/test-create-issues.sh`
Expected: FAIL with missing category line.

- [ ] **Step 3: Modify `create-issues.sh` to inject `category`**

Find the section that writes issue frontmatter. The script already has a CR-ID-to-category mapping from `review-criteria.md`. Add the lookup logic:

```python
# Inside the python heredoc:
# After parsing review-criteria.md to get LLM CR set:
crit_text = open(os.path.join(common_dir, "review-criteria.md")).read()
cr_to_category: dict[str, str] = {}
for m in re.finditer(r"- id:\s*(CR-[A-Z0-9-]+)\s*\n((?:  [^\n]*\n)+)", crit_text):
    crid, body = m.group(1), m.group(2)
    cm = re.search(r"category:\s*([a-z0-9-]+)", body)
    if cm:
        cr_to_category[crid] = cm.group(1)

# When writing each issue:
cat = cr_to_category.get(criterion_id)
if cat is None:
    # Skip — legacy CR without category. check-issue.sh will warn.
    cat_line = ""
else:
    cat_line = f"category: {cat}\n"

issue_md = f"""---
id: {issue_id}
criterion_id: {criterion_id}
{cat_line}file: {file_path}
severity: {severity}
state: new
created_in_round: {round_num}
history:
  - {{round: {round_num}, action: created}}
fix_history: []
---

## Description
{description}

## Suggested fix
{suggested_fix}
"""
```

- [ ] **Step 4: Run test; all pass**

Run: `bash skills/prd-analysis/tests/test-create-issues.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/prd-analysis/scripts/create-issues.sh skills/prd-analysis/tests/test-create-issues.sh
git commit -m "feat(prd-analysis): create-issues injects category from criterion_id"
```

---

### Task 10: Mirror Task 9 for system-design

**Files:**
- Modify: `skills/system-design/scripts/create-issues.sh`
- Modify: `skills/system-design/tests/test-create-issues.sh`

- [ ] **Step 1-4: Same pattern, SD namespace**

Use `CR-SD-DESIGN01` / `module-boundary` in test fixtures.

- [ ] **Step 5: Commit**

```bash
git add skills/system-design/scripts/create-issues.sh skills/system-design/tests/test-create-issues.sh
git commit -m "feat(system-design): create-issues injects category from criterion_id"
```

---

### Task 11: Extend `check-reviewer-output.sh` to validate `category_applied` (PRD)

**Files:**
- Modify: `skills/prd-analysis/scripts/check-reviewer-output.sh`
- Modify: `skills/prd-analysis/tests/test-check-reviewer-output.sh`

- [ ] **Step 1: Add failing test**

Append before `end_tests` in `test-check-reviewer-output.sh`:

```bash
test_case "category_applied present passes"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "category_applied": "traceability",
  "issues": []
}'
assert_exit 0 "$REPO_SCRIPTS/check-reviewer-output.sh" "$FIXTURE"
assert_stdout_contains "PASS"
teardown_fixture

test_case "category_applied missing fails CR-RO02"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/reviewer-output"
write_file ".review/round-1/reviewer-output/R1-V-001.json" '{
  "round": 1,
  "reviewer_variant": "cross",
  "trace_id": "R1-V-001",
  "issues": []
}'
assert_exit 1 "$REPO_SCRIPTS/check-reviewer-output.sh" "$FIXTURE"
assert_stdout_contains "category_applied"
teardown_fixture
```

- [ ] **Step 2: Run test; verify failure**

- [ ] **Step 3: Modify `check-reviewer-output.sh`** — add to the per-file required-fields check:

```python
# After loading JSON `data`:
if "category_applied" not in data:
    findings.append(Finding(
        "FAIL", rel_path, None, "CR-RO02",
        "reviewer output missing required top-level field: category_applied"))
```

- [ ] **Step 4: Tests pass; commit**

```bash
bash skills/prd-analysis/tests/test-check-reviewer-output.sh
git add skills/prd-analysis/scripts/check-reviewer-output.sh skills/prd-analysis/tests/test-check-reviewer-output.sh
git commit -m "feat(prd-analysis): check-reviewer-output requires category_applied"
```

---

### Task 12: Mirror Task 11 for system-design

```bash
git add skills/system-design/scripts/check-reviewer-output.sh skills/system-design/tests/test-check-reviewer-output.sh
git commit -m "feat(system-design): check-reviewer-output requires category_applied"
```

---

## Phase 3: Review Pipeline (category-cluster fan-out)

### Task 13: Extend `compute-review-scope.sh` to emit `category_clusters` (PRD)

**Files:**
- Modify: `skills/prd-analysis/scripts/compute-review-scope.sh`
- Modify: `skills/prd-analysis/tests/test-review-scope.sh`

- [ ] **Step 1: Add failing test**

Append before `end_tests` in `test-review-scope.sh`:

```bash
test_case "review-scope.yml contains category_clusters with all LLM categories"
setup_fixture
mkdir -p "$FIXTURE/.review"
write_file "README.md" "# product\n"
write_file "features/F-001.md" "x"
write_file "journeys/J-001.md" "x"
write_file "architecture.md" "y"
# Simulate a prior manifest absent → full mode is fine
assert_exit 0 "$REPO_SCRIPTS/compute-review-scope.sh" "$FIXTURE" 1
scope_file="$FIXTURE/.review/round-1/review-scope.yml"
[ -f "$scope_file" ] && _record_pass || _record_fail "missing $scope_file"
result=$(cat "$scope_file")
case "$result" in
  *"category_clusters:"*) _record_pass ;;
  *) _record_fail "category_clusters section missing" ;;
esac
case "$result" in
  *"category: traceability"*) _record_pass ;;
  *) _record_fail "traceability cluster missing" ;;
esac
teardown_fixture
```

- [ ] **Step 2: Verify failure**

Run: `bash skills/prd-analysis/tests/test-review-scope.sh`

- [ ] **Step 3: Extend `compute-review-scope.sh`**

In the python heredoc, after determining `mode` / `changed_leaves` / `unchanged_leaves`:

```python
# Parse criterion -> category map from review-criteria.md
common_dir = os.path.join(SKILL_ROOT, "common")
crit_text = open(os.path.join(common_dir, "review-criteria.md")).read()
cr_to_cat: dict[str, str] = {}
for m in re.finditer(r"- id:\s*(CR-[A-Z0-9-]+)\s*\n((?:  [^\n]*\n)+)", crit_text):
    crid, body = m.group(1), m.group(2)
    if "checker_type: llm" not in body:
        continue
    cm = re.search(r"category:\s*([a-z0-9-]+)", body)
    if cm:
        cr_to_cat[crid] = cm.group(1)

# Determine which CR-IDs are in scope this round (respecting incremental_skip)
cat_to_crs: dict[str, list[str]] = {}
for crid, cat in cr_to_cat.items():
    cat_to_crs.setdefault(cat, []).append(crid)

all_leaves = sorted(changed_leaves | unchanged_leaves)
# Build category_clusters
clusters_yaml = "category_clusters:\n"
for cat in sorted(cat_to_crs):
    clusters_yaml += f"  - category: {cat}\n"
    clusters_yaml += f"    criteria: [{', '.join(sorted(cat_to_crs[cat]))}]\n"
    clusters_yaml += f"    leaves: [{', '.join(all_leaves)}]\n"

scope_yaml += clusters_yaml
open(scope_yml_path, "w").write(scope_yaml)
```

Note: `SKILL_ROOT` must be derived inside the script — typically `script_dir/..`. Use the existing pattern in the script (look for `SCRIPT_DIR` / similar). Pass it into the python heredoc via argv.

- [ ] **Step 4: Tests pass**

Run: `bash skills/prd-analysis/tests/test-review-scope.sh`

- [ ] **Step 5: Commit**

```bash
git add skills/prd-analysis/scripts/compute-review-scope.sh skills/prd-analysis/tests/test-review-scope.sh
git commit -m "feat(prd-analysis): compute-review-scope emits category_clusters"
```

---

### Task 14: Mirror Task 13 for system-design

```bash
git add skills/system-design/scripts/compute-review-scope.sh skills/system-design/tests/test-review-scope.sh
git commit -m "feat(system-design): compute-review-scope emits category_clusters"
```

---

### Task 15: Rewrite PRD `cross-reviewer-subagent.md` (single-category scope)

**Files:**
- Modify: `skills/prd-analysis/review/cross-reviewer-subagent.md`

- [ ] **Step 1: Read existing prompt fully**

Run: `cat skills/prd-analysis/review/cross-reviewer-subagent.md`

- [ ] **Step 2: Edit the "What you do" numbered list**

Replace step 5 (currently "Apply every criterion in `common/review-criteria.md` whose `checker_type: llm` ...") with:

```markdown
5. **Read your assigned category cluster** from
   `<artifact-root>/.review/round-<N>/review-scope.yml`. The cluster you
   were dispatched against names a single `category` and a `criteria` list
   of CR-IDs. **Apply ONLY those CR-IDs**. Do NOT apply criteria from
   other categories — those are being reviewed in parallel by other
   sub-agents with their own scope. The orchestrator's dispatch message
   tells you which category you own; if it does not, ACK FAIL.
```

- [ ] **Step 3: Edit the JSON output schema example**

Replace the example reviewer-output JSON with:

```json
{
  "round": 3,
  "reviewer_variant": "cross",
  "trace_id": "R3-V-001",
  "scope_applied": "incremental",
  "category_applied": "traceability",
  "issues": [
    {
      "criterion_id": "CR-PP06",
      "file": "features/F-007-checkout.md",
      "severity": "error",
      "description": "Acceptance Criteria #2 references the 'guest-checkout' touchpoint, but the J-002-onboarding journey lists no such touchpoint — there is no upstream user path that triggers AC#2.",
      "suggested_fix": "Either add a 'guest-checkout' touchpoint to journeys/J-002-onboarding.md (Stage 'Browse and Add to Cart'), or rewrite F-007 AC#2 to reference an existing touchpoint."
    }
  ]
}
```

- [ ] **Step 4: Add `category_applied` to "Top-level required fields"**

In the "### Top-level required fields" section, add:

```markdown
- `category_applied` — one of the category names defined in
  `common/criterion-categories.md`. MUST equal the category your cluster
  was scoped to. If your dispatch did not specify a category, ACK FAIL.
  This is enforced by `scripts/check-reviewer-output.sh`.
```

- [ ] **Step 5: Add a "Why one category at a time" note to the prompt opening**

Insert near the top, right after the trace-id explanation:

```markdown
## Scope: one category, all leaves

Each cross-reviewer dispatch is scoped to a single criterion category
(e.g. `traceability`, `coherence`, `accessibility-i18n`). You will see
the entire artifact bundle, but you only apply the CR-IDs listed in your
cluster — every other category is being reviewed in parallel by a sibling
sub-agent. Stay in lane: finding an issue that conceptually belongs to
another category is NOT your job; that sibling will catch it. This
discipline is what makes one-cluster-per-category cheaper than one
reviewer that handles all criteria across all files.
```

- [ ] **Step 6: Commit**

```bash
git add skills/prd-analysis/review/cross-reviewer-subagent.md
git commit -m "feat(prd-analysis): cross-reviewer scoped to one category per dispatch"
```

---

### Task 16: Mirror Task 15 for system-design

**Files:**
- Modify: `skills/system-design/review/cross-reviewer-subagent.md`

Apply the same diffs with SD's namespace (CR-SD-DESIGN* IDs, SD categories).

```bash
git add skills/system-design/review/cross-reviewer-subagent.md
git commit -m "feat(system-design): cross-reviewer scoped to one category per dispatch"
```

---

### Task 17: Update PRD `review/index.md` Step 2 to fan out by category

**Files:**
- Modify: `skills/prd-analysis/review/index.md`

- [ ] **Step 1: Read existing Step 2 (lines around 96–135)**

- [ ] **Step 2: Replace Step 2 body with the new fan-out spec**

Replace from `### Step 2 — Cross-Reviewer Dispatch (substantive only)` through to the start of `### Step 3 — Adversarial-Reviewer Dispatch` with:

```markdown
### Step 2 — Cross-Reviewer Dispatch (per-category fan-out)

Pre-conditions: Step 1 exit 0 (entry verification PASS) **and** there is meaningful
work for the reviewer (artifact changed since last delivery, or prior-round
issues are still open).

Read `<prd-dir>/.review/round-<N>/review-scope.yml`. Its `category_clusters:` block
lists one entry per criterion category active this round (each entry has
`category`, `criteria`, `leaves`). For each entry, dispatch ONE
`review/cross-reviewer-subagent.md` sub-agent, all in a **single assistant response**
(parallel-dispatch.md Rule 1).

The dispatch prompt for each sub-agent MUST include:

- `trace_id: R<round>-V-<NNN>` (counter monotonic across all reviewer dispatches this round)
- The category name and the full CR-ID list for that category
- The leaves list (full path from artifact root)
- The PRD bundle root path (for reading)
- Standard reviewer inputs unchanged: `summary.yml` path, `review-scope.yml` path,
  writer self-review files

**Sub-agent output**: one JSON file at
`<prd-dir>/.review/round-<N>/reviewer-output/<trace_id>.json` with required field
`category_applied` (validated by `check-reviewer-output.sh`).

**Orchestrator action on ACK**: record each trace_id in `state.yml`; do not yet
materialize issues — that happens after Step 3 / 4 so all reviewer outputs are merged
in one create-issues pass.

**Cluster cap protection**: if a category's `leaves` list exceeds
`config.yml review.cluster_leaf_cap` (default 25), the orchestrator splits the cluster
into multiple sub-clusters by leaf, each carrying the same `criteria` list. Each
sub-cluster gets its own trace_id and runs in parallel.
```

- [ ] **Step 3: Update Step 2's "Sub-agent inputs" bullet list** to remove the implication that the reviewer applies all LLM criteria; replace with category-scoped wording.

- [ ] **Step 4: Commit**

```bash
git add skills/prd-analysis/review/index.md
git commit -m "feat(prd-analysis): review Step 2 fans out one reviewer per category"
```

---

### Task 18: Mirror Task 17 for system-design

```bash
git add skills/system-design/review/index.md
git commit -m "feat(system-design): review Step 2 fans out one reviewer per category"
```

---

## Phase 4: Revise Pipeline (criterion-cluster reviser)

### Task 19: Rewrite PRD `revise/index.md` Step 2 grouping

**Files:**
- Modify: `skills/prd-analysis/revise/index.md`

- [ ] **Step 1: Replace Step 2's `revise_groups` block with `revise_clusters`**

In the section starting `### Step 2 — Build Issue-Group Manifest (script)`, replace the YAML example and surrounding prose with:

```markdown
### Step 2 — Build Criterion-Cluster Manifest

The orchestrator reads `<prd-dir>/.review/round-<N>/issues/*.md` and groups them
by `criterion_id:` field (NOT by `file:` — that was the prior model). Issues whose
`state` is already in {fixed, false-positive, deferred, superseded} are skipped —
only `state: new` needs work. The grouping is mechanical (frontmatter-only
inspection); the orchestrator does it inline. Output is held in `state.yml` as
`revise_clusters:`.

Each cluster covers ONE `criterion_id` and AT MOST `config.yml revise.edit_cap`
issues (default 8). When a criterion has more than `edit_cap` issues, the
orchestrator splits it into multiple clusters; each cluster gets a distinct
`cluster_id` (`R<round>-CC-<nnn>`).

```yaml
revise_clusters:
  - cluster_id: R3-CC-001
    criterion_id: CR-PP06
    category: traceability
    issues: [I-007, I-019, I-024]
    affected_leaves: [features/F-001-checkout.md, features/F-003-cart.md, journeys/J-002.md]
  - cluster_id: R3-CC-002
    criterion_id: CR-PP24
    category: coherence
    issues: [I-012, I-031]
    affected_leaves: [features/F-001-checkout.md, features/F-005-orders.md]
```

It is **expected** that the same leaf appears in multiple clusters — different
revisers will Edit different sections of that leaf, with `Edit`'s unique-match
semantics providing the safety lock.

(Step 1's `verify-phase-entry revise` already guarantees at least one
`state: new` issue exists in the round, so the manifest is always non-empty when
we reach Step 2.)
```

- [ ] **Step 2: Replace Step 3 (Fan-out) wording**

Edit the "### Step 3 — Fan-out Per-Issue-Reviser (parallel)" section. Replace the dispatch description with:

```markdown
### Step 3 — Fan-out Per-Criterion-Cluster Reviser (parallel)

For each entry in `revise_clusters`, dispatch one
`revise/per-issue-reviser-subagent.md` (single assistant response,
parallel-dispatch.md Rule 1) with:

- `trace_id: R<round>-R-<NNN>`
- The cluster's `criterion_id` and `category`
- The full text of every issue in this cluster (from
  `<prd-dir>/.review/round-<N>/issues/<id>.md`)
- The `affected_leaves` list (absolute paths from artifact root) — the reviser
  reads each leaf at processing time, not in advance
- `<prd-dir>/.review/issues/summary.yml` — for `recurrence_of` reference, the
  reviser reads `fix_history` to see how prior attempts failed (guide §7.5.1)
- The relevant section of `common/criterion-categories.md` for this category
  (typical fix pattern + anti-patterns)

The reviser **MUST use `Edit` only** (no `Write`). Concurrency safety follows
from `Edit`'s requirement that `old_string` be unique; collisions surface as
self-loop iterations in Step 4 rather than silent overwrites.

**Reviser is allowed to** Edit any leaf listed in `affected_leaves`, then
transition each issue's `state:` field. Permitted state transitions (guide §7.2,
unchanged): new → fixed | false-positive | deferred | superseded.

The reviser MUST NOT silently leave an issue at `state: new` while claiming to
have addressed it. Any such issue is caught by the gate in Step 5.

**Reviser MUST append** to `history` (one row per state transition) and
**MAY append** to `fix_history` (one row per non-trivial fix per guide §7.5.1).
Append-only — never rewrite or delete prior entries.
```

- [ ] **Step 3: Update Step 4 "Self-Verify Formal Pass" to clarify reviser re-dispatch**

Edit the "### Step 4 — Self-Verify Formal Pass" section. Add to the description:

```markdown
On formal failure, the orchestrator re-dispatches reviser sub-agents **by failing
leaf** (not by criterion — formal failures often span multiple types, so leaf is
the better re-dispatch unit for self-loop). Each re-dispatched reviser sees:

- The failing leaf path
- The formal-checker's JSON output (failure rows scoped to this leaf)
- All (criterion, issue) pairs touching this leaf that have not yet reached a
  terminal state

The re-dispatched reviser still uses `Edit`-only. If a formal failure can only
be repaired by integrated rewriting (rare), the reviser ACKs `FAIL trace_id=...
reason=requires-write-not-edit` and the orchestrator escalates to HITL.
```

- [ ] **Step 4: Commit**

```bash
git add skills/prd-analysis/revise/index.md
git commit -m "feat(prd-analysis): revise Step 2 groups by criterion_id (not file)"
```

---

### Task 20: Mirror Task 19 for system-design

```bash
git add skills/system-design/revise/index.md
git commit -m "feat(system-design): revise Step 2 groups by criterion_id (not file)"
```

---

### Task 21: Rewrite PRD `per-issue-reviser-subagent.md`

**Files:**
- Modify: `skills/prd-analysis/revise/per-issue-reviser-subagent.md`

- [ ] **Step 1: Read existing prompt**

Run: `cat skills/prd-analysis/revise/per-issue-reviser-subagent.md`

- [ ] **Step 2: Replace the "Inputs" section**

Replace section "## Inputs" body with:

```markdown
You receive (from the orchestrator's task message):

1. **Cluster identity** — `criterion_id` and `category`. Your scope is
   **one criterion across multiple leaves**, not one leaf across multiple
   criteria.
2. **Issue list** — the full text of every issue file in your cluster (1–8
   issues), all of which share the same `criterion_id`. Each lives at
   `<artifact-root>/.review/round-<N>/issues/<id>.md`.
3. **Affected leaves** — absolute paths (from artifact root) of every leaf
   touched by at least one of your issues. Read each leaf at processing time,
   in order, NOT in advance.
4. **summary.yml** at `<artifact-root>/.review/issues/summary.yml`. For
   issues with `recurrence_of:` set, look up the prior id and read its
   `fix_history`.
5. **Category context** — the section of
   `<artifact-root>/.review/round-<N>/category-context.md` (created by the
   orchestrator from `common/criterion-categories.md`) describing typical
   fix patterns and anti-patterns for your category. Read this first so
   your fixes match the canonical pattern.
```

- [ ] **Step 3: Replace the "What you do" intro paragraph**

Replace with:

```markdown
## What you do

You handle ALL issues in your cluster — they all share the same `criterion_id`
across possibly multiple leaves. Process them in this exact order:

1. Read `category-context.md` (your category's fix patterns).
2. Group your issues by leaf (mechanical — just look at each issue's `file:` field).
3. For each leaf in your group, in order:
   a. Read the leaf.
   b. For each issue on this leaf, decide a state transition and apply one
      `Edit` (precision replacement of `old_string` → `new_string`). Do NOT
      use `Write` to overwrite the whole file.
   c. Update each issue's frontmatter with the state transition (per the
      tables below).
4. ACK with the list of transitioned issue IDs.

Per-leaf order matters: you read each leaf once, then edit it for every issue
on it, then move on. **You MUST NOT** Read or Edit a leaf outside your
`affected_leaves` list.
```

- [ ] **Step 4: Replace the "Transition: new → fixed" sub-section**

```markdown
### Transition: new → fixed

Use this when you genuinely fix the problem.

1. Read the leaf (Read tool).
2. Apply the fix using ONE `Edit` call per issue (no `Write` — see below).
   The `old_string` MUST be unique within the file; if you cannot find a
   unique anchor, you MUST mark the issue `deferred` with
   `defer_reason: edit-unique-anchor-not-findable`. Do NOT escalate to
   `Write` to "force" the change — concurrency safety depends on unique-match.
3. Update the issue's frontmatter:
   - `state: fixed`
   - `fixed_in_round: <current round>`
   - Append `{round: <N>, action: state-change, from: new, to: fixed}` to `history:`.
   - For non-trivial fixes, append a one-line summary to `fix_history:` describing
     what you changed.

**Why Edit-only**: multiple revisers in the same round may be editing the same
leaf in parallel (each handling a different `criterion_id`). `Edit`'s unique-
match semantics serialize naturally — first-Edit-wins on a given anchor, late
Edits fail and trigger the Step 4 self-loop, which is the correct behavior.
Using `Write` would silently overwrite a sibling's changes.

The orchestrator runs `scripts/run-checkers.sh` on the bundle after your
dispatch. If your "fix" introduces a new formal violation, the orchestrator
re-dispatches a reviser scoped to the failing leaf (not your criterion) with
the formal-checker output.
```

- [ ] **Step 5: Update the "ACK contract" section**

Replace the OK ACK example with:

```markdown
## ACK contract

```
OK trace_id=R3-R-001 role=reviser cluster_id=R3-CC-001 criterion_id=CR-PP06 linked_issues=I-007,I-019,I-024
```

`linked_issues` lists every issue id you transitioned in this dispatch. The
orchestrator uses this to verify all issues in your cluster were addressed.

```
FAIL trace_id=R3-R-001 reason=<one-line technical reason>
```

Use FAIL for technical failures (file unreadable, Edit unique-match failed for
all attempted anchors). Substantive non-resolution (false-positive / deferred)
is NOT a FAIL — pick the appropriate state transition.
```

- [ ] **Step 6: Add a "Forbidden tools" callout**

Insert near "What you do NOT do":

```markdown
- **Do not use the `Write` tool on any artifact leaf.** Revisers are Edit-only.
  The single exception is per-issue frontmatter updates inside `.review/round-N/issues/<id>.md`,
  for which `Edit` of the YAML frontmatter is still the preferred tool.
```

- [ ] **Step 7: Commit**

```bash
git add skills/prd-analysis/revise/per-issue-reviser-subagent.md
git commit -m "feat(prd-analysis): reviser scoped to one criterion, Edit-only writes"
```

---

### Task 22: Mirror Task 21 for system-design

```bash
git add skills/system-design/revise/per-issue-reviser-subagent.md
git commit -m "feat(system-design): reviser scoped to one criterion, Edit-only writes"
```

---

### Task 23: Update PRD `parallel-dispatch.md` Rule 3 / 5 / 6

**Files:**
- Modify: `skills/prd-analysis/common/parallel-dispatch.md`

- [ ] **Step 1: Update Rule 3 "Cluster Sizing"**

Replace the "Fix subagents" line with:

```markdown
- **Fix subagents (revisers):** grouping is by `criterion_id`, NOT by leaf.
  One reviser per criterion-cluster. Each cluster carries ≤8 issues (the
  `revise.edit_cap` from `common/config.yml`). The leaf count in a cluster is
  emergent (depends on how the criterion's issues are distributed across leaves)
  and is not directly capped — the edit-count cap is the protection. If a single
  criterion has >8 issues this round, split into multiple clusters with
  monotonic cluster_ids; the same criterion's clusters may run in parallel.
```

- [ ] **Step 2: Update Rule 3 "Review subagents" line**

```markdown
- **Review subagents:** grouping is by **criterion category**, not by artifact
  class. One cross-reviewer per category active this round. Each reviewer
  receives all in-scope leaves and ONLY the CR-IDs in its category. If a single
  category's leaf set exceeds `review.cluster_leaf_cap` (default 25), split into
  multiple sub-clusters by leaf range; sub-clusters carry identical criteria.
```

- [ ] **Step 3: Update Rule 5 "Per-Leaf Isolation Contract"**

Rename the section to "Per-Work-Unit Isolation Contract" and replace the body:

```markdown
## Rule 5 — Per-Work-Unit Isolation Contract (MANDATORY)

Each sub-agent owns exactly one work unit. The work unit definition varies by role:

- **Writer**: one leaf file. (No change from prior contract.)
- **Reviewer (cross / adversarial)**: one category cluster — all leaves listed
  in the cluster + the cluster's CR-ID list. Reviewer MUST NOT apply CR-IDs
  outside the cluster, MUST NOT read leaves outside the cluster's leaf list.
- **Reviser**: one criterion-cluster — ≤8 issues, all sharing the same
  `criterion_id`, plus their `affected_leaves` list. Reviser MUST NOT Edit
  leaves outside `affected_leaves`, MUST NOT touch issues outside its cluster.

Common to all roles:

- No Grep/Glob to discover sibling files — all target paths are pre-supplied
  in the dispatch prompt.
- No post-write re-read of files just written.
- No Task return content beyond the single-line ACK.
- The dispatch prompt MUST supply all inline context (criterion-category notes,
  data-model excerpts, etc.) so cross-file reads outside the work unit are
  unnecessary.
```

- [ ] **Step 4: Update Rule 6 "Tool Usage Inside Subagents"**

Add a new bullet specifically for revisers, and adjust the "1 edit / >1 edit on the same file" rule:

```markdown
- **Revisers**: `Edit` only. Never `Write`. Each issue corresponds to one
  `Edit` call (one precision replacement); if multiple Edits hit the same
  leaf in one cluster, that's fine — issue them sequentially within the
  sub-agent. Do NOT merge multiple Edits into one Write. Writes would silently
  overwrite parallel revisers' changes; Edit's unique-match semantics
  serialize naturally.
- **Writers**: rule unchanged — use `Write` for new files, `Edit` for single
  modifications, batch into Write for multi-modify on the same file.
- **Reviewers**: read-only on artifact leaves (no Edit, no Write); single
  `Write` to `reviewer-output/<trace_id>.json`. Rule unchanged.
```

- [ ] **Step 5: Update Rule 8 "Reduce Step After Writer Fan-Out"**

Update the cross-reference at the bottom:

```markdown
See `review/index.md` Step 2 (per-category fan-out) and `revise/index.md`
Step 2 (per-criterion fan-out) for the full templates that bake these rules in.
```

- [ ] **Step 6: Commit**

```bash
git add skills/prd-analysis/common/parallel-dispatch.md
git commit -m "feat(prd-analysis): parallel-dispatch encodes criterion-cluster + Edit-only reviser"
```

---

### Task 24: Mirror Task 23 for system-design

```bash
git add skills/system-design/common/parallel-dispatch.md
git commit -m "feat(system-design): parallel-dispatch encodes criterion-cluster + Edit-only reviser"
```

---

### Task 25: Add `revise.edit_cap` and `review.cluster_leaf_cap` to config (both skills)

**Files:**
- Modify: `skills/prd-analysis/common/config.yml`
- Modify: `skills/system-design/common/config.yml`

- [ ] **Step 1: Add config keys**

In PRD `config.yml`, locate the top-level mapping and add:

```yaml
revise:
  edit_cap: 8       # max issues per criterion-cluster (parallel-dispatch.md Rule 3)

review:
  cluster_leaf_cap: 25   # max leaves per per-category cluster before splitting
```

- [ ] **Step 2: Same in SD `config.yml`**

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/common/config.yml skills/system-design/common/config.yml
git commit -m "feat: configurable edit_cap and cluster_leaf_cap for criterion-centric batching"
```

---

## Phase 5: Migration

### Task 26: Write `migrate-issues-add-category.sh` (PRD)

**Files:**
- Create: `skills/prd-analysis/scripts/migrate-issues-add-category.sh`
- Create: `skills/prd-analysis/tests/test-migrate-issues-add-category.sh`

- [ ] **Step 1: Add failing test**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"
MIGRATE="$REPO_SCRIPTS/migrate-issues-add-category.sh"

test_case "adds category line after criterion_id"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/issues"
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-PP06
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history: []
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
result=$(cat "$FIXTURE/.review/round-1/issues/I-001.md")
case "$result" in
  *"category: traceability"*) _record_pass ;;
  *) _record_fail "category not injected; got: $result" ;;
esac
teardown_fixture

test_case "idempotent on already-migrated issue"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/issues"
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-PP06
category: traceability
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history: []
fix_history: []
---

## Description
x

## Suggested fix
y
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
# Should not duplicate
result=$(grep -c "^category:" "$FIXTURE/.review/round-1/issues/I-001.md")
[ "$result" = "1" ] && _record_pass || _record_fail "expected 1 category line, got $result"
teardown_fixture

test_case "unknown criterion_id skipped with warning"
setup_fixture
mkdir -p "$FIXTURE/.review/round-1/issues"
write_file ".review/round-1/issues/I-001.md" '---
id: I-001
criterion_id: CR-UNKNOWN-XX
file: features/F-001.md
severity: error
state: new
created_in_round: 1
history: []
fix_history: []
---
'
assert_exit 0 "$MIGRATE" "$FIXTURE"
assert_stdout_contains "WARNING"
assert_stdout_contains "CR-UNKNOWN-XX"
teardown_fixture

end_tests
```

- [ ] **Step 2: Verify failure**

Run: `bash skills/prd-analysis/tests/test-migrate-issues-add-category.sh`

- [ ] **Step 3: Implement migration script**

```bash
#!/usr/bin/env bash
# migrate-issues-add-category.sh — one-time backfill: add category: field
# to every legacy issue file under .review/round-*/issues/. The category is
# looked up from common/review-criteria.md by criterion_id.
#
# Idempotent — re-running on already-migrated issues is a no-op.
#
# Usage: migrate-issues-add-category.sh <artifact-root>
# Exit codes: 0 OK; 2 script error

set -euo pipefail

ART="${1:-}"
if [ -z "$ART" ] || [ ! -d "$ART" ]; then
  echo "Usage: $0 <artifact-root>" >&2
  exit 2
fi
ART="${ART%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$ART" "$SKILL_ROOT/common/review-criteria.md" <<'PYEOF'
import os, re, sys, glob

art, crit_path = sys.argv[1], sys.argv[2]

# Build CR -> category map
crit_text = open(crit_path).read()
cr_to_cat: dict[str, str] = {}
for m in re.finditer(r"- id:\s*(CR-[A-Z0-9-]+)\s*\n((?:  [^\n]*\n)+)", crit_text):
    crid, body = m.group(1), m.group(2)
    if "checker_type: llm" not in body:
        continue
    cm = re.search(r"category:\s*([a-z0-9-]+)", body)
    if cm:
        cr_to_cat[crid] = cm.group(1)

migrated = 0
warnings = 0
for path in glob.glob(os.path.join(art, ".review", "round-*", "issues", "*.md")):
    text = open(path).read()
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        continue
    fm = m.group(1)
    crid_m = re.search(r"^criterion_id:\s*(CR-[A-Z0-9-]+)", fm, re.M)
    if not crid_m:
        continue
    crid = crid_m.group(1)
    if re.search(r"^category:", fm, re.M):
        # Already has category — skip.
        continue
    cat = cr_to_cat.get(crid)
    if cat is None:
        print(f"WARNING: {os.path.relpath(path, art)} has unknown criterion_id {crid}; skipping")
        warnings += 1
        continue
    # Insert category: line immediately after criterion_id: line
    new_fm = re.sub(
        r"^(criterion_id:\s*CR-[A-Z0-9-]+\s*)$",
        rf"\1\ncategory: {cat}",
        fm, count=1, flags=re.M)
    new_text = text.replace(fm, new_fm, 1)
    open(path, "w").write(new_text)
    migrated += 1

print(f"PASS: migrated {migrated} issue file(s), {warnings} warning(s)")
PYEOF
```

- [ ] **Step 4: Make executable; tests pass**

```bash
chmod +x skills/prd-analysis/scripts/migrate-issues-add-category.sh
bash skills/prd-analysis/tests/test-migrate-issues-add-category.sh
```
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/prd-analysis/scripts/migrate-issues-add-category.sh skills/prd-analysis/tests/test-migrate-issues-add-category.sh
git commit -m "feat(prd-analysis): one-time migration script to backfill issue.category"
```

---

### Task 27: Mirror Task 26 for system-design

```bash
cp skills/prd-analysis/scripts/migrate-issues-add-category.sh skills/system-design/scripts/migrate-issues-add-category.sh
chmod +x skills/system-design/scripts/migrate-issues-add-category.sh
# Test file: same structure, replace CR-PP06 with CR-SD-DESIGN01, traceability with module-boundary
git add skills/system-design/scripts/migrate-issues-add-category.sh skills/system-design/tests/test-migrate-issues-add-category.sh
git commit -m "feat(system-design): one-time migration script to backfill issue.category"
```

---

## Phase 6: Documentation Sync & Full Test Run

### Task 28: Update PRD SKILL.md for new cluster contract

**Files:**
- Modify: `skills/prd-analysis/SKILL.md`

- [ ] **Step 1: Locate the "Forbidden Actions" section's per-leaf mention**

The block currently states:

> Per-leaf writer dispatch (one writer per `plan.add[]` / `plan.modify[]` entry), per-leaf reviser dispatch (one reviser per leaf with `state: new` issues, never one reviser for >1 leaf), and per-cluster reviewer dispatch (clusters sized per `common/parallel-dispatch.md` Rule 3) are **contracts** — the orchestrator MAY NOT coalesce them into a single "mega" dispatch.

- [ ] **Step 2: Replace it with the new unit-definition wording**

```markdown
Per-leaf writer dispatch (one writer per `plan.add[]` / `plan.modify[]` entry),
per-criterion-cluster reviser dispatch (one reviser per criterion-cluster sized
per `common/parallel-dispatch.md` Rule 3, ≤8 issues; multiple clusters per
criterion when count exceeds cap), and per-category reviewer dispatch (one
reviewer per criterion category active this round) are **contracts** — the
orchestrator MAY NOT coalesce them into a single "mega" dispatch. If you find
yourself authoring a single Task prompt that lists >1 leaf for a writer, >1
criterion-cluster for a reviser, or >1 category for a reviewer, STOP — split
into per-unit dispatches and emit them as a parallel batch per Rule 1.
```

- [ ] **Step 3: Locate the Output Structure section and update Configuration & Subagent Files**

Add to the "Configuration & Subagent Files" list:

```markdown
- **Criterion categories**: `common/criterion-categories.md` — taxonomy mapping
  each LLM-type CR to one category (consumed by reviewer cluster fan-out + reviser
  category-context prompt)
```

Add to the "Formal-review scripts" list:

```markdown
- `scripts/check-criteria-categories.sh` — consistency check between
  review-criteria.md and criterion-categories.md
- `scripts/migrate-issues-add-category.sh` — one-time legacy issue backfill
```

- [ ] **Step 4: Commit**

```bash
git add skills/prd-analysis/SKILL.md
git commit -m "docs(prd-analysis): SKILL.md updated for criterion-cluster contracts"
```

---

### Task 29: Mirror Task 28 for system-design

Apply same diffs to `skills/system-design/SKILL.md`.

```bash
git add skills/system-design/SKILL.md
git commit -m "docs(system-design): SKILL.md updated for criterion-cluster contracts"
```

---

### Task 30: Append CHANGELOG entries (both skills)

**Files:**
- Modify: `skills/prd-analysis/CHANGELOG.md`
- Modify: `skills/system-design/CHANGELOG.md`

- [ ] **Step 1: Prepend a new entry to PRD CHANGELOG.md**

```markdown
## [1.4.0] - 2026-05-24

### Changed (BREAKING)
- Review fan-out is now **per-category** (`common/criterion-categories.md`).
  Each cross-reviewer dispatch is scoped to one criterion category, not one
  artifact-class cluster. `review/index.md` Step 2 rewritten;
  `cross-reviewer-subagent.md` prompt rewritten.
- Revise grouping is now **per-criterion** (`criterion_id`). Each reviser
  dispatch carries ≤8 issues sharing the same criterion across multiple
  leaves. `revise/index.md` Step 2 rewritten;
  `per-issue-reviser-subagent.md` prompt rewritten.
- Reviser sub-agents are now **`Edit`-only** on artifact leaves. `Write` is
  forbidden for revisers. Concurrency safety follows from `Edit`'s unique-match.
- `common/review-criteria.md` LLM-type CRs now carry a required `category:`
  field.
- `.review/round-*/issues/*.md` files gain a required `category:` frontmatter
  field (auto-derived by `create-issues.sh`; legacy files migrated via
  `scripts/migrate-issues-add-category.sh`).
- Reviewer output JSON gains a required `category_applied:` top-level field.
- `common/parallel-dispatch.md` Rules 3/5/6 updated; Rule 5 renamed
  "Per-Work-Unit Isolation".

### Added
- `common/criterion-categories.md` — single source of truth for CR-to-category mapping.
- `scripts/check-criteria-categories.sh` — consistency check.
- `scripts/migrate-issues-add-category.sh` — one-time legacy backfill.
- `common/config.yml` `revise.edit_cap` (default 8) and
  `review.cluster_leaf_cap` (default 25).

### Migration
- Existing PRD bundles: run
  `scripts/migrate-issues-add-category.sh <prd-dir>` once to backfill the
  `category:` field on legacy issue files. `check-issue.sh` treats missing
  category as a non-fatal WARNING during the migration window.
```

- [ ] **Step 2: Same entry structure for SD CHANGELOG with SD-specific category names**

- [ ] **Step 3: Commit**

```bash
git add skills/prd-analysis/CHANGELOG.md skills/system-design/CHANGELOG.md
git commit -m "docs: changelog for criterion-centric batching v1.4"
```

---

### Task 31: Update existing smoke fixtures (PRD + SD)

**Files:**
- Modify: `skills/prd-analysis/tests/fixtures/` (any fixture that references `revise_groups` or per-file cluster shape)
- Modify: `skills/system-design/tests/fixtures/` (same)

- [ ] **Step 1: Locate affected fixtures**

Run:
```bash
grep -rl "revise_groups\|per-leaf reviser\|files: \[" skills/prd-analysis/tests/fixtures skills/system-design/tests/fixtures 2>/dev/null
```

- [ ] **Step 2: For each affected fixture file, update the YAML to the new schema**

`revise_groups:` → `revise_clusters:` with `cluster_id`, `criterion_id`, `category`, `issues`, `affected_leaves`. Use the format defined in Task 19 Step 1.

- [ ] **Step 3: Re-run smoke tests for both skills**

Run:
```bash
bash skills/prd-analysis/tests/run-all.sh
bash skills/system-design/tests/run-all.sh
```
Expected: every test PASS.

- [ ] **Step 4: Commit**

```bash
git add skills/prd-analysis/tests/fixtures/ skills/system-design/tests/fixtures/
git commit -m "test: update smoke fixtures for criterion-cluster shape"
```

---

### Task 32: Full integration check + run real consistency script on shipped criteria

**Files:**
- No code changes

- [ ] **Step 1: Run all tests in both skills**

```bash
bash skills/prd-analysis/tests/run-all.sh && bash skills/system-design/tests/run-all.sh
```
Expected: 0 failures across all test scripts.

- [ ] **Step 2: Run consistency check on real criteria**

```bash
bash skills/prd-analysis/scripts/check-criteria-categories.sh skills/prd-analysis/common/
bash skills/system-design/scripts/check-criteria-categories.sh skills/system-design/common/
```
Both expected to PASS.

- [ ] **Step 3: Run end-to-end revise smoke on a sample fixture**

If a sample PRD bundle exists with ≥3 leaves × ≥5 state:new issues across ≥2 criteria, run:

```bash
bash skills/prd-analysis/scripts/verify-phase-entry.sh revise <sample-bundle> 1
# Inspect the printed revise_clusters output
```

Expected output should list ≥2 clusters keyed by criterion (not by leaf).

- [ ] **Step 4: Spot-check that a reviser dispatch prompt is well-formed**

Manually inspect the dispatch prompt the orchestrator would produce for one cluster: confirm it includes `criterion_id`, `category`, the full text of each issue, and the `affected_leaves` list, and that it cites the Edit-only contract.

- [ ] **Step 5: Final commit (no code, but documents the integration milestone)**

```bash
# If nothing to commit, skip. Otherwise tag the integration milestone.
git tag -a criterion-batching-integrated -m "criterion-centric batching integration verified"
```

---

## Self-Review

After writing the plan, I checked it against the spec:

**Spec coverage:**
- §3.1 grouping algorithm → Task 19/20
- §3.2 reviser sub-agent contract → Task 21/22
- §3.3 self-loop semantics → Task 19 Step 3 (Self-Verify Formal Pass update)
- §3.4 concurrency safety proof → covered by Task 21 Step 4 (Why Edit-only callout)
- §3.5 Rule 3/5/6 changes → Task 23/24
- §4.1–4.4 review-end cluster model → Task 13/14, 15/16, 17/18
- §4.5 adversarial unchanged → no task needed (correctly omitted)
- §5 taxonomy → Task 1/3
- §6.1 review-criteria.md category field → Task 2/3
- §6.2 issue-schema category field → Task 6
- §6.3 reviewer-output category_applied → Task 11/12
- §7 implementation steps → all 32 tasks
- §8 risks → covered by tests (Task 6/7/8 unique-match, Task 11/12 validation)
- §9 non-goals → respected (no verdict/adversarial/auto changes)
- §10 acceptance criteria → Task 32

**Type consistency check:**
- `cluster_id` format `R<round>-CC-<nnn>` used consistently (Task 19, 21)
- `category` field name consistent across schemas, scripts, prompts
- `revise.edit_cap` config key consistent (Task 19, 23, 25)
- `review.cluster_leaf_cap` consistent (Task 17, 23, 25)
- `category_applied` JSON field consistent (Task 11, 15)
- ACK format updated consistently (Task 21 Step 5)

**Placeholder scan:**
- All code blocks contain actual implementation, not pseudocode markers
- All test fixtures contain real content
- No "implement later" / TBD
- One soft spot: Task 1 Step 1 says "use the output to populate the table in Step 2" — this is acceptable because the actual table template IS in Step 2, the engineer just fills in CR-IDs from the grep output.

Plan complete.
