#!/usr/bin/env bash
# prepare-input.sh — Round 0 input preparation per guide §6.1
# Usage: prepare-input.sh [--bootstrap-subdir <subdir>] <user-prompt> <review-dir>
#   <user-prompt>:              raw prompt string, or '-' to read from stdin
#   <review-dir>:               the .review/ root of the target skill
#   --bootstrap-subdir <name>:  subdir under <review-dir> to write input.md +
#                               input-meta.yml into (default: "round-0"). For
#                               new-version delivery-N bootstrap, orchestrator
#                               should pass the starting round of that delivery
#                               (e.g. "round-5") so delivery-1's round-0 archive
#                               is preserved. Guide §10.5 round continuity + §6.1
#                               Round-0 semantics bridged by this flag. (F8 fix)
# Produces:
#   <review-dir>/<bootstrap-subdir>/input.md
#   <review-dir>/<bootstrap-subdir>/input-meta.yml
# No external packages — stdlib only (re, urllib, pathlib, datetime).
set -euo pipefail

BOOTSTRAP_SUBDIR="round-0"
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --bootstrap-subdir) BOOTSTRAP_SUBDIR="$2"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# No external/p' "$0" | sed 's/^# //'
      exit 0
      ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

if [ $# -lt 2 ]; then
  echo "Usage: prepare-input.sh [--bootstrap-subdir <subdir>] <user-prompt|--> <review-dir>" >&2
  exit 1
fi

USER_PROMPT="$1"
REVIEW_DIR="$2"

# Read from stdin if '-' passed
if [ "$USER_PROMPT" = "-" ]; then
  USER_PROMPT="$(cat)"
fi

# CWD at time of invocation — used for @path resolution
INVOKE_CWD="$(pwd)"

python3 - "$USER_PROMPT" "$REVIEW_DIR" "$INVOKE_CWD" "$BOOTSTRAP_SUBDIR" <<'PYEOF'
import sys
import os
import re
import subprocess
import datetime
import pathlib

prompt_text     = sys.argv[1]
review_dir      = sys.argv[2]
invoke_cwd      = sys.argv[3]
bootstrap_subdir = sys.argv[4]

bootstrap_dir = pathlib.Path(review_dir) / bootstrap_subdir
bootstrap_dir.mkdir(parents=True, exist_ok=True)

input_md_path   = bootstrap_dir / "input.md"
meta_yml_path   = bootstrap_dir / "input-meta.yml"

# ── 1. Find @path refs and http(s):// URLs ──────────────────────────────────
# @path: must start with alnum/_, then legal filesystem chars. Stops at punctuation
# like `)`, `,`, `;` so "See @notes.md." and "use @foo.md)" both match `notes.md` / `foo.md`.
path_refs = re.findall(r'@([A-Za-z0-9_][A-Za-z0-9._/\-]*)', prompt_text)
# URLs: strip trailing punctuation that's commonly adjacent to URLs in prose
url_refs  = [u.rstrip(').,;:!?\'"') for u in re.findall(r'https?://\S+', prompt_text)]

# ── 2. Expand references ────────────────────────────────────────────────────
expanded_sections = []
expanded_count    = 0
fetch_errors      = []

MAX_FETCH_BYTES = 50 * 1024  # 50 KB

for ref in path_refs:
    heading = f"## @{ref}"
    full_path = pathlib.Path(invoke_cwd) / ref
    if full_path.exists():
        content = full_path.read_text(encoding="utf-8", errors="replace")
        expanded_sections.append(f"{heading}\n\n{content.rstrip()}")
        expanded_count += 1
    else:
        expanded_sections.append(f"{heading}\n\n(file not found: {ref})")
        fetch_errors.append(f"@{ref}")

for url in url_refs:
    heading = f"## {url}"
    try:
        result = subprocess.run(
            ["curl", "-sSL", "--max-time", "10", url],
            capture_output=True, timeout=15
        )
        if result.returncode == 0:
            body = result.stdout[:MAX_FETCH_BYTES].decode("utf-8", errors="replace")
            expanded_sections.append(f"{heading}\n\n{body.rstrip()}")
            expanded_count += 1
        else:
            err_msg = result.stderr.decode("utf-8", errors="replace").strip()
            expanded_sections.append(f"{heading}\n\n(fetch error: {err_msg or 'non-zero exit'})")
            fetch_errors.append(url)
    except Exception as exc:
        expanded_sections.append(f"{heading}\n\n(fetch error: {exc})")
        fetch_errors.append(url)

# ── 3. Write input.md ───────────────────────────────────────────────────────
expanded_block = "\n\n".join(expanded_sections) if expanded_sections else "(none)"

input_md_content = f"# User Prompt\n\n{prompt_text}\n\n# Expanded References\n\n{expanded_block}\n"
input_md_path.write_text(input_md_content, encoding="utf-8")

# ── 4. Compute meta fields ──────────────────────────────────────────────────
word_count        = len(prompt_text.split())
has_code_block    = "```" in prompt_text
has_structured    = bool(re.search(r'\n[-*] |\n\d+\. ', "\n" + prompt_text))
generated_at      = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ── 5. Write input-meta.yml ─────────────────────────────────────────────────
def bool_str(b):
    return "true" if b else "false"

def yaml_str(s):
    """Escape a string for embedding in a YAML double-quoted scalar."""
    return s.replace("\\", "\\\\").replace('"', '\\"')

fetch_errors_yaml = "[]" if not fetch_errors else (
    "\n" + "".join(f'  - "{yaml_str(e)}"\n' for e in fetch_errors)
)

meta_yml = (
    f"generated_at: \"{generated_at}\"\n"
    f"word_count: {word_count}\n"
    f"has_code_block: {bool_str(has_code_block)}\n"
    f"has_structured_lists: {bool_str(has_structured)}\n"
    f"expanded_references: {expanded_count}\n"
    f"fetch_errors: {fetch_errors_yaml}\n"
)
meta_yml_path.write_text(meta_yml, encoding="utf-8")

print(f"OK input written to {bootstrap_dir}")
PYEOF
