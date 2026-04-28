#!/usr/bin/env bash
# check-skill-md-sections.sh — CR-S15 skill-md-cost-control-sections
# Verifies the target's SKILL.md includes the cost-control sections that
# orchestrator-facing documentation requires. The skill-md-template.md bakes
# these in as canonical boilerplate; this checker enforces that the writer
# did not silently skip them when authoring the target's SKILL.md.
#
# Usage: check-skill-md-sections.sh <target-skill-dir>
# Output contract §12.4: stdout = JSON array; exit 0=pass, 1=issues, 2=error.
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

SKILL_MD="${TARGET%/}/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
  cat <<EOF
[
  {
    "criterion_id": "CR-S15",
    "file": "SKILL.md",
    "severity": "error",
    "description": "SKILL.md not found at target root",
    "suggested_fix": "scaffold.sh should have copied skill-md-template.md to SKILL.md; re-run scaffold or have writer author SKILL.md per common/templates/skill-md-template.md"
  }
]
EOF
  exit 1
fi

python3 - "$SKILL_MD" <<'PYEOF'
import sys, json, re

skill_md_path = sys.argv[1]
text = open(skill_md_path, encoding="utf-8").read()
issues = []

# ── Required section anchors (regex; match anywhere) ──
checks = [
    {
        "name": "model-tiers-section",
        "pattern": r'(?m)^##\s+Model Tiers\b',
        "description": (
            "SKILL.md missing top-level `## Model Tiers` section — required to anchor "
            "the per-dispatch model-override guidance below it."
        ),
        "fix": (
            "Add `## Model Tiers` section per common/templates/skill-md-template.md. "
            "It introduces the abstract tier vocabulary (heavy/balanced/light) and "
            "references config.yml's model_tier_defaults + model_mapping."
        ),
    },
    {
        "name": "per-dispatch-model-override-subsection",
        "pattern": r'(?im)^###\s+Per[- ]dispatch model override\b',
        "description": (
            "SKILL.md missing `### Per-dispatch model override` subsection — without "
            "this, orchestrators don't know to pass the Agent-tool `model` parameter "
            "explicitly and sub-agents inherit the parent session's opus tier "
            "(5–25× the configured tier rate)."
        ),
        "fix": (
            "Add the `### Per-dispatch model override` subsection from "
            "common/templates/skill-md-template.md verbatim, including the role→tier "
            "mapping table (domain-consultant/planner/reviewer → opus, writer/reviser → "
            "sonnet, summarizer/judge → haiku)."
        ),
    },
    {
        "name": "model-override-role-table",
        "pattern": r'(?is)Per[- ]dispatch model override.*?\|\s*Role\s*\|\s*Default tier\s*\|\s*Agent[- ]tool\s+`?model`?\s+value',
        "description": (
            "Per-dispatch model override section is present but missing the canonical "
            "role→tier→Agent-tool-model mapping table. Without the explicit table, "
            "orchestrators have no contract to follow."
        ),
        "fix": (
            "Insert the 7-row table from common/templates/skill-md-template.md mapping "
            "every role (domain-consultant, planner, writer, reviewer, reviser, "
            "summarizer, judge) to its default tier and the corresponding Agent-tool "
            "`model` value (\"opus\" / \"sonnet\" / \"haiku\")."
        ),
    },
    {
        "name": "cli-flags-section",
        "pattern": r'(?m)^##\s+CLI Flags\b',
        "description": (
            "SKILL.md missing `## CLI Flags` section — without it, users cannot "
            "discover cost-shedding flags like `--no-consultant`, `--tier`, "
            "`--max-iterations`, or `--full`."
        ),
        "fix": (
            "Add `## CLI Flags` section per common/templates/skill-md-template.md, "
            "including at minimum these rows: `--full`, `--interactive`, "
            "`--no-consultant`, `--force-continue`, `--tier <role>=<tier>`, "
            "`--max-iterations N`."
        ),
    },
]

for check in checks:
    if not re.search(check["pattern"], text):
        issues.append({
            "criterion_id": "CR-S15",
            "file": "SKILL.md",
            "severity": "error",
            "description": check["description"],
            "suggested_fix": check["fix"],
            "subcheck": check["name"],
        })

# ── CLI Flags table required-rows check (only if section is present) ──
cli_section_present = bool(re.search(r'(?m)^##\s+CLI Flags\b', text))
if cli_section_present:
    # Extract the section body (everything from "## CLI Flags" until the next "## ")
    m = re.search(r'(?m)^##\s+CLI Flags\b(.*?)(?=^##\s+|\Z)', text, re.DOTALL)
    section_body = m.group(1) if m else ""
    required_flags = [
        "--full",
        "--no-consultant",
        "--tier",
        "--max-iterations",
    ]
    missing = []
    for flag in required_flags:
        # Match the flag inside backticks (typical markdown table cell shape).
        # Tolerate either `--no-consultant` or `--no-consultant <foo>` as long as the
        # flag literal appears in a backtick-quoted form within the section.
        if not re.search(r'`' + re.escape(flag) + r'\b', section_body):
            missing.append(flag)
    if missing:
        issues.append({
            "criterion_id": "CR-S15",
            "file": "SKILL.md",
            "severity": "error",
            "description": (
                f"CLI Flags table missing required rows: {', '.join(missing)}. These "
                f"flags govern cost-shedding behavior and must be discoverable."
            ),
            "suggested_fix": (
                "Add a row per missing flag to the CLI Flags table; copy semantics "
                "from common/templates/skill-md-template.md."
            ),
            "subcheck": "cli-flags-required-rows",
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
