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
# Issue files are written to <design-dir>/.reviews/LINT-<NNN>.md.
# NNN is determined by the next unused 3-digit sequence number in that dir.

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
  printf 'ERROR: modules/ directory not found under: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Helper: next LINT sequence number in <design-dir>/.reviews/
# ---------------------------------------------------------------------------
reviews_dir="${DESIGN_DIR%/}/.reviews"
mkdir -p "$reviews_dir"

next_lint_seq() {
  local max=0
  local n base f
  # Glob into an array; if no matches, the glob literal is returned — handle via -e check
  for f in "$reviews_dir"/LINT-*.md; do
    [ -e "$f" ] || continue
    # Extract the numeric portion from LINT-NNN.md
    base="$(basename "$f" .md)"
    n="${base#LINT-}"
    # Convert to decimal; strip leading zeros by using arithmetic expansion
    n=$(( 10#${n} )) 2>/dev/null || n=0
    if [ "$n" -gt "$max" ]; then
      max="$n"
    fi
  done
  printf '%03d' $(( max + 1 ))
}

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

  local issue_file="${reviews_dir}/LINT-${seq}.md"

  cat > "$issue_file" <<ISSUE
# LINT-${seq}

- **Severity**: blocker
- **CR-id**: CR-L3
- **File**: ${rel_file}
- **Line**: ${lineno}
- **Title**: Boundary Enforcement row has empty cell
- **Reasoning**: Column "${col_name}" is empty or contains a forbidden placeholder${extra_note:+ — ${extra_note}}.
- **Suggested fix**: Fill the "${col_name}" cell following the module-template.md Boundary Enforcement rules:
  - **Constraint**: one concrete rule; descriptive English like "code should be clean" is rejected.
  - **Tool / Lint / Test**: named tool + rule identifier (e.g. \`golangci-lint:errcheck\`, \`eslint:custom-rule-name\`); not "custom lint".
  - **File Path**: path to the config file or test file that encodes the rule — must resolve to a real file in the repo.
  - **CI Job**: job name from the CI pipeline that runs the check — must match a job defined in the Development Infrastructure module.
  If all four columns cannot be filled, move the constraint to **Implementation Constraints** as advisory guidance.
ISSUE

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-L3] blocker  %s:%d — Boundary Enforcement column "%s" is empty or placeholder\n' \
      "$rel_file" "$lineno" "$col_name"
    printf '  Fix: fill the cell per module-template.md Boundary Enforcement rules (issue written to %s)\n' \
      "${reviews_dir}/LINT-${seq}.md"
  fi
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
          seq="$(next_lint_seq)"
          issue_file="${reviews_dir}/LINT-${seq}.md"
          cat > "$issue_file" <<ISSUE
# LINT-${seq}

- **Severity**: blocker
- **CR-id**: CR-L3
- **File**: ${rel_file}
- **Line**: ${lineno}
- **Title**: Boundary Enforcement table header has wrong column count
- **Reasoning**: Expected 4 columns (Constraint | Tool / Lint / Test | File Path | CI Job), found ${ncols}.
- **Suggested fix**: Rewrite the header row to match the module-template.md Boundary Enforcement table definition.
ISSUE
          if [ "$QUIET" -eq 0 ]; then
            printf '[CR-L3] blocker  %s:%d — Boundary Enforcement header has %d columns (expected 4)\n' \
              "$rel_file" "$lineno" "$ncols"
            printf '  Fix: use header "| Constraint | Tool / Lint / Test | File Path | CI Job |\"\n'
          fi
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
          seq="$(next_lint_seq)"
          write_issue "$seq" "$rel_file" "$lineno" "$col_name" ""
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
    "$TOTAL_VIOLATIONS" "$BLOCKER_COUNT"
  if [ "$TOTAL_VIOLATIONS" -gt 0 ]; then
    printf 'Issue files: %s/LINT-*.md\n' "$reviews_dir"
  fi
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
