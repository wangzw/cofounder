#!/usr/bin/env bash
# check-issue-schema.sh — formal review of audit artifacts (guide §10 self-closure)
#
# Validates that every issue file in <artifact-root>/.review/round-*/issues/
# conforms to the on-disk schema defined in common/issue-schema.md. This is
# itself a formal-review script — review artifacts are themselves artifacts
# (guide §10) and must pass the same gates.
#
# Usage: check-issue-schema.sh <artifact-root>
#
# Exit codes:
#   0  all issue files conform to schema
#   1  one or more violations found (issues listed on stdout as JSON)
#   2  script error / bad input

set -euo pipefail

ARTIFACT_ROOT="${1:-}"

if [ -z "$ARTIFACT_ROOT" ] || [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "ERROR: artifact root not found: ${ARTIFACT_ROOT:-<empty>}" >&2
  echo "Usage: check-issue-schema.sh <artifact-root>" >&2
  exit 2
fi

ARTIFACT_ROOT="${ARTIFACT_ROOT%/}"
REVIEW_DIR="$ARTIFACT_ROOT/.review"

if [ ! -d "$REVIEW_DIR" ]; then
  echo "PASS 0 issue files (no .review history yet)"
  exit 0
fi

CRITERIA_FILE="$ARTIFACT_ROOT/common/review-criteria.md"
# Fall back to the skill-root criteria if the artifact is itself the skill.
if [ ! -f "$CRITERIA_FILE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CRITERIA_FILE="$SCRIPT_DIR/../common/review-criteria.md"
fi

python3 - "$REVIEW_DIR" "$CRITERIA_FILE" <<'PYEOF'
import os, re, sys, json

review_dir = sys.argv[1]
criteria_file = sys.argv[2]

# ─── Load valid criterion IDs ─────────────────────────────────────────
valid_crids = set()
if os.path.isfile(criteria_file):
    with open(criteria_file, 'r', encoding='utf-8') as f:
        for m in re.finditer(r'^- id:\s*(CR-[A-Za-z0-9_-]+)\s*$', f.read(), re.M):
            valid_crids.add(m.group(1))

# ─── Frontmatter parser (minimal — no third-party YAML) ───────────────
def parse_frontmatter(text):
    if not text.startswith('---'):
        return None, "missing leading frontmatter delimiter"
    end = text.find('\n---', 3)
    if end < 0:
        return None, "unterminated frontmatter"
    fm = {}
    for raw in text[3:end].splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$', line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        elif val.startswith("'") and val.endswith("'"):
            val = val[1:-1]
        fm[key] = val
    body = text[end + 4:]
    return (fm, body), None

# ─── Validation rules ─────────────────────────────────────────────────
REQUIRED_FIELDS = ['id', 'criterion_id', 'file', 'severity', 'state', 'created_in_round']
VALID_SEVERITIES = {'critical', 'error', 'warning', 'info'}
VALID_STATES = {'new', 'fixed', 'false-positive', 'deferred', 'superseded'}
ID_RE = re.compile(r'^I-\d{3,}$')
ROUND_RE = re.compile(r'^\d+$')

def validate_one(rel_path, fm, body, all_ids):
    issues = []
    def fail(field, msg, fix):
        issues.append({
            "criterion_id": "CR-IS01",
            "file": rel_path,
            "severity": "error",
            "description": f"{field}: {msg}",
            "suggested_fix": fix,
        })

    # Required fields
    for f in REQUIRED_FIELDS:
        if f not in fm or not fm[f]:
            fail(f, "required field missing or empty",
                 f"add '{f}: <value>' to issue frontmatter")

    if 'id' in fm and fm['id'] and not ID_RE.match(fm['id']):
        fail('id', f"value {fm['id']!r} does not match I-\\d{{3,}}",
             "rename to I-NNN format (e.g. I-001)")

    if 'severity' in fm and fm['severity'] and fm['severity'] not in VALID_SEVERITIES:
        fail('severity', f"value {fm['severity']!r} not in {sorted(VALID_SEVERITIES)}",
             f"set severity to one of {sorted(VALID_SEVERITIES)}")

    state = fm.get('state', '')
    if state and state not in VALID_STATES:
        fail('state', f"value {state!r} not in {sorted(VALID_STATES)}",
             f"set state to one of {sorted(VALID_STATES)}")

    if 'created_in_round' in fm and fm['created_in_round']:
        if not ROUND_RE.match(fm['created_in_round']):
            fail('created_in_round', "must be a non-negative integer",
                 "set created_in_round to the integer round number this issue was filed in")

    if 'criterion_id' in fm and fm['criterion_id'] and valid_crids \
            and fm['criterion_id'] not in valid_crids:
        fail('criterion_id', f"unknown criterion {fm['criterion_id']!r} "
                              f"(not declared in review-criteria.md)",
             "add this criterion to common/review-criteria.md or correct the id")

    # State-conditional fields
    if state == 'fixed' and not fm.get('fixed_in_round'):
        fail('fixed_in_round', "required when state=fixed",
             "add 'fixed_in_round: <N>' where N is the round the fix landed")
    if state == 'deferred':
        if not fm.get('defer_until'):
            fail('defer_until', "required when state=deferred",
                 "add 'defer_until: round-N+M | delivery-N+M | never | input-arrived'")
        else:
            v = fm['defer_until']
            ok = v in ('never', 'input-arrived') or \
                 re.match(r'^round-\d+$', v) or \
                 re.match(r'^delivery-\d+$', v)
            if not ok:
                fail('defer_until', f"unrecognized value {v!r}",
                     "use one of: round-<N>, delivery-<N>, never, input-arrived")
        if not fm.get('defer_reason'):
            fail('defer_reason', "required when state=deferred",
                 "add 'defer_reason: <one-sentence reason>'")
    if state == 'false-positive' and not fm.get('dismissed_reason'):
        fail('dismissed_reason', "required when state=false-positive",
             "add 'dismissed_reason: <why reviewer was wrong>'")
    if state == 'superseded':
        sb = fm.get('superseded_by', '')
        if not sb:
            fail('superseded_by', "required when state=superseded",
                 "add 'superseded_by: I-NNN' referencing the covering issue")
        elif sb not in all_ids:
            fail('superseded_by', f"references unknown issue {sb!r}",
                 "fix the id to reference an existing issue in this artifact")

    # Recurrence references
    rec = fm.get('recurrence_of', '')
    if rec and rec not in all_ids:
        fail('recurrence_of', f"references unknown issue {rec!r}",
             "fix the id to reference an existing issue or remove the field")

    # Body sections must be present and non-trivially populated
    if body is not None:
        body_l = body.lower()
        if '## description' not in body_l:
            fail('body', "missing '## Description' section",
                 "add a '## Description' section with the issue's location and "
                 "what's wrong")
        if '## suggested fix' not in body_l:
            fail('body', "missing '## Suggested fix' section",
                 "add a '## Suggested fix' section with one concrete change to make")
    return issues

# ─── Walk all issue files ─────────────────────────────────────────────
all_ids = set()
all_files = []
for entry in sorted(os.listdir(review_dir)):
    if not entry.startswith('round-'):
        continue
    issues_dir = os.path.join(review_dir, entry, 'issues')
    if not os.path.isdir(issues_dir):
        continue
    for fname in sorted(os.listdir(issues_dir)):
        if not fname.endswith('.md'):
            continue
        all_files.append(os.path.join(issues_dir, fname))

# First pass: collect ids for cross-reference validation
for fpath in all_files:
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            text = f.read()
    except OSError:
        continue
    parsed, err = parse_frontmatter(text)
    if not parsed:
        continue
    fm, _ = parsed
    if 'id' in fm and fm['id']:
        all_ids.add(fm['id'])

# Second pass: validate each
violations = []
for fpath in all_files:
    rel = os.path.relpath(fpath, os.path.dirname(review_dir))
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            text = f.read()
    except OSError as e:
        violations.append({"criterion_id": "CR-IS01", "file": rel, "severity": "error",
                           "description": f"cannot read file: {e}",
                           "suggested_fix": "ensure the file is readable"})
        continue
    parsed, err = parse_frontmatter(text)
    if err:
        violations.append({"criterion_id": "CR-IS01", "file": rel, "severity": "error",
                           "description": err,
                           "suggested_fix": "wrap frontmatter in '---' delimiters"})
        continue
    fm, body = parsed
    violations.extend(validate_one(rel, fm, body, all_ids))

if violations:
    print(f"FOUND {len(violations)} issue-schema violation(s):")
    print(json.dumps(violations, indent=2))
    sys.exit(1)

print(f"PASS all {len(all_files)} issue file(s) conform to schema")
sys.exit(0)
PYEOF
