#!/usr/bin/env bash
# sd_emit.sh — shared §9 emitter for cross-bundle linters.
#
# Cross-bundle scripts (architecture-coverage, analytics-coverage, dependency-
# layering, placeholder-json, readme-references, single-source-of-truth)
# accumulate findings into a comma-separated `$JSON_FINDINGS` shell variable
# whose objects use a pre-§9 vocabulary (criterion ids `CR-X3/X4/X6/L2/X7/X8`,
# severities `blocker/mechanical`).  This helper normalises that vocabulary
# to the canonical `CR-SD14..19` ids and `sd_lint.py` severity values, then
# emits the conformant `PASS … / FOUND … {"issues":[…]}` format and exits
# the process with the §9 status code.
#
# Usage at the END of a cross-bundle script:
#
#     SCOPE_LABEL="(check-X)"
#     SD_LEGACY_FINDINGS="$JSON_FINDINGS" exec bash "$SCRIPT_DIR/lib/sd_emit.sh" "$SCOPE_LABEL"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE="${1-}"

python3 - "$SCRIPT_DIR" "$SCOPE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, sys.argv[1])
from sd_lint import Finding, emit

scope = sys.argv[2]
raw = os.environ.get("SD_LEGACY_FINDINGS", "").strip()
if not raw:
    objs = []
else:
    try:
        objs = json.loads("[" + raw + "]")
    except json.JSONDecodeError as e:
        print(f"ERROR: legacy JSON_FINDINGS could not be parsed: {e}", file=sys.stderr)
        sys.exit(2)

CR_MAP = {
    "CR-X3": "CR-SD14",
    "CR-X4": "CR-SD15",
    "CR-X6": "CR-SD16",
    "CR-L2": "CR-SD17",
    "CR-X8": "CR-SD18",
    "CR-X7": "CR-SD19",
}
SEV_MAP = {
    "blocker": "error",
    "mechanical": "warning",
    "critical": "critical",
    "error": "error",
    "warning": "warning",
    "info": "info",
}

findings = []
for o in objs:
    cid = CR_MAP.get(o.get("criterion_id", ""), o.get("criterion_id", ""))
    sev = SEV_MAP.get(o.get("severity", "error"), "error")
    desc = (o.get("description") or "").strip() or "issue (legacy script provided no description)"
    fix = (o.get("suggested_fix") or "").strip() or "see script output for context"
    findings.append(Finding(
        criterion_id=cid,
        file=o.get("file", "?"),
        severity=sev,
        description=desc,
        suggested_fix=fix,
    ))
emit(findings, scope_label=scope)
PYEOF
