#!/usr/bin/env bash
# check-api-surface-cols.sh — CR-L4 (API Surface seven-column fill)
#
# Usage:
#   scripts/check-api-surface-cols.sh <design-dir> [--quiet] [--strict]
#
# Checks every <design-dir>/modules/M-*.md file for a complete API Surface table:
#   1. Header row must have exactly 7 columns.
#   2. Every data row must have exactly 7 non-empty cells (not in: "", "—", "TBD",
#      "...", "TODO", "FIXME").
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.
#
# Exit codes:
#   0  — no violations found
#   1  — one or more violations found (or --strict with any issue)
#   2  — usage / I/O error
#
# Flags:
#   --quiet   suppress per-violation stdout; only print summary line
#   --strict  exit 1 even when 0 violations (reserved for pipeline use; currently same as default)
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
      echo "ERROR: unknown flag: $arg" >&2
      echo "Usage: $0 <design-dir> [--quiet] [--strict]" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then
        DESIGN_DIR="$arg"
      else
        echo "ERROR: unexpected argument: $arg" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$DESIGN_DIR" ]; then
  echo "Usage: $0 <design-dir> [--quiet] [--strict]" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  echo "ERROR: design directory not found: $DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
MODULES_DIR="$DESIGN_DIR/modules"

if [ ! -d "$MODULES_DIR" ]; then
  [ "$QUIET" -eq 0 ] && echo "INFO: no modules/ directory found in $DESIGN_DIR — nothing to check." >&2
  printf '[]\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# is_empty_cell: returns 0 (true) if the cell value counts as empty/forbidden
is_empty_cell() {
  local cell="$1"
  # trim leading/trailing whitespace
  cell="$(echo "$cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$cell" in
    ""|"—"|"TBD"|"..."|"TODO"|"FIXME") return 0 ;;
    *) return 1 ;;
  esac
}

# split_pipe_row: echo each cell (between first and last |) as a separate line
# Input: "| cell1 | cell2 | ... |"
split_pipe_row() {
  local row="$1"
  # Remove leading/trailing pipe and split on |
  row="${row#|}"
  row="${row%|}"
  echo "$row" | tr '|' '\n'
}

# count_pipe_cols: count the number of columns in a markdown table row
count_pipe_cols() {
  local row="$1"
  # Remove leading/trailing pipe
  local inner="${row#|}"
  inner="${inner%|}"
  # Count pipes in inner content + 1
  local pipes
  pipes=$(echo "$inner" | tr -cd '|' | wc -c)
  echo $(( pipes + 1 ))
}

# is_separator_row: returns 0 if row looks like |---|---|
is_separator_row() {
  local row="$1"
  local sep_re='^\|[-|: ]+\|$'
  if [[ "$row" =~ $sep_re ]]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Required column names (positional, 1-indexed)
# ---------------------------------------------------------------------------
COL_NAMES=(
  ""                    # 1-indexed — index 0 unused
  "Method + Path"
  "Auth & Role"
  "Success"
  "Error Codes"
  "Request Example"
  "Response Example"
  "Constraints"
)
REQUIRED_COLS=7

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
violation_count=0
total_files=0
JSON_FINDINGS=""

while IFS= read -r module_file; do
  total_files=$(( total_files + 1 ))
  rel_file="${module_file#"$DESIGN_DIR/"}"

  # Parse the file line by line; track state
  in_api_surface=0
  header_checked=0
  header_col_count=0
  lineno=0

  while IFS= read -r raw_line; do
    lineno=$(( lineno + 1 ))
    line="$raw_line"

    # Detect entry into API Surface section
    if [[ "$line" =~ ^##[[:space:]]+(API[[:space:]]+Surface) ]]; then
      in_api_surface=1
      header_checked=0
      header_col_count=0
      continue
    fi

    # Detect exit: another ## heading
    if [[ "$line" =~ ^##[[:space:]] ]] && [ "$in_api_surface" -eq 1 ]; then
      in_api_surface=0
      header_checked=0
      continue
    fi

    # Only process lines inside API Surface section
    [ "$in_api_surface" -eq 0 ] && continue

    # Skip blank lines
    [[ -z "${line// }" ]] && continue

    # Must be a table row (starts with |)
    [[ "$line" != \|* ]] && continue

    # Skip separator rows (|---|---|)
    is_separator_row "$line" && continue

    col_count=$(count_pipe_cols "$line")

    # ---- Header row (first non-separator pipe row) ----
    if [ "$header_checked" -eq 0 ]; then
      header_col_count="$col_count"
      header_checked=1

      if [ "$col_count" -ne "$REQUIRED_COLS" ]; then
        msg="Header has $col_count column(s) instead of $REQUIRED_COLS in API Surface table."
        fix="Add or remove columns so the header matches: | Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints |"

        [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg" >&2

        _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
        _jdesc=$(printf '%s' "$msg" | sed 's/"/\\"/g')
        _jfix=$(printf '%s' "$fix" | sed 's/"/\\"/g')
        _jentry="{\"criterion_id\":\"CR-L4\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
        if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
        violation_count=$(( violation_count + 1 ))
      fi
      continue
    fi

    # ---- Data rows ----
    # If header had wrong col count, still check data rows against REQUIRED_COLS
    expected_cols="$REQUIRED_COLS"

    if [ "$col_count" -ne "$expected_cols" ]; then
      msg="Data row has $col_count column(s) instead of $expected_cols in API Surface table."
      fix="Ensure all 7 cells are present: Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints"

      [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg" >&2

      _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
      _jdesc=$(printf '%s' "$msg" | sed 's/"/\\"/g')
      _jfix=$(printf '%s' "$fix" | sed 's/"/\\"/g')
      _jentry="{\"criterion_id\":\"CR-L4\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
      if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
      violation_count=$(( violation_count + 1 ))
      continue
    fi

    # Check each cell for empty/forbidden values
    col_idx=0
    while IFS= read -r cell; do
      col_idx=$(( col_idx + 1 ))
      [ "$col_idx" -gt "$REQUIRED_COLS" ] && break

      if is_empty_cell "$cell"; then
        col_name="${COL_NAMES[$col_idx]}"
        trimmed_cell="$(echo "$cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        msg="Column $col_idx ($col_name) is empty or forbidden value (\"$trimmed_cell\") at line $lineno."
        fix="Fill column '$col_name' with a concrete value. See module-template.md for the expected content per column."

        [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg" >&2

        _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
        _jdesc=$(printf '%s' "$msg" | sed 's/"/\\"/g')
        _jfix=$(printf '%s' "$fix" | sed 's/"/\\"/g')
        _jentry="{\"criterion_id\":\"CR-L4\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
        if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
        violation_count=$(( violation_count + 1 ))
      fi
    done < <(split_pipe_row "$line")

  done < "$module_file"

done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' | sort)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then
  echo "" >&2
  echo "CR-L4 check complete — $total_files module(s) scanned, $violation_count violation(s) found." >&2
fi

if [ "$violation_count" -eq 0 ]; then
  printf '[]\n'
else
  printf '[%s]\n' "$JSON_FINDINGS"
fi

if [ "$violation_count" -gt 0 ]; then
  exit 1
fi

exit 0
