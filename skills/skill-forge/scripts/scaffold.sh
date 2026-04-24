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
  {{SKILL_NAME}}        The name of the skill
  {{ARTIFACT_ROOT}}     The artifact output root directory
  {{SKILL_VERSION}}     The skill version (e.g. 1.0.0)
  {{SKILL_DESCRIPTION}} The skill description (must start with "Use when")

Notes:
  - Skeletons live at skills/skill-forge/common/skeleton/<variant>/
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

# Check if target exists — drift check
if os.path.exists(target_path):
    drift = []
    no_sub_norm = {p.replace('\\', '/') for p in NO_SUBSTITUTE}
    for dirpath, dirnames, filenames in os.walk(skeleton_dir):
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        for fname in filenames:
            skel_file = os.path.join(dirpath, fname)
            rel = os.path.relpath(skel_file, skeleton_dir)
            rel_norm = rel.replace('\\', '/')
            tgt_file = os.path.join(target_path, rel)
            if not os.path.isfile(tgt_file):
                drift.append(f"MISSING: {rel}")
            else:
                is_sha_pinned = rel_norm in no_sub_norm
                expected = expected_target_bytes(skel_file, clarification, is_sha_pinned)
                target_bytes = open(tgt_file, 'rb').read()
                if sha256_bytes(expected) != sha256_bytes(target_bytes):
                    drift.append(f"MODIFIED: {rel}")
    if drift:
        sys.stderr.write("ERROR: target path exists with drift from skeleton:\n")
        for d in drift:
            sys.stderr.write(f"  {d}\n")
        sys.exit(2)
    print(f"OK target already matches skeleton: {target_path}")
    sys.exit(0)

# Copy skeleton to target
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

print(f"OK scaffolded: {target_path}")
PYEOF
