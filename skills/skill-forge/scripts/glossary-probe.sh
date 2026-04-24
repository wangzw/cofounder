#!/usr/bin/env bash
# glossary-probe.sh — Round 0 glossary probe per guide §6.2
# Usage: glossary-probe.sh <review-dir> <glossary-path>
#   <review-dir>:    the .review/ root (must already have round-0/input.md + input-meta.yml)
#   <glossary-path>: path to common/domain-glossary.md
# Produces:
#   <review-dir>/round-0/trigger-flags.yml
# No external packages — stdlib only.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: glossary-probe.sh <review-dir> <glossary-path>" >&2
  exit 1
fi

REVIEW_DIR="$1"
GLOSSARY_PATH="$2"

python3 - "$REVIEW_DIR" "$GLOSSARY_PATH" <<'PYEOF'
import sys
import re
import pathlib
import datetime

review_dir    = pathlib.Path(sys.argv[1])
glossary_path = pathlib.Path(sys.argv[2])

round0_dir        = review_dir / "round-0"
input_md_path     = round0_dir / "input.md"
meta_yml_path     = round0_dir / "input-meta.yml"
trigger_yml_path  = round0_dir / "trigger-flags.yml"

# ── 1. Extract User Prompt section from input.md ────────────────────────────
input_md = input_md_path.read_text(encoding="utf-8")

# Grab everything between "# User Prompt" and the next "# " heading
user_prompt_body = ""
m = re.search(
    r'^# User Prompt\s*\n(.*?)(?=^# |\Z)',
    input_md, re.MULTILINE | re.DOTALL
)
if m:
    user_prompt_body = m.group(1).strip()

prompt_lines = user_prompt_body.splitlines()

# ── 2. Parse input-meta.yml (hand-rolled, no pyyaml) ───────────────────────
meta_text = meta_yml_path.read_text(encoding="utf-8")

def parse_yml_scalar(text, key):
    """Return raw string value for a simple scalar key: value line."""
    m = re.search(rf'^{re.escape(key)}:\s*(.+)$', text, re.MULTILINE)
    return m.group(1).strip().strip('"') if m else None

word_count_str      = parse_yml_scalar(meta_text, "word_count")
has_code_str        = parse_yml_scalar(meta_text, "has_code_block")
has_structured_str  = parse_yml_scalar(meta_text, "has_structured_lists")

word_count      = int(word_count_str) if word_count_str and word_count_str.isdigit() else 0
has_code_block  = (has_code_str == "true")
has_structured  = (has_structured_str == "true")

# ── 3. Parse glossary for disambiguation_required entries ───────────────────
glossary_text = glossary_path.read_text(encoding="utf-8")

# Collect all ```yaml ... ``` blocks
yaml_blocks = re.findall(r'```yaml\s*(.*?)```', glossary_text, re.DOTALL)

entries = []  # list of {"term": str, "aliases": [str]}

for block in yaml_blocks:
    # Split into individual items (lines starting with "- term:")
    items = re.split(r'(?=^- term:)', block, flags=re.MULTILINE)
    for item in items:
        if 'disambiguation_required: true' not in item:
            continue
        term_m = re.search(r'^  term:\s*"([^"]+)"', item, re.MULTILINE)
        if not term_m:
            term_m = re.search(r"^  term:\s*'([^']+)'", item, re.MULTILINE)
        if not term_m:
            term_m = re.search(r'^- term:\s*"([^"]+)"', item, re.MULTILINE)
        if not term_m:
            term_m = re.search(r'^- term:\s*([^\n\[]+)', item, re.MULTILINE)
        if not term_m:
            continue
        term = term_m.group(1).strip().strip('"\'')

        aliases = []
        aliases_m = re.search(r'aliases:\s*\[([^\]]*)\]', item, re.DOTALL)
        if aliases_m:
            raw = aliases_m.group(1)
            aliases = [a.strip().strip('"\'') for a in raw.split(',') if a.strip()]

        entries.append({"term": term, "aliases": aliases})

# ── 4. Grep User Prompt body for each term/alias ────────────────────────────
def is_ascii(s):
    try:
        s.encode('ascii')
        return True
    except UnicodeEncodeError:
        return False

def match_term_in_lines(t, lines):
    """Return list of (1-indexed line number, matched_string) for term t."""
    results = []
    if is_ascii(t):
        pattern = re.compile(r'\b' + re.escape(t) + r'\b', re.IGNORECASE)
    else:
        pattern = re.compile(re.escape(t), re.IGNORECASE)
    for idx, line in enumerate(lines, start=1):
        if pattern.search(line):
            results.append(idx)
    return results

hit_records = []  # list of dicts for YAML output

for entry in entries:
    term    = entry["term"]
    aliases = entry["aliases"]

    # Check primary term first
    primary_hits = match_term_in_lines(term, prompt_lines)
    for line_no in primary_hits:
        hit_records.append({"term": term, "line": line_no, "alias_matched": None})

    # Check aliases
    for alias in aliases:
        alias_hits = match_term_in_lines(alias, prompt_lines)
        for line_no in alias_hits:
            hit_records.append({"term": term, "line": line_no, "alias_matched": alias})

# Deduplicate by (term, line)
seen = set()
deduped = []
for r in hit_records:
    key = (r["term"], r["line"])
    if key not in seen:
        seen.add(key)
        deduped.append(r)
hit_records = deduped

glossary_hit = len(hit_records) > 0

# ── 5. Compute sparse_input ─────────────────────────────────────────────────
sparse_input  = (word_count < 15) and (not has_code_block) and (not has_structured)
sparse_reason = f"word_count={word_count} < 15" if sparse_input else None

# ── 6. Write trigger-flags.yml ──────────────────────────────────────────────
generated_at = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

def bool_str(b):
    return "true" if b else "false"

lines_out = [
    f'generated_at: "{generated_at}"',
    f'glossary_hit: {bool_str(glossary_hit)}',
    'hit_terms:',
]

if hit_records:
    for r in hit_records:
        lines_out.append(f'  - term: "{r["term"]}"')
        lines_out.append(f'    line: {r["line"]}')
        if r["alias_matched"] is not None:
            lines_out.append(f'    alias_matched: "{r["alias_matched"]}"')
else:
    lines_out[-1] = 'hit_terms: []'

lines_out.append(f'sparse_input: {bool_str(sparse_input)}')
if sparse_reason is not None:
    lines_out.append(f'sparse_reason: "{sparse_reason}"')
else:
    lines_out.append('sparse_reason: null')

trigger_yml_path.write_text("\n".join(lines_out) + "\n", encoding="utf-8")

print(f"OK trigger-flags written to {trigger_yml_path}")
PYEOF
