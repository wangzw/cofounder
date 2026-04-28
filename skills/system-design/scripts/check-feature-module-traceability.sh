#!/usr/bin/env bash
# check-feature-module-traceability.sh — CR-X5 (feature-module-traceability)
# Usage: check-feature-module-traceability.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-X5: bidirectional sync between PRD feature index and the
# Feature-Module Mapping Matrix in <design-dir>/README.md.
#
# Check 1 (blocker): every PRD F-NNN feature MUST be referenced (✦ or △) in
#   at least one cell of the matrix.  An F-NNN that appears in features/ but has
#   no ✦/△ anywhere in its matrix column is an orphaned feature.
#
# Check 2 (mechanical): for each module M-NNN in the matrix, parse
#   modules/M-NNN.md "## Source Features" section; extract referenced F-NNN IDs.
#   For each such F-NNN, the matrix cell (row=F-NNN, col=M-NNN) must be ✦.
#   Mismatches → violation (e.g. F-NNN listed in Source Features but matrix cell
#   is blank or △).
#
# PRD path resolution:
#   Parse <design-dir>/README.md "Design Input" section for a "Source:" line
#   containing a Markdown link "[…](<path>)".  Resolve that path relative to
#   <design-dir>.  Strip a trailing "README.md" to get the PRD directory.
#   If the PRD path cannot be resolved or the features/ subdir is absent, skip
#   Check 1 with a WARNING (not a failure).
#
# Exit codes:
#   0  No violations found  (or PRD unresolvable and all other checks pass)
#   1  At least one violation found AND (blocker present OR --strict set)
#   2  Usage error or <design-dir> not found
#
# Issue files: <design-dir>/.reviews/LINT-<NNN>.md (severity/CR-id/fix inline).

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
      printf 'Usage: check-feature-module-traceability.sh <design-dir> [--quiet] [--strict]\n' >&2
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
  printf 'ERROR: <design-dir> is required\n' >&2
  printf 'Usage: check-feature-module-traceability.sh <design-dir> [--quiet] [--strict]\n' >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design dir not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
README="$DESIGN_DIR/README.md"
MODULES_DIR="$DESIGN_DIR/modules"
REVIEWS_DIR="$DESIGN_DIR/.reviews"

if [ ! -f "$README" ]; then
  printf 'ERROR: README.md not found in design dir: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

mkdir -p "$REVIEWS_DIR"

# ---------------------------------------------------------------------------
# Helper: allocate next LINT sequence number (zero-padded to 3 digits)
# ---------------------------------------------------------------------------
next_lint_id() {
  local max=0
  local n
  for f in "$REVIEWS_DIR"/LINT-*.md; do
    [ -e "$f" ] || continue
    n=$(basename "$f" | sed 's/^LINT-\([0-9][0-9]*\).*/\1/')
    if [ "$n" -gt "$max" ] 2>/dev/null; then
      max="$n"
    fi
  done
  echo $((max + 1))
}

# ---------------------------------------------------------------------------
# Helper: emit a LINT-NNN.md file
# Arguments: severity cr_id rel_file anchor title reasoning fix
# ---------------------------------------------------------------------------
emit_lint() {
  local severity="$1"
  local cr_id="$2"
  local rel_file="$3"
  local anchor="$4"
  local title="$5"
  local reasoning="$6"
  local fix="$7"

  local lint_id
  lint_id=$(next_lint_id)
  local lint_id_padded
  lint_id_padded=$(printf '%03d' "$lint_id")
  local lint_file="$REVIEWS_DIR/LINT-${lint_id_padded}.md"

  cat > "$lint_file" << LINT_EOF
# LINT-${lint_id_padded}

**ID**: LINT-${lint_id_padded}
**Severity**: ${severity}
**CR-id**: ${cr_id}
**File**: ${rel_file}
**Anchor**: ${anchor}
**Title**: ${title}

## Reasoning

${reasoning}

## Suggested Fix

${fix}
LINT_EOF

  if [ "$QUIET" -eq 0 ]; then
    printf '[%s] %s: %s — %s → %s\n' \
      "$cr_id" "$severity" "${rel_file}:${anchor}" "$title" "$(basename "$lint_file")"
  fi

  echo "$lint_file"
}

# ---------------------------------------------------------------------------
# PRD path resolution
# ---------------------------------------------------------------------------
# Look for "**Source:**" or "- **Source:**" line in README.md that contains
# a markdown link.  Extract the path inside the parentheses.
# Example line:
#   - **Source:** [My PRD](../../../prd/2026-01-01-foo/README.md) | …
resolve_prd_path() {
  local readme="$1"
  # Extract the first markdown link on a Source: line
  local raw_link
  raw_link=$(grep -m1 '\*\*Source:\*\*' "$readme" | grep -oE '\([^)]+\)' | head -1 | tr -d '()')
  [ -z "$raw_link" ] && return 1

  # Resolve relative to design dir
  local resolved
  # raw_link may be relative; resolve from DESIGN_DIR
  if [ "${raw_link#/}" = "$raw_link" ]; then
    # relative path
    resolved="$DESIGN_DIR/$raw_link"
  else
    resolved="$raw_link"
  fi

  # Normalize: strip trailing README.md to get PRD directory
  resolved="${resolved%/README.md}"
  resolved="${resolved%/}"

  # Canonicalize (remove .. components) using pwd -P or manual resolution
  # Use a subshell so we don't change cwd
  if [ -d "$resolved" ]; then
    resolved=$(cd "$resolved" && pwd -P)
    echo "$resolved"
    return 0
  fi

  return 1
}

PRD_PATH=""
if PRD_PATH=$(resolve_prd_path "$README"); then
  PRD_FEATURES_DIR="$PRD_PATH/features"
  if [ ! -d "$PRD_FEATURES_DIR" ]; then
    printf 'WARNING: PRD features/ not found at %s — Check 1 skipped\n' "$PRD_FEATURES_DIR" >&2
    PRD_PATH=""
  fi
else
  printf 'WARNING: PRD path unresolvable from %s — Check 1 skipped\n' "$README" >&2
  PRD_PATH=""
fi

# ---------------------------------------------------------------------------
# Parse the Feature-Module Mapping Matrix from README.md
# ---------------------------------------------------------------------------
# The matrix section starts with "## Feature-Module Mapping" and ends at the
# next "##" heading (or end of file).
# Header row format:  | | M-001 name | M-002 name | ...
# Data row format:    | F-001 name | ✦ | △ | |  (first col = feature label)
#
# We extract:
#   - module_ids[]     : ordered list of M-NNN extracted from header
#   - feature_ids[]    : ordered list of F-NNN extracted from row labels
#   - matrix[F-NNN,M-NNN]: cell symbol (✦, △, or "")
# ---------------------------------------------------------------------------

# Extract the matrix section lines (from the heading until next ## or EOF)
MATRIX_LINES=$(awk '
  /^## Feature-Module Mapping/ { in_section=1; next }
  in_section && /^## / { in_section=0 }
  in_section { print }
' "$README")

if [ -z "$MATRIX_LINES" ]; then
  printf 'WARNING: "## Feature-Module Mapping" section not found in README.md — both checks skipped\n' >&2
  printf 'OK 0 findings (no matrix to check)\n'
  exit 0
fi

# ── Extract module column headers ────────────────────────────────────────────
# Header row: first table row in the matrix, containing M-NNN tokens.
# We pick the first line that has "|" and an M- token.
HEADER_ROW=$(echo "$MATRIX_LINES" | grep -m1 'M-[0-9]' | grep '|' || true)

if [ -z "$HEADER_ROW" ]; then
  printf 'WARNING: no module header row found in Feature-Module Mapping matrix — checks skipped\n' >&2
  printf 'OK 0 findings (no matrix header)\n'
  exit 0
fi

# Extract M-NNN tokens from header row (preserving order)
MODULE_IDS=$(echo "$HEADER_ROW" | grep -oE 'M-[0-9]{3}' || true)

if [ -z "$MODULE_IDS" ]; then
  printf 'WARNING: no M-NNN identifiers in matrix header — checks skipped\n' >&2
  printf 'OK 0 findings\n'
  exit 0
fi

# Build an indexed array of module IDs (space-separated, in order)
MODULE_IDS_LIST=""
for mid in $MODULE_IDS; do
  MODULE_IDS_LIST="$MODULE_IDS_LIST $mid"
done
MODULE_IDS_LIST="${MODULE_IDS_LIST# }"  # trim leading space

# ── Determine column index for each M-NNN ───────────────────────────────────
# We need to know which pipe-delimited column position each M-NNN occupies in
# the header row so we can read the same position from data rows.
#
# Strategy: split header row on '|', iterate cells, find first cell containing
# each M-NNN.
#
# Store results in a temp file: "M-NNN colindex" per line (1-based pipe cols).
TMP_COL_MAP=$(mktemp /tmp/x5-colmap-XXXXXX)

# Python-free column mapping using awk
echo "$HEADER_ROW" | awk '
BEGIN { FS="|" }
{
  for (i=1; i<=NF; i++) {
    cell=$i
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
    if (match(cell, /M-[0-9]{3}/)) {
      mid=substr(cell, RSTART, RLENGTH)
      printf "%s %d\n", mid, i
    }
  }
}
' > "$TMP_COL_MAP"

# ── Extract data rows (F-NNN rows) ───────────────────────────────────────────
# A data row has "|" and an F- token in the first cell.
# Skip separator rows (containing only dashes/colons/pipes).

TMP_DATA_ROWS=$(mktemp /tmp/x5-datarows-XXXXXX)
echo "$MATRIX_LINES" | grep '|' | grep -v '^[[:space:]]*|[-: |]*|[[:space:]]*$' | grep 'F-[0-9]' > "$TMP_DATA_ROWS" || true

# ── Build cell map: for each (F-NNN, M-NNN) store the cell symbol ─────────────
# cell_symbol[F-NNN M-NNN] = "✦" | "△" | ""
TMP_CELL_MAP=$(mktemp /tmp/x5-cellmap-XXXXXX)

while IFS= read -r row; do
  # Extract the F-NNN from the first data cell
  f_id=$(echo "$row" | awk 'BEGIN{FS="|"} {for(i=1;i<=NF;i++){if($i~/F-[0-9]{3}/){match($i,/F-[0-9]{3}/); print substr($i,RSTART,RLENGTH); exit}}}')
  [ -z "$f_id" ] && continue

  # For each M-NNN, look up its column index and read the cell
  while IFS=' ' read -r mid col_idx; do
    # Extract the cell at col_idx from this row
    cell=$(echo "$row" | awk -v col="$col_idx" 'BEGIN{FS="|"} {cell=$col; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell); print cell}')
    # Determine symbol
    if printf '%s' "$cell" | grep -q '✦'; then
      symbol="✦"
    elif printf '%s' "$cell" | grep -q '△'; then
      symbol="△"
    else
      symbol=""
    fi
    printf '%s %s %s\n' "$f_id" "$mid" "$symbol"
  done < "$TMP_COL_MAP"

done < "$TMP_DATA_ROWS" > "$TMP_CELL_MAP"

# ---------------------------------------------------------------------------
# Collect PRD feature IDs
# ---------------------------------------------------------------------------
PRD_FEATURE_IDS=""
if [ -n "$PRD_PATH" ]; then
  for feat_file in "$PRD_FEATURES_DIR"/F-*.md; do
    [ -e "$feat_file" ] || continue
    # Extract F-NNN from filename (e.g. F-001-some-slug.md → F-001)
    f_id=$(basename "$feat_file" | grep -oE '^F-[0-9]{3}')
    [ -z "$f_id" ] && continue
    PRD_FEATURE_IDS="$PRD_FEATURE_IDS $f_id"
  done
  PRD_FEATURE_IDS="${PRD_FEATURE_IDS# }"
fi

# ---------------------------------------------------------------------------
# FINDING tracking
# ---------------------------------------------------------------------------
FINDING_COUNT=0
HAS_BLOCKER=0

record_finding() {
  local severity="$1"
  FINDING_COUNT=$((FINDING_COUNT + 1))
  if [ "$severity" = "blocker" ]; then
    HAS_BLOCKER=1
  fi
}

# ---------------------------------------------------------------------------
# Check 1: every PRD F-NNN must appear in at least one matrix cell (✦ or △)
# ---------------------------------------------------------------------------
if [ -n "$PRD_FEATURE_IDS" ]; then
  for f_id in $PRD_FEATURE_IDS; do
    # Check if any matrix row covers this F-NNN
    has_cell=$(grep "^${f_id} " "$TMP_CELL_MAP" | grep -v ' $' | grep -E ' (✦|△)$' || true)
    if [ -z "$has_cell" ]; then
      severity="blocker"
      record_finding "$severity"
      emit_lint \
        "$severity" \
        "CR-X5" \
        "README.md" \
        "## Feature-Module Mapping" \
        "PRD feature ${f_id} has no module allocation in the Feature-Module Mapping matrix" \
        "PRD feature ${f_id} was found in \`${PRD_FEATURES_DIR}\` but has no ✦ or △ symbol in any column of the Feature-Module Mapping matrix in \`README.md\`.

Per CR-X5 (structural-lint.md §X5), every PRD feature MUST be allocated to at least one module (✦ = implements/modifies, △ = read-only dependency). A feature with zero allocation cannot be planned or implemented by \`/autoforge\`." \
        "Add ${f_id} as a row in the \`## Feature-Module Mapping\` matrix in \`README.md\` and mark at least one module column with ✦ (if the module mutates/creates data for this feature) or △ (read-only usage). Then update the owning module's \`## Source Features\` section to include ${f_id}." \
        > /dev/null
    fi
  done
fi

# ---------------------------------------------------------------------------
# Check 2: for each M-NNN in the matrix, its modules/M-NNN.md "## Source
# Features" section must list exactly the F-NNN IDs that have ✦ in the matrix
# for that module's column.
# ---------------------------------------------------------------------------
for mid in $MODULE_IDS_LIST; do
  # Find the module file (may have a slug suffix)
  module_file=""
  for mf in "$MODULES_DIR"/"${mid}"-*.md "$MODULES_DIR"/"${mid}".md; do
    if [ -f "$mf" ]; then
      module_file="$mf"
      break
    fi
  done

  if [ -z "$module_file" ]; then
    # Module file doesn't exist — this is a different lint class (not X5).
    # Skip silently; X5 only checks the traceability agreement.
    continue
  fi

  rel_module="modules/$(basename "$module_file")"

  # ── Collect F-NNN IDs that have ✦ in the matrix for this module ──────────
  MATRIX_MARKED=$(grep " ${mid} ✦$" "$TMP_CELL_MAP" | awk '{print $1}' | sort -u || true)

  # ── Parse "## Source Features" section from the module file ───────────────
  # Accept either the header block form:  > **Source Features:** F-001, F-003
  # or the section form:                  ## Source Features\n- [F-NNN: …](…)
  #
  # We collect ALL F-NNN references in either location.
  SOURCE_FEATURES_SECTION=$(awk '
    /^## Source Features/ { in_section=1; next }
    in_section && /^## / { in_section=0 }
    in_section { print }
  ' "$module_file")

  # Also check the header callout line: "> **Source Features:** F-001, F-003"
  HEADER_SF_LINE=$(grep -E '^\s*>\s*\*\*Source Features:\*\*' "$module_file" || true)

  # Combine and extract all F-NNN tokens
  SOURCE_FEATURES_IDS=$(
    { echo "$SOURCE_FEATURES_SECTION"; echo "$HEADER_SF_LINE"; } \
    | grep -oE 'F-[0-9]{3}' | sort -u
  )

  # ── Compare matrix ✦ set vs Source Features set ───────────────────────────
  # Violation: F-NNN appears in Source Features but matrix cell is NOT ✦.
  # (It could be blank or △.)
  for sf_id in $SOURCE_FEATURES_IDS; do
    # Lookup cell symbol
    cell_symbol=$(grep "^${sf_id} ${mid} " "$TMP_CELL_MAP" | awk '{print $3}' || true)
    cell_symbol="${cell_symbol:-}"  # empty if not found

    if [ "$cell_symbol" != "✦" ]; then
      severity="mechanical"
      record_finding "$severity"
      if [ "$cell_symbol" = "△" ]; then
        mismatch_desc="matrix cell is △ (read-only) but module claims full ownership via Source Features"
      elif [ -z "$cell_symbol" ]; then
        mismatch_desc="matrix cell is blank (no allocation) but module lists ${sf_id} in Source Features"
      else
        mismatch_desc="matrix cell contains unexpected symbol '${cell_symbol}'; expected ✦"
      fi
      emit_lint \
        "$severity" \
        "CR-X5" \
        "$rel_module" \
        "## Source Features" \
        "${mid} Source Features lists ${sf_id} but matrix cell (${sf_id}, ${mid}) is not ✦" \
        "\`${rel_module}\` lists \`${sf_id}\` in its \`## Source Features\` section, but the Feature-Module Mapping matrix in \`README.md\` does not have ✦ at the intersection of row \`${sf_id}\` and column \`${mid}\` (${mismatch_desc}).

Per CR-X5 (structural-lint.md §X5), the Source Features section and the matrix ✦ cells must be in bidirectional agreement: if a module lists a feature in Source Features, the matrix must mark that cell ✦." \
        "Choose one of:
A) If ${mid} truly modifies/creates data for ${sf_id}: update the Feature-Module Mapping matrix in \`README.md\` to mark the (${sf_id}, ${mid}) cell with ✦.
B) If ${mid} only has a read-only dependency on ${sf_id}: change the matrix cell to △ and remove ${sf_id} from \`${rel_module}\`'s \`## Source Features\` section.
C) If ${mid} has no relation to ${sf_id}: remove ${sf_id} from \`${rel_module}\`'s \`## Source Features\` section." \
        > /dev/null
    fi
  done

  # ── Reverse check: matrix ✦ entries with no Source Features listing ────────
  # This is also a mechanical violation (module's Source Features is incomplete).
  for matrix_f in $MATRIX_MARKED; do
    # Check if this F-NNN appears in the module's Source Features
    if ! echo "$SOURCE_FEATURES_IDS" | grep -qE "^${matrix_f}$"; then
      severity="mechanical"
      record_finding "$severity"
      emit_lint \
        "$severity" \
        "CR-X5" \
        "$rel_module" \
        "## Source Features" \
        "Matrix marks (${matrix_f}, ${mid}) as ✦ but ${mid} does not list ${matrix_f} in Source Features" \
        "The Feature-Module Mapping matrix in \`README.md\` marks the cell at row \`${matrix_f}\`, column \`${mid}\` as ✦ (modifies/creates data), but \`${rel_module}\`'s \`## Source Features\` section does not include \`${matrix_f}\`.

Per CR-X5 (structural-lint.md §X5), every module with a ✦ cell in the matrix must list the corresponding feature in its Source Features section so that coding agents can trace the requirement back to the PRD." \
        "Add a \`## Source Features\` entry for \`${matrix_f}\` in \`${rel_module}\`.  The entry should include a relative path link to the PRD feature file (e.g. \`[${matrix_f}: Feature Name](../../../prd/YYYY-MM-DD-{slug}/features/${matrix_f}-{slug}.md)\`) and a note describing which part of the feature this module implements." \
        > /dev/null
    fi
  done
done

# ---------------------------------------------------------------------------
# Cleanup temp files
# ---------------------------------------------------------------------------
rm -f "$TMP_COL_MAP" "$TMP_DATA_ROWS" "$TMP_CELL_MAP"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$FINDING_COUNT" -eq 0 ]; then
  printf 'OK 0 findings\n'
  exit 0
fi

printf 'FAIL %d findings\n' "$FINDING_COUNT"
if [ "$HAS_BLOCKER" -eq 1 ] || [ "$STRICT" -eq 1 ]; then
  exit 1
fi
exit 0
