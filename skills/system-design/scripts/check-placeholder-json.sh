#!/usr/bin/env bash
# check-placeholder-json.sh — CR-L2 (placeholder-json)
# Lint check: forbid placeholder tokens inside ```json fenced code blocks across
# all <design-dir>/api/*.md and <design-dir>/modules/*.md files.
#
# Usage:
#   scripts/check-placeholder-json.sh <design-dir> [--quiet] [--strict]
#
# Flags:
#   --quiet   Suppress per-finding stdout output; only exit code communicates results.
#   --strict  Accepted as a no-op for backward compatibility. Findings are
#             emitted through the shared §9 emitter (sd_emit.sh →
#             sd_lint.emit), which always exits 1 on any finding regardless
#             of severity — there is no warning-only path for this rule, so
#             the strict/non-strict distinction does not apply. Earlier
#             versions of this header documented a strict-vs-default
#             behaviour that never matched the implementation; the actual
#             behaviour is unchanged from then to now.
#
# Forbidden tokens (case-insensitive) inside ```json blocks:
#   TODO  FIXME  ...  <...>  XXX  PLACEHOLDER  TBD
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.
#
# Exit codes:
#   0  No findings
#   1  At least one finding (--strict is a no-op; see Flags above)
#   2  Bad arguments (missing design-dir, dir not found)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_finalize() {
  # §9 contract emission via shared helper.
  SD_LEGACY_FINDINGS="${1-}" exec bash "$SCRIPT_DIR/lib/sd_emit.sh" "(check-placeholder-json)"
}

# ─── Argument parsing ────────────────────────────────────────────────────────

DESIGN_DIR=""
QUIET=1
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet)  QUIET=1;  shift ;;
    --strict) STRICT=1; shift ;;
    --)       shift; while [ $# -gt 0 ]; do
                if [ -z "$DESIGN_DIR" ]; then DESIGN_DIR="$1"; fi
                shift
              done ;;
    -*)
      printf 'ERROR: unknown flag: %s\n' "$1" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then
        DESIGN_DIR="$1"
      else
        printf 'ERROR: unexpected positional argument: %s\n' "$1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [ -z "$DESIGN_DIR" ]; then
  printf 'Usage: check-placeholder-json.sh <design-dir> [--quiet] [--strict]\n' >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design dir not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

# Normalise: strip trailing slash
DESIGN_DIR="${DESIGN_DIR%/}"

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ─── Forbidden token patterns ─────────────────────────────────────────────────
# Each entry is a grep-compatible extended-regex fragment (case-insensitive).
# Patterns are tested against the raw line text while inside a ```json fence.
#
# Pattern rationale (mirrors structural-lint.md L2 table):
#   TODO        — explicit TODO placeholder
#   FIXME       — explicit FIXME placeholder
#   \.\.\.      — three literal dots used as filler (handles "...", ..., /* ... */, // ...)
#   <[^>]*>     — angle-bracket placeholder e.g. <field>, <value>, <...>
#   XXX         — explicit XXX marker
#   PLACEHOLDER — explicit PLACEHOLDER string
#   TBD         — explicit TBD string

FORBIDDEN_PATTERNS=(
  'TODO'
  'FIXME'
  '\.\.\.'
  '<[^>]*>'
  'XXX'
  'PLACEHOLDER'
  'TBD'
)

# ─── Token label for display (same order as FORBIDDEN_PATTERNS) ───────────────
FORBIDDEN_LABELS=(
  'TODO'
  'FIXME'
  '...'
  '<...>'
  'XXX'
  'PLACEHOLDER'
  'TBD'
)

# ─── File collection ──────────────────────────────────────────────────────────

# Collect api/*.md and modules/*.md (non-recursive; these directories are flat
# per the system-design output convention).
mapfile -t TARGET_FILES < <(
  {
    find "${DESIGN_DIR}/api"     -maxdepth 1 -name '*.md' 2>/dev/null || true
    find "${DESIGN_DIR}/modules" -maxdepth 1 -name '*.md' 2>/dev/null || true
  } | sort
)

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && printf 'INFO: no api/*.md or modules/*.md files found in %s\n' "$DESIGN_DIR" >&2
  _finalize ""
fi

# ─── Core scanning logic ──────────────────────────────────────────────────────

FINDING_COUNT=0

_emit_finding() {
  local rel_file="$1" lineno="$2" token_label="$3" offending_line="$4"
  FINDING_COUNT=$((FINDING_COUNT + 1))

  # Print to stderr unless --quiet
  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-L2] blocker  %s:%d — placeholder token "%s" inside ```json block\n' \
      "$rel_file" "$lineno" "$token_label" >&2
    printf '  Fix: replace placeholder with a realistic example value\n' >&2
  fi

  # Accumulate JSON finding
  _jfile=$(printf '%s' "$rel_file" | sed 's/"/\\"/g')
  _jtok=$(printf '%s' "$token_label" | sed 's/"/\\"/g')
  _jdesc="Forbidden placeholder token \"${_jtok}\" inside \`\`\`json block at line ${lineno}"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Replace the placeholder token with a realistic example value derived from the surrounding Request/Response table"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-L2\",\"file\":\"${_jfile}\",\"severity\":\"blocker\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then
    JSON_FINDINGS="$_jentry"
  else
    JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"
  fi
}

# Scan a single file.  Pure-bash line-by-line; no external grep inside the
# fence-tracking loop (avoids spawning per-line subprocesses on large files).
_scan_file() {
  local filepath="$1"
  local rel_file
  rel_file="${filepath#${DESIGN_DIR}/}"

  local in_json_fence=0
  local lineno=0
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # ── Fence tracking ────────────────────────────────────────────────────────
    # Opening fence: line starts with optional whitespace then ```json
    # Closing fence: line starts with optional whitespace then ``` (with no
    #   language specifier, or a different specifier) while we are in a block.
    #
    # We use parameter-expansion trimming to check prefixes without spawning
    # subshells on every line.

    # Strip leading whitespace for fence detection
    local trimmed="${line#"${line%%[![:space:]]*}"}"

    if [ "$in_json_fence" -eq 0 ]; then
      # Check if this line opens a ```json block
      case "$trimmed" in
        '```json'|'```json '*)
          in_json_fence=1
          continue
          ;;
      esac
    else
      # Check if this line closes the block: starts with ``` and is NOT ```json
      case "$trimmed" in
        '```'|'``` '*)
          in_json_fence=0
          continue
          ;;
        '```'*)
          # Could be ```something-else opening a nested fence within — treat as
          # content (JSON doesn't nest fences in practice; flag as content line).
          ;;
      esac

      # ── Forbidden token detection (case-insensitive) ─────────────────────
      local upper_line
      # Bash built-in uppercasing (bash 4+); avoids tr subprocess per line.
      upper_line="${line^^}"

      local i token_re token_label
      for i in "${!FORBIDDEN_PATTERNS[@]}"; do
        token_re="${FORBIDDEN_PATTERNS[$i]}"
        token_label="${FORBIDDEN_LABELS[$i]}"

        # Use bash's =~ operator for regex match (case already uppercased).
        # For the angle-bracket pattern we need case-insensitive match on the
        # original line (token_re already matches any case via upper_line).
        if [[ "$upper_line" =~ $token_re ]]; then
          _emit_finding "$rel_file" "$lineno" "$token_label" "$line"
          # Report only the first forbidden token per line to avoid duplicate
          # findings for the same line position; break inner loop.
          break
        fi
      done
    fi
  done < "$filepath"
}

# ─── Run scan across all collected files ─────────────────────────────────────

for f in "${TARGET_FILES[@]}"; do
  [ -f "$f" ] || continue
  _scan_file "$f"
done

# ─── Summary and exit ─────────────────────────────────────────────────────────

if [ "$QUIET" -eq 0 ]; then
  if [ "$FINDING_COUNT" -eq 0 ]; then
    printf 'CR-L2: PASS — no placeholder tokens found in ```json blocks (%d file(s) scanned)\n' \
      "${#TARGET_FILES[@]}" >&2
  else
    printf 'CR-L2: %d finding(s)\n' "$FINDING_COUNT" >&2
  fi
fi

_finalize "$JSON_FINDINGS"
