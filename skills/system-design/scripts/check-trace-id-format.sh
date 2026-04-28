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

# trace_id pattern: R<digits>-<role-letter>-<3 digits>
VALID_PATTERN = re.compile(r'\btrace_id[=:\s]+R\d+-[CPWVRSJ]-\d{3}\b')
# Detect any trace_id= value at all
ANY_TRACE = re.compile(r'\btrace_id[=:\s]+(\S+)')

for fpath in sorted(files):
    rel = os.path.relpath(fpath, os.path.dirname(target) if os.path.isfile(target) else target)
    try:
        content = open(fpath, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for m in ANY_TRACE.finditer(content):
        value = m.group(1).rstrip('.,;)')
        # Check the full match in context using valid pattern
        start = max(0, m.start() - 5)
        snippet = content[start:m.end() + len(value)]
        if not VALID_PATTERN.search(content[m.start():m.end() + 20]):
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
