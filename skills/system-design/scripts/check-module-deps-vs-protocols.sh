#!/usr/bin/env bash
# check-module-deps-vs-protocols.sh — CR-X1 (module-deps-vs-protocols)
#
# Usage:
#   check-module-deps-vs-protocols.sh <design-dir> [--quiet] [--strict]
#
# What it does:
#   Bidirectional sync check between every module's "## Module Deps" (or
#   "Deps (direct)") section and <design-dir>/README.md's
#   "## Module Interaction Protocols" table.
#
#   Step 1 — Parse every <design-dir>/modules/M-*.md:
#     - Extract the module slug from the filename (M-NNN-{slug}).
#     - Extract sibling M-NNN references from the module's Deps cell.
#   Step 2 — Build set A = {(caller_slug, callee_slug)} from all module deps.
#   Step 3 — Parse <design-dir>/README.md "## Module Interaction Protocols"
#     table: extract Caller → Callee column (format "M-NNN ... → M-NNN ...").
#   Step 4 — Build set B = {(caller_id, callee_id)} from README rows.
#   Step 5 — Findings = (A − B) ∪ (B − A). Each finding emits one LINT-NNN.md.
#
#   Both missing-from-README and missing-from-Deps directions are blockers
#   (CR-X1 severity: blocker).
#
# Flags:
#   --quiet   Suppress per-issue stdout lines; print only final summary.
#   --strict  Exit 1 if any issues found (default: exit 1 on blockers only,
#             which for X1 is always — all X1 findings are blockers).
#
# Exit codes:
#   0  No findings.
#   1  At least one finding (X1 findings are always blockers).
#   2  Usage / environment error.
#
# Notes / limitations:
#   - Module slug is extracted from the filename; the script uses the full
#     "M-NNN-slug" token for display but compares by M-NNN ID only.
#   - The Deps section is detected by any heading matching:
#       ## Dependencies, ## Module Deps, ## Deps, ## Deps (direct)
#     Dep entries are any M-NNN tokens on lines inside that section until
#     the next ## heading (or EOF).
#   - The Module Interaction Protocols table Caller → Callee column is
#     parsed by extracting the first M-NNN token and the M-NNN token after
#     the "→" or "->" separator on each data row.
#   - Rows with a cross-cutting exemption annotation ("(cross-cutting)" or
#     "consumer-side interface") in either module's Deps cell are still
#     included in set A — the exemption must be documented as a proper
#     Protocols row per design-template.md rules.
#   - The README "Module Index" table also contains M-NNN in a Deps column;
#     that column is NOT used — only the "## Module Interaction Protocols"
#     table is the source of truth for set B.
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
# Ensure .reviews/ directory exists and get next LINT sequence number
# ---------------------------------------------------------------------------
REVIEWS_DIR="$DESIGN_DIR/.reviews"
mkdir -p "$REVIEWS_DIR"

_next_seq() {
  local max=0
  local f n base
  for f in "$REVIEWS_DIR"/LINT-*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    n="${base#LINT-}"
    # Strip leading zeros to avoid octal interpretation
    n=$(printf '%d' "0x$(printf '%s' "$n" | sed 's/^0*//' | grep . || echo 0)" 2>/dev/null) || \
      n=$(echo "$n" | sed 's/^0*//' | grep -E '^[0-9]+$' || echo 0)
    # Safer arithmetic: use expr to avoid octal
    n=$(expr "$n" + 0 2>/dev/null || echo 0)
    if [ "$n" -gt "$max" ]; then max="$n"; fi
  done
  echo "$max"
}

SEQ=$(_next_seq)

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Helper: emit a LINT issue file for one (caller, callee) pair finding
#
# Args:
#   $1 — direction: "A_not_B" (in Deps but not in Protocols) |
#                   "B_not_A" (in Protocols but not in Deps)
#   $2 — caller_id  (e.g. M-003)
#   $3 — callee_id  (e.g. M-007)
#   $4 — caller_file (relative path, e.g. modules/M-003-tasks.md) or "README.md"
#   $5 — callee_file (relative path) or "README.md"
# ---------------------------------------------------------------------------
emit_issue() {
  local direction="$1"
  local caller_id="$2"
  local callee_id="$3"
  local caller_file="$4"
  local callee_file="$5"

  SEQ=$(( SEQ + 1 ))
  local seq_str
  seq_str=$(printf '%03d' "$SEQ")
  local issue_file="$REVIEWS_DIR/LINT-${seq_str}.md"

  local reasoning suggested_fix files_list

  if [ "$direction" = "A_not_B" ]; then
    reasoning="${caller_id} declares a dep on ${callee_id} in its Module Deps section but README.md's \"## Module Interaction Protocols\" table has no row for ${caller_id} → ${callee_id}."
    suggested_fix="Add a row to README.md's \`## Module Interaction Protocols\` table for \`${caller_id} → ${callee_id}\`. The row must fill all columns: Interaction, Caller → Callee, Method, Data Format, Error Strategy, Contract Test. If this pair is wired via a consumer-side interface or cross-cutting note, annotate the Deps cell accordingly AND add a dedicated row with Method = \"consumer-side interface (Wire-injected)\" per design-template.md rules."
    files_list="${caller_file}, README.md"
  else
    reasoning="README.md's \"## Module Interaction Protocols\" table has a row for ${caller_id} → ${callee_id} but no module's Deps section declares this dep pair."
    suggested_fix="Either (a) add the dep declaration to ${caller_id}'s Module Deps section (format: \"Depends on: [${callee_id}](./...) — {reason}\") to make the protocol row traceable, or (b) remove the orphaned row from the \"## Module Interaction Protocols\" table in README.md if the interaction no longer exists."
    files_list="${caller_file}, README.md"
  fi

  cat > "$issue_file" <<ISSUE
# Lint Issue LINT-${seq_str}

- **Severity**: blocker
- **CR-id**: CR-X1
- **Files**: ${files_list}
- **Pair**: ${caller_id} → ${callee_id}
- **Direction**: ${direction}

## Reasoning

${reasoning}

Per design-template.md Module Interaction Protocols sync rule:
> "every (caller, callee) pair that appears in any module's Deps (direct) cell MUST have a corresponding row here, and vice versa. Bidirectional sync is enforced at review time."

## Suggested Fix

${suggested_fix}
ISSUE

  if [ "$QUIET" -eq 0 ]; then
    if [ "$direction" = "A_not_B" ]; then
      printf '  [CR-X1] blocker: %s → %s  in Deps but missing from README Protocols → %s\n' \
        "$caller_id" "$callee_id" "LINT-${seq_str}.md" >&2
    else
      printf '  [CR-X1] blocker: %s → %s  in README Protocols but no module declares this dep → %s\n' \
        "$caller_id" "$callee_id" "LINT-${seq_str}.md" >&2
    fi
  fi

  # Accumulate JSON finding
  _jfiles=$(printf '%s' "$files_list" | sed 's/"/\\"/g')
  _jreasoning=$(printf '%s' "$reasoning" | sed 's/"/\\"/g; s/\n/ /g')
  _jsugfix=$(printf '%s' "$suggested_fix" | sed 's/"/\\"/g; s/\n/ /g')
  _jentry="{\"criterion_id\":\"CR-X1\",\"file\":\"${_jfiles}\",\"severity\":\"blocker\",\"description\":\"${_jreasoning}\",\"suggested_fix\":\"${_jsugfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Step 1+2: Parse every M-*.md and build set A = {caller_id:callee_id}
#
# For each module file:
#   - Determine caller_id from filename (M-NNN portion).
#   - Find the Deps section heading and collect M-NNN tokens until next ##.
# ---------------------------------------------------------------------------
[ "$QUIET" -eq 0 ] && printf 'CR-X1 — checking module deps vs README protocols in: %s\n' "$DESIGN_DIR" >&2

# Associative array: key = "caller_id:callee_id", value = caller_relative_file
declare -A SET_A

# Map: module_id -> relative file path
declare -A MOD_ID_TO_FILE

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

# Build MOD_ID_TO_FILE map
for f in "${MODULE_FILES[@]}"; do
  base="$(basename "$f")"
  mod_id="$(printf '%s\n' "$base" | grep -Eo '^M-[0-9]+' || true)"
  [ -z "$mod_id" ] && continue
  MOD_ID_TO_FILE["$mod_id"]="modules/${base}"
done

# Parse each module file for its Deps section
for module_file in "${MODULE_FILES[@]}"; do
  base="$(basename "$module_file")"
  caller_id="$(printf '%s\n' "$base" | grep -Eo '^M-[0-9]+' || true)"
  [ -z "$caller_id" ] && continue

  rel_file="modules/${base}"

  # Extract the Deps section using awk:
  # Matches headings: "## Dependencies", "## Module Deps", "## Deps",
  # "## Deps (direct)", "## Internal (modules)" (Dependencies subsection)
  # Collect content until the next ## heading (not subheadings of Deps).
  #
  # We use a two-pass approach:
  #   Pass A: find lines inside any Deps-like section
  #   Then grep those lines for M-NNN tokens (excluding the caller itself)
  deps_section=$(awk '
    /^##[[:space:]]+(Dependencies|Module[[:space:]]+Deps|Deps(\s.*)?|Internal\s+\(modules\))([[:space:]]|$)/ {
      in_section = 1; next
    }
    in_section && /^##[[:space:]]/ { in_section = 0 }
    in_section { print }
  ' "$module_file")

  if [ -z "$deps_section" ]; then
    continue
  fi

  # Extract M-NNN tokens from the deps section, excluding the caller itself
  while IFS= read -r callee_id; do
    [ -z "$callee_id" ] && continue
    [ "$callee_id" = "$caller_id" ] && continue
    SET_A["${caller_id}:${callee_id}"]="$rel_file"
  done < <(printf '%s\n' "$deps_section" | grep -Eo '\bM-[0-9]+\b' | sort -u || true)
done

[ "$QUIET" -eq 0 ] && printf '  set A (module deps pairs): %d\n' "${#SET_A[@]}" >&2

# ---------------------------------------------------------------------------
# Step 3+4: Parse README.md "## Module Interaction Protocols" table
# Build set B = {caller_id:callee_id}
#
# Table format (design-template.md):
#   | Interaction | Caller → Callee | Method | Data Format | Error Strategy | Contract Test |
#
# The "Caller → Callee" column contains values like:
#   "M-001 → M-002"   or   "M-001 → M-002 (some note)"
#
# We extract the first M-NNN before the "→" or "->" and the first M-NNN after it.
# ---------------------------------------------------------------------------
declare -A SET_B
# Map: "caller_id:callee_id" -> row text for diagnostics
declare -A SET_B_ROW

protocols_section=$(awk '
  /^##[[:space:]]+Module[[:space:]]+Interaction[[:space:]]+Protocols([[:space:]]|$)/ {
    in_section = 1; next
  }
  in_section && /^##[[:space:]]/ { in_section = 0 }
  in_section { print }
' "$README_FILE")

if [ -z "$protocols_section" ]; then
  [ "$QUIET" -eq 0 ] && printf '  INFO: README.md has no "## Module Interaction Protocols" section — set B is empty.\n' >&2
else
  # Parse table rows: lines starting with |, skip header and separator rows
  while IFS= read -r row; do
    # Skip separator rows (cells that are only dashes/colons/spaces)
    if printf '%s\n' "$row" | grep -qE '^\|[-: |]+\|'; then
      continue
    fi
    # Skip header row (contains "Caller" as a word)
    if printf '%s\n' "$row" | grep -qi '\bCaller\b'; then
      continue
    fi
    # Must be a table data row
    if ! printf '%s\n' "$row" | grep -qE '^\|'; then
      continue
    fi

    # Extract the "Caller → Callee" column (column 2 — after the Interaction column)
    # Use awk to get cell 2
    caller_callee_cell=$(printf '%s\n' "$row" | awk -F'|' '{
      gsub(/^[ \t]+|[ \t]+$/, "", $3)
      print $3
    }')

    [ -z "$caller_callee_cell" ] && continue

    # Extract first M-NNN before → or ->
    readme_caller=$(printf '%s\n' "$caller_callee_cell" | \
      grep -Eo '^[[:space:]]*M-[0-9]+' | grep -Eo 'M-[0-9]+' | head -1 || true)
    # Extract first M-NNN after → or ->
    readme_callee=$(printf '%s\n' "$caller_callee_cell" | \
      sed 's/.*[→>]//' | grep -Eo 'M-[0-9]+' | head -1 || true)

    [ -z "$readme_caller" ] && continue
    [ -z "$readme_callee" ] && continue

    SET_B["${readme_caller}:${readme_callee}"]="1"
    SET_B_ROW["${readme_caller}:${readme_callee}"]="${row}"
  done < <(printf '%s\n' "$protocols_section")
fi

[ "$QUIET" -eq 0 ] && printf '  set B (README protocol rows): %d\n' "${#SET_B[@]}" >&2

# ---------------------------------------------------------------------------
# Step 5: Compute findings = (A − B) ∪ (B − A)
# ---------------------------------------------------------------------------
TOTAL_ISSUES=0

[ "$QUIET" -eq 0 ] && printf '\n' >&2

# A − B: pairs in module Deps but missing from README Protocols
for key in "${!SET_A[@]}"; do
  if [ -z "${SET_B[$key]+set}" ]; then
    caller_id="${key%%:*}"
    callee_id="${key##*:}"
    caller_file="${SET_A[$key]}"
    callee_file="${MOD_ID_TO_FILE[$callee_id]:-README.md}"
    emit_issue "A_not_B" "$caller_id" "$callee_id" "$caller_file" "$callee_file"
    TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))
  fi
done

# B − A: pairs in README Protocols but no module declares the dep
for key in "${!SET_B[@]}"; do
  if [ -z "${SET_A[$key]+set}" ]; then
    caller_id="${key%%:*}"
    callee_id="${key##*:}"
    caller_file="${MOD_ID_TO_FILE[$caller_id]:-README.md}"
    callee_file="${MOD_ID_TO_FILE[$callee_id]:-README.md}"
    emit_issue "B_not_A" "$caller_id" "$callee_id" "$caller_file" "$callee_file"
    TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
[ "$QUIET" -eq 0 ] && printf '\n'

if [ "$TOTAL_ISSUES" -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && printf 'CR-X1 PASS — module deps and README Module Interaction Protocols are in sync (%d modules, %d protocol rows).\n' \
    "${#MODULE_FILES[@]}" "${#SET_B[@]}" >&2
  printf '[]\n'
  exit 0
else
  printf 'CR-X1 FINDINGS — %d bidirectional sync violation(s) (all blocker).\n' "$TOTAL_ISSUES" >&2
  printf '  Issue files written to: %s\n' "$REVIEWS_DIR" >&2
  printf '[%s]\n' "$JSON_FINDINGS"
  exit 1
fi
