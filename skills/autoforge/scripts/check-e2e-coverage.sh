#!/usr/bin/env bash
# check-e2e-coverage.sh — verify the acceptance report records a real
# E2E command invocation AND that every frontend / E2E feature ID has at
# least one matching spec file.
#
# Background. delivery-1 and delivery-2 retros showed the same failure
# mode: the orchestrator wrote "PASS" into acceptance.md based on unit /
# integration tests alone. The autoforge skill has always required
# E2E + traceability, but nothing enforced it. This checker closes the
# loop by parsing the `## E2E Test Run` section that the Acceptance
# Tester subagent must produce, and by globbing the project tree for
# spec files whose name encodes the feature IDs the plan references.
#
#   CR-AF23  e2e-run-evidence-missing
#            (E2E Test Run section absent OR has no Command/Exit Code OR
#            shows non-zero exit code without justification)
#   CR-AF26  e2e-feature-spec-missing
#            (a feature id appearing in any module plan's
#            `Source Features` row has no spec file under the e2e
#            roots whose name encodes the F-ID)
#
# Usage: check-e2e-coverage.sh <plan-dir> [--source-root <dir>]

set -euo pipefail

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  echo "Usage: check-e2e-coverage.sh <plan-dir> [--source-root <dir>]" >&2
  exit 2
fi
shift

SOURCE_ROOT="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_SCRIPT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import glob, os, re, sys

plan_dir = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]
script_dir = os.environ["AF_SCRIPT_DIR"]

sys.path.insert(0, os.path.join(script_dir, "lib"))
from autoforge_lint import Finding, emit, fail_with_script_error, FEATURE_ID_RE  # noqa: E402

findings: list[Finding] = []

# ─── 1. Parse acceptance.md `## E2E Test Run` block (CR-AF23) ──────────────

acceptance = os.path.join(plan_dir, "reports", "acceptance.md")
if not os.path.isfile(acceptance):
    findings.append(Finding(
        criterion_id="CR-AF23",
        file=os.path.relpath(acceptance, plan_dir),
        severity="critical",
        description="reports/acceptance.md missing — cannot verify e2e coverage",
        suggested_fix=(
            "spawn the Acceptance Tester subagent to produce reports/acceptance.md "
            "(autoforge SKILL.md Step 3 / E6); only the subagent may write this "
            "file."
        ),
    ))
else:
    with open(acceptance, "r", encoding="utf-8", errors="replace") as f:
        body = f.read()

    # Extract the E2E Test Run section.
    m = re.search(
        r"^##\s+E2E Test Run\s*$(.+?)(?=^##\s|\Z)",
        body,
        flags=re.MULTILINE | re.DOTALL,
    )
    if not m:
        findings.append(Finding(
            criterion_id="CR-AF23",
            file="reports/acceptance.md",
            severity="critical",
            description="`## E2E Test Run` section missing from acceptance.md",
            suggested_fix=(
                "add the E2E Test Run section per acceptance/report-template.md; "
                "it must record the actual e2e command invocation (or `n/a — …` "
                "with written justification)"
            ),
        ))
        e2e_section = ""
    else:
        e2e_section = m.group(1)

    if e2e_section:
        # Look for the `n/a` escape hatch first; if present, accept the
        # section but still check for justification text.
        is_na = bool(re.search(r"\|\s*Command\s*\|.*?\bn/?a\b", e2e_section, re.IGNORECASE))
        if is_na:
            # Justification = anything substantive after the n/a marker on
            # the same row. We require >= 6 chars after `n/a`.
            row_m = re.search(
                r"\|\s*Command\s*\|(.*?)\|",
                e2e_section,
                flags=re.IGNORECASE,
            )
            row = (row_m.group(1) if row_m else "").strip()
            stripped = re.sub(r".*?n/?a", "", row, count=1, flags=re.IGNORECASE).strip(" \t—-")
            if len(stripped) < 6:
                findings.append(Finding(
                    criterion_id="CR-AF23",
                    file="reports/acceptance.md",
                    severity="error",
                    description=(
                        "E2E Test Run Command is `n/a` but no justification was "
                        "provided"
                    ),
                    suggested_fix=(
                        "after `n/a` write a one-clause reason such as "
                        "`n/a — project is a Go library, no UI surface`"
                    ),
                ))
            else:
                # Per delivery-discipline §L, certain reason phrases are
                # complexity excuses, not observable causes. Reject them
                # even when length passes. The list mirrors §L's forbidden
                # reason phrases for deferral entries.
                FORBIDDEN_REASON_RE = re.compile(
                    r"(?i)\b("
                    r"too\s+(complex|hard|difficult|long)|complicated|complexity|"
                    r"too\s+slow|too\s+expensive|"
                    r"no\s+time|out\s+of\s+time|ran\s+out\s+of\s+time|"
                    r"will\s+(do|fix)\s+later|do\s+it\s+later|later\s+iteration|"
                    r"needs?\s+refactor(ing)?|"
                    r"scope\s+creep|out\s+of\s+scope|"
                    r"tbd|todo|follow.?up|we'?ll\s+revisit|"
                    r"tracked\s+as\s+follow.?up"
                    r")\b"
                )
                m = FORBIDDEN_REASON_RE.search(stripped)
                if m:
                    findings.append(Finding(
                        criterion_id="CR-AF23",
                        file="reports/acceptance.md",
                        severity="error",
                        description=(
                            f"E2E Test Run Command `n/a` justification uses a "
                            f"forbidden complexity-excuse phrase ({m.group(0)!r}); "
                            f"per delivery-discipline §L the reason must be a "
                            f"concrete observable cause, not a complexity claim"
                        ),
                        suggested_fix=(
                            "rewrite the justification with a structural cause: "
                            "`n/a — project is a Go library, no UI surface` / "
                            "`n/a — pure CLI, no DOM` / "
                            "`n/a — design has no `## UI Architecture` modules`. "
                            "If e2e is genuinely needed but blocked, run the suite "
                            "and record its real exit code (or open a tracked issue "
                            "and downgrade the verdict to PARTIAL/FAIL)."
                        ),
                    ))
        else:
            # Real run: must have Command, Exit Code, and an output block.
            cmd_m = re.search(
                r"\|\s*Command\s*\|\s*(.+?)\s*\|",
                e2e_section,
                re.IGNORECASE,
            )
            exit_m = re.search(
                r"\|\s*Exit\s*Code\s*\|\s*(.+?)\s*\|",
                e2e_section,
                re.IGNORECASE,
            )
            cmd_value = (cmd_m.group(1).strip() if cmd_m else "")
            exit_value = (exit_m.group(1).strip() if exit_m else "")

            # Strip backticks for the "looks empty" heuristic.
            cmd_clean = re.sub(r"[`$\s]+", "", cmd_value)
            if not cmd_clean or cmd_clean in {"...", "TODO", "TBD"}:
                findings.append(Finding(
                    criterion_id="CR-AF23",
                    file="reports/acceptance.md",
                    severity="critical",
                    description=(
                        "E2E Test Run `Command` is empty or a placeholder "
                        f"({cmd_value!r})"
                    ),
                    suggested_fix=(
                        "fill in the verbatim command the Acceptance Tester "
                        "ran (e.g. `npm run test:e2e`, `npx playwright test`)"
                    ),
                ))
            if not exit_value or exit_value in {"...", "TODO", "TBD"}:
                findings.append(Finding(
                    criterion_id="CR-AF23",
                    file="reports/acceptance.md",
                    severity="critical",
                    description=(
                        f"E2E Test Run `Exit Code` is empty or placeholder ({exit_value!r})"
                    ),
                    suggested_fix=(
                        "fill in the actual exit code (must be `0` for the "
                        "delivery-tag gate to pass)"
                    ),
                ))
            elif not re.fullmatch(r"`?0`?", exit_value):
                # Non-zero exit: only acceptable if the verdict is FAIL/PARTIAL.
                # We only warn here; the verdict itself is enforced by
                # CR-AF06 elsewhere.
                findings.append(Finding(
                    criterion_id="CR-AF23",
                    file="reports/acceptance.md",
                    severity="error",
                    description=(
                        f"E2E run exit code is non-zero ({exit_value!r}); "
                        "delivery-tag gate cannot pass"
                    ),
                    suggested_fix=(
                        "fix the failing e2e specs and re-run the suite, OR "
                        "downgrade the verdict to PARTIAL/FAIL with the "
                        "failing scenarios listed under Failed Items"
                    ),
                ))

            # Output evidence: a fenced code block must be present.
            if not re.search(r"```", e2e_section):
                findings.append(Finding(
                    criterion_id="CR-AF23",
                    file="reports/acceptance.md",
                    severity="error",
                    description=(
                        "E2E Test Run section has no fenced code block with "
                        "the run output"
                    ),
                    suggested_fix=(
                        "paste the last ~30 lines of the e2e command's "
                        "output inside a ```text ... ``` fenced block, "
                        "including the framework's summary line"
                    ),
                ))

# ─── 2. Cross-validate: every F-ID in any module plan's Source Features ────
#                       row that names a frontend / UI surface must have a
#                       matching e2e spec.

# Collect F-IDs from all module plans' "Source Features" lines.
feature_ids: set[str] = set()
for plan_path in glob.glob(os.path.join(plan_dir, "plans", "plan-M-*.md")):
    try:
        with open(plan_path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        continue
    # Multiple match patterns: Markdown table cell, prose, "Source Features:",
    # "Source Feature:", "Promoted from feature F-NNN", etc.
    for hit in re.finditer(r"\bF-\d{3,}\b", text):
        feature_ids.add(hit.group(0))

# Heuristic: only require an e2e spec for features that touch the frontend.
# Look at the corresponding feature spec under PRD `features/F-NNN-*.md`
# (if reachable from source root) and check for a "Frontend Draft"
# subsection or any UI / frontend keyword. Falls back to "require for
# every F-ID" if PRD is not reachable, since a missing spec is a louder
# signal than a missed gate.
# Compute the set of frontend-touching F-IDs by walking the DESIGN
# directory: a feature is frontend-touching iff some design module owns
# it AND that design module has a `## UI Architecture` (or
# `## UI Architecture & Layer` etc.) section.
#
# This is a much stronger signal than scraping PRD prose for keywords —
# the design author explicitly declares "this module has a UI surface"
# by writing a UI Architecture section. Backend modules don't have it;
# frontend modules do. Tested against the d2 plan: 9 design modules
# (M-035 through M-044) carry it; their union of Source Features is
# exactly the set of frontend features.

UI_SECTION_RE = re.compile(
    r"^##+\s*UI\s+Architecture\b",
    re.MULTILINE | re.IGNORECASE,
)
SOURCE_FEATURES_INLINE_RE = re.compile(
    r"^>\s*\*\*Source Features:\*\*\s*(.+?)(?:\s{2,}\*\*|\s*$)",
    re.MULTILINE,
)
F_ID_RE = re.compile(r"\bF-\d{3,}\b")

def collect_frontend_feature_ids() -> set[str]:
    """Return the set of F-IDs owned by any design module that has a
    `## UI Architecture` section. Returns an empty set if the design
    directory cannot be located (which disables CR-AF26 entirely —
    callers fall back to CR-AF23 alone)."""
    design_root_candidates = [
        os.path.normpath(os.path.join(plan_dir, "..", "..", "design")),
        os.path.normpath(os.path.join(source_root, "docs", "raw", "design")),
    ]
    out: set[str] = set()
    for design_root in design_root_candidates:
        if not os.path.isdir(design_root):
            continue
        for project in os.listdir(design_root):
            modules_dir = os.path.join(design_root, project, "modules")
            if not os.path.isdir(modules_dir):
                continue
            for entry in os.listdir(modules_dir):
                if not entry.startswith("M-") or not entry.endswith(".md"):
                    continue
                full = os.path.join(modules_dir, entry)
                try:
                    with open(full, "r", encoding="utf-8", errors="replace") as f:
                        spec = f.read()
                except OSError:
                    continue
                if not UI_SECTION_RE.search(spec):
                    continue
                inline = SOURCE_FEATURES_INLINE_RE.search(spec)
                if inline:
                    for fid in F_ID_RE.findall(inline.group(1)):
                        out.add(fid)
                    continue
                # Fallback: parse the `## Source Features` section.
                section_match = re.search(
                    r"^##\s+Source Features\s*$(.+?)(?=^##\s|\Z)",
                    spec,
                    flags=re.MULTILINE | re.DOTALL,
                )
                if section_match:
                    for fid in F_ID_RE.findall(section_match.group(1)):
                        out.add(fid)
    return out

frontend_feature_ids = collect_frontend_feature_ids()

def feature_has_frontend_surface(fid: str) -> bool:
    return fid in frontend_feature_ids

# Discover e2e roots under source_root.
def find_e2e_roots() -> list[str]:
    candidates = [
        os.path.join(source_root, "frontend", "e2e"),
        os.path.join(source_root, "e2e"),
        os.path.join(source_root, "tests", "e2e"),
        os.path.join(source_root, "test", "e2e"),
    ]
    return [c for c in candidates if os.path.isdir(c)]

e2e_roots = find_e2e_roots()
if e2e_roots:
    # Index every spec file by name.
    spec_files: list[str] = []
    for root in e2e_roots:
        for dirpath, _dirs, files in os.walk(root):
            # Skip node_modules etc.
            if any(seg in dirpath for seg in ("node_modules", ".cache", "dist", "build")):
                continue
            for name in files:
                if re.search(r"\.(spec|test|e2e)\.[jt]sx?$", name) or name.endswith(".cy.ts") or name.endswith(".cy.js"):
                    spec_files.append(os.path.join(dirpath, name))

    for fid in sorted(feature_ids):
        if not feature_has_frontend_surface(fid):
            continue
        # Match any spec containing the F-ID (with hyphen or underscore).
        fid_alts = [fid, fid.replace("-", "_"), fid.replace("-", "")]
        matched = [
            os.path.relpath(p, source_root)
            for p in spec_files
            if any(alt in os.path.basename(p) for alt in fid_alts)
        ]
        if not matched:
            findings.append(Finding(
                criterion_id="CR-AF26",
                file=f"e2e-coverage[{fid}]",
                severity="error",
                description=(
                    f"frontend feature {fid} has no e2e spec file under "
                    f"{', '.join(os.path.relpath(r, source_root) for r in e2e_roots)} "
                    f"whose name encodes the F-ID"
                ),
                suggested_fix=(
                    f"add at least one spec file named e.g. "
                    f"`{fid}-<scenario>.spec.ts` (or .test.ts / .e2e.ts) "
                    f"that drives the feature's user-visible journey end "
                    f"to end and asserts each touchpoint per "
                    f"delivery-discipline §E and §M"
                ),
            ))
# If no e2e roots exist at all, that itself is a finding only when the
# acceptance.md does NOT mark e2e as `n/a`. We already emit CR-AF23 for
# the missing E2E Test Run block; emitting CR-AF26 here would be noise.

emit(findings, scope_label="(e2e-coverage)")
PYEOF
