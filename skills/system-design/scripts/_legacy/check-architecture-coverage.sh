#!/usr/bin/env bash
# check-architecture-coverage.sh — CR-X3 (architecture-coverage)
#
# Lint check: every PRD architecture/*.md file MUST appear as a row in
# <design-dir>/README.md's "## Implementation Conventions" table OR be
# explicitly marked "N/A — {reason}" in that section.
#
# PRD path resolution:
#   Read <design-dir>/README.md and look for a relative path to the PRD in
#   a "Source:" line, a "References" section, or a fenced path block.
#   If the PRD path cannot be resolved → skip with a warning; exit 0.
#   If the PRD path resolves but architecture/ does not exist → skip; exit 0.
#
# Detection:
#   1. List ${PRD_PATH}/architecture/*.md.  For each file: capture basename.
#   2. Parse the "## Implementation Conventions" section of README.md:
#      extract the "Source PRD file" column (col 2) of every data row, plus
#      any "N/A — " lines that name a file.
#   3. For each architecture file: verify (a) its basename or a relative path
#      containing the basename appears in a table cell or N/A note, OR (b) a
#      row exists whose Category or PRD Policy cell references the basename.
#   4. Missing → emit JSON finding on stdout (severity=blocker, CR-id=CR-X3).
#
# Usage:
#   check-architecture-coverage.sh <design-dir> [--quiet] [--strict]
#
#   --quiet   Suppress per-issue stdout; only print summary line.
#   --strict  Exit 1 even when only mechanical violations exist (no blockers).
#             Without --strict: exit 1 only when at least one blocker exists.
#
# Exit codes:
#   0  No violations found (or PRD path / architecture/ not resolvable — skipped).
#   1  At least one blocker found; or at least one mechanical + --strict.
#   2  Usage error or <design-dir> not found / not readable.
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DESIGN_DIR=""
QUIET=0
STRICT=0

for arg in "$@"; do
  case "$arg" in
    --quiet)  QUIET=1 ;;
    --strict) STRICT=1 ;;
    -*)
      printf 'ERROR: unknown flag: %s\n' "$arg" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then
        DESIGN_DIR="$arg"
      else
        printf 'ERROR: unexpected argument: %s\n' "$arg" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$DESIGN_DIR" ]; then
  printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design dir not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
README="${DESIGN_DIR}/README.md"

if [ ! -f "$README" ]; then
  printf 'SKIP: README.md not found in: %s — no artifact to lint\n' "$DESIGN_DIR" >&2
  echo "[]"
  exit 0
fi

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Helper: write a LINT issue file and (unless --quiet) print to stdout.
# Arguments: basename_of_arch_file
# ---------------------------------------------------------------------------
write_issue() {
  local arch_basename="$1"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-X3] blocker  README.md — PRD architecture file `%s` is silently dropped from Implementation Conventions\n' \
      "$arch_basename" >&2
  fi

  # Accumulate JSON finding
  _jbn=$(printf '%s' "$arch_basename" | sed 's/"/\\"/g')
  _jdesc="PRD architecture file ${_jbn} is not referenced in ## Implementation Conventions and has no N/A note"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Add a row referencing ${_jbn} to ## Implementation Conventions in README.md, or add an N/A row naming the file"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-X3\",\"file\":\"README.md\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Step 1 — Resolve PRD path from README.md
# ---------------------------------------------------------------------------
# Strategy (in order):
#   a) Lines containing "Source:" — extract the markdown link href via sed.
#      Handles: **Source:** [{name}]({rel-path}) | ...
#   b) References section — extract any markdown link href from lines that
#      follow "## References" and contain "[PRD" or "[prd".
#   c) Any line that contains a markdown link href matching a relative path
#      (not http) — scan all markdown link hrefs in the file.
#
# All candidates are resolved relative to DESIGN_DIR via "cd" in a subshell.
# We use sed (not grep -oE with bracket expressions) to extract hrefs because
# BSD grep on macOS misparses [^\n] when the input contains literal "[".
#
# Note: BSD "cd" inside "$(…)" under set -euo pipefail is safe because we use
# "|| true" to suppress failures from bad paths.

_try_resolve_candidate() {
  # Given a raw href candidate and the design dir, print the resolved absolute
  # path if it is an existing directory; otherwise print nothing.
  local candidate="$1"
  local design_dir="$2"
  local resolved

  [ -n "$candidate" ] || return 0
  # Strip trailing slash and fragment
  candidate="${candidate%/}"
  candidate="${candidate%%#*}"
  # Skip http(s) URLs
  case "$candidate" in http*) return 0 ;; esac
  # If the href points to a file (has an extension), use its parent dir
  case "$(basename "$candidate")" in
    *.*)  candidate="$(dirname "$candidate")" ;;
  esac
  [ -n "$candidate" ] || return 0

  # Resolve relative to design_dir
  resolved="$(cd "$design_dir" 2>/dev/null && cd "$candidate" 2>/dev/null && pwd)" || true
  if [ -n "$resolved" ] && [ -d "$resolved" ]; then
    printf '%s\n' "$resolved"
  fi
}

resolve_prd_path() {
  local readme="$1"
  local design_dir="$2"
  local candidate result

  # Pattern a: lines containing "Source:" — use sed to grab the first (…) href
  while IFS= read -r candidate; do
    result="$(_try_resolve_candidate "$candidate" "$design_dir")"
    if [ -n "$result" ]; then
      printf '%s\n' "$result"
      return 0
    fi
  done < <(grep -i 'Source:' "$readme" 2>/dev/null \
             | sed -n 's/.*(\([^)]*\)).*/\1/p' \
             | grep -v '^http' \
             | head -5)

  # Pattern b: References section — lines with "[PRD" or "[prd"
  while IFS= read -r candidate; do
    result="$(_try_resolve_candidate "$candidate" "$design_dir")"
    if [ -n "$result" ]; then
      printf '%s\n' "$result"
      return 0
    fi
  done < <(grep -iE '^\s*[-*]\s*\[prd' "$readme" 2>/dev/null \
             | sed -n 's/.*(\([^)]*\)).*/\1/p' \
             | grep -v '^http' \
             | head -5)

  # Pattern c: all markdown link hrefs in the file (broad fallback)
  while IFS= read -r candidate; do
    result="$(_try_resolve_candidate "$candidate" "$design_dir")"
    if [ -n "$result" ]; then
      printf '%s\n' "$result"
      return 0
    fi
  done < <(grep -v '^http' "$readme" 2>/dev/null \
             | sed -n 's/.*(\([^)]*\)).*/\1/p' \
             | grep -v '^http' \
             | head -20)

  return 1
}

PRD_PATH=""
if ! PRD_PATH="$(resolve_prd_path "$README" "$DESIGN_DIR")"; then
  printf 'OK 0 findings — PRD path not resolvable, skipped\n' >&2
  printf '[]\n'
  exit 0
fi

ARCH_DIR="${PRD_PATH}/architecture"
if [ ! -d "$ARCH_DIR" ]; then
  printf 'OK 0 findings — PRD architecture/ directory not found, skipped\n' >&2
  printf '[]\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 2 — List architecture/*.md files
# ---------------------------------------------------------------------------
mapfile -t ARCH_FILES < <(find "$ARCH_DIR" -maxdepth 1 -name '*.md' -print | sort)

if [ "${#ARCH_FILES[@]}" -eq 0 ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'OK 0 findings — architecture/ contains no .md files\n' >&2
  fi
  printf '[]\n'
  exit 0
fi

# Collect basenames
declare -a ARCH_BASENAMES=()
for arch_file in "${ARCH_FILES[@]}"; do
  ARCH_BASENAMES+=( "$(basename "$arch_file")" )
done

# ---------------------------------------------------------------------------
# Step 3 — Parse ## Implementation Conventions section of README.md
# ---------------------------------------------------------------------------
# Extract all text lines from the ## Implementation Conventions section.
# The section ends at the next ## heading.
# We collect:
#   - Every table data row (lines starting with |, not header/separator)
#   - Every line containing "N/A —" (inline N/A notes)
#
# For matching: an architecture file is considered "covered" if its basename
# (with or without .md extension) appears anywhere in the section text.

extract_conventions_section() {
  local readme="$1"
  local in_section=0
  local line

  while IFS= read -r line; do
    # Section entry
    if printf '%s\n' "$line" | grep -qE '^##[[:space:]]+Implementation Conventions'; then
      in_section=1
      continue
    fi
    # Section exit
    if [ "$in_section" -eq 1 ] && printf '%s\n' "$line" | grep -qE '^##[[:space:]]'; then
      break
    fi
    if [ "$in_section" -eq 1 ]; then
      printf '%s\n' "$line"
    fi
  done < "$readme"
}

CONVENTIONS_TEXT="$(extract_conventions_section "$README")"

# ---------------------------------------------------------------------------
# Helper: check if an arch basename is referenced in the conventions section.
# Returns 0 (found) or 1 (not found).
# We test both "basename.md" and "basename" (without extension) to be robust.
# ---------------------------------------------------------------------------
basename_covered() {
  local bname="$1"
  local bname_noext="${bname%.md}"

  # Search the full conventions section text for either form
  if printf '%s\n' "$CONVENTIONS_TEXT" | grep -qF "$bname"; then
    return 0
  fi
  if printf '%s\n' "$CONVENTIONS_TEXT" | grep -qF "$bname_noext"; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Step 4 — Check each architecture file; emit issues for missing ones
# ---------------------------------------------------------------------------
TOTAL_VIOLATIONS=0
BLOCKER_COUNT=0

for bname in "${ARCH_BASENAMES[@]}"; do
  if ! basename_covered "$bname"; then
    write_issue "$bname"
    TOTAL_VIOLATIONS=$(( TOTAL_VIOLATIONS + 1 ))
    BLOCKER_COUNT=$(( BLOCKER_COUNT + 1 ))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 0 ] || [ "$TOTAL_VIOLATIONS" -gt 0 ]; then
  printf '\nCR-X3 Architecture coverage: %d violation(s) (%d blocker)\n' \
    "$TOTAL_VIOLATIONS" "$BLOCKER_COUNT" >&2
fi

# ---------------------------------------------------------------------------
# JSON stdout output
# ---------------------------------------------------------------------------
if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
  printf '[]\n'
else
  printf '[%s]\n' "$JSON_FINDINGS"
fi

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------
if [ "$BLOCKER_COUNT" -gt 0 ]; then
  exit 1
elif [ "$TOTAL_VIOLATIONS" -gt 0 ] && [ "$STRICT" -eq 1 ]; then
  exit 1
else
  exit 0
fi
