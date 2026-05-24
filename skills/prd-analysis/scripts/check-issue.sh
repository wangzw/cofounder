#!/usr/bin/env bash
# check-issue.sh — formal review of .review/round-*/issues/I-NNN.md files.
#
# Implements:
#   CR-IS01  issue-schema-conformance — on-disk schema (guide §10 self-closure)
#
# Validates every issue file across all rounds:
#   - Required frontmatter fields (id, criterion_id, file, severity, state,
#     created_in_round)
#   - State-conditional required fields (fixed_in_round / dismissed_reason
#     / defer_until + defer_reason / superseded_by)
#   - Body sections (## Description, ## Suggested fix) present and non-trivial
#   - Cross-references (recurrence_of / superseded_by) resolve to existing ids
#   - criterion_id is declared in common/review-criteria.md (when available)
#
# Replaces the prior check-issue-schema.sh.
#
# Usage: check-issue.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-issue.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate criteria source: prefer the artifact's own copy (when prd-analysis
# is reviewing its own bundle, the artifact root is the skill root); else
# fall back to this skill's own.
CRITERIA="$PRD_ROOT/common/review-criteria.md"
if [ ! -f "$CRITERIA" ]; then
  CRITERIA="$SCRIPT_DIR/../common/review-criteria.md"
fi

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" "$CRITERIA" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
criteria_path = sys.argv[3]
from prd_lint import (
    Finding, parse_frontmatter, frontmatter_error, read_text, emit,
    find_round_dirs, ISSUE_ID_RE,
)

VALID_SEV = {"critical", "error", "warning", "info"}
VALID_STATES = {"new", "fixed", "false-positive", "deferred", "superseded"}
VALID_CATEGORIES = {
    "traceability", "evidence", "coherence", "accessibility-i18n",
    "interaction-design", "privacy-security", "risk-governance", "meta",
}
REQUIRED = ("id", "criterion_id", "file", "severity", "state", "created_in_round")
ROUND_NUM_RE = re.compile(r"^\d+$")

# Load valid criterion ids from the criteria file (if present)
valid_crids: set[str] = set()
if os.path.isfile(criteria_path):
    with open(criteria_path, "r", encoding="utf-8") as f:
        for m in re.finditer(r"^- id:\s*(CR-[A-Za-z0-9_-]+)\s*$", f.read(), re.M):
            valid_crids.add(m.group(1))

# Walk every issue file across all rounds
issue_files: list[tuple[str, str]] = []  # (relative_path, full_path)
for _, round_dir in find_round_dirs(prd_root):
    issues_dir = os.path.join(round_dir, "issues")
    if not os.path.isdir(issues_dir):
        continue
    for fname in sorted(os.listdir(issues_dir)):
        if not fname.endswith(".md"):
            continue
        full = os.path.join(issues_dir, fname)
        rel = os.path.relpath(full, prd_root)
        issue_files.append((rel, full))

# First pass: collect ids for cross-reference validation
all_ids: set[str] = set()
for _, full in issue_files:
    text = read_text(full)
    if text is None:
        continue
    if frontmatter_error(text):
        continue
    fm, _ = parse_frontmatter(text)
    if fm.get("id"):
        all_ids.add(fm["id"])

# Second pass: validate each
findings: list[Finding] = []
warnings: list[str] = []
for rel, full in issue_files:
    text = read_text(full)
    if text is None:
        findings.append(Finding(
            criterion_id="CR-IS01", file=rel, severity="error",
            description="cannot read issue file (IO error)",
            suggested_fix="ensure the file exists and is readable",
        ))
        continue
    err = frontmatter_error(text)
    if err:
        findings.append(Finding(
            criterion_id="CR-IS01", file=rel, severity="error",
            description=err,
            suggested_fix="wrap frontmatter in '---' delimiters with a closing '---'",
        ))
        continue
    fm, body = parse_frontmatter(text)

    def fail(field, msg, fix):
        findings.append(Finding(
            criterion_id="CR-IS01", file=rel, severity="error",
            description=f"{field}: {msg}", suggested_fix=fix,
        ))

    # Required fields
    for f in REQUIRED:
        if f not in fm or not fm[f]:
            fail(f, "required field missing or empty",
                 f"add '{f}: <value>' to issue frontmatter")

    if fm.get("id") and not ISSUE_ID_RE.match(fm["id"]):
        fail("id", f"value {fm['id']!r} does not match I-NNN[N+] pattern",
             "rename the file and frontmatter id to I-NNN format (e.g. I-001)")

    if fm.get("severity") and fm["severity"] not in VALID_SEV:
        fail("severity", f"value {fm['severity']!r} not in {sorted(VALID_SEV)}",
             f"set severity to one of {sorted(VALID_SEV)}")

    state = fm.get("state", "")
    if state and state not in VALID_STATES:
        fail("state", f"value {state!r} not in {sorted(VALID_STATES)}",
             f"set state to one of {sorted(VALID_STATES)}")

    if fm.get("created_in_round") and not ROUND_NUM_RE.match(fm["created_in_round"]):
        fail("created_in_round", "must be a non-negative integer",
             "set created_in_round to the round number this issue was filed in")

    if fm.get("criterion_id") and valid_crids and fm["criterion_id"] not in valid_crids:
        fail("criterion_id",
             f"unknown criterion {fm['criterion_id']!r} (not declared in review-criteria.md)",
             "add this criterion to common/review-criteria.md or correct the id")

    # category field (v1.4+) — missing is non-fatal WARNING; invalid is FAIL
    cat = fm.get("category", "")
    if not cat:
        warnings.append(
            f"WARNING: {rel}: missing category field (legacy issue; "
            f"run scripts/migrate-issues-add-category.sh to backfill)")
    elif cat not in VALID_CATEGORIES:
        fail("category",
             f"unknown category {cat!r} (must be one of {sorted(VALID_CATEGORIES)})",
             "set category to one of the canonical category names defined in common/criterion-categories.md")

    # State-conditional fields
    if state == "fixed" and not fm.get("fixed_in_round"):
        fail("fixed_in_round", "required when state=fixed",
             "add 'fixed_in_round: <N>' where N is the round the fix landed")
    if state == "deferred":
        if not fm.get("defer_until"):
            fail("defer_until", "required when state=deferred",
                 "add 'defer_until: round-N | delivery-N | never | input-arrived'")
        else:
            v = fm["defer_until"]
            ok = (
                v in ("never", "input-arrived")
                or re.match(r"^round-\d+$", v)
                or re.match(r"^delivery-\d+$", v)
            )
            if not ok:
                fail("defer_until", f"unrecognized value {v!r}",
                     "use one of: round-<N>, delivery-<N>, never, input-arrived")
        if not fm.get("defer_reason"):
            fail("defer_reason", "required when state=deferred",
                 "add 'defer_reason: <one-sentence reason>'")
    if state == "false-positive" and not fm.get("dismissed_reason"):
        fail("dismissed_reason", "required when state=false-positive",
             "add 'dismissed_reason: <why reviewer was wrong>'")
    if state == "superseded":
        sb = fm.get("superseded_by", "")
        if not sb:
            fail("superseded_by", "required when state=superseded",
                 "add 'superseded_by: I-NNN' referencing the covering issue")
        elif sb not in all_ids:
            fail("superseded_by", f"references unknown issue {sb!r}",
                 "fix the id to reference an existing issue")

    rec = fm.get("recurrence_of", "")
    if rec and rec not in all_ids:
        fail("recurrence_of", f"references unknown issue {rec!r}",
             "fix the id to reference an existing issue or remove the field")

    # Body sections
    body_l = (body or "").lower()
    if "## description" not in body_l:
        fail("body", "missing '## Description' section",
             "add a '## Description' section locating and explaining the issue")
    if "## suggested fix" not in body_l:
        fail("body", "missing '## Suggested fix' section",
             "add a '## Suggested fix' section with one concrete change")

for w in warnings:
    print(w)

scope = f"({len(issue_files)} issue file(s))"
emit(findings, scope_label=scope)
PYEOF
