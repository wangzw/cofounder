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
# Each violation is written to <design-dir>/.reviews/LINT-<NNN>.md as a blocker issue.
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
REVIEWS_DIR="$DESIGN_DIR/.reviews"

if [ ! -d "$MODULES_DIR" ]; then
  [ "$QUIET" -eq 0 ] && echo "INFO: no modules/ directory found in $DESIGN_DIR — nothing to check."
  exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# next_lint_seq: return the next available LINT-NNN sequence number
next_lint_seq() {
  local dir="$1"
  local max=0
  if [ -d "$dir" ]; then
    while IFS= read -r f; do
      local base
      base="$(basename "$f")"
      if [[ "$base" =~ ^LINT-([0-9]+)\.md$ ]]; then
        local n="${BASH_REMATCH[1]}"
        # strip leading zeros for arithmetic
        n=$((10#$n))
        [ "$n" -gt "$max" ] && max="$n"
      fi
    done < <(find "$dir" -maxdepth 1 -name 'LINT-*.md' 2>/dev/null)
  fi
  printf "%03d" $(( max + 1 ))
}

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
mkdir -p "$REVIEWS_DIR"

violation_count=0
total_files=0

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
        seq=$(next_lint_seq "$REVIEWS_DIR")
        issue_file="$REVIEWS_DIR/LINT-${seq}.md"

        msg="Header has $col_count column(s) instead of $REQUIRED_COLS in API Surface table."
        fix="Add or remove columns so the header matches: | Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints |"

        [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg"

        cat > "$issue_file" <<ISSUE
# LINT-${seq} — CR-L4 API Surface column count

**Severity**: blocker
**CR-id**: CR-L4
**File**: $rel_file
**Line**: $lineno

## Finding

$msg

Expected 7 columns: Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints

## Suggested Fix

$fix

Per \`module-template.md\`: every API Surface row must fill all 7 columns (no blanks, no "see API-XXX" cross-references without anchor links).
ISSUE

        violation_count=$(( violation_count + 1 ))
      fi
      continue
    fi

    # ---- Data rows ----
    # If header had wrong col count, still check data rows against REQUIRED_COLS
    expected_cols="$REQUIRED_COLS"

    if [ "$col_count" -ne "$expected_cols" ]; then
      seq=$(next_lint_seq "$REVIEWS_DIR")
      issue_file="$REVIEWS_DIR/LINT-${seq}.md"

      msg="Data row has $col_count column(s) instead of $expected_cols in API Surface table."
      fix="Ensure all 7 cells are present: Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints"

      [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg"

      cat > "$issue_file" <<ISSUE
# LINT-${seq} — CR-L4 API Surface column count (data row)

**Severity**: blocker
**CR-id**: CR-L4
**File**: $rel_file
**Line**: $lineno

## Finding

$msg

Row content:
\`$line\`

## Suggested Fix

$fix

Per \`module-template.md\` Rules: "every column must be filled (no blanks, no 'see API-XXX' cross-references)".
ISSUE

      violation_count=$(( violation_count + 1 ))
      continue
    fi

    # Check each cell for empty/forbidden values
    col_idx=0
    while IFS= read -r cell; do
      col_idx=$(( col_idx + 1 ))
      [ "$col_idx" -gt "$REQUIRED_COLS" ] && break

      if is_empty_cell "$cell"; then
        seq=$(next_lint_seq "$REVIEWS_DIR")
        issue_file="$REVIEWS_DIR/LINT-${seq}.md"

        col_name="${COL_NAMES[$col_idx]}"
        trimmed_cell="$(echo "$cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        msg="Column $col_idx ($col_name) is empty or forbidden value (\"$trimmed_cell\") at line $lineno."
        fix="Fill column '$col_name' with a concrete value. See module-template.md for the expected content per column."

        [ "$QUIET" -eq 0 ] && echo "[CR-L4] blocker  $rel_file:$lineno — $msg"

        cat > "$issue_file" <<ISSUE
# LINT-${seq} — CR-L4 API Surface empty cell

**Severity**: blocker
**CR-id**: CR-L4
**File**: $rel_file
**Line**: $lineno
**Column**: $col_idx — $col_name

## Finding

$msg

Row content:
\`$line\`

## Suggested Fix

$fix

Required column content per \`module-template.md\`:
- **Method + Path**: full HTTP verb + path (e.g. \`POST /v1/tasks\`)
- **Auth & Role**: required headers + role matrix, or \`internal-only\`
- **Success**: HTTP status code for the happy path (e.g. \`200\`, \`201\`)
- **Error Codes**: all triggerable codes with error-type strings (e.g. \`400 invalid_request_error\`)
- **Request Example**: anchor link \`[API-NNN](../api/API-NNN-slug.md#anchor)\`; \`{}\` is not acceptable
- **Response Example**: anchor link \`[API-NNN](../api/API-NNN-slug.md#anchor)\`; \`{}\` is not acceptable
- **Constraints**: rate limits, size caps, idempotency; \`—\` only for pure internal endpoints
ISSUE

        violation_count=$(( violation_count + 1 ))
      fi
    done < <(split_pipe_row "$line")

  done < "$module_file"

done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' | sort)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then
  echo ""
  echo "CR-L4 check complete — $total_files module(s) scanned, $violation_count violation(s) found."
  if [ "$violation_count" -gt 0 ]; then
    echo "Issue files written to: $REVIEWS_DIR/"
  fi
fi

if [ "$violation_count" -gt 0 ]; then
  exit 1
fi

exit 0
