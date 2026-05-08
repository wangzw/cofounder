#!/usr/bin/env bash
# check-traceability.sh — validate reports/traceability.json against the
# schema declared in acceptance/tester-prompt.md and enforce closure.
#
#   CR-AF07  schema-valid (criteria/journeys/orphan_tests/unmapped_criteria
#            keys present; criterion entries have id+status; status enum;
#            journey entries have id+status+touchpoints_total)
#   CR-AF08  no-unmapped-criteria   (delivery-discipline §F)
#   CR-AF09  no-orphan-tests        (§F)
#   CR-AF10  not-covered-needs-issue  (each NOT_COVERED entry has
#            a non-empty issue field; §D)
#   CR-AF11  fail-status-blocks-pass (any FAIL entry must be reported,
#            not silently absent — covered by closure: every AC must
#            appear in criteria[] or in unmapped_criteria[])
#   CR-AF15  tests-list-must-have-concrete-paths (PASS / FAIL entries
#            must reference at least one non-empty test path string —
#            stops "PASS with empty tests" or "PASS with [\"\"]" soft-pass)
#   CR-AF21  journey-negative-coverage (each journey must record at least
#            one scenario whose `kind` is not `happy`, or document the
#            gap with a tracked issue — delivery-discipline §M.2)
#
# Usage: check-traceability.sh <traceability-json> [--source-root <dir>]
#
# When --source-root is supplied, CR-AF15 additionally checks that each
# referenced test path resolves to an existing file under <source-root>.
# Without it, only the "non-empty string" check fires.

set -euo pipefail

TFILE="${1:-}"
if [ -z "$TFILE" ] || [ ! -f "$TFILE" ]; then
  echo "ERROR: traceability file not found: ${TFILE:-<empty>}" >&2
  echo "Usage: check-traceability.sh <traceability-json> [--source-root <dir>]" >&2
  exit 2
fi
shift

SOURCE_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_TFILE="$TFILE"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_LIB_DIR="$SCRIPT_DIR/lib"

python3 - <<'PYEOF'
import json, os, sys
tfile = os.environ["AF_TFILE"]
source_root = os.environ.get("AF_SOURCE_ROOT") or ""
sys.path.insert(0, os.environ["AF_LIB_DIR"])
from autoforge_lint import (
    Finding, emit, fail_with_script_error, AC_REF_RE, JOURNEY_ID_RE,
    ISSUE_REF_RE,
)

rel = os.path.basename(tfile)
try:
    with open(tfile, "r", encoding="utf-8") as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    fail_with_script_error(f"{rel}: invalid JSON ({e})")

findings: list[Finding] = []

# CR-AF07 — top-level schema
if not isinstance(data, dict):
    fail_with_script_error(f"{rel}: top-level value must be an object")

REQUIRED_KEYS = ("criteria", "journeys", "orphan_tests", "unmapped_criteria")
for key in REQUIRED_KEYS:
    if key not in data:
        findings.append(Finding(
            criterion_id="CR-AF07",
            file=rel,
            severity="error",
            description=f"missing top-level key `{key}`",
            suggested_fix=f"add `\"{key}\": []` (or populated array) to "
                          "traceability.json",
        ))
    elif not isinstance(data[key], list):
        findings.append(Finding(
            criterion_id="CR-AF07",
            file=rel,
            severity="error",
            description=f"top-level key `{key}` must be an array",
            suggested_fix=f"change `{key}` to a JSON array",
        ))

VALID_STATUS = {"PASS", "FAIL", "NOT_COVERED"}

for i, c in enumerate(data.get("criteria", []) or []):
    if not isinstance(c, dict):
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"criteria[{i}] is not an object",
            suggested_fix="entry must be an object with id and status",
        ))
        continue
    cid = c.get("id", "")
    if not cid or not AC_REF_RE.match(str(cid)):
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"criteria[{i}].id missing or malformed: {cid!r}",
            suggested_fix="use `F-NNN/AC<n>` format",
        ))
    status = c.get("status", "")
    if status not in VALID_STATUS:
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"criteria[{i}] ({cid}): status must be one of "
                        f"{sorted(VALID_STATUS)}, got {status!r}",
            suggested_fix="use PASS / FAIL / NOT_COVERED",
        ))
    if status in ("PASS", "FAIL"):
        tests = c.get("tests")
        if not isinstance(tests, list) or not tests:
            findings.append(Finding(
                criterion_id="CR-AF07", file=rel, severity="error",
                description=f"criteria[{i}] ({cid}): {status} entry has no tests[]",
                suggested_fix="list at least one test path that exercises this AC",
            ))
        elif isinstance(tests, list):
            # CR-AF15 — every test path must be a non-empty string; if a
            # source-root is supplied, the path must resolve to a real file.
            for ti, tp in enumerate(tests):
                if not isinstance(tp, str) or not tp.strip():
                    findings.append(Finding(
                        criterion_id="CR-AF15", file=rel, severity="error",
                        description=(
                            f"criteria[{i}] ({cid}).tests[{ti}] is not a "
                            f"non-empty string ({tp!r})"
                        ),
                        suggested_fix=(
                            "replace with the actual test file path or "
                            "test case identifier (e.g. "
                            "`tests/acceptance/test_F001_AC3.py` or "
                            "`e2e/F-001-login.spec.ts::happy_path`)"
                        ),
                    ))
                    continue
                if source_root:
                    # Strip ::testname suffix and any trailing whitespace.
                    raw_path = tp.split("::", 1)[0].strip()
                    full = os.path.join(source_root, raw_path)
                    # Use isfile, not exists: a directory at the test path
                    # means the path is wrong (renamed test, deleted file
                    # but stale parent dir, etc.).
                    if not os.path.isfile(full):
                        findings.append(Finding(
                            criterion_id="CR-AF15", file=rel, severity="error",
                            description=(
                                f"criteria[{i}] ({cid}).tests[{ti}] references "
                                f"a path that is not an existing file under "
                                f"source-root: {tp!r}"
                            ),
                            suggested_fix=(
                                "fix the path to point at a real test file "
                                "(typo, wrong subdir, or the test was never "
                                "actually written — the AC is then "
                                "NOT_COVERED, not PASS)"
                            ),
                        ))
    # CR-AF10 — NOT_COVERED needs issue link
    if status == "NOT_COVERED":
        issue = str(c.get("issue", "")).strip()
        if not issue or not ISSUE_REF_RE.match(issue):
            findings.append(Finding(
                criterion_id="CR-AF10", file=rel, severity="error",
                description=f"criteria[{i}] ({cid}): NOT_COVERED without "
                            f"`issue` field (got {issue!r})",
                suggested_fix="open a tracked issue and reference it as "
                              "`owner/repo#NNN` (delivery-discipline §D)",
            ))

for i, j in enumerate(data.get("journeys", []) or []):
    if not isinstance(j, dict):
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"journeys[{i}] is not an object",
            suggested_fix="entry must be an object with id, status, "
                          "touchpoints_traversed, touchpoints_total",
        ))
        continue
    jid = j.get("id", "")
    if not JOURNEY_ID_RE.match(str(jid)):
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"journeys[{i}].id missing or malformed: {jid!r}",
            suggested_fix="use `J-NNN` format",
        ))
    if j.get("status") not in VALID_STATUS:
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"journeys[{i}] ({jid}): status missing or invalid",
            suggested_fix="use PASS / FAIL / NOT_COVERED",
        ))
    total = j.get("touchpoints_total")
    traversed = j.get("touchpoints_traversed")
    if not isinstance(total, int) or total <= 0:
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"journeys[{i}] ({jid}): touchpoints_total must be a "
                        f"positive integer (got {total!r})",
            suggested_fix="set touchpoints_total to the number of touchpoints "
                          "in the journey spec",
        ))
    if isinstance(total, int) and isinstance(traversed, int) and traversed > total:
        findings.append(Finding(
            criterion_id="CR-AF07", file=rel, severity="error",
            description=f"journeys[{i}] ({jid}): traversed > total",
            suggested_fix="touchpoints_traversed cannot exceed touchpoints_total",
        ))

    # CR-AF21 — every journey must have at least one non-happy scenario
    # (error / boundary / concurrency / ...) unless the gap is tracked.
    scenarios = j.get("scenarios")
    coverage_gap_issue = str(j.get("coverage_gap_issue", "")).strip()
    if scenarios is None:
        # Tolerated only if traceability hasn't migrated yet AND the gap
        # is explicitly acknowledged via coverage_gap_issue.
        if not coverage_gap_issue or not ISSUE_REF_RE.match(coverage_gap_issue):
            findings.append(Finding(
                criterion_id="CR-AF21", file=rel, severity="error",
                description=f"journeys[{i}] ({jid}): no `scenarios[]` array — "
                            "cannot verify negative-path coverage",
                suggested_fix="add a `scenarios` array with `kind` "
                              "(happy/error/boundary/concurrency) per entry "
                              "(delivery-discipline §M.2)",
            ))
    else:
        if not isinstance(scenarios, list):
            findings.append(Finding(
                criterion_id="CR-AF07", file=rel, severity="error",
                description=f"journeys[{i}] ({jid}): scenarios must be an array",
                suggested_fix="change `scenarios` to a JSON array",
            ))
        else:
            kinds: list[str] = []
            for k, s in enumerate(scenarios):
                if not isinstance(s, dict):
                    findings.append(Finding(
                        criterion_id="CR-AF07", file=rel, severity="error",
                        description=f"journeys[{i}] ({jid}).scenarios[{k}] is not an object",
                        suggested_fix="each scenario must be an object with kind/test/status",
                    ))
                    continue
                kind = str(s.get("kind", "")).lower()
                if kind not in {"happy", "error", "boundary", "concurrency", "idempotency"}:
                    findings.append(Finding(
                        criterion_id="CR-AF07", file=rel, severity="error",
                        description=f"journeys[{i}] ({jid}).scenarios[{k}].kind invalid: {kind!r}",
                        suggested_fix="use one of happy / error / boundary / "
                                      "concurrency / idempotency",
                    ))
                else:
                    kinds.append(kind)
                # CR-AF15 — scenario.test must be a non-empty path; if
                # source-root is supplied, file must exist.
                stat = s.get("status")
                if stat in ("PASS", "FAIL"):
                    test_path = s.get("test")
                    if not isinstance(test_path, str) or not test_path.strip():
                        findings.append(Finding(
                            criterion_id="CR-AF15", file=rel, severity="error",
                            description=(
                                f"journeys[{i}] ({jid}).scenarios[{k}] ({kind}, "
                                f"{stat}) has empty/missing `test` path "
                                f"({test_path!r})"
                            ),
                            suggested_fix=(
                                "set `test` to the spec file that asserts this "
                                "scenario (e.g. `e2e/J-001-checkout-error.spec.ts`); "
                                "PASS without a test path is a soft-pass per "
                                "delivery-discipline §A SP4"
                            ),
                        ))
                    elif source_root:
                        raw_path = test_path.split("::", 1)[0].strip()
                        # Use isfile, not exists: a directory at the spec
                        # path means the spec was renamed/deleted.
                        if not os.path.isfile(os.path.join(source_root, raw_path)):
                            findings.append(Finding(
                                criterion_id="CR-AF15", file=rel, severity="error",
                                description=(
                                    f"journeys[{i}] ({jid}).scenarios[{k}].test "
                                    f"references non-existent file: {test_path!r}"
                                ),
                                suggested_fix=(
                                    "fix the path to point at a real spec file, "
                                    "or downgrade the scenario to NOT_COVERED "
                                    "with an issue link"
                                ),
                            ))
            non_happy = [k for k in kinds if k != "happy"]
            if not non_happy:
                if not coverage_gap_issue or not ISSUE_REF_RE.match(coverage_gap_issue):
                    findings.append(Finding(
                        criterion_id="CR-AF21", file=rel, severity="error",
                        description=(
                            f"journeys[{i}] ({jid}): only happy-path scenarios "
                            "recorded; no error / boundary / concurrency "
                            "coverage"
                        ),
                        suggested_fix=(
                            "add at least one scenario with kind=error or "
                            "kind=boundary asserting the specific failure mode "
                            "the PRD describes, or set "
                            "`coverage_gap_issue: \"owner/repo#NNN\"` to "
                            "track the gap (delivery-discipline §M.2)"
                        ),
                    ))

# CR-AF09 — no orphan tests allowed
for i, o in enumerate(data.get("orphan_tests", []) or []):
    path = (o or {}).get("path") if isinstance(o, dict) else None
    findings.append(Finding(
        criterion_id="CR-AF09", file=rel, severity="error",
        description=f"orphan test present: {path or o!r}",
        suggested_fix="map test to an AC / journey touchpoint, delete it, or "
                      "rename it to reflect what it actually verifies",
    ))

# CR-AF08 — no unmapped acceptance criteria
for i, u in enumerate(data.get("unmapped_criteria", []) or []):
    cid = u if isinstance(u, str) else (u or {}).get("id", "")
    findings.append(Finding(
        criterion_id="CR-AF08", file=rel, severity="error",
        description=f"unmapped acceptance criterion: {cid!r}",
        suggested_fix="write a test that asserts the AC, or record the entry "
                      "in criteria[] with status NOT_COVERED + issue link",
    ))

emit(findings, scope_label=f"({rel})")
PYEOF
