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
#   --strict  Exit 1 when findings are present (default: exit 0 even with findings).
#
# Forbidden tokens (case-insensitive) inside ```json blocks:
#   TODO  FIXME  ...  <...>  XXX  PLACEHOLDER  TBD
#
# Each finding → issue file at <design-dir>/.reviews/LINT-<NNN>.md
#   Severity: blocker
#   CR-id:    CR-L2
#   Fields:   file, line, offending token, suggested fix
#
# Exit codes:
#   0  No findings (or findings present but --strict not set)
#   1  Findings present AND --strict flag was passed
#   2  Bad arguments (missing design-dir, dir not found)
set -euo pipefail

# ─── Argument parsing ────────────────────────────────────────────────────────

DESIGN_DIR=""
QUIET=0
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

# ─── Issue-file sequencing ────────────────────────────────────────────────────

REVIEWS_DIR="${DESIGN_DIR}/.reviews"
mkdir -p "$REVIEWS_DIR"

# Determine the next LINT sequence number by scanning existing LINT-NNN.md files.
_next_seq() {
  local max=0 n f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Extract the NNN from LINT-NNN.md (or LINT-NNN.applied.md etc.)
    n=$(basename "$f" | grep -Eo 'LINT-[0-9]+' | grep -Eo '[0-9]+' || true)
    [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
  done < <(find "${REVIEWS_DIR}" -maxdepth 1 -name 'LINT-*.md' 2>/dev/null || true)
  printf '%d' $((max + 1))
}

NEXT_SEQ=$(_next_seq)

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
  [ "$QUIET" -eq 0 ] && printf 'INFO: no api/*.md or modules/*.md files found in %s\n' "$DESIGN_DIR"
  exit 0
fi

# ─── Core scanning logic ──────────────────────────────────────────────────────

FINDING_COUNT=0

_emit_finding() {
  local rel_file="$1" lineno="$2" token_label="$3" offending_line="$4"
  local seq_padded seq_num
  seq_num=$NEXT_SEQ
  seq_padded=$(printf '%03d' "$seq_num")
  NEXT_SEQ=$((NEXT_SEQ + 1))
  FINDING_COUNT=$((FINDING_COUNT + 1))

  local issue_file="${REVIEWS_DIR}/LINT-${seq_padded}.md"

  # Print to stdout unless --quiet
  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-L2] blocker  %s:%d — placeholder token "%s" inside ```json block\n' \
      "$rel_file" "$lineno" "$token_label"
    printf '  Fix: replace placeholder with a realistic example value\n'
  fi

  # Write the issue file
  cat > "$issue_file" <<ISSUE_EOF
---
id: LINT-${seq_padded}
status: new
severity: blocker
criterion_id: CR-L2
file: "${rel_file}"
line: ${lineno}
token: "${token_label}"
source: script
---

# CR-L2 — Forbidden placeholder in \`\`\`json block

**File**: \`${rel_file}\`
**Line**: ${lineno}
**Token**: \`${token_label}\`

Forbidden placeholder token found inside a fenced \`\`\`json\`\`\` block.

Offending line:
\`\`\`
${offending_line}
\`\`\`

## Suggested Fix

Replace the placeholder token with a realistic example value derived from
the surrounding Request/Response table and field constraints.

Examples:
- \`"TODO"\` / \`"TBD"\` → actual example string e.g. \`"active"\`, \`"user@example.com"\`
- \`"..."\` / \`...\` → populated object/array e.g. \`{"key": "value"}\`, \`[1, 2, 3]\`
- \`<field_name>\` → typed example value e.g. \`"my-value"\`, \`42\`, \`true\`
- \`PLACEHOLDER\` → the actual value the field would hold in a realistic scenario
- \`XXX\` → a concrete representative value
- \`FIXME\` → fill with the correct value per the API contract
ISSUE_EOF
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
      "${#TARGET_FILES[@]}"
  else
    printf 'CR-L2: %d finding(s) written to %s\n' "$FINDING_COUNT" "$REVIEWS_DIR"
  fi
fi

if [ "$FINDING_COUNT" -gt 0 ] && [ "$STRICT" -eq 1 ]; then
  exit 1
fi

exit 0
