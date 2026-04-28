#!/usr/bin/env bash
# check-endpoint-literal-vs-api.sh — CR-X2 (endpoint-literal-vs-api)
# Usage: check-endpoint-literal-vs-api.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-X2: bidirectional sync between module API Surface tables and
# api/API-*.md endpoint definitions.
#
#   Set A — endpoints referenced in any modules/M-*.md API Surface table
#            (Method and Path columns, i.e. col 1 of the 7-col table).
#   Set B — endpoints defined in api/API-*.md as headings matching:
#            ^##[[:space:]]+(METHOD)[[:space:]]+/ (direct)
#            ^##[[:space:]].*[[:space:]](METHOD)[[:space:]]+/ (decorated, e.g. ## [Deprecated] GET /v1/foo)
#
#   Findings = (A − B) ∪ (B − A)
#
#     A − B  → module references an endpoint not defined in any api/ file  (blocker)
#     B − A  → api/ defines an endpoint not claimed by any module           (blocker)
#
# Skip entirely if <design-dir>/api/ directory does not exist (project has no APIs).
#
# Issue files: <design-dir>/.reviews/LINT-<NNN>.md
#   Each file contains: severity, CR-id, source file, line, offending endpoint,
#   and a suggested fix.
#
# Exit codes:
#   0 — no violations (or api/ absent — silent skip)
#   1 — one or more violations found
#   2 — usage / I/O error
#
# Flags:
#   --quiet   suppress per-violation stdout; only print summary line
#   --strict  reserved for pipeline use; currently same behaviour as default
#             (exit 1 on any finding regardless of this flag)
#
# Limitations:
#   1. Method+path extraction from API Surface tables reads col 1 of the
#      pipe-delimited row (the Method + Path column). Designs with non-standard
#      column order may produce false positives or missed entries.
#   2. Endpoint headings in api/ files must use exactly "##" (H2). Headings at
#      "###" or deeper are not matched.
#   3. Path normalisation strips trailing slashes only. Query-string literals or
#      anchor fragments embedded in Method + Path cells will fail to match api/
#      headings — use only canonical paths in the cell.
#   4. Method tokens are uppercased for comparison; "get /v1/foo" in a module
#      cell matches "## GET /v1/foo" in an api/ file.
#   5. Bash 5.x on macOS triggers "unbound variable" for empty associative arrays
#      under set -u. Workaround: set +u / set -u guards around all array expansions.
set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────
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
  echo "ERROR: <design-dir> is required" >&2
  echo "Usage: $0 <design-dir> [--quiet] [--strict]" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  echo "ERROR: design directory not found: $DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
API_DIR="$DESIGN_DIR/api"
MODULES_DIR="$DESIGN_DIR/modules"
REVIEWS_DIR="$DESIGN_DIR/.reviews"

# ── skip if no api/ directory (project has no APIs) ───────────────────────────
if [ ! -d "$API_DIR" ]; then
  [ "$QUIET" -eq 0 ] && echo "INFO: no api/ directory in $DESIGN_DIR — CR-X2 skipped." >&2
  printf '[]\n'
  exit 0
fi

mkdir -p "$REVIEWS_DIR"

# ── helpers ───────────────────────────────────────────────────────────────────

# next_lint_seq: return the next available zero-padded LINT sequence number.
# Scans existing LINT-NNN.md files; returns max+1 (or 001 if none exist).
next_lint_seq() {
  local max=0
  local base n
  while IFS= read -r f; do
    base="$(basename "$f")"
    if [[ "$base" =~ ^LINT-([0-9]+) ]]; then
      n="${BASH_REMATCH[1]}"
      n=$((10#$n))
      [ "$n" -gt "$max" ] && max="$n"
    fi
  done < <(find "$REVIEWS_DIR" -maxdepth 1 -name 'LINT-*.md' 2>/dev/null)
  printf "%03d" $(( max + 1 ))
}

VIOLATION_COUNT=0
JSON_FINDINGS=""

# emit_issue: write a LINT-NNN.md file for one violation.
# Args: $1=normalised endpoint  $2=direction ("module-missing"|"api-orphan")
#       $3=absolute source file  $4=line number
emit_issue() {
  local endpoint="$1"
  local direction="$2"
  local source_file="$3"
  local lineno="$4"

  local seq
  seq="$(next_lint_seq)"
  local issue_file="$REVIEWS_DIR/LINT-${seq}.md"
  local rel_file="${source_file#"$DESIGN_DIR/"}"

  local finding fix
  if [ "$direction" = "module-missing" ]; then
    finding="Module references endpoint \`$endpoint\` in its API Surface table, but no \`api/API-*.md\` file defines this endpoint."
    fix="Add a \`## $endpoint\` heading (with all seven required subsections) to the appropriate \`api/API-*.md\` file, or correct the Method + Path cell in the module if the literal is a typo."
  else
    finding="Endpoint \`$endpoint\` is defined in \`$rel_file\` but is not listed in any module's API Surface table."
    fix="Add a row for \`$endpoint\` in the relevant module's \`## API Surface\` table, or remove the endpoint definition from \`$rel_file\` if it is no longer needed."
  fi

  [ "$QUIET" -eq 0 ] && echo "[CR-X2] blocker  $rel_file:$lineno — $finding" >&2

  cat > "$issue_file" <<ISSUE
# LINT-${seq} — CR-X2 endpoint-literal-vs-api

**Severity**: blocker
**CR-id**: CR-X2
**File**: $rel_file
**Line**: $lineno
**Endpoint**: \`$endpoint\`

## Finding

$finding

## Suggested Fix

$fix

Per \`structural-lint.md\` X2: every endpoint literal in a module's API Surface
MUST appear as an endpoint heading in \`api/API-*.md\`, and every endpoint in
\`api/API-*.md\` MUST be claimed by at least one module's API Surface table.
ISSUE

  VIOLATION_COUNT=$(( VIOLATION_COUNT + 1 ))

  # Accumulate JSON finding
  _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
  _jep=$(printf '%s' "$endpoint" | sed 's/"/\\"/g')
  _jfinding=$(printf '%s' "$finding" | sed 's/"/\\"/g')
  _jfix=$(printf '%s' "$fix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-X2\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jfinding}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ── Step 1: build Set A from modules/M-*.md API Surface tables ────────────────
# For each module file, find the ## API Surface section and extract col 1
# (Method + Path) from every data row (skipping the header and separator rows).
#
# Storage: associative array  A_ENDPOINT["METHOD /path"] = "relfile:lineno"
# (first occurrence wins for reporting; duplicates within the same or different
# modules are fine as long as at least one api/ heading exists)

declare -A A_ENDPOINT   # key=normalised endpoint  value="relfile:lineno"

if [ -d "$MODULES_DIR" ]; then
  while IFS= read -r module_file; do
    in_api_surface=0
    header_seen=0
    lineno=0

    while IFS= read -r line; do
      lineno=$(( lineno + 1 ))

      # Enter ## API Surface section (H2 only)
      if [[ "$line" =~ ^##[[:space:]]+(API[[:space:]]+Surface) ]]; then
        in_api_surface=1
        header_seen=0
        continue
      fi

      # Exit on the next ## heading
      if [[ "$line" =~ ^##[[:space:]] ]] && [ "$in_api_surface" -eq 1 ]; then
        in_api_surface=0
        header_seen=0
        continue
      fi

      [ "$in_api_surface" -eq 0 ] && continue

      # Must be a pipe-delimited table row
      [[ "$line" != \|* ]] && continue

      # Skip blank / whitespace-only
      [[ -z "${line//[[:space:]]/}" ]] && continue

      # Skip separator rows (|---|---|  or  |:---:|:---:|)
      if [[ "$line" =~ ^\|[[:space:][:punct:]]+\|$ ]]; then
        # A separator row contains only pipes, dashes, colons, and spaces
        local_stripped="${line//[| :—-]/}"
        if [ -z "$local_stripped" ]; then
          continue
        fi
      fi
      # More reliable separator check: no alphanumeric characters between pipes
      # after removing separators
      stripped_check="${line//|/}"
      stripped_check="${stripped_check//[- :]/}"
      if [ -z "$stripped_check" ]; then
        continue
      fi

      # First non-separator pipe row = header row; skip it
      if [ "$header_seen" -eq 0 ]; then
        header_seen=1
        continue
      fi

      # Extract column 1 (Method + Path)
      # Row: | col1 | col2 | ... |  — strip leading pipe, take up to next pipe
      inner="${line#|}"
      col1="${inner%%|*}"
      # Trim surrounding whitespace
      col1="$(echo "$col1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

      # Must look like METHOD /path (method token followed by a path starting with /)
      if [[ "$col1" =~ ^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[[:space:]]+(/[^[:space:]]*) ]]; then
        raw_method="${BASH_REMATCH[1]}"
        raw_path="${BASH_REMATCH[2]}"
      elif [[ "$col1" =~ ^(get|post|put|patch|delete|head|options)[[:space:]]+(/[^[:space:]]*) ]]; then
        raw_method="$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')"
        raw_path="${BASH_REMATCH[2]}"
      else
        continue
      fi

      # Normalise: uppercase method, strip trailing slash (keep bare / intact)
      norm_method="$(echo "$raw_method" | tr '[:lower:]' '[:upper:]')"
      norm_path="$raw_path"
      if [ "${#norm_path}" -gt 1 ]; then
        norm_path="${norm_path%/}"
      fi
      norm="$norm_method $norm_path"

      rel_mod="${module_file#"$DESIGN_DIR/"}"

      # Record only the first occurrence (set +u guards for bash 5.x compat)
      set +u
      already="${A_ENDPOINT["$norm"]+set}"
      set -u
      if [ -z "$already" ]; then
        A_ENDPOINT["$norm"]="$rel_mod:$lineno"
      fi

    done < "$module_file"
  done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' 2>/dev/null | sort)
fi

# ── Step 2: build Set B from api/API-*.md endpoint headings ──────────────────
# Match H2 headings that contain a method token followed by a path.
# Two patterns handled:
#   Direct:    ## GET /v1/tasks
#   Decorated: ## [Deprecated] DELETE /v1/things

declare -A B_ENDPOINT   # key=normalised endpoint  value="relfile:lineno"

while IFS= read -r api_file; do
  lineno=0
  while IFS= read -r line; do
    lineno=$(( lineno + 1 ))

    # Fast pre-filter: must start with ##
    [[ "$line" != \#\#* ]] && continue

    # Pattern 1: method immediately after "## " (no decorator)
    #   ## GET /v1/tasks
    if [[ "$line" =~ ^##[[:space:]]+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[[:space:]]+(/[^[:space:]]*) ]]; then
      raw_method="${BASH_REMATCH[1]}"
      raw_path="${BASH_REMATCH[2]}"
    # Pattern 2: method after some decorator text
    #   ## [Deprecated] GET /v1/tasks
    elif [[ "$line" =~ ^##[[:space:]].*[[:space:]](GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[[:space:]]+(/[^[:space:]]*) ]]; then
      raw_method="${BASH_REMATCH[1]}"
      raw_path="${BASH_REMATCH[2]}"
    else
      continue
    fi

    # Normalise
    norm_method="$(echo "$raw_method" | tr '[:lower:]' '[:upper:]')"
    norm_path="$raw_path"
    if [ "${#norm_path}" -gt 1 ]; then
      norm_path="${norm_path%/}"
    fi
    norm="$norm_method $norm_path"

    rel_api="${api_file#"$DESIGN_DIR/"}"

    set +u
    already="${B_ENDPOINT["$norm"]+set}"
    set -u
    if [ -z "$already" ]; then
      B_ENDPOINT["$norm"]="$rel_api:$lineno"
    fi

  done < "$api_file"
done < <(find "$API_DIR" -maxdepth 1 -name 'API-*.md' 2>/dev/null | sort)

# ── Step 3: compute findings ──────────────────────────────────────────────────

# A − B: module references endpoint not defined in any api/ file
set +u
a_keys=("${!A_ENDPOINT[@]}")
set -u

for ep in "${a_keys[@]+"${a_keys[@]}"}"; do
  set +u
  in_b="${B_ENDPOINT["$ep"]+set}"
  set -u
  if [ -z "$in_b" ]; then
    loc="${A_ENDPOINT["$ep"]}"     # "relfile:lineno"
    src_file="$DESIGN_DIR/${loc%:*}"
    src_line="${loc##*:}"
    emit_issue "$ep" "module-missing" "$src_file" "$src_line"
  fi
done

# B − A: api/ endpoint not claimed by any module
set +u
b_keys=("${!B_ENDPOINT[@]}")
set -u

for ep in "${b_keys[@]+"${b_keys[@]}"}"; do
  set +u
  in_a="${A_ENDPOINT["$ep"]+set}"
  set -u
  if [ -z "$in_a" ]; then
    loc="${B_ENDPOINT["$ep"]}"     # "relfile:lineno"
    src_file="$DESIGN_DIR/${loc%:*}"
    src_line="${loc##*:}"
    emit_issue "$ep" "api-orphan" "$src_file" "$src_line"
  fi
done

# ── summary ───────────────────────────────────────────────────────────────────
set +u
module_ep_count="${#A_ENDPOINT[@]}"
api_ep_count="${#B_ENDPOINT[@]}"
set -u

if [ "$QUIET" -eq 0 ]; then
  echo "" >&2
  echo "CR-X2 check complete — ${module_ep_count} endpoint(s) in modules, ${api_ep_count} endpoint(s) in api/, ${VIOLATION_COUNT} violation(s) found." >&2
  if [ "$VIOLATION_COUNT" -gt 0 ]; then
    echo "Issue files written to: $REVIEWS_DIR/" >&2
  fi
fi

if [ "$VIOLATION_COUNT" -eq 0 ]; then
  printf '[]\n'
else
  printf '[%s]\n' "$JSON_FINDINGS"
fi

if [ "$VIOLATION_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
