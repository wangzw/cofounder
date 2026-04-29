#!/usr/bin/env bash
# check-dependency-layering.sh — CR-X6 (dependency-layering-forward-only)
#
# Usage:
#   check-dependency-layering.sh <design-dir> [--quiet] [--strict]
#
# What it does:
#   Enforces forward-only dependency layering: no module may import a module
#   that belongs to a higher layer than itself, unless a cross-cutting exemption
#   is explicitly documented in the Dependency Layering table.
#
#   Step 1 — Parse <design-dir>/README.md "## Dependency Layering" table:
#     Extract each module ID (M-NNN) and its layer number from the "Modules"
#     column. Row order determines layers: first row = layer 1, second = layer 2,
#     etc. Also capture the raw row text for cross-cutting exemption detection.
#
#   Step 2 — Parse each <design-dir>/modules/M-*.md "## Module Deps" (or
#     "Deps (direct)", "## Dependencies") section. Extract all M-NNN references.
#
#   Step 3 — For each (caller, callee) dep pair:
#     a. If either module is absent from the Dependency Layering table → emit
#        a blocker finding (severity=blocker, "missing from Dependency Layering table").
#     b. If layer(callee) > layer(caller) → REVERSE IMPORT → blocker (CR-X6).
#     c. If layer(callee) == layer(caller) → same-layer dep. Blocker unless the
#        Dependency Layering table row for either module (or an adjacent note)
#        contains "cross-cutting" or "consumer-side interface" text.
#     d. If layer(callee) < layer(caller) → forward-only dep → OK.
#
# Flags:
#   --quiet   Suppress per-issue stdout lines; print only final summary.
#   --strict  Exit 1 if any issues found (default: exit 1 on blockers only,
#             which for X6 is always — all X6 findings are blockers).
#
# Exit codes:
#   0  No findings.
#   1  At least one blocker finding (or any finding with --strict).
#   2  Usage / environment error.
#
# Notes / limitations:
#   - The Dependency Layering table is detected under the "## Dependency Layering"
#     heading. The table must have a "Modules" column (cols: Layer, Modules,
#     May Depend On — as in design-template.md).
#   - Layer numbers are assigned by row order (1-indexed). The "Layer" column
#     label (e.g. "Types", "Repository") is used only for display messages.
#   - M-NNN tokens in the Deps section are extracted greedily; the caller module
#     itself is excluded from the callee set.
#   - Same-layer cross-cutting exemptions must be noted in the Dependency Layering
#     table (the row text for the modules, or a cross-cutting note paragraph
#     immediately following the table in the "## Dependency Layering" section).
#     The check searches for the strings "cross-cutting" or "consumer-side
#     interface" anywhere in that section within ±5 rows of either module's row.
#
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
      printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then
        DESIGN_DIR="$arg"
      else
        printf 'ERROR: unexpected positional argument: %s\n' "$arg" >&2
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
  printf 'ERROR: design directory not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
MODULES_DIR="$DESIGN_DIR/modules"
README_FILE="$DESIGN_DIR/README.md"

if [ ! -d "$MODULES_DIR" ]; then
  [ "$QUIET" -eq 0 ] && printf 'INFO: no modules/ directory found under %s — nothing to check.\n' "$DESIGN_DIR" >&2
  printf '[]\n'
  exit 0
fi

if [ ! -f "$README_FILE" ]; then
  printf 'ERROR: README.md not found in design directory: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# JSON findings accumulator
# ---------------------------------------------------------------------------
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Temp files (cleaned on exit)
# ---------------------------------------------------------------------------
TMP_LAYER_TABLE="$(mktemp /tmp/crl_layer_XXXXXX)"
TMP_LAYER_SECTION="$(mktemp /tmp/crl_lsec_XXXXXX)"
trap 'rm -f "$TMP_LAYER_TABLE" "$TMP_LAYER_SECTION"' EXIT

# ---------------------------------------------------------------------------
# Step 1 — Parse README.md "## Dependency Layering" table
#
# Extract the full Dependency Layering section for cross-cutting text search,
# and build:
#   MOD_TO_LAYER[M-NNN]  = integer layer number (1-indexed by row order)
#   MOD_TO_LABEL[M-NNN]  = layer label (e.g. "Types", "Repository")
# ---------------------------------------------------------------------------
[ "$QUIET" -eq 0 ] && printf 'CR-X6 — checking dependency layering in: %s\n' "$DESIGN_DIR" >&2

# Extract the Dependency Layering section (stop at next ## heading or EOF)
awk '
  /^##[[:space:]]+Dependency[[:space:]]+Layering([[:space:]]|$)/ { in_section=1; next }
  in_section && /^##[[:space:]]/ { in_section=0 }
  in_section { print }
' "$README_FILE" > "$TMP_LAYER_SECTION"

if [ ! -s "$TMP_LAYER_SECTION" ]; then
  [ "$QUIET" -eq 0 ] && printf 'INFO: README.md has no "## Dependency Layering" section — cannot check X6.\n' >&2
  # All modules missing from table will be flagged below (set A loop with empty MOD_TO_LAYER)
fi

# Parse the table rows: format is | Layer | Modules | May Depend On |
# Layer number is assigned by row order (row 1 = layer 1, etc.)
# We capture the "Layer" label from column 1 and M-NNN IDs from column 2.
declare -A MOD_TO_LAYER   # M-NNN -> integer layer
declare -A MOD_TO_LABEL   # M-NNN -> layer label string

_layer_row=0
while IFS= read -r row; do
  # Skip separator rows and header row
  if printf '%s\n' "$row" | grep -qE '^\|[-: |]+\|'; then
    continue
  fi
  if printf '%s\n' "$row" | grep -qi '\bLayer\b'; then
    continue
  fi
  if ! printf '%s\n' "$row" | grep -qE '^\|'; then
    continue
  fi
  # Must contain at least one M-NNN token to be a data row
  if ! printf '%s\n' "$row" | grep -qE '\bM-[0-9]+\b'; then
    continue
  fi

  _layer_row=$(( _layer_row + 1 ))

  # Extract layer label from column 1
  layer_label=$(printf '%s\n' "$row" | awk -F'|' '{
    gsub(/^[ \t]+|[ \t]+$/, "", $2)
    print $2
  }')

  # Extract all M-NNN tokens from column 2 (Modules cell)
  modules_cell=$(printf '%s\n' "$row" | awk -F'|' '{
    gsub(/^[ \t]+|[ \t]+$/, "", $3)
    print $3
  }')

  while IFS= read -r mod_id; do
    [ -z "$mod_id" ] && continue
    MOD_TO_LAYER["$mod_id"]="$_layer_row"
    MOD_TO_LABEL["$mod_id"]="$layer_label"
  done < <(printf '%s\n' "$modules_cell" | grep -Eo '\bM-[0-9]+\b' || true)

done < "$TMP_LAYER_SECTION"

[ "$QUIET" -eq 0 ] && printf '  Dependency Layering table: %d layer(s), %d module entries\n' \
  "$_layer_row" "${#MOD_TO_LAYER[@]}" >&2

# ---------------------------------------------------------------------------
# Helper: check if a cross-cutting exemption is documented for a same-layer pair
#
# We search the full Dependency Layering section text for the strings
# "cross-cutting" or "consumer-side interface". Additionally, we search the
# individual module files for those strings in their Deps section.
# If either location contains the exemption marker → exempt.
#
# Args: $1=caller_id  $2=callee_id  $3=caller_module_file
# Returns: 0 (exempt) or 1 (not exempt)
# ---------------------------------------------------------------------------
_has_crosscutting_exemption() {
  local caller_id="$1"
  local callee_id="$2"
  local caller_file="$3"

  # Search the Dependency Layering section for cross-cutting/consumer-side interface
  if grep -qiE '(cross-cutting|consumer-side[[:space:]]+interface)' "$TMP_LAYER_SECTION" 2>/dev/null; then
    # Further: check that the exemption is near the relevant modules
    # Search for a line mentioning the caller or callee adjacent to cross-cutting text
    if grep -E "(${caller_id}|${callee_id})" "$TMP_LAYER_SECTION" 2>/dev/null | \
        grep -qiE '(cross-cutting|consumer-side[[:space:]]+interface)'; then
      return 0
    fi
    # Also accept if the section has a cross-cutting block that mentions both modules
    if grep -iE '(cross-cutting|consumer-side[[:space:]]+interface)' "$TMP_LAYER_SECTION" 2>/dev/null | \
        grep -qE "(${caller_id}|${callee_id})"; then
      return 0
    fi
  fi

  # Search the caller's Deps section for cross-cutting/consumer-side interface annotation
  if [ -f "$DESIGN_DIR/$caller_file" ]; then
    local deps_sec
    deps_sec=$(awk '
      /^##[[:space:]]+(Dependencies|Module[[:space:]]+Deps|Deps(\s.*)?|Internal\s+\(modules\))([[:space:]]|$)/ {
        in_section=1; next
      }
      in_section && /^##[[:space:]]/ { in_section=0 }
      in_section { print }
    ' "$DESIGN_DIR/$caller_file")

    if printf '%s\n' "$deps_sec" | grep -qiE '(cross-cutting|consumer-side[[:space:]]+interface)'; then
      return 0
    fi
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Helper: emit a LINT issue file
#
# Args:
#   $1 — issue_type: "reverse_import" | "same_layer" | "missing_from_table"
#   $2 — caller_id  (e.g. M-003)
#   $3 — callee_id  (e.g. M-007)
#   $4 — caller_layer (integer or "?" if unknown)
#   $5 — callee_layer (integer or "?" if unknown)
#   $6 — caller_label (layer name or "unknown")
#   $7 — callee_label (layer name or "unknown")
#   $8 — caller_file (relative path, e.g. modules/M-003-tasks.md)
# ---------------------------------------------------------------------------
emit_issue() {
  local issue_type="$1"
  local caller_id="$2"
  local callee_id="$3"
  local caller_layer="$4"
  local callee_layer="$5"
  local caller_label="$6"
  local callee_label="$7"
  local caller_file="$8"

  local title reasoning suggested_fix files_list

  case "$issue_type" in
    reverse_import)
      title="Reverse-layer import: ${caller_id} (layer ${caller_layer}/${caller_label}) → ${callee_id} (layer ${callee_layer}/${callee_label})"
      reasoning="Module ${caller_id} (layer ${caller_layer}: ${caller_label}) declares a dependency on ${callee_id} (layer ${callee_layer}: ${callee_label}). Because layer(callee) = ${callee_layer} > layer(caller) = ${caller_layer}, this is a reverse-layer import. Per structural-lint.md X6: \"Any edge A → B where layer(B) > layer(A) … is a reverse-layer import\" and severity is always blocker."
      suggested_fix="(a) Extract the interface ${caller_id} needs from ${callee_id} into a lower layer (≤ layer ${caller_layer}) so the dep direction is forward-only. (b) Move ${callee_id} to a lower layer (≤ layer ${caller_layer}) if it has no upward deps of its own. (c) If this is a legitimate cross-cutting wiring pattern (e.g. consumer-side interface via Wire injection), document the exemption in the Dependency Layering section of README.md and annotate the Deps cell in ${caller_id}'s module file."
      files_list="${caller_file}, README.md"
      ;;
    same_layer)
      title="Undocumented same-layer import: ${caller_id} (layer ${caller_layer}/${caller_label}) → ${callee_id} (layer ${callee_layer}/${callee_label})"
      reasoning="Module ${caller_id} (layer ${caller_layer}: ${caller_label}) declares a dependency on ${callee_id} in the same layer (layer ${callee_layer}: ${callee_label}). Same-layer imports are blockers unless a cross-cutting exemption is explicitly documented in the Dependency Layering table (\"cross-cutting\" or \"consumer-side interface\" annotation). No such documentation was found."
      suggested_fix="(a) Document a cross-cutting exemption in the Dependency Layering section of README.md (e.g. add a note naming the pair and the wiring pattern). (b) Annotate the Deps cell in ${caller_id}'s module file with \"(consumer-side interface)\" or \"(cross-cutting)\" so the exemption is traceable. (c) If the same-layer dep indicates a layering design error, extract a shared abstraction into a lower layer."
      files_list="${caller_file}, README.md"
      ;;
    missing_from_table)
      title="Module ${caller_id} missing from Dependency Layering table"
      reasoning="Module ${caller_id} appears in ${caller_file}'s Deps section as a caller (or appears as a callee in another module's Deps) but is not listed in README.md's \"## Dependency Layering\" table. Without a layer assignment, forward-only ordering cannot be verified. Per X6, all modules with deps must be in the table."
      suggested_fix="Add ${caller_id} to the appropriate row in README.md's \"## Dependency Layering\" table (under its architectural layer). If this is a new module, determine its layer from its responsibility and add it to the correct row's Modules cell."
      files_list="${caller_file}, README.md"
      ;;
  esac

  if [ "$QUIET" -eq 0 ]; then
    case "$issue_type" in
      reverse_import)
        printf '  [CR-X6] blocker: %s (layer %s) → %s (layer %s) — reverse-layer import\n' \
          "$caller_id" "$caller_layer" "$callee_id" "$callee_layer" >&2
        ;;
      same_layer)
        printf '  [CR-X6] blocker: %s (layer %s) → %s (layer %s) — same-layer, no cross-cutting exemption\n' \
          "$caller_id" "$caller_layer" "$callee_id" "$callee_layer" >&2
        ;;
      missing_from_table)
        printf '  [CR-X6] blocker: %s missing from Dependency Layering table\n' \
          "$caller_id" >&2
        ;;
    esac
  fi

  # Accumulate JSON finding
  _jfiles=$(printf '%s' "$files_list" | sed 's/"/\\"/g')
  _jreasoning=$(printf '%s' "$reasoning" | sed 's/"/\\"/g; s/\n/ /g')
  _jsugfix=$(printf '%s' "$suggested_fix" | sed 's/"/\\"/g; s/\n/ /g')
  _jentry="{\"criterion_id\":\"CR-X6\",\"file\":\"${_jfiles}\",\"severity\":\"blocker\",\"description\":\"${_jreasoning}\",\"suggested_fix\":\"${_jsugfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Step 2+3 — Parse each M-*.md Deps section; check each (caller, callee) pair
# ---------------------------------------------------------------------------
MODULE_FILES=()
while IFS= read -r -d '' f; do
  MODULE_FILES+=("$f")
done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' -print0 2>/dev/null | sort -z)

if [ "${#MODULE_FILES[@]}" -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && printf 'INFO: no M-*.md files found in %s — nothing to check.\n' "$MODULES_DIR" >&2
  printf '[]\n'
  exit 0
fi

[ "$QUIET" -eq 0 ] && printf '  modules found: %d\n' "${#MODULE_FILES[@]}" >&2

# Track modules flagged as missing-from-table so we emit only one issue per module
declare -A MISSING_FLAGGED

TOTAL_ISSUES=0
[ "$QUIET" -eq 0 ] && printf '\n' >&2

for module_file in "${MODULE_FILES[@]}"; do
  base="$(basename "$module_file")"
  caller_id="$(printf '%s\n' "$base" | grep -Eo '^M-[0-9]+' || true)"
  [ -z "$caller_id" ] && continue

  rel_file="modules/${base}"

  # Extract the Deps section
  deps_section=$(awk '
    /^##[[:space:]]+(Dependencies|Module[[:space:]]+Deps|Deps(\s.*)?|Internal\s+\(modules\))([[:space:]]|$)/ {
      in_section=1; next
    }
    in_section && /^##[[:space:]]/ { in_section=0 }
    in_section { print }
  ' "$module_file")

  [ -z "$deps_section" ] && continue

  # Extract all callee M-NNN tokens (excluding self)
  while IFS= read -r callee_id; do
    [ -z "$callee_id" ] && continue
    [ "$callee_id" = "$caller_id" ] && continue

    # Determine caller layer
    caller_layer="${MOD_TO_LAYER[$caller_id]:-}"
    callee_layer="${MOD_TO_LAYER[$callee_id]:-}"
    caller_label="${MOD_TO_LABEL[$caller_id]:-unknown}"
    callee_label="${MOD_TO_LABEL[$callee_id]:-unknown}"

    # Check: caller missing from table
    if [ -z "$caller_layer" ]; then
      if [ -z "${MISSING_FLAGGED[$caller_id]+set}" ]; then
        emit_issue "missing_from_table" "$caller_id" "$callee_id" \
          "?" "?" "unknown" "unknown" "$rel_file"
        MISSING_FLAGGED["$caller_id"]="1"
        TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))
      fi
      # Cannot determine direction without caller layer; skip further checks for this pair
      continue
    fi

    # Check: callee missing from table
    if [ -z "$callee_layer" ]; then
      if [ -z "${MISSING_FLAGGED[$callee_id]+set}" ]; then
        emit_issue "missing_from_table" "$callee_id" "$caller_id" \
          "?" "?" "unknown" "unknown" "$rel_file"
        MISSING_FLAGGED["$callee_id"]="1"
        TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))
      fi
      continue
    fi

    # Compare layers
    if [ "$callee_layer" -gt "$caller_layer" ]; then
      # Reverse import — always blocker
      emit_issue "reverse_import" "$caller_id" "$callee_id" \
        "$caller_layer" "$callee_layer" "$caller_label" "$callee_label" "$rel_file"
      TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))

    elif [ "$callee_layer" -eq "$caller_layer" ]; then
      # Same-layer dep — blocker unless cross-cutting exemption documented
      if ! _has_crosscutting_exemption "$caller_id" "$callee_id" "$rel_file"; then
        emit_issue "same_layer" "$caller_id" "$callee_id" \
          "$caller_layer" "$callee_layer" "$caller_label" "$callee_label" "$rel_file"
        TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))
      fi
      # else: exempt — OK

    fi
    # callee_layer < caller_layer → forward-only dep, OK — no action

  done < <(printf '%s\n' "$deps_section" | grep -Eo '\bM-[0-9]+\b' | sort -u || true)
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
[ "$QUIET" -eq 0 ] && printf '\n' >&2

if [ "$TOTAL_ISSUES" -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && printf 'CR-X6 PASS — all dep edges are forward-only (%d modules checked).\n' \
    "${#MODULE_FILES[@]}" >&2
  printf '[]\n'
  exit 0
else
  printf 'CR-X6 FINDINGS — %d violation(s) (all blocker).\n' "$TOTAL_ISSUES" >&2
  printf '[%s]\n' "$JSON_FINDINGS"
  if [ "$STRICT" -eq 1 ] || [ "$TOTAL_ISSUES" -gt 0 ]; then
    exit 1
  fi
  exit 0
fi
