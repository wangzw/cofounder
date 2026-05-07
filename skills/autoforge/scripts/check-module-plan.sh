#!/usr/bin/env bash
# check-module-plan.sh — verify a per-module plan file conforms to
# planning/module-plan-template.md.
#
# Required `## ` sections (per the updated template):
#   Context, Implementation Steps, Integration Points,
#   Wiring & Registration, Out-of-Scope / Deferred Work,
#   Acceptance Criteria Mapping
#
# Additional structural checks:
#   CR-AF01  required-sections-present
#   CR-AF02  wiring-section-non-empty (table with at least one data row)
#   CR-AF03  ac-mapping-non-empty (table with at least one row)
#   CR-AF04  out-of-scope-rows-have-issue-link (rows must reference an
#            owner/repo#NNN issue; placeholder rows tolerated when whole
#            section is the template's example row only)
#   CR-AF17  out-of-scope-reason-not-a-complexity-excuse (reason field
#            must be a causal explanation, not "too complex"/"hard"/etc.)
#   CR-AF18  out-of-scope-item-concrete (item field must be ≥ 12 chars
#            and not a vague placeholder like "polish UX")
#   CR-AF19  out-of-scope-item-not-also-claimed (an AC marked PASS in
#            Acceptance Criteria Mapping cannot also appear in
#            Out-of-Scope — pick one)
#
# Usage: check-module-plan.sh <plan-file>
#
# 3-state contract (matches prd-analysis):
#   0 = PASS, 1 = FOUND issues + JSON, 2 = script error.

set -euo pipefail

PLAN_PATH="${1:-}"
if [ -z "$PLAN_PATH" ] || [ ! -f "$PLAN_PATH" ]; then
  echo "ERROR: plan file not found: ${PLAN_PATH:-<empty>}" >&2
  echo "Usage: check-module-plan.sh <plan-file>" >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PLAN_PATH" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys
plan_path = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from autoforge_lint import (
    Finding, read_text, heading_set, emit, fail_with_script_error,
    ISSUE_REF_RE,
)

text = read_text(plan_path)
if text is None:
    fail_with_script_error(f"cannot read {plan_path}")

REQUIRED = {
    "Context", "Implementation Steps", "Integration Points",
    "Wiring & Registration", "Out-of-Scope / Deferred Work",
    "Acceptance Criteria Mapping",
}
findings: list[Finding] = []
rel = os.path.basename(plan_path)
present = heading_set(text, level=2)
missing = sorted(REQUIRED - present)
for s in missing:
    findings.append(Finding(
        criterion_id="CR-AF01",
        file=rel,
        severity="error",
        description=f"missing required `## {s}` section",
        suggested_fix=f"add a `## {s}` section per planning/module-plan-template.md",
    ))


def section_body(name: str) -> str:
    """Return body lines under `## name` up to the next `## ` heading."""
    out: list[str] = []
    capture = False
    for line in text.splitlines():
        if line.startswith("## "):
            if capture:
                break
            capture = (line[3:].strip() == name)
            continue
        if capture:
            out.append(line)
    return "\n".join(out)


def table_data_rows(body: str) -> list[str]:
    """Return non-divider data rows (lines starting with `|`)."""
    return [
        ln for ln in body.splitlines()
        if ln.lstrip().startswith("|")
        and not re.match(r"^\s*\|\s*[-:|\s]+\|\s*$", ln)
        and "---" not in ln
    ]


def is_template_row(row: str) -> bool:
    """Crude detector for placeholder rows shipped by the template."""
    return "{" in row and "}" in row


# CR-AF02 wiring-section-non-empty
if "Wiring & Registration" not in missing:
    body = section_body("Wiring & Registration")
    rows = table_data_rows(body)
    # Skip the header row.
    data_rows = rows[1:] if rows else []
    real_rows = [r for r in data_rows if not is_template_row(r)]
    if not real_rows:
        findings.append(Finding(
            criterion_id="CR-AF02",
            file=rel,
            severity="error",
            description="Wiring & Registration section has no concrete rows; "
                        "every wire-up step must be explicitly listed",
            suggested_fix="add rows for each schema-registration / route-mount / "
                          "middleware-insert / env-flag the module ships, "
                          "with a verifiable signal column",
        ))

# CR-AF03 ac-mapping-non-empty
if "Acceptance Criteria Mapping" not in missing:
    body = section_body("Acceptance Criteria Mapping")
    rows = table_data_rows(body)
    data_rows = rows[1:] if rows else []
    real_rows = [r for r in data_rows if not is_template_row(r)]
    if not real_rows:
        findings.append(Finding(
            criterion_id="CR-AF03",
            file=rel,
            severity="error",
            description="Acceptance Criteria Mapping has no concrete rows; "
                        "module owns no AC traceability",
            suggested_fix="add a row per AC the module owns: AC id, journey "
                          "touchpoint, implementation step, test step, "
                          "strict assertion",
        ))

# CR-AF04 / CR-AF17 / CR-AF18 / CR-AF19 — Out-of-Scope row scrutiny
WEAK_REASON_PATTERNS = [
    r"\btoo[ -]?complex\b", r"\bcomplex(ity|ities)?\b",
    r"\bcomplicat(ed|ion)\b",
    r"\btoo[ -]?hard\b", r"\bdifficult\b", r"\bhard to (implement|do)\b",
    r"\bno time\b", r"\bran out of time\b", r"\bout of time\b",
    r"\b(do|will do|fix|finish) (it )?later\b",
    r"\blater iteration\b(?!.*phase)", r"\bnext time\b",
    r"\bneeds? refactor(ing)?\b",
    r"\bscope creep\b", r"^out of scope$",
    r"^tbd$", r"^todo$", r"^follow[- ]?up$", r"\bwe.?ll revisit\b",
    r"^later$", r"^soon$",
]
WEAK_ITEM_PATTERNS = [
    r"^polish[ -]?(ux|ui)?$", r"^edge cases?$", r"^tech[- ]?debt$",
    r"^refactor(ing)?$", r"^improvements?$", r"^cleanup$", r"^misc$",
    r"^various$", r"^etc\.?$",
]

def matches_any(s: str, patterns: list[str]) -> str | None:
    low = s.strip().lower()
    for pat in patterns:
        if re.search(pat, low):
            return pat
    return None

# Collect AC ids claimed in the Acceptance Criteria Mapping (PASS rows).
claimed_acs: set[str] = set()
if "Acceptance Criteria Mapping" not in missing:
    body_ac = section_body("Acceptance Criteria Mapping")
    for r in table_data_rows(body_ac)[1:]:
        if is_template_row(r):
            continue
        for m in re.finditer(r"F-\d{3,}/AC\d+", r):
            claimed_acs.add(m.group(0))

if "Out-of-Scope / Deferred Work" not in missing:
    body = section_body("Out-of-Scope / Deferred Work")
    rows = table_data_rows(body)
    data_rows = rows[1:] if rows else []
    for r in data_rows:
        if is_template_row(r):
            continue
        cells = [c.strip() for c in r.strip().strip("|").split("|")]
        # Expected cell layout (template): #, Item, Reason, Tracked In
        # If the leading column is numeric, drop it.
        if cells and re.match(r"^\d+$", cells[0]):
            cells = cells[1:]
        item_cell = cells[0] if len(cells) > 0 else ""
        reason_cell = cells[1] if len(cells) > 1 else ""
        issue_cell = cells[-1] if cells else ""

        m = re.search(r"[\w.-]+/[\w.-]+#\d+", issue_cell)
        if not m:
            findings.append(Finding(
                criterion_id="CR-AF04",
                file=rel,
                severity="error",
                description=f"Out-of-Scope row missing issue link: {r.strip()[:120]}",
                suggested_fix="reference a GitHub issue (owner/repo#NNN) for "
                              "every deferred item — TODO comments are not a "
                              "substitute (delivery-discipline §D)",
            ))

        # CR-AF17 weak reason
        weak = matches_any(reason_cell, WEAK_REASON_PATTERNS)
        if weak or len(reason_cell) < 12:
            findings.append(Finding(
                criterion_id="CR-AF17",
                file=rel,
                severity="error",
                description=(
                    f"Out-of-Scope reason is a complexity excuse, not a cause: "
                    f"'{reason_cell[:80]}' (row: {r.strip()[:120]})"
                ),
                suggested_fix=(
                    "rewrite the reason as an observable cause: upstream PR not "
                    "merged, third-party API contract missing, regulatory "
                    "blocker, or an explicit PRD scoping decision linked from "
                    "this row (delivery-discipline §L)"
                ),
            ))

        # CR-AF18 vague item
        weak_item = matches_any(item_cell, WEAK_ITEM_PATTERNS)
        if weak_item or len(item_cell) < 12:
            findings.append(Finding(
                criterion_id="CR-AF18",
                file=rel,
                severity="error",
                description=(
                    f"Out-of-Scope item is too vague: '{item_cell[:80]}' "
                    "(must name a concrete deliverable)"
                ),
                suggested_fix=(
                    "name a concrete, verifiable deliverable (≥ 12 chars). "
                    "If it is genuinely a bucket, split it into the actual "
                    "items it contains (delivery-discipline §L)"
                ),
            ))

        # CR-AF19 item also claimed
        for ac in re.findall(r"F-\d{3,}/AC\d+", item_cell):
            if ac in claimed_acs:
                findings.append(Finding(
                    criterion_id="CR-AF19",
                    file=rel,
                    severity="critical",
                    description=(
                        f"contradiction: {ac} is both claimed in Acceptance "
                        f"Criteria Mapping and listed as Out-of-Scope"
                    ),
                    suggested_fix=(
                        f"remove {ac} from one of the two sections — a module "
                        "cannot simultaneously own and defer the same AC "
                        "(delivery-discipline §L)"
                    ),
                ))

emit(findings, scope_label=f"({rel})")
PYEOF
