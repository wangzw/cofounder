#!/usr/bin/env bash
# check-config-schema.sh — CR-S06 (config-schema) + CR-S11 (tool-permissions-coverage)
# Usage: check-config-schema.sh <target-skill-dir>
# Verifies common/config.yml has all required top-level keys + correct tool_permissions block.
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues, 2=error
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

python3 - "$TARGET" <<'PYEOF'
import sys, json, os, re

target = sys.argv[1]
issues = []

config_path = os.path.join(target, "common", "config.yml")
if not os.path.isfile(config_path):
    issues.append({
        "criterion_id": "CR-S06",
        "file": "common/config.yml",
        "severity": "error",
        "description": "common/config.yml not found",
        "suggested_fix": "Create common/config.yml with all required top-level keys"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

try:
    content = open(config_path, encoding="utf-8").read()
except OSError as e:
    issues.append({
        "criterion_id": "CR-S06",
        "file": "common/config.yml",
        "severity": "error",
        "description": f"Cannot read common/config.yml: {e}",
        "suggested_fix": "Ensure file is readable"
    })
    print(json.dumps(issues, indent=2))
    sys.exit(1)

# CR-S06: check all required top-level keys (§21.2 — derived from skill-forge reference config)
REQUIRED_KEYS = [
    "skill_version", "review_criteria_version", "artifact_template_version",
    "convergence", "model_tier_defaults", "model_mapping", "pricing",
    "priority_order", "adversarial_review", "domain_consultant",
    "delivery_commit", "retention", "regression_gate", "retry_policy",
    "partial_failure_policy", "hitl", "tool_permissions", "incremental_review",
]
present_keys = set(re.findall(r'^([a-z][a-z0-9_]+)\s*:', content, re.MULTILINE))
for key in REQUIRED_KEYS:
    if key not in present_keys:
        issues.append({
            "criterion_id": "CR-S06",
            "file": "common/config.yml",
            "severity": "error",
            "description": f"Required top-level key '{key}' missing from config.yml",
            "suggested_fix": f"Add '{key}:' section to common/config.yml per §21.2"
        })

# CR-S11: tool_permissions must list all 8 roles
REQUIRED_ROLES = [
    "orchestrator", "domain_consultant", "planner", "writer",
    "reviewer", "reviser", "summarizer", "judge"
]
# Find tool_permissions block (from key to next top-level key or EOF)
tp_match = re.search(r'^tool_permissions\s*:\s*\n((?:[ \t]+.*\n)*)', content, re.MULTILINE)
if tp_match:
    tp_block = tp_match.group(1)
    for role in REQUIRED_ROLES:
        if not re.search(rf'^\s+{role}\s*:', tp_block, re.MULTILINE):
            issues.append({
                "criterion_id": "CR-S11",
                "file": "common/config.yml",
                "severity": "error",
                "description": f"Role '{role}' missing from tool_permissions block",
                "suggested_fix": f"Add '{role}:' entry to tool_permissions in config.yml"
            })
    # user-interaction: true must only appear on domain_consultant
    for role in REQUIRED_ROLES:
        role_match = re.search(
            rf'^\s+{role}\s*:.*?(?=^\s+\w|\Z)', tp_block, re.MULTILINE | re.DOTALL
        )
        if role_match:
            role_text = role_match.group(0)
            if "user-interaction: true" in role_text and role != "domain_consultant":
                issues.append({
                    "criterion_id": "CR-S11",
                    "file": "common/config.yml",
                    "severity": "error",
                    "description": f"Role '{role}' has user-interaction: true — only domain_consultant may have this",
                    "suggested_fix": f"Set user-interaction: false for '{role}' in tool_permissions"
                })
    if "user-interaction: true" not in tp_block:
        issues.append({
            "criterion_id": "CR-S11",
            "file": "common/config.yml",
            "severity": "error",
            "description": "domain_consultant must have user-interaction: true but none found in tool_permissions",
            "suggested_fix": "Add 'user-interaction: true' to domain_consultant in tool_permissions"
        })
else:
    if "tool_permissions" not in present_keys:
        pass  # already caught by CR-S06
    else:
        issues.append({
            "criterion_id": "CR-S11",
            "file": "common/config.yml",
            "severity": "error",
            "description": "tool_permissions block is empty or unparseable",
            "suggested_fix": "Define all 8 roles under tool_permissions"
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
