#!/usr/bin/env bash
# scaffold.sh — copy skeleton variant tree with placeholder substitution
# Usage: scaffold.sh <variant> <target-path> <clarification-yml-path>
# Variants: document, code, schema, hybrid
# Exit: 0=success, 2=error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_FORGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

VALID_VARIANTS=("document" "code" "schema" "hybrid")

usage() {
  cat <<'EOF'
Usage: scaffold.sh <variant> <target-path> <clarification-yml-path>

Copy a skeleton variant tree to <target-path> with placeholder substitution.

Arguments:
  variant               Scaffold variant: document | code | schema | hybrid
  target-path           Destination directory for the scaffolded skill
  clarification-yml-path YAML file with placeholder values from domain-consultant

Supported placeholders in skeleton files:
  prd-analysis        The name of the skill
  docs/raw/prd/     The artifact output root directory
  0.1.0     The skill version (e.g. 1.0.0)
  Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert sparse product ideas or brainstorming notes into structured self-contained PRDs optimized for AI coding agents, or evolve an existing PRD for a new iteration. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis'. The skill description (must start with "Use when")

Notes:
  - Skeletons live at <generator-skill-root>/common/skeleton/<variant>/
    (the generator is whatever meta-skill invokes this script; for skill-forge
    the root is skill-forge itself — this comment is tool-agnostic).
  - scaffold.sh exits 2 if the skeleton for the requested variant is not yet implemented
  - scaffold.sh exits 2 if target-path exists and any file drifts from the skeleton
  - scripts/metrics-aggregate.sh and scripts/lib/aggregate.py are never substituted
    (they are sha-pinned shared infrastructure)
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

VARIANT="${1:-}"
TARGET_PATH="${2:-}"
CLARIFICATION_YML="${3:-}"

if [ -z "$VARIANT" ] || [ -z "$TARGET_PATH" ] || [ -z "$CLARIFICATION_YML" ]; then
  echo "ERROR: three arguments required: variant, target-path, clarification-yml-path" >&2
  usage >&2
  exit 2
fi

# Validate variant
VALID=false
for v in "${VALID_VARIANTS[@]}"; do
  [ "$VARIANT" = "$v" ] && VALID=true && break
done
if [ "$VALID" = "false" ]; then
  echo "ERROR: unknown variant '${VARIANT}'; must be one of: ${VALID_VARIANTS[*]}" >&2
  exit 2
fi

SKELETON_DIR="${SKILL_FORGE_DIR}/common/skeleton/${VARIANT}"

# Check skeleton exists
if [ ! -d "$SKELETON_DIR" ]; then
  echo "ERROR: skeleton for variant '${VARIANT}' not yet implemented" >&2
  exit 2
fi

# Check clarification YAML exists
if [ ! -f "$CLARIFICATION_YML" ]; then
  echo "ERROR: clarification YAML not found: ${CLARIFICATION_YML}" >&2
  exit 2
fi

# Load placeholder values from clarification YAML (simple key: value parsing)
python3 - "$SKELETON_DIR" "$TARGET_PATH" "$CLARIFICATION_YML" <<'PYEOF'
import sys, os, re, hashlib, shutil

skeleton_dir = sys.argv[1]
target_path = sys.argv[2]
clarification_yml = sys.argv[3]

# No-substitute files (sha-pinned)
NO_SUBSTITUTE = {
    os.path.join('scripts', 'metrics-aggregate.sh'),
    os.path.join('scripts', 'lib', 'aggregate.py'),
}

SUPPORTED_PLACEHOLDERS = {
    'SKILL_NAME', 'ARTIFACT_ROOT', 'SKILL_VERSION', 'SKILL_DESCRIPTION'
}

def parse_yaml_simple(path):
    """Parse flat key: value YAML (no nesting, no lists)."""
    result = {}
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)', line)
            if m:
                key = m.group(1).strip()
                val = m.group(2).strip().strip('"').strip("'")
                result[key] = val
    return result

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha256_file(path):
    with open(path, 'rb') as f:
        return sha256_bytes(f.read())

def expected_target_bytes(skeleton_path, placeholders, is_sha_pinned):
    """Return the expected content of the target file after substitution."""
    raw = open(skeleton_path, 'rb').read()
    if is_sha_pinned:
        return raw
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        # Binary file — no substitution
        return raw
    for key in SUPPORTED_PLACEHOLDERS:
        placeholder = '{{' + key + '}}'
        if placeholder in text:
            text = text.replace(placeholder, placeholders.get(key, placeholder))
    return text.encode('utf-8')

def substitute_placeholders(content, values):
    """Replace {{KEY}} with values[KEY] for supported placeholders."""
    for key in SUPPORTED_PLACEHOLDERS:
        placeholder = '{{' + key + '}}'
        if placeholder in content:
            val = values.get(key, placeholder)
            content = content.replace(placeholder, val)
    return content

clarification = parse_yaml_simple(clarification_yml)

# Fail-fast on missing flat placeholder keys. The domain-consultant is
# required to emit SKILL_NAME / SKILL_VERSION / SKILL_DESCRIPTION / ARTIFACT_ROOT
# as top-level flat keys at the head of clarification.yml. If any is absent,
# the {{placeholders}} in the copied skeleton would silently remain un-substituted,
# producing a target skill with literal `prd-analysis` strings in its SKILL.md
# and review-criteria.md files.
_missing_placeholders = [p for p in SUPPORTED_PLACEHOLDERS if p not in clarification]
if _missing_placeholders:
    sys.stderr.write(
        f"ERROR: clarification YAML missing required flat placeholder keys: "
        f"{sorted(_missing_placeholders)}\n"
        f"  Consultant MUST emit these as top-level `KEY: \"value\"` lines before any nested block.\n"
        f"  See generate/domain-consultant-subagent.md output contract.\n"
    )
    sys.exit(2)

# Check if target exists — drift check
# Drift check only applies if target already holds skeleton content.
# A target that exists but contains only process state (.review/ from prepare-input /
# glossary-probe / consultant) is treated as "not yet scaffolded" and proceeds
# to the copy step. The heuristic: count how many skeleton files are already
# present in target. If zero, treat as fresh scaffold; otherwise drift-check all.
if os.path.exists(target_path):
    drift = []
    no_sub_norm = {p.replace('\\', '/') for p in NO_SUBSTITUTE}
    present_count = 0
    for dirpath, dirnames, filenames in os.walk(skeleton_dir):
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        for fname in filenames:
            skel_file = os.path.join(dirpath, fname)
            rel = os.path.relpath(skel_file, skeleton_dir)
            rel_norm = rel.replace('\\', '/')
            tgt_file = os.path.join(target_path, rel)
            if not os.path.isfile(tgt_file):
                drift.append(('MISSING', rel))
            else:
                present_count += 1
                is_sha_pinned = rel_norm in no_sub_norm
                expected = expected_target_bytes(skel_file, clarification, is_sha_pinned)
                target_bytes = open(tgt_file, 'rb').read()
                if sha256_bytes(expected) != sha256_bytes(target_bytes):
                    drift.append(('MODIFIED', rel))
    if present_count == 0:
        # Target dir exists but holds no skeleton content (only .review/ etc).
        # Fall through to copy step below.
        pass
    else:
        # Partial scaffold — report drift and abort.
        modified = [d for d in drift if d[0] == 'MODIFIED']
        missing  = [d for d in drift if d[0] == 'MISSING']
        if modified or missing:
            sys.stderr.write("ERROR: target path exists with drift from skeleton:\n")
            for kind, rel in drift:
                sys.stderr.write(f"  {kind}: {rel}\n")
            sys.exit(2)
        print(f"OK target already matches skeleton: {target_path}")
        sys.exit(0)

# Copy skeleton to target. shutil.copytree refuses if target exists, so when
# target is pre-existing with only process state (present_count == 0 branch),
# we copy file-by-file instead of using copytree.
if os.path.exists(target_path):
    for dirpath, dirnames, filenames in os.walk(skeleton_dir):
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        rel_dir = os.path.relpath(dirpath, skeleton_dir)
        tgt_dir = target_path if rel_dir == '.' else os.path.join(target_path, rel_dir)
        os.makedirs(tgt_dir, exist_ok=True)
        for fname in filenames:
            shutil.copy2(os.path.join(dirpath, fname), os.path.join(tgt_dir, fname))
else:
    shutil.copytree(skeleton_dir, target_path)

# Substitute placeholders
for dirpath, dirnames, filenames in os.walk(target_path):
    dirnames[:] = [d for d in dirnames if not d.startswith('.')]
    for fname in filenames:
        fpath = os.path.join(dirpath, fname)
        rel = os.path.relpath(fpath, target_path)
        # Normalize path separators for comparison
        rel_norm = rel.replace('\\', '/')
        if rel_norm in {p.replace('\\', '/') for p in NO_SUBSTITUTE}:
            continue
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                content = f.read()
            new_content = substitute_placeholders(content, clarification)
            if new_content != content:
                with open(fpath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
        except (UnicodeDecodeError, OSError):
            # Binary file — skip substitution
            pass

# Write scaffold-provenance manifest. Records the sha256 of every file we just
# scaffolded (post-substitution). run-checkers.sh Phase A reads this to decide
# which leaves are "still pure scaffold" vs "writer-authored" — files whose
# current sha matches the manifest are auto-added to cross_reviewer_skip so
# the LLM cross-reviewer doesn't waste tokens re-auditing unchanged boilerplate.
provenance_lines = [
    "# Auto-generated by scaffold.sh — DO NOT edit by hand.",
    "# Records post-substitution sha256 of every scaffolded file. Consumed by",
    "# run-checkers.sh Phase A: files whose current sha matches are marked",
    "# provenance=scaffold and default into cross_reviewer_skip. Writer /",
    "# reviser dispatches mutate a file → sha drifts → provenance=authored →",
    "# file re-enters cross_reviewer_focus automatically.",
    "files:",
]
for dirpath, dirnames, filenames in os.walk(target_path):
    dirnames[:] = [d for d in dirnames if not d.startswith('.')]
    for fname in sorted(filenames):
        fpath = os.path.join(dirpath, fname)
        rel = os.path.relpath(fpath, target_path).replace('\\', '/')
        if rel == "common/scaffold-provenance.yml":
            continue  # we are writing this
        try:
            sha = sha256_file(fpath)
        except OSError:
            continue
        provenance_lines.append(f"  {rel}: {sha}")
provenance_path = os.path.join(target_path, "common", "scaffold-provenance.yml")
os.makedirs(os.path.dirname(provenance_path), exist_ok=True)
with open(provenance_path, "w", encoding="utf-8") as f:
    f.write("\n".join(provenance_lines) + "\n")

print(f"OK scaffolded: {target_path}")
PYEOF
