#!/usr/bin/env bash
# check-trace-id-format.sh — CR-S10 (trace-id-format)
# Usage: check-trace-id-format.sh <file-or-dir>
# Scans .md files for trace_id occurrences and validates format R<digits>-[CPWVRSJ]-<3 digits>.
# Output contract §12.4: stdout=JSON array; exit 0=pass, 1=issues, 2=error
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target file or dir required" >&2
  exit 2
fi

if [ ! -e "$TARGET" ]; then
  echo "[]" >&2
  echo "ERROR: target not found: ${TARGET}" >&2
  exit 2
fi

python3 - "$TARGET" <<'PYEOF'
import sys, json, os, re

target = sys.argv[1]
issues = []

# Collect files to scan
if os.path.isfile(target):
    files = [target]
else:
    files = []
    for root, dirs, fnames in os.walk(target):
        for fn in fnames:
            if fn.endswith(".md") or fn.endswith(".yml") or fn.endswith(".yaml"):
                files.append(os.path.join(root, fn))

# Real trace_id values match this strict pattern: R<digits>-<role-letter>-<3 digits>
VALID_RE = re.compile(r'^R\d+-[CPWVRSJ]-\d{3}$')
# Detect a trace_id assignment — `=` or `:` separator only (whitespace alone is prose,
# e.g. "trace_id strings" or "in trace_id" sentences, NOT a literal value).
ANY_TRACE = re.compile(r'\btrace_id\s*[=:]\s*(\S+)')
# Marker chars that indicate the captured token is a placeholder / format-doc / markdown
# fragment, not a real trace_id literal we should validate.
PLACEHOLDER_CHARS = set('<>{}[]()')


def is_placeholder(value: str) -> bool:
    """Return True if `value` is doc syntax (placeholder, format hint, markdown fragment),
    False if it looks like a real trace_id literal we should validate against VALID_RE."""
    # Strip surrounding markdown/quote punctuation that isn't part of the value
    stripped = value.strip('`"\',.;:)')
    if not stripped:
        return True
    # Angle/curly/square/round-bracket placeholders: <id>, {trace_id}, [id], (id)
    if any(c in stripped for c in PLACEHOLDER_CHARS):
        return True
    return False


for fpath in sorted(files):
    rel = os.path.relpath(fpath, os.path.dirname(target) if os.path.isfile(target) else target)
    try:
        content = open(fpath, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for m in ANY_TRACE.finditer(content):
        raw = m.group(1)
        value = raw.strip('`"\',.;:)')
        if is_placeholder(raw):
            continue
        if not VALID_RE.match(value):
            issues.append({
                "criterion_id": "CR-S10",
                "file": rel,
                "severity": "error",
                "description": f"Malformed trace_id value '{value}' — expected R<digits>-[CPWVRSJ]-<3 digits>",
                "suggested_fix": "Use format R<N>-<role-letter>-<nnn> e.g. R3-W-007"
            })

print(json.dumps(issues, indent=2))
sys.exit(1 if issues else 0)
PYEOF
