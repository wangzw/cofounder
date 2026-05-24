#!/usr/bin/env bash
# migrate-issues-add-category.sh — one-time backfill: add category: field
# to every legacy issue file under .review/round-*/issues/. The category is
# looked up from common/review-criteria.md by criterion_id.
#
# Idempotent — re-running on already-migrated issues is a no-op.
#
# Usage: migrate-issues-add-category.sh <artifact-root>
# Exit codes: 0 OK; 2 script error

set -euo pipefail

ART="${1:-}"
if [ -z "$ART" ] || [ ! -d "$ART" ]; then
  echo "Usage: $0 <artifact-root>" >&2
  exit 2
fi
ART="${ART%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$ART" "$SKILL_ROOT/common/review-criteria.md" <<'PYEOF'
import os, re, sys, glob

art, crit_path = sys.argv[1], sys.argv[2]

if not os.path.isfile(crit_path):
    print(f"ERROR: review-criteria.md not found: {crit_path}", file=sys.stderr)
    sys.exit(2)

# Build CR -> category map (LLM-type only)
crit_text = open(crit_path).read()
cr_to_cat: dict[str, str] = {}
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
    cm = re.search(r"^\s+category:\s*([a-z0-9-]+)\s*$", body, re.M)
    if cm:
        cr_to_cat[crid] = cm.group(1)

migrated = 0
warnings = 0
already = 0
for path in sorted(glob.glob(os.path.join(art, ".review", "round-*", "issues", "*.md"))):
    text = open(path).read()
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        continue
    fm = m.group(1)
    crid_m = re.search(r"^criterion_id:\s*(CR-[A-Za-z0-9-]+)", fm, re.M)
    if not crid_m:
        continue
    crid = crid_m.group(1)
    if re.search(r"^category:", fm, re.M):
        already += 1
        continue
    cat = cr_to_cat.get(crid)
    if cat is None:
        print(f"WARNING: {os.path.relpath(path, art)} has unknown criterion_id {crid}; skipping")
        warnings += 1
        continue
    new_fm = re.sub(
        r"^(criterion_id:\s*CR-[A-Za-z0-9-]+)\s*$",
        rf"\1\ncategory: {cat}",
        fm, count=1, flags=re.M)
    new_text = text.replace(fm, new_fm, 1)
    open(path, "w").write(new_text)
    migrated += 1

print(f"PASS: migrated {migrated} issue file(s), {already} already migrated, {warnings} warning(s)")
PYEOF
