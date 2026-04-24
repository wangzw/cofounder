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

# Resolve template path — sibling to this script via `../common/templates/`.
# Works both when run inside this skill (before scaffold) and inside a scaffolded
# target (after scaffold copies scripts/ + common/templates/ forward).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README_TEMPLATE="${SCRIPT_DIR}/../common/templates/review-readme-template.md"

python3 - "$USER_PROMPT" "$REVIEW_DIR" "$INVOKE_CWD" "$BOOTSTRAP_SUBDIR" "$README_TEMPLATE" <<'PYEOF'
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
readme_template = sys.argv[5] if len(sys.argv) > 5 else ""

review_root = pathlib.Path(review_dir)
review_root.mkdir(parents=True, exist_ok=True)

# Drop the self-documenting .review/README.md on first bootstrap (idempotent —
# skip if already present so authors can hand-edit the file without losing
# their edits on the next delivery-N bootstrap).
review_readme_path = review_root / "README.md"
if not review_readme_path.exists() and readme_template:
    tpl = pathlib.Path(readme_template)
    if tpl.is_file():
        review_readme_path.write_text(tpl.read_text(encoding="utf-8"), encoding="utf-8")

bootstrap_dir = review_root / bootstrap_subdir
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

MAX_FETCH_BYTES = 50 * 1024          # 50 KB per file
MAX_DIR_TOTAL_BYTES = 512 * 1024     # 512 KB aggregate per directory ref
TEXT_EXTS = {".md", ".txt", ".yml", ".yaml", ".json", ".sh", ".py", ".toml",
             ".ini", ".cfg", ".rst", ".html", ".xml", ".css", ".js", ".ts"}

def _is_text_file(p):
    return p.suffix.lower() in TEXT_EXTS or p.name in {"README", "LICENSE", "CHANGELOG"}

def _should_skip(rel_parts):
    # Skip dotdirs (.git, .review, .venv, ...) and common build/cache dirs
    skip = {"node_modules", "__pycache__", "dist", "build", ".git", ".review"}
    for part in rel_parts:
        if part.startswith(".") or part in skip:
            return True
    return False

for ref in path_refs:
    heading = f"## @{ref}"
    full_path = pathlib.Path(invoke_cwd) / ref
    if not full_path.exists():
        expanded_sections.append(f"{heading}\n\n(file not found: {ref})")
        fetch_errors.append(f"@{ref}")
        continue
    if full_path.is_dir():
        # Directory ref: enumerate tree + inline text files under a per-dir budget
        listing_lines = []
        content_sections = []
        used = 0
        for p in sorted(full_path.rglob("*")):
            rel = p.relative_to(full_path)
            if _should_skip(rel.parts):
                continue
            if p.is_dir():
                continue
            try:
                size = p.stat().st_size
            except OSError:
                continue
            listing_lines.append(f"- {rel} ({size} bytes)")
            if _is_text_file(p) and size <= MAX_FETCH_BYTES and used + size <= MAX_DIR_TOTAL_BYTES:
                try:
                    body = p.read_text(encoding="utf-8", errors="replace").rstrip()
                    content_sections.append(f"### {rel}\n\n```\n{body}\n```")
                    used += size
                except OSError as exc:
                    fetch_errors.append(f"@{ref}/{rel} ({exc})")
        parts = [
            heading,
            f"_(directory; per-file cap {MAX_FETCH_BYTES} B, total cap {MAX_DIR_TOTAL_BYTES} B, used {used} B)_",
            "**File tree:**",
            "\n".join(listing_lines) if listing_lines else "(empty)",
        ]
        if content_sections:
            parts.append("**Contents:**")
            parts.append("\n\n".join(content_sections))
        expanded_sections.append("\n\n".join(parts))
        expanded_count += 1
        continue
    # Regular file
    try:
        content = full_path.read_text(encoding="utf-8", errors="replace")
        expanded_sections.append(f"{heading}\n\n{content.rstrip()}")
        expanded_count += 1
    except OSError as exc:
        expanded_sections.append(f"{heading}\n\n(read error: {exc})")
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
