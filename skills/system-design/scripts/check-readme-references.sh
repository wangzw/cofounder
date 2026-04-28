#!/usr/bin/env bash
# check-readme-references.sh — CR-X8 (readme-references)
# Usage: check-readme-references.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-X8: every relative path referenced from <design-dir>/README.md
# MUST resolve to an existing file.
#
# Detection:
#   1. Parse <design-dir>/README.md for markdown links: [text](path)
#   2. For each link target:
#      - Skip external URLs (http:// / https:// / mailto:).
#      - Skip anchor-only links (#...).
#      - Strip query/fragment suffix (?... / #...) for resolution.
#      - Resolve path relative to README.md's directory.
#        If target starts with ./ or ../ → relative to README dir.
#        If target starts with /           → treat as absolute.
#        Otherwise                         → relative to README dir.
#      - Verify file exists via [ -e "$path" ].
#
# Special-case severities:
#   - modules/M-NNN-{slug}.md  → blocker (module file MUST exist)
#   - api/API-NNN-{slug}.md    → blocker (API file MUST exist)
#   - ../../../prd/…           → mechanical (PRD may not be in same checkout)
#   - all other relative paths → blocker
#   - Anchor-only (#...)       → skip (no file to resolve)
#
# Issue files: <design-dir>/.reviews/LINT-<NNN>.md
#   Each file contains: severity, CR-id, source file, line, offending path,
#   reasoning, and a suggested fix.
#
# Exit codes:
#   0 — no violations found
#   1 — one or more violations found (blocker present, or --strict and any finding)
#   2 — usage / I/O error
#
# Flags:
#   --quiet   Suppress per-violation stdout; only print summary line.
#   --strict  Exit 1 even when all findings are mechanical (no blockers).
#
# Limitations:
#   1. Multi-line markdown links (link text spanning multiple lines) are not
#      parsed — only single-line [text](path) forms are matched.
#   2. Links inside fenced code blocks (``` ... ```) are still parsed; add a
#      known-exception mechanism if needed.
#   3. Only files are checked ([ -e ]) — a path that is a directory passes.
#   4. Fragment-only suffix stripping removes the FIRST occurrence of # after
#      the scheme-check; paths with literal # characters are not supported.
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
      printf 'ERROR: unknown flag: %s\n' "$arg" >&2
      printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
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
  printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design directory not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
README="$DESIGN_DIR/README.md"
REVIEWS_DIR="$DESIGN_DIR/.reviews"

if [ ! -f "$README" ]; then
  printf 'ERROR: README.md not found in: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

mkdir -p "$REVIEWS_DIR"

# ── helpers ───────────────────────────────────────────────────────────────────

# next_lint_seq: return next available zero-padded (3-digit) LINT sequence number.
next_lint_seq() {
  local max=0
  local n
  for f in "$REVIEWS_DIR"/LINT-*.md; do
    [ -e "$f" ] || continue
    n=$(basename "$f" | sed 's/^LINT-\([0-9][0-9]*\).*/\1/')
    if [ "$n" -gt "$max" ] 2>/dev/null; then
      max="$n"
    fi
  done
  printf '%03d' $(( max + 1 ))
}

VIOLATION_COUNT=0
HAS_BLOCKER=0

# emit_issue: write one LINT-NNN.md for a broken link.
# Args: $1=severity  $2=raw-link-target  $3=lineno
emit_issue() {
  local severity="$1"
  local raw_target="$2"
  local lineno="$3"

  local seq
  seq="$(next_lint_seq)"
  local issue_file="$REVIEWS_DIR/LINT-${seq}.md"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-X8] %s  README.md:%s — broken link `%s`\n' \
      "$severity" "$lineno" "$raw_target"
  fi

  cat > "$issue_file" << ISSUE_EOF
# LINT-${seq} — CR-X8 readme-references

**Severity**: ${severity}
**CR-id**: CR-X8
**File**: README.md
**Line**: ${lineno}
**Target**: \`${raw_target}\`

## Reasoning

Relative path \`${raw_target}\` referenced from README does not exist.

Per \`structural-lint.md\` X8: every relative path in \`README.md\` markdown links
MUST resolve to an existing file. Broken links prevent navigation and signal that
the design is incomplete or was partially renamed.

## Suggested Fix

Either fix the path, remove the broken link, or create the referenced file.
ISSUE_EOF

  VIOLATION_COUNT=$(( VIOLATION_COUNT + 1 ))
  if [ "$severity" = "blocker" ]; then
    HAS_BLOCKER=1
  fi
}

# ── parse README.md for markdown links ────────────────────────────────────────
# Extract [text](target) links, one match at a time per line using grep -oE.
# We only care about the target (inside the parentheses).

lineno=0

while IFS= read -r line; do
  lineno=$(( lineno + 1 ))

  # Fast pre-filter: skip lines with no '(' to avoid unnecessary work
  [[ "$line" != *"("* ]] && continue

  # Extract all markdown link targets on this line.
  # Pattern: [text](target)  — greedy text capture, non-greedy target.
  # We use grep -oE to pull each [...](...) token, then strip outer parts.
  while IFS= read -r raw_target; do
    # ── skip non-file targets ──────────────────────────────────────────────
    # External URLs
    case "$raw_target" in
      http://*|https://*|mailto:*) continue ;;
    esac

    # Anchor-only links
    case "$raw_target" in
      \#*) continue ;;
    esac

    # Strip query (?...) and fragment (#...) suffixes for resolution.
    # Remove everything from the first '?' or '#' that follows a non-empty path.
    stripped_target="${raw_target%%\?*}"   # strip ?query
    stripped_target="${stripped_target%%\#*}"  # strip #fragment

    # After stripping, if empty — skip (was anchor + possible query only)
    if [ -z "$stripped_target" ]; then
      continue
    fi

    # ── resolve absolute path ──────────────────────────────────────────────
    local_abs=""
    case "$stripped_target" in
      /*)
        # Absolute path — use as-is
        local_abs="$stripped_target"
        ;;
      *)
        # Relative to README.md's directory (= DESIGN_DIR)
        local_abs="$DESIGN_DIR/$stripped_target"
        ;;
    esac

    # Normalize by resolving .. and . components without cd
    # Use printf + awk to collapse path components
    local_abs="$(printf '%s' "$local_abs" | awk '
    BEGIN { FS="/"; OFS="/" }
    {
      n = split($0, parts, "/")
      j = 0
      for (i = 1; i <= n; i++) {
        p = parts[i]
        if (p == "." || p == "") {
          if (i == 1 && p == "") { result[++j] = ""; }  # leading slash
          continue
        } else if (p == "..") {
          if (j > 1) { j-- }
        } else {
          result[++j] = p
        }
      }
      out = ""
      for (i = 1; i <= j; i++) {
        out = out "/" result[i]
      }
      # Preserve leading slash
      if (substr($0,1,1) != "/") sub("^/", "", out)
      print out
    }
    ')"

    # ── existence check ────────────────────────────────────────────────────
    if [ -e "$local_abs" ]; then
      continue
    fi

    # ── classify severity ──────────────────────────────────────────────────
    sev="blocker"

    # Cross-doc refs to PRD (path contains prd/ component that escapes design-dir)
    # Detect by checking whether the raw target goes up enough levels to leave design-dir.
    # Heuristic: target starts with ../ and contains /prd/ somewhere.
    case "$raw_target" in
      *../*/prd/*|../prd/*|../../prd/*)
        sev="mechanical"
        ;;
    esac

    emit_issue "$sev" "$raw_target" "$lineno"

  done < <(
    # Extract the content inside each (...) that follows a ]
    # Pattern: look for ](  then capture until matching )
    # We use grep -oE to find ](...) tokens, then strip the leading ]( and trailing )
    printf '%s\n' "$line" \
      | grep -oE '\]\([^)]*\)' \
      | sed 's/^\](//;s/)$//'
  )

done < "$README"

# ── summary ───────────────────────────────────────────────────────────────────
link_count=0
# Re-parse just for counting (lightweight — count extracted targets)
while IFS= read -r line; do
  [[ "$line" != *"("* ]] && continue
  cnt=$(printf '%s\n' "$line" | grep -oE '\]\([^)]*\)' | wc -l | tr -d ' ')
  link_count=$(( link_count + cnt ))
done < "$README"

if [ "$QUIET" -eq 0 ]; then
  printf '\nCR-X8 check complete — %d link(s) parsed, %d violation(s) found.\n' \
    "$link_count" "$VIOLATION_COUNT"
  if [ "$VIOLATION_COUNT" -gt 0 ]; then
    printf 'Issue files written to: %s/\n' "$REVIEWS_DIR"
  fi
fi

if [ "$VIOLATION_COUNT" -eq 0 ]; then
  exit 0
fi

if [ "$HAS_BLOCKER" -eq 1 ] || [ "$STRICT" -eq 1 ]; then
  exit 1
fi

# Findings exist but all mechanical and no --strict
exit 0
