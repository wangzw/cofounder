#!/usr/bin/env bash
# check-analytics-coverage.sh — CR-X4 (analytics-coverage)
#
# Lint check: every PRD analytics event enumerated in any PRD feature file's
# "## Analytics" section MUST appear in <design-dir>/README.md's
# "## Analytics Coverage" section as an explicit row, or be covered by a named
# sweep rule that lists the feature IDs and the emitting channel. Unnamed
# blanket rules ("all backend features emit audit events" without feature IDs
# or channel) fail.
#
# PRD path resolution:
#   Read <design-dir>/README.md and look for a relative path to the PRD in a
#   "Source:" line or any markdown link whose href contains "prd/". The first
#   resolvable directory is used. If the PRD path cannot be resolved → skip
#   with a warning; exit 0. If the PRD path resolves but features/ does not
#   exist → skip; exit 0.
#
# Detection:
#   1. For each PRD feature file (${PRD_PATH}/features/F-*.md): locate
#      "## Analytics" section; extract event names from:
#        a) "### event_name" headings within the section, OR
#        b) table rows where the first column is an event name (not a header
#           or separator row). The table must have an "Event" column header.
#   2. Build set A = {(feature_id, event_name)}.
#   3. Parse <design-dir>/README.md "## Analytics Coverage" section: extract
#      event names from table rows (Event column). Also detect named sweep
#      rules of the form "F-NNN..F-NNN ... → channel" that enumerate feature IDs.
#   4. Build set B = {event_name}.
#   5. Missing = A.event_names − B. Each gap → JSON finding on stdout.
#
# Named sweep rules: a row whose Event cell contains a sweep expression like
# "F-001..F-042 → audit.Emit → Log Viewer" is considered to cover any event
# from those feature IDs. Unnamed blanket rules (no feature IDs listed) do NOT
# satisfy coverage — they produce a separate "unnamed sweep" warning.
#
# Usage:
#   check-analytics-coverage.sh <design-dir> [--quiet] [--strict]
#
#   --quiet   Suppress per-issue stdout; only print summary line.
#   --strict  Exit 1 on any violation (blocker or unnamed-sweep warning).
#             Without --strict: exit 1 only when at least one blocker exists.
#
# Exit codes:
#   0  No blockers found (may have unnamed-sweep warnings unless --strict).
#   1  At least one blocker; or --strict with any violation.
#   2  Usage error or <design-dir> not found / not readable.
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_finalize() {
  # §9 contract emission via shared helper.
  SD_LEGACY_FINDINGS="${1-}" exec bash "$SCRIPT_DIR/lib/sd_emit.sh" "(check-analytics-coverage)"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DESIGN_DIR=""
QUIET=1
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
  _finalize ""
fi

# ---------------------------------------------------------------------------
# JSON findings accumulator
# ---------------------------------------------------------------------------
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Helper: emit a finding for a missing event
# Arguments: feature_id event_name
# ---------------------------------------------------------------------------
write_missing_event_issue() {
  local feature_id="$1"
  local event_name="$2"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-X4] blocker  README.md — PRD analytics event `%s` from feature `%s` is missing from Analytics Coverage\n' \
      "$event_name" "$feature_id" >&2
    printf '  Fix: add a row to ## Analytics Coverage\n' >&2
  fi

  # Accumulate JSON finding
  _jfid=$(printf '%s' "$feature_id" | sed 's/"/\\"/g')
  _jevt=$(printf '%s' "$event_name" | sed 's/"/\\"/g')
  _jdesc="PRD analytics event ${_jevt} from feature ${_jfid} is missing from ## Analytics Coverage"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Add a row for event ${_jevt} from feature ${_jfid} to ## Analytics Coverage in README.md"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-X4\",\"file\":\"README.md\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Helper: emit a finding for an unnamed sweep rule
# Arguments: row_text
# ---------------------------------------------------------------------------
write_unnamed_sweep_issue() {
  local row_text="$1"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-X4] mechanical  README.md — unnamed sweep rule in Analytics Coverage: `%s`\n' \
      "$row_text" >&2
    printf '  Fix: list feature IDs and emitting channel\n' >&2
  fi

  # Accumulate JSON finding
  _jrow=$(printf '%s' "$row_text" | sed 's/"/\\"/g')
  _jdesc="Unnamed blanket sweep rule in Analytics Coverage: ${_jrow}"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Replace the blanket rule with explicit rows, or list feature IDs and the emitting channel"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-X4\",\"file\":\"README.md\",\"severity\":\"mechanical\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Step 1 — Resolve PRD path from README.md
# ---------------------------------------------------------------------------
# Strategy (in order):
#   a) "**Source:**" line: **Source:** [{name}]({rel-path}) | ...
#   b) Any markdown link whose href contains "prd/" and resolves to a directory.
#
# We extract candidate relative paths, resolve them relative to DESIGN_DIR,
# and take the first that is an existing directory.

resolve_prd_path() {
  local readme="$1"
  local design_dir="$2"
  local candidate resolved resolved_parent

  # try_resolve: given a candidate path (possibly a file link like ../prd/README.md),
  # attempt to resolve as a directory. If the candidate ends in .md, also try
  # the parent directory. Echoes the resolved absolute path and returns 0 on success.
  _try_resolve() {
    local cand="$1"
    local ddir="$2"
    local rp

    # Direct: candidate itself is a directory
    rp="$(cd "$ddir" 2>/dev/null && cd "$cand" 2>/dev/null && pwd)" || true
    if [ -n "$rp" ] && [ -d "$rp" ]; then
      printf '%s\n' "$rp"
      return 0
    fi

    # If candidate ends in .md, try the parent directory of that file
    case "$cand" in
      *.md)
        local parent_cand
        parent_cand="$(dirname "$cand")"
        rp="$(cd "$ddir" 2>/dev/null && cd "$parent_cand" 2>/dev/null && pwd)" || true
        if [ -n "$rp" ] && [ -d "$rp" ]; then
          printf '%s\n' "$rp"
          return 0
        fi
        ;;
    esac

    return 1
  }

  # Pattern a: **Source:** [...](path)
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="${candidate%/}"
    candidate="${candidate%%#*}"
    case "$candidate" in http*) continue ;; esac
    if _try_resolve "$candidate" "$design_dir"; then
      return 0
    fi
  done < <(grep -oE '\*\*Source:\*\*[^\n]*' "$readme" 2>/dev/null \
           | grep -oE '\([^)]+\)' | tr -d '()' | grep -v '^http' | head -5)

  # Pattern b: any markdown link path containing "prd/"
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="${candidate%/}"
    candidate="${candidate%%#*}"
    case "$candidate" in http*) continue ;; esac
    if _try_resolve "$candidate" "$design_dir"; then
      return 0
    fi
  done < <(grep -oE '\([^)]*prd/[^)]*\)' "$readme" 2>/dev/null | tr -d '()' | head -10)

  return 1
}

PRD_PATH=""
if ! PRD_PATH="$(resolve_prd_path "$README" "$DESIGN_DIR")"; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'SKIP: PRD path not resolvable from %s — skipping CR-X4 check\n' "$README" >&2
  fi
  _finalize ""
fi

FEATURES_DIR="${PRD_PATH}/features"
if [ ! -d "$FEATURES_DIR" ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'SKIP: PRD features/ directory not found at %s — skipping CR-X4 check\n' "$FEATURES_DIR" >&2
  fi
  _finalize ""
fi

# ---------------------------------------------------------------------------
# Step 2 — Extract analytics events from each PRD feature file
# ---------------------------------------------------------------------------
# For each features/F-*.md:
#   Locate the "## Analytics" section (ends at next ## heading or EOF).
#   Within that section, extract event names via:
#     a) "### event_name" headings  (heading-style event declarations)
#     b) Table rows whose first column is a non-header, non-separator value,
#        when the table header row contains an "Event" column.
#
# Result: parallel arrays FEAT_IDS and FEAT_EVENTS (one entry per event found).

declare -a FEAT_IDS=()
declare -a FEAT_EVENTS=()

extract_analytics_events() {
  # Usage: extract_analytics_events <feature_file> <feature_id>
  # Appends to FEAT_IDS / FEAT_EVENTS (global arrays).
  local ffile="$1"
  local fid="$2"
  local in_analytics=0
  local event_col_idx=0
  local header_found=0
  local line

  while IFS= read -r line; do
    # Detect entry: "## Analytics" (any casing after ##, but typically "Analytics")
    if printf '%s\n' "$line" | grep -qE '^##[[:space:]]+Analytics'; then
      in_analytics=1
      event_col_idx=0
      header_found=0
      continue
    fi

    # Detect exit: any other ## heading
    if [ "$in_analytics" -eq 1 ] && printf '%s\n' "$line" | grep -qE '^##[[:space:]]'; then
      in_analytics=0
      event_col_idx=0
      header_found=0
      continue
    fi

    [ "$in_analytics" -eq 0 ] && continue

    # Pattern a: "### event_name" headings
    if printf '%s\n' "$line" | grep -qE '^###[[:space:]]+'; then
      local event_name
      event_name="$(printf '%s\n' "$line" | sed -E 's/^###[[:space:]]*//')"
      event_name="$(printf '%s\n' "$event_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [ -n "$event_name" ]; then
        FEAT_IDS+=( "$fid" )
        FEAT_EVENTS+=( "$event_name" )
      fi
      continue
    fi

    # Pattern b: table rows in "## Analytics" section
    # The table must have an "Event" column header.
    if printf '%s\n' "$line" | grep -qE '^\|'; then
      # Separator row — skip
      if printf '%s\n' "$line" | grep -qE '^\|[-|: ]+\|'; then
        continue
      fi

      # Detect header row: contains "Event" as a column name
      if [ "$header_found" -eq 0 ]; then
        # Look for "Event" in one of the pipe-delimited cells
        local header_lower
        header_lower="$(printf '%s\n' "$line" | tr '[:upper:]' '[:lower:]')"
        if printf '%s\n' "$header_lower" | grep -qE '\|\s*event\s*\|'; then
          # Find which 1-based column index contains "Event"
          local col_n=0
          local IFS_orig="$IFS"
          IFS='|'
          local cells
          read -ra cells <<< "$line"
          IFS="$IFS_orig"
          local ci=0
          for cell in "${cells[@]}"; do
            cell_trimmed="$(printf '%s\n' "$cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
            if [ "$cell_trimmed" = "event" ]; then
              col_n="$ci"
              break
            fi
            ci=$(( ci + 1 ))
          done
          event_col_idx="$col_n"
          header_found=1
        fi
        continue
      fi

      # Data row — extract the Event column
      if [ "$header_found" -eq 1 ] && [ "$event_col_idx" -gt 0 ]; then
        local IFS_orig="$IFS"
        IFS='|'
        local cells
        read -ra cells <<< "$line"
        IFS="$IFS_orig"
        local num_cells="${#cells[@]}"
        if [ "$event_col_idx" -lt "$num_cells" ]; then
          local event_val="${cells[$event_col_idx]}"
          event_val="$(printf '%s\n' "$event_val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
          if [ -n "$event_val" ]; then
            FEAT_IDS+=( "$fid" )
            FEAT_EVENTS+=( "$event_val" )
          fi
        fi
      fi
    fi

  done < "$ffile"
}

# Enumerate feature files
mapfile -t FEATURE_FILES < <(find "$FEATURES_DIR" -maxdepth 1 -name 'F-*.md' -print | sort)

if [ "${#FEATURE_FILES[@]}" -eq 0 ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'OK 0 findings — PRD features/ contains no F-*.md files\n' >&2
  fi
  _finalize ""
fi

for ffile in "${FEATURE_FILES[@]}"; do
  # Derive feature ID from filename: F-001-slug.md → F-001
  fname="$(basename "$ffile" .md)"
  fid="$(printf '%s\n' "$fname" | grep -oE '^F-[0-9]+')" || true
  [ -n "$fid" ] || fid="$fname"
  extract_analytics_events "$ffile" "$fid"
done

# If no events found in any feature, nothing to check
if [ "${#FEAT_EVENTS[@]}" -eq 0 ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'OK 0 findings — no analytics events found in PRD feature files\n' >&2
  fi
  _finalize ""
fi

# ---------------------------------------------------------------------------
# Step 3 — Parse ## Analytics Coverage section of README.md
# ---------------------------------------------------------------------------
# Collect lines in the section, then extract:
#   - Event names from table rows (column "Event")
#   - Named sweep rules (rows listing feature ID ranges + channel)
#
# A named sweep rule is a row whose Event cell matches: F-\d+ (optionally ..F-\d+)
# The rule covers all events in those feature IDs.
# An unnamed sweep rule (no feature IDs) is detected and flagged separately.

extract_analytics_section() {
  local readme="$1"
  local in_section=0
  local line

  while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -qE '^##[[:space:]]+Analytics Coverage'; then
      in_section=1
      continue
    fi
    if [ "$in_section" -eq 1 ] && printf '%s\n' "$line" | grep -qE '^##[[:space:]]'; then
      break
    fi
    if [ "$in_section" -eq 1 ]; then
      printf '%s\n' "$line"
    fi
  done < "$readme"
}

ANALYTICS_SECTION="$(extract_analytics_section "$README")"

# ---------------------------------------------------------------------------
# Step 4 — Build set B: covered event names from Analytics Coverage
# ---------------------------------------------------------------------------
# Parse the Analytics Coverage table.
# Table format: | Feature | Event | Trigger | Emitting Channel | Responsible Module |
# We find the "Event" column index, then extract each data row's Event cell.
#
# Additionally, collect "sweep rules" — rows where the Event cell is a range
# like "F-004..F-042 (description) → channel".

declare -a COVERED_EVENTS=()       # exact event names
declare -a SWEPT_FEATURE_IDS=()    # feature IDs covered by named sweep rules
UNNAMED_SWEEP_ROWS=""              # accumulate unnamed sweep row texts

COVERAGE_HEADER_FOUND=0
COVERAGE_EVENT_COL=0

while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Only process table rows
  printf '%s\n' "$line" | grep -qE '^\|' || continue

  # Separator row — skip
  printf '%s\n' "$line" | grep -qE '^\|[-|: ]+\|' && continue

  # Header row: look for "Event" column
  if [ "$COVERAGE_HEADER_FOUND" -eq 0 ]; then
    local_lower="$(printf '%s\n' "$line" | tr '[:upper:]' '[:lower:]')"
    if printf '%s\n' "$local_lower" | grep -qE '\|\s*event\s*\|'; then
      # Find column index of "Event"
      IFS_orig="$IFS"
      IFS='|'
      read -ra header_cells <<< "$line"
      IFS="$IFS_orig"
      ci=0
      for cell in "${header_cells[@]}"; do
        cell_t="$(printf '%s\n' "$cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
        if [ "$cell_t" = "event" ]; then
          COVERAGE_EVENT_COL="$ci"
          COVERAGE_HEADER_FOUND=1
          break
        fi
        ci=$(( ci + 1 ))
      done
    fi
    continue
  fi

  # Data row — extract the Event column
  if [ "$COVERAGE_HEADER_FOUND" -eq 1 ] && [ "$COVERAGE_EVENT_COL" -gt 0 ]; then
    IFS_orig="$IFS"
    IFS='|'
    read -ra data_cells <<< "$line"
    IFS="$IFS_orig"
    num_cells="${#data_cells[@]}"
    if [ "$COVERAGE_EVENT_COL" -lt "$num_cells" ]; then
      event_cell="${data_cells[$COVERAGE_EVENT_COL]}"
      event_cell="$(printf '%s\n' "$event_cell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

      if [ -n "$event_cell" ]; then
        # Check if this is a named sweep rule: must contain F-NNN pattern
        if printf '%s\n' "$event_cell" | grep -qE 'F-[0-9]+'; then
          # Extract feature ID range(s) from the sweep expression
          # e.g. "F-004..F-042 (operational backend) → audit.Emit → Log Viewer"
          while IFS= read -r fid_match; do
            [ -n "$fid_match" ] || continue
            SWEPT_FEATURE_IDS+=( "$fid_match" )
          done < <(printf '%s\n' "$event_cell" | grep -oE 'F-[0-9]+' || true)
        elif printf '%s\n' "$event_cell" | grep -qiE 'all\s|backend\s|frontend\s|every\s|each\s'; then
          # Unnamed blanket rule — flag it
          if [ -z "$UNNAMED_SWEEP_ROWS" ]; then
            UNNAMED_SWEEP_ROWS="$event_cell"
          else
            UNNAMED_SWEEP_ROWS="${UNNAMED_SWEEP_ROWS}"$'\n'"$event_cell"
          fi
        else
          # Regular explicit event name
          COVERED_EVENTS+=( "$event_cell" )
        fi
      fi
    fi
  fi

done <<< "$ANALYTICS_SECTION"

# ---------------------------------------------------------------------------
# Step 5 — Find missing events
# ---------------------------------------------------------------------------
TOTAL_VIOLATIONS=0
BLOCKER_COUNT=0
MECHANICAL_COUNT=0

# Helper: check if an event name is covered (exact match in COVERED_EVENTS
# or the feature ID is in SWEPT_FEATURE_IDS from a named sweep rule)
is_covered() {
  local fid="$1"
  local ename="$2"

  # Check exact event name match
  for cov in "${COVERED_EVENTS[@]+"${COVERED_EVENTS[@]}"}"; do
    if [ "$cov" = "$ename" ]; then
      return 0
    fi
  done

  # Check named sweep rule coverage (feature ID listed in a sweep)
  for swept_fid in "${SWEPT_FEATURE_IDS[@]+"${SWEPT_FEATURE_IDS[@]}"}"; do
    if [ "$swept_fid" = "$fid" ]; then
      return 0
    fi
  done

  return 1
}

# Report any unnamed sweep rows as mechanical findings
if [ -n "$UNNAMED_SWEEP_ROWS" ]; then
  while IFS= read -r sweep_row; do
    [ -n "$sweep_row" ] || continue
    write_unnamed_sweep_issue "$sweep_row"
    TOTAL_VIOLATIONS=$(( TOTAL_VIOLATIONS + 1 ))
    MECHANICAL_COUNT=$(( MECHANICAL_COUNT + 1 ))
  done <<< "$UNNAMED_SWEEP_ROWS"
fi

# Check each PRD event for coverage
declare -A REPORTED_EVENTS=()   # avoid duplicate issues for the same event

num_events="${#FEAT_EVENTS[@]}"
for (( i=0; i<num_events; i++ )); do
  fid="${FEAT_IDS[$i]}"
  ename="${FEAT_EVENTS[$i]}"

  # Skip if this event was already reported (same event name from multiple features
  # is intentional — each needs its own row, but dedup within same feature+event)
  dedup_key="${fid}::${ename}"
  if [ -n "${REPORTED_EVENTS[$dedup_key]+set}" ]; then
    continue
  fi
  REPORTED_EVENTS["$dedup_key"]=1

  if ! is_covered "$fid" "$ename"; then
    write_missing_event_issue "$fid" "$ename"
    TOTAL_VIOLATIONS=$(( TOTAL_VIOLATIONS + 1 ))
    BLOCKER_COUNT=$(( BLOCKER_COUNT + 1 ))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 0 ] || [ "$TOTAL_VIOLATIONS" -gt 0 ]; then
  printf '\nCR-X4 Analytics coverage: %d violation(s) (%d blocker, %d mechanical)\n' \
    "$TOTAL_VIOLATIONS" "$BLOCKER_COUNT" "$MECHANICAL_COUNT" >&2
fi

_finalize "$JSON_FINDINGS"
