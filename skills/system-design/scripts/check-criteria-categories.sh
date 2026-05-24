#!/usr/bin/env bash
# check-criteria-categories.sh — verify consistency between
# common/criterion-categories.md and common/review-criteria.md:
#   - Every checker_type: llm CR in review-criteria.md has a category: field
#   - Every category: value appears in criterion-categories.md as a heading
#   - Every CR-ID listed under a category in criterion-categories.md exists in
#     review-criteria.md as an LLM-type CR
#
# Usage: check-criteria-categories.sh <common-dir>
# Exit codes: 0 PASS; 1 inconsistency found; 2 script error

set -euo pipefail

COMMON_DIR="${1:-}"
if [ -z "$COMMON_DIR" ] || [ ! -d "$COMMON_DIR" ]; then
  echo "Usage: $0 <common-dir>" >&2
  exit 2
fi
CATS="$COMMON_DIR/criterion-categories.md"
CRIT="$COMMON_DIR/review-criteria.md"
for f in "$CATS" "$CRIT"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: not found: $f" >&2
    exit 2
  fi
done

python3 - "$CATS" "$CRIT" <<'PYEOF'
import re, sys
cats_path, crit_path = sys.argv[1], sys.argv[2]

cats_text = open(cats_path).read()
crit_text = open(crit_path).read()

# Parse categories: ### `name` headers + their CR-ID lists
cat_to_crs: dict[str, set[str]] = {}
current = None
for line in cats_text.splitlines():
    m = re.match(r"^###\s+`([a-z0-9-]+)`", line)
    if m:
        current = m.group(1)
        cat_to_crs[current] = set()
        continue
    if current and "Included CR-IDs:" in line:
        for cr in re.findall(r"`(CR-[A-Za-z0-9-]+)`", line):
            cat_to_crs[current].add(cr)

cat_names = set(cat_to_crs.keys())

# Parse criteria: YAML blocks under `- id:` lines
failures: list[str] = []
seen_llm: set[str] = set()
for m in re.finditer(r"^- id:\s*(CR-[A-Za-z0-9-]+)$", crit_text, re.M):
    crid = m.group(1)
    rest = crit_text[m.end():m.end()+2000]
    body_lines: list[str] = []
    for line in rest.split("\n"):
        if line.startswith("  ") or (line == "" and not body_lines):
            body_lines.append(line)
        else:
            break
    body = "\n".join(body_lines)
    if "checker_type: llm" not in body:
        continue
    seen_llm.add(crid)
    cat_m = re.search(r"^\s+category:\s*([a-z0-9-]+)\s*$", body, re.M)
    if not cat_m:
        failures.append(f"FAIL: {crid} is checker_type: llm but has no category field — missing category")
        continue
    cat_val = cat_m.group(1)
    if cat_val not in cat_names:
        failures.append(f"FAIL: {crid} has category: {cat_val} which is not defined in criterion-categories.md (known: {sorted(cat_names)})")

# Every CR listed in a category must exist as an LLM CR
for cat, crs in cat_to_crs.items():
    for cr in crs:
        if cr not in seen_llm:
            failures.append(f"FAIL: category `{cat}` lists `{cr}` but no LLM CR with that id exists in review-criteria.md")

if failures:
    for f in failures:
        print(f)
    sys.exit(1)
print(f"PASS: {len(seen_llm)} LLM CRs cross-checked against {len(cat_names)} categories")
PYEOF
