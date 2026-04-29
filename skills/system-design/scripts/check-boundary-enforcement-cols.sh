#!/usr/bin/env bash
# check-boundary-enforcement-cols.sh — CR-L3 (boundary-enforcement-cols)
#
# Lint check: every <design-dir>/modules/M-*.md Boundary Enforcement table
# must have ALL FOUR columns filled on every data row.
#
# Columns: Constraint | Tool / Lint / Test | File Path | CI Job
#
# Usage:
#   check-boundary-enforcement-cols.sh <design-dir> [--quiet] [--strict]
#
#   --quiet   Suppress per-issue stdout; only print summary line to stdout.
#   --strict  Exit 1 even when all violations are mechanical (no blockers).
#             Without --strict: exit 1 only when at least one blocker exists.
#
# Exit codes:
#   0  No violations found.
#   1  At least one violation found (blocker always triggers; mechanical
#      triggers only with --strict).
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

MODULES_DIR="${DESIGN_DIR%/}/modules"
if [ ! -d "$MODULES_DIR" ]; then
  printf 'SKIP: modules/ directory not found under: %s — no artifact to lint\n' "$DESIGN_DIR" >&2
  echo "[]"
  exit 0
fi

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Helper: check whether a cell value is forbidden (empty / placeholder)
# Returns 0 (true) if the cell is forbidden, 1 (false) if it has real content.
# ---------------------------------------------------------------------------
cell_is_forbidden() {
  local cell="$1"
  case "$cell" in
    ""|"—"|"TBD"|"..."|"TODO"|"FIXME") return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: split a markdown table row on | and return trimmed cells.
# Input: the raw line e.g.  "| foo | bar | baz | qux |"
# Output: newline-separated cells (interior cells only, no leading/trailing empties).
# We use awk for reliable field splitting inside pure bash.
# ---------------------------------------------------------------------------
split_row_cells() {
  local row="$1"
  # Use awk: split on |, trim whitespace, skip empty first/last fields
  printf '%s\n' "$row" | awk -F'|' '{
    for (i=2; i<=NF-1; i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", $i)
      print $i
    }
  }'
}

# ---------------------------------------------------------------------------
# Helper: count cells in a markdown table row
# ---------------------------------------------------------------------------
count_cells() {
  split_row_cells "$1" | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# Helper: write a LINT issue file and (unless --quiet) print to stdout.
# Arguments: seq file lineno col_index
# ---------------------------------------------------------------------------
write_issue() {
  local seq="$1"
  local rel_file="$2"
  local lineno="$3"
  local col_name="$4"
  local extra_note="$5"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-L3] blocker  %s:%d — Boundary Enforcement column "%s" is empty or placeholder\n' \
      "$rel_file" "$lineno" "$col_name" >&2
    printf '  Fix: fill the cell per module-template.md Boundary Enforcement rules\n' >&2
  fi
  _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
  _jcol=$(printf '%s' "$col_name" | sed 's/"/\\"/g')
  _jdesc="Boundary Enforcement row has empty or placeholder cell in column \\\"${_jcol}\\\" at line ${lineno}"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Fill the \\\"${_jcol}\\\" cell per module-template.md Boundary Enforcement rules"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-L3\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Column name map (1-based index)
# ---------------------------------------------------------------------------
col_name_for_index() {
  case "$1" in
    1) printf 'Constraint' ;;
    2) printf 'Tool / Lint / Test' ;;
    3) printf 'File Path' ;;
    4) printf 'CI Job' ;;
    *) printf 'Column %d' "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Main: iterate over all M-*.md files
# ---------------------------------------------------------------------------
TOTAL_VIOLATIONS=0
BLOCKER_COUNT=0

# Use find with sorted output so results are deterministic
while IFS= read -r -d '' module_file; do
  rel_file="modules/$(basename "$module_file")"

  # State machine to find and parse the Boundary Enforcement table
  in_section=0      # 1 when we are inside ## Boundary Enforcement
  header_checked=0  # 1 after the header row has been validated
  separator_seen=0  # 1 after the separator row (---|---|...) has been consumed

  lineno=0
  while IFS= read -r line; do
    lineno=$(( lineno + 1 ))

    # Detect section entry
    if printf '%s\n' "$line" | grep -qE '^##[[:space:]]+Boundary Enforcement'; then
      in_section=1
      header_checked=0
      separator_seen=0
      continue
    fi

    # Detect section exit: another ## heading (any level) ends the section
    if [ "$in_section" -eq 1 ]; then
      if printf '%s\n' "$line" | grep -qE '^##'; then
        in_section=0
        continue
      fi

      # Skip blank lines and non-table lines
      if ! printf '%s\n' "$line" | grep -qE '^\|'; then
        continue
      fi

      # ---- Header row ----
      if [ "$header_checked" -eq 0 ]; then
        ncols="$(count_cells "$line")"
        if [ "$ncols" -ne 4 ]; then
          # Header column count mismatch — report as a single issue
          if [ "$QUIET" -eq 0 ]; then
            printf '[CR-L3] blocker  %s:%d — Boundary Enforcement header has %d columns (expected 4)\n' \
              "$rel_file" "$lineno" "$ncols" >&2
          fi
          _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
          _jdesc="Boundary Enforcement table header has ${ncols} columns (expected 4)"
          _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
          _jfix="Rewrite header row to match module-template.md Boundary Enforcement table definition"
          _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
          _jentry="{\"criterion_id\":\"CR-L3\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
          if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
          TOTAL_VIOLATIONS=$(( TOTAL_VIOLATIONS + 1 ))
          BLOCKER_COUNT=$(( BLOCKER_COUNT + 1 ))
        fi
        header_checked=1
        continue
      fi

      # ---- Separator row (---|---|...) ----
      if [ "$separator_seen" -eq 0 ]; then
        # A separator row consists of cells that are all dashes/colons/spaces
        if printf '%s\n' "$line" | grep -qE '^\|[-: |]+\|'; then
          separator_seen=1
          continue
        fi
        # If it looks like a table row but not a separator, treat as data row
      fi

      # ---- Data row ----
      # Read cells into an array
      cell_idx=0
      while IFS= read -r cell; do
        cell_idx=$(( cell_idx + 1 ))
        if cell_is_forbidden "$cell"; then
          col_name="$(col_name_for_index "$cell_idx")"
          write_issue "$rel_file" "$lineno" "$col_name" ""
          TOTAL_VIOLATIONS=$(( TOTAL_VIOLATIONS + 1 ))
          BLOCKER_COUNT=$(( BLOCKER_COUNT + 1 ))
        fi
      done < <(split_row_cells "$line")
    fi
  done < "$module_file"

done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' -print0 | sort -z)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 0 ] || [ "$TOTAL_VIOLATIONS" -gt 0 ]; then
  printf '\nCR-L3 Boundary Enforcement column fill: %d violation(s) (%d blocker)\n' \
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
