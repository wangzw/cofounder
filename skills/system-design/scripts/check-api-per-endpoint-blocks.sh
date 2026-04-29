#!/usr/bin/env bash
# check-api-per-endpoint-blocks.sh — CR-L1 (api-per-endpoint-blocks)
# Usage: check-api-per-endpoint-blocks.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-L1: every endpoint defined in <design-dir>/api/API-*.md MUST
# have all seven required subsections:
#   1. Description              (**Description:**)
#   2. Authentication & Perms   (**Authentication & Permissions:**)
#   3. Request                  (**Request:**)
#   4. Request example          (**Request example:**)
#   5. Response                 (**Response:**)
#   6. Response example         (**Response example:**)
#   7. Constraints              (**Constraints:**)
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.
# Output: "OK 0 findings" or "FAIL <N> findings" to stdout.
# Exit codes: 0 = no findings; 1 = findings (only fatal with --strict); 2 = invalid args.
set -euo pipefail

# ── argument parsing ─────────────────────────────────────────────────────────
DESIGN_DIR=""
QUIET=0
STRICT=0

for arg in "$@"; do
  case "$arg" in
    --quiet)  QUIET=1 ;;
    --strict) STRICT=1 ;;
    -*)
      echo "ERROR: unknown flag: $arg" >&2
      echo "Usage: check-api-per-endpoint-blocks.sh <design-dir> [--quiet] [--strict]" >&2
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
  echo "ERROR: <design-dir> is required" >&2
  echo "Usage: check-api-per-endpoint-blocks.sh <design-dir> [--quiet] [--strict]" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  echo "ERROR: design dir not found: $DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
API_DIR="$DESIGN_DIR/api"

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ── seven required subsection patterns (grep -i friendly) ────────────────────
# Each entry: "label|grep_pattern"
# Patterns match the bold-heading style used in api-template.md:
#   **Description:**  **Authentication & Permissions:**  **Request:**
#   **Request example:**  **Response:**  **Response example:**  **Constraints:**
# Also accept common alternatives (case-insensitive matching applied at grep time).
SUBSECTION_LABELS=(
  "Description"
  "Authentication & Permissions"
  "Request"
  "Request example"
  "Response"
  "Response example"
  "Constraints"
)
SUBSECTION_PATTERNS=(
  '^\*\*[Dd]escription:'
  '^\*\*[Aa]uth'
  '^\*\*[Rr]equest:'
  '^\*\*[Rr]equest[[:space:]]\{1,\}[Ee]xample:'
  '^\*\*[Rr]esponse:'
  '^\*\*[Rr]esponse[[:space:]]\{1,\}[Ee]xample:'
  '^\*\*[Cc]onstraint'
)

TOTAL_SUBSECTIONS=${#SUBSECTION_LABELS[@]}

# ── main lint loop ─────────────────────────────────────────────────────────────
FINDING_COUNT=0

# Collect API files; if none, exit cleanly.
if [ ! -d "$API_DIR" ]; then
  echo "OK 0 findings (no api/ directory)" >&2
  printf '[]\n'
  exit 0
fi

# Build list of API-*.md files
API_FILES=""
for f in "$API_DIR"/API-*.md; do
  [ -e "$f" ] || continue
  API_FILES="$API_FILES $f"
done

if [ -z "$API_FILES" ]; then
  echo "OK 0 findings (no API-*.md files)" >&2
  printf '[]\n'
  exit 0
fi

# ── process each API file ─────────────────────────────────────────────────────
for api_file in $API_FILES; do
  rel_file="api/$(basename "$api_file")"

  # Extract endpoint headings: lines matching **METHOD /path** where METHOD is
  # one of GET POST PUT PATCH DELETE HEAD OPTIONS.
  # Format in api-template.md: **{METHOD} {/path}**
  # We collect: line_number|heading_text
  endpoint_lines=$(grep -n '^\*\*\(GET\|POST\|PUT\|PATCH\|DELETE\|HEAD\|OPTIONS\)[[:space:]]' "$api_file" || true)

  if [ -z "$endpoint_lines" ]; then
    # No REST endpoints in this file; skip (might be gRPC/CLI).
    continue
  fi

  # Total lines in file (for end-of-file boundary)
  total_lines=$(wc -l < "$api_file" | tr -d ' ')

  # Process each endpoint
  # endpoint_lines is newline-separated "linenum:heading" strings
  # We need pairs of consecutive endpoints to extract the block between them.

  # Write endpoint start lines to a temp file for indexed access
  tmp_ep=$(mktemp /tmp/check-api-ep-XXXXXX)
  # Use printf to preserve newlines properly
  printf '%s\n' "$endpoint_lines" > "$tmp_ep"

  # Count endpoints
  ep_count=$(wc -l < "$tmp_ep" | tr -d ' ')

  ep_index=0
  while IFS= read -r ep_line; do
    ep_index=$((ep_index + 1))

    # Parse line number and heading text
    ep_lineno=$(echo "$ep_line" | cut -d: -f1)
    ep_heading=$(echo "$ep_line" | cut -d: -f2-)

    # Determine block end: next endpoint start - 1, or end of file
    if [ "$ep_index" -lt "$ep_count" ]; then
      next_ep_line=$(sed -n "${ep_index}p" "$tmp_ep" 2>/dev/null || true)
      # This gives us the CURRENT endpoint; we need the NEXT one (ep_index+1)
      next_ep_line=$(sed -n "$((ep_index + 1))p" "$tmp_ep")
      block_end=$(echo "$next_ep_line" | cut -d: -f1)
      block_end=$((block_end - 1))
    else
      block_end=$total_lines
    fi

    # Extract the block for this endpoint (from its heading to block_end)
    block=$(sed -n "${ep_lineno},${block_end}p" "$api_file")

    # Check each required subsection
    for i in $(seq 0 $((TOTAL_SUBSECTIONS - 1))); do
      label="${SUBSECTION_LABELS[$i]}"
      pattern="${SUBSECTION_PATTERNS[$i]}"

      # Special case: **Response:** must not match **Response example:** accidentally.
      # The plain Response pattern uses '^\*\*[Rr]esponse:' which ends at ':',
      # so it won't match '**Response example:**'. Same for Request vs Request example.
      # (Both patterns are already anchored with ':' at the end, so no collision.)

      if ! echo "$block" | grep -q "$pattern"; then
        # Severity: blocker for Auth/Constraints; mechanical for others
        case "$i" in
          1|6) severity="blocker" ;;
          *)   severity="mechanical" ;;
        esac

        FINDING_COUNT=$((FINDING_COUNT + 1))

        # Accumulate JSON finding
        _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
        _jheading=$(printf '%s' "$ep_heading" | sed 's/"/\\"/g')
        _jlabel=$(printf '%s' "$label" | sed 's/"/\\"/g')
        _jdesc="Endpoint ${_jheading} (line ${ep_lineno}) missing required subsection: ${_jlabel}"
        _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
        _jfix="Add the missing **${_jlabel}:** subsection to the endpoint block in ${_jfile}"
        _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
        _jentry="{\"criterion_id\":\"CR-L1\",\"file\":\"${_jfile}\",\"severity\":\"${severity}\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
        if [ -z "$JSON_FINDINGS" ]; then
          JSON_FINDINGS="$_jentry"
        else
          JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"
        fi

        if [ "$QUIET" -eq 0 ]; then
          echo "[CR-L1] ${severity}: ${rel_file}:${ep_lineno} — endpoint '${ep_heading}' missing subsection '${label}'" >&2
        fi
      fi
    done

  done < "$tmp_ep"

  rm -f "$tmp_ep"
done

# ── summary ───────────────────────────────────────────────────────────────────
if [ "$FINDING_COUNT" -eq 0 ]; then
  echo "OK 0 findings" >&2
  printf '[]\n'
  exit 0
else
  echo "FAIL $FINDING_COUNT findings" >&2
  printf '[%s]\n' "$JSON_FINDINGS"
  if [ "$STRICT" -eq 1 ]; then
    exit 1
  fi
  exit 0
fi
