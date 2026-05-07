#!/usr/bin/env bash
# check-frontend-draft.sh — formal review of `#### Frontend Draft Reference`
# coverage on user-facing feature leaves.
#
# Per guide §1.1 + §9: emits one issue per finding in JSON; 3-state
# returncode; idempotent. Implements:
#
#   CR-PP-FD01  frontend-draft-reference-populated — every feature whose body
#               contains `## Interaction Design` (i.e. user-facing) MUST have
#               a populated `#### Frontend Draft Reference` subsection with:
#                 - `Draft path:` line bearing a concrete repo-relative path
#                   (no `{repo-root}` / `{frontend-implementation-path}` /
#                   `{feature-area}` template placeholders).
#                 - `Confirmed (experience):` line bearing either a
#                   YYYY-MM-DD date OR the literal `null`. When `null`, a
#                   sibling `Drift:` line MUST explain why the experience
#                   confirmation is deferred.
#
# This script is auto-discovered by run-checkers.sh and therefore participates
# in the formal hard gate enforced by `verify-phase-entry.sh read`. It is
# intentionally NOT in the writer-subagent's per-leaf pre-check table — the
# `feature-template.md` instructs writers to OMIT the subsection during initial
# generation; Phase 5 (run by the orchestrator after the writer fan-out) is
# responsible for filling it. The convergence-time hard gate is the backstop.
#
# Usage: check-frontend-draft.sh <prd-dir>

set -uo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-frontend-draft.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import (
    Finding, list_dir, read_text, emit, FEATURE_FILE_RE,
)

features_dir = os.path.join(prd_root, "features")
if not os.path.isdir(features_dir):
    # No features/ dir: layout problem, but check-readme owns that surface.
    emit([], scope_label="(no features/ directory)")

INTERACTION_HEADING = re.compile(r"(?im)^##\s+Interaction\s+Design\b")
DRAFT_HEADING = re.compile(r"(?im)^####\s+Frontend\s+Draft\s+Reference\b")
# Relaxed heading match: any markdown heading level (h1–h6) bearing the
# `Frontend Draft Reference` text. Used to detect wrong-level drift so the
# error message can be specific instead of reporting a generic "missing"
# section. Captures the leading hash-run so the actual level can be reported.
DRAFT_HEADING_ANY_LEVEL = re.compile(
    r"(?im)^(#{1,6})\s+Frontend\s+Draft\s+Reference\b"
)
DRAFT_PATH_LINE = re.compile(r"(?im)^[^\n]*\bDraft\s+path\s*:\s*(.*)$")
CONFIRMED_LINE = re.compile(r"(?im)^[^\n]*\bConfirmed\s*\(experience\)\s*:\s*(.*)$")
DRIFT_LINE = re.compile(r"(?im)^[^\n]*\bDrift\s*:\s*(.*)$")
NEXT_HEADING = re.compile(r"(?m)^#{1,4}\s")

PLACEHOLDER_TOKENS = re.compile(r"\{repo-root\}|\{frontend-implementation-path\}|\{feature-area\}")
DATE_RE = re.compile(r"\b\d{4}-\d{2}-\d{2}\b")
PLACEHOLDER_DATE = re.compile(r"\{?YYYY-MM-DD\}?", re.IGNORECASE)

# Strip Markdown decoration around the captured value. Bold-key labels of the
# form `- **Draft path:** value` leave the closing `**` on the value side of
# the colon, so we strip leading and trailing decoration chars (`*`, `_`,
# `` ` ``) plus whitespace, and we drop trailing italic notes such as
# `*(repo-relative; the base path is set in architecture/tech-stack.md)*`.
DECORATION_CHARS = "*_`"
TRAILING_NOTE_RE = re.compile(r"\s*\*\([^)]*\)\*\s*$")

def normalize(value: str) -> str:
    v = value.strip()
    v = TRAILING_NOTE_RE.sub("", v).strip()
    while v and v[0] in DECORATION_CHARS:
        v = v[1:].lstrip()
    while v and v[-1] in DECORATION_CHARS:
        v = v[:-1].rstrip()
    return v

findings: list[Finding] = []

for fname in list_dir(prd_root, "features"):
    if not fname.endswith(".md") or not FEATURE_FILE_RE.match(fname):
        continue
    rel = f"features/{fname}"
    text = read_text(os.path.join(prd_root, rel))
    if text is None:
        continue

    if not INTERACTION_HEADING.search(text):
        # Non-user-facing feature (no Interaction Design) — Frontend Draft
        # Reference is N/A.
        continue

    m_h = DRAFT_HEADING.search(text)
    if not m_h:
        # Distinguish "heading absent entirely" from "heading present but at
        # the wrong level (h3 / h5 / etc.)". Both are CR-PP-FD01 failures, but
        # the actionable fix differs: the wrong-level case is a one-character
        # repair, the absent case requires running Phase 5.
        m_drift = DRAFT_HEADING_ANY_LEVEL.search(text)
        if m_drift:
            actual_level = len(m_drift.group(1))
            findings.append(Finding(
                criterion_id="CR-PP-FD01",
                file=rel,
                severity="error",
                description=(
                    f"'Frontend Draft Reference' heading is at wrong heading "
                    f"level: found h{actual_level} ('"
                    f"{'#' * actual_level} Frontend Draft Reference'), must "
                    f"be h4 ('#### Frontend Draft Reference')"
                ),
                suggested_fix=(
                    f"change the heading from '{'#' * actual_level} Frontend "
                    f"Draft Reference' to '#### Frontend Draft Reference' "
                    f"(four hashes); the subsection content can stay as-is"
                ),
            ))
        else:
            findings.append(Finding(
                criterion_id="CR-PP-FD01",
                file=rel,
                severity="error",
                description=(
                    "user-facing feature is missing the '#### Frontend Draft "
                    "Reference' subsection — Phase 5 has not produced or "
                    "recorded a frontend draft for this feature"
                ),
                suggested_fix=(
                    "run Phase 5 for this feature (generate the runnable draft "
                    "under the architecture/tech-stack.md Frontend Implementation "
                    "Path, then validate the experience with the user) and add a "
                    "'#### Frontend Draft Reference' subsection with populated "
                    "'Draft path:' and 'Confirmed (experience):' lines"
                ),
            ))
        continue

    # Slice the section: from after the heading to the next markdown heading
    # (any level 1–4) or EOF.
    section_start = m_h.end()
    rest = text[section_start:]
    nh = NEXT_HEADING.search(rest)
    section = rest if nh is None else rest[:nh.start()]

    # ─── Draft path: required, must be concrete (no template placeholder) ──
    m_dp = DRAFT_PATH_LINE.search(section)
    if not m_dp:
        findings.append(Finding(
            criterion_id="CR-PP-FD01",
            file=rel,
            severity="error",
            description=(
                "'#### Frontend Draft Reference' subsection is missing the "
                "'Draft path:' line"
            ),
            suggested_fix=(
                "add a 'Draft path:' line pointing at the repo-relative "
                "directory under architecture/tech-stack.md Frontend "
                "Implementation Path where the runnable draft lives "
                "(e.g. 'frontend/src/pages/<feature-area>/')"
            ),
        ))
    else:
        dp_value = normalize(m_dp.group(1))
        if not dp_value or PLACEHOLDER_TOKENS.search(dp_value):
            findings.append(Finding(
                criterion_id="CR-PP-FD01",
                file=rel,
                severity="error",
                description=(
                    "'Draft path:' value is empty or still carries the "
                    "feature-template placeholder "
                    "(e.g. '{repo-root}/{frontend-implementation-path}/"
                    "{feature-area}/') — Phase 5 has not been run or its "
                    "output was not recorded"
                ),
                suggested_fix=(
                    "replace the placeholder with the concrete repo-relative "
                    "path of the runnable draft produced in Phase 5"
                ),
            ))

    # ─── Confirmed (experience): required, YYYY-MM-DD or null+Drift ────────
    m_cf = CONFIRMED_LINE.search(section)
    if not m_cf:
        findings.append(Finding(
            criterion_id="CR-PP-FD01",
            file=rel,
            severity="error",
            description=(
                "'#### Frontend Draft Reference' subsection is missing the "
                "'Confirmed (experience):' line"
            ),
            suggested_fix=(
                "add a 'Confirmed (experience):' line bearing the YYYY-MM-DD "
                "date the user validated the draft, or the literal 'null' "
                "with a sibling 'Drift:' line explaining the deferral"
            ),
        ))
    else:
        cf_value = normalize(m_cf.group(1))
        cf_lower = cf_value.lower()
        if cf_lower == "null":
            m_dr = DRIFT_LINE.search(section)
            drift_value = normalize(m_dr.group(1)) if m_dr else ""
            if not drift_value:
                findings.append(Finding(
                    criterion_id="CR-PP-FD01",
                    file=rel,
                    severity="error",
                    description=(
                        "'Confirmed (experience): null' MUST be paired with a "
                        "sibling 'Drift:' line stating why the experience "
                        "confirmation is deferred"
                    ),
                    suggested_fix=(
                        "add a 'Drift:' line in the same subsection "
                        "explaining why Phase 5 was deferred for this "
                        "feature (e.g. 'baseline draft predates schema "
                        "migration; will be regenerated in delivery-N+1')"
                    ),
                ))
        elif not cf_value or PLACEHOLDER_DATE.search(cf_value) or not DATE_RE.search(cf_value):
            findings.append(Finding(
                criterion_id="CR-PP-FD01",
                file=rel,
                severity="error",
                description=(
                    "'Confirmed (experience):' value is empty, still the "
                    "'{YYYY-MM-DD}' template placeholder, or not a "
                    "YYYY-MM-DD date — the user-experience confirmation has "
                    "not been recorded"
                ),
                suggested_fix=(
                    "replace with the YYYY-MM-DD date the user validated the "
                    "draft, or set to 'null' with a sibling 'Drift:' line "
                    "explaining the deferral"
                ),
            ))

emit(findings, scope_label="(features/)")
PYEOF
