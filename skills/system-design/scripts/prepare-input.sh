#!/usr/bin/env bash
# prepare-input.sh — Round-0 input preparation per guide §6.1
# Usage: prepare-input.sh [--bootstrap-subdir <subdir>] <user-prompt|-> <review-dir>
#   <user-prompt>:              raw prompt string, or '-' to read from stdin.
#                               The prompt is written verbatim — no @path / URL
#                               expansion. Sub-agents (consultant, planner,
#                               writer) have Read / WebFetch tools and pull any
#                               referenced paths or URLs on demand.
#   <review-dir>:               the .review/ root of the target skill.
#   --bootstrap-subdir <name>:  subdir under <review-dir> to write input.md +
#                               input-meta.yml into (default: "round-0"). For
#                               new-version delivery-N bootstrap, orchestrator
#                               passes the starting round of that delivery
#                               (e.g. "round-5") so prior round-0 archive is
#                               preserved.
# Produces:
#   <review-dir>/<bootstrap-subdir>/input.md
#   <review-dir>/<bootstrap-subdir>/input-meta.yml
#   <review-dir>/README.md      (idempotent first-bootstrap drop from template)
# No external packages — stdlib only.
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
    -)
      POSITIONAL+=("$1"); shift ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

if [ $# -lt 2 ]; then
  echo "Usage: prepare-input.sh [--bootstrap-subdir <subdir>] <user-prompt|-> <review-dir>" >&2
  exit 1
fi

USER_PROMPT="$1"
REVIEW_DIR="$2"

if [ "$USER_PROMPT" = "-" ]; then
  USER_PROMPT="$(cat)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README_TEMPLATE="${SCRIPT_DIR}/../common/templates/review-readme-template.md"

python3 - "$USER_PROMPT" "$REVIEW_DIR" "$BOOTSTRAP_SUBDIR" "$README_TEMPLATE" <<'PYEOF'
import sys
import re
import datetime
import pathlib

prompt_text      = sys.argv[1]
review_dir       = sys.argv[2]
bootstrap_subdir = sys.argv[3]
readme_template  = sys.argv[4] if len(sys.argv) > 4 else ""

review_root = pathlib.Path(review_dir)
review_root.mkdir(parents=True, exist_ok=True)

# Idempotent bootstrap of .review/README.md from template.
review_readme_path = review_root / "README.md"
if not review_readme_path.exists() and readme_template:
    tpl = pathlib.Path(readme_template)
    if tpl.is_file():
        review_readme_path.write_text(tpl.read_text(encoding="utf-8"), encoding="utf-8")

bootstrap_dir = review_root / bootstrap_subdir
bootstrap_dir.mkdir(parents=True, exist_ok=True)

input_md_path = bootstrap_dir / "input.md"
meta_yml_path = bootstrap_dir / "input-meta.yml"

# input.md: raw prompt, no @path / URL expansion. The "Expanded References"
# section is gone — sub-agents use Read / WebFetch on demand instead of paying
# for an inlined dump in every downstream prompt.
input_md_path.write_text(
    f"# User Prompt\n\n{prompt_text}\n",
    encoding="utf-8",
)

# Meta fields kept: only those still consumed downstream (glossary-probe.sh
# computes sparse_input from word_count + has_code_block + has_structured).
ws_word_count   = len(prompt_text.split())
cjk_char_count  = len(re.findall(r'[一-鿿぀-ヿ가-힯]', prompt_text))
word_count      = ws_word_count + cjk_char_count
char_count      = len(prompt_text)
has_code_block  = "```" in prompt_text
has_structured  = bool(re.search(r'\n[-*] |\n\d+\. ', "\n" + prompt_text))
generated_at    = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def bool_str(b):
    return "true" if b else "false"

meta_yml_path.write_text(
    f"generated_at: \"{generated_at}\"\n"
    f"word_count: {word_count}\n"
    f"char_count: {char_count}\n"
    f"has_code_block: {bool_str(has_code_block)}\n"
    f"has_structured_lists: {bool_str(has_structured)}\n",
    encoding="utf-8",
)

print(f"OK input written to {bootstrap_dir}")
PYEOF
