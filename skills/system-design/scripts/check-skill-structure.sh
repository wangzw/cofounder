#!/usr/bin/env bash
# check-skill-structure.sh — CR-S03 (directory-skeleton) + CR-S04 (subagent-file-inventory) + CR-S16 (skeleton-conformance)
# Usage: check-skill-structure.sh <target-skill-dir>
# Output contract §12.4: stdout=JSON array of issues; exit 0=pass, 1=issues, 2=error
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

TARGET="${TARGET%/}"

python3 - "$TARGET" <<'PYEOF'
import sys, json, os

target = sys.argv[1]
issues = []

# CR-S03: required directories
REQUIRED_DIRS = ["generate", "review", "revise", "shared", "common", "scripts"]
for d in REQUIRED_DIRS:
    if not os.path.isdir(os.path.join(target, d)):
        issues.append({
            "criterion_id": "CR-S03",
            "file": d + "/",
            "severity": "critical",
            "description": f"Required directory '{d}/' is missing from skill root",
            "suggested_fix": f"Create the '{d}/' directory at the skill root"
        })

# CR-S04: required sub-agent files (7 standalone; orchestrator is inline in SKILL.md)
REQUIRED_SUBAGENTS = [
    "generate/domain-consultant-subagent.md",
    "generate/planner-subagent.md",
    "generate/writer-subagent.md",
    "review/cross-reviewer-subagent.md",
    "review/adversarial-reviewer-subagent.md",
    "revise/per-issue-reviser-subagent.md",
    "shared/summarizer-subagent.md",
    "shared/judge-subagent.md",
]
for f in REQUIRED_SUBAGENTS:
    if not os.path.isfile(os.path.join(target, f)):
        issues.append({
            "criterion_id": "CR-S04",
            "file": f,
            "severity": "critical",
            "description": f"Required sub-agent prompt '{f}' is missing",
            "suggested_fix": f"Create '{f}' with the sub-agent prompt content"
        })

# CR-S16: skeleton-conformance — strict whitelist of root-level entries.
# CR-S03 verifies REQUIRED dirs exist; CR-S16 verifies NO stray files/dirs.
ROOT_ALLOWED_FILES = {"SKILL.md", "CHANGELOG.md", "README.md"}
ROOT_ALLOWED_DIRS = {
    "common", "generate", "review", "revise", "shared", "scripts", ".review"
}

def suggest_target(name: str) -> str:
    """Infer the canonical skeleton target path from a stray filename."""
    if name.endswith("-template.md") or name.endswith("-checklist.md"):
        return f"common/templates/{name}"
    if name.endswith("-subagent.md"):
        n = name.lower()
        if "writer" in n or "planner" in n or "consultant" in n:
            return f"generate/{name}"
        if "reviewer" in n:
            return f"review/{name}"
        if "reviser" in n:
            return f"revise/{name}"
        if "summarizer" in n or "judge" in n:
            return f"shared/{name}"
        return f"<role-dir>/{name}"
    if name.endswith("-mode.md"):
        base = name[: -len("-mode.md")]
        if base == "review":
            return "review/index.md"
        if base == "revise":
            return "revise/index.md"
        return f"generate/{name}"
    return f"common/{name}"

try:
    root_entries = sorted(os.listdir(target))
except OSError:
    root_entries = []

allowed_files_str = ", ".join(sorted(ROOT_ALLOWED_FILES))
allowed_dirs_str = ", ".join(sorted(ROOT_ALLOWED_DIRS))

for name in root_entries:
    full = os.path.join(target, name)
    if name.startswith("."):
        # Tolerate dotfiles/dotdirs (.gitignore, .review, .DS_Store, etc.)
        continue
    if os.path.isfile(full):
        if name in ROOT_ALLOWED_FILES:
            continue
        suggested = suggest_target(name)
        issues.append({
            "criterion_id": "CR-S16",
            "file": name,
            "severity": "error",
            "description": (
                f"Loose file '{name}' at skill root is outside the canonical "
                f"skeleton; only [{allowed_files_str}] are permitted as root-"
                f"level files."
            ),
            "suggested_fix": (
                f"Move '{name}' to '{suggested}' (or another canonical "
                f"skeleton subdirectory) and update any references."
            )
        })
    elif os.path.isdir(full):
        if name in ROOT_ALLOWED_DIRS:
            continue
        issues.append({
            "criterion_id": "CR-S16",
            "file": name + "/",
            "severity": "error",
            "description": (
                f"Unexpected directory '{name}/' at skill root; canonical "
                f"skeleton only allows [{allowed_dirs_str}]."
            ),
            "suggested_fix": (
                f"Relocate the contents of '{name}/' under one of the "
                f"canonical skeleton directories, then remove the empty "
                f"directory."
            )
        })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
