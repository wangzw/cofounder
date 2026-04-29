#!/usr/bin/env bash
# check-single-source-of-truth.sh — CR-X7 (single-source-of-truth)
# Usage: check-single-source-of-truth.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-X7: data-model definitions (interface/type/class/enum/struct
# in TypeScript-style fenced code blocks within "## Data Models" sections)
# MUST have exactly one canonical home.  Cross-file copies MUST be byte-equal
# to the canonical definition AND carry a <!-- excerpt-from: M-NNN-{slug} -->
# HTML-comment marker.
#
# Conservative approach — only case 1 (data models) is implemented.
# Cases 2 (endpoint-signature drift) and 3 (boundary-enforcement rule copies)
# are noted as TODO below.
#
# ─────────────────────────────────────────────────────────────────────────────
# ALGORITHM
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. SCAN PHASE
#    For every scanned file (modules/M-*.md, api/API-*.md, README.md), extract
#    each TypeScript-style type definition found inside a "## Data Models"
#    section.  A definition begins with a line matching:
#      ^(export )?(interface|type|class|enum|struct)[[:space:]]+<Name>
#    and ends at the closing "}" (or ";" for type aliases).
#
#    For each (TypeName, DefinitionText) record the source file.
#
# 2. GROUP PHASE
#    Group records by TypeName.  Types that appear in only one file → OK.
#    Types in 2+ files → check:
#
#    a) CONTENT EQUALITY
#       Byte-compare definition text across all occurrences (strip trailing
#       whitespace for robustness but preserve internal indentation).
#       If any two occurrences differ in content → BLOCKER (content divergence).
#
#    b) EXCERPT MARKER
#       For files that are NOT the "primary" (= file where the type first
#       appears, i.e. canonical alphabetically by filename), check whether
#       the file contains:
#         <!-- excerpt-from: <primary-module-slug> -->
#       where <primary-module-slug> is the basename of the primary file
#       without the .md extension.
#       If the marker is absent → MECHANICAL (missing excerpt marker).
#
# 3. REPORT PHASE
#    Emit one JSON finding per violation on stdout; print summary on stderr.
#
# ─────────────────────────────────────────────────────────────────────────────
# TODO (endpoint-signature drift — case 2):
#   For each (METHOD PATH) in api/API-*.md, check every module's ## API Surface
#   table row summary cell against the api/ file description.  Warn if they
#   diverge "wildly" (heuristic: ratio of common tokens < 0.4, or length
#   differs by more than 3×).  Deferred: too many formatting variants in the
#   wild to be conservative here.
#
# TODO (boundary-enforcement rule copies — case 3):
#   Trust X6 for layering and L3 for column completeness.  No separate X7
#   check for boundary-enforcement rules.
# ─────────────────────────────────────────────────────────────────────────────
#
# Exit codes:
#   0  No violations found
#   1  At least one violation found AND (blocker present OR --strict set)
#   2  Usage error or <design-dir> not found
#
# Findings are emitted as JSON on stdout; run-checkers.sh writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.

set -euo pipefail

# ─── argument parsing ─────────────────────────────────────────────────────────
DESIGN_DIR=""
QUIET=0
STRICT=0

for arg in "$@"; do
  case "$arg" in
    --quiet)  QUIET=1 ;;
    --strict) STRICT=1 ;;
    -*)
      printf 'ERROR: unknown flag: %s\n' "$arg" >&2
      printf 'Usage: check-single-source-of-truth.sh <design-dir> [--quiet] [--strict]\n' >&2
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
  printf 'Usage: check-single-source-of-truth.sh <design-dir> [--quiet] [--strict]\n' >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design directory not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
MODULES_DIR="$DESIGN_DIR/modules"
API_DIR="$DESIGN_DIR/api"
README="$DESIGN_DIR/README.md"

# ─── helpers ──────────────────────────────────────────────────────────────────

VIOLATION_COUNT=0
HAS_BLOCKER=0
JSON_FINDINGS=""

# emit_issue: emit one finding as a JSON entry on stdout (accumulated).
# Args:
#   $1 severity   (blocker | mechanical)
#   $2 primary    relative path of canonical file
#   $3 duplicate  relative path of duplicate file
#   $4 type_name  the conflicting type name
#   $5 title      short title
#   $6 reasoning  multi-line reasoning text
#   $7 fix        suggested fix text
emit_issue() {
  local severity="$1"
  local primary_rel="$2"
  local dup_rel="$3"
  local type_name="$4"
  local title="$5"
  local reasoning="$6"
  local fix="$7"

  if [ "$QUIET" -eq 0 ]; then
    printf '[CR-X7] %s  %s — %s\n' "$severity" "$dup_rel" "$title" >&2
  fi

  # Accumulate JSON finding
  _jfile=$(printf '%s' "$dup_rel" | sed 's/"/\\"/g')
  _jtitle=$(printf '%s' "$title" | sed 's/"/\\"/g; s/\n/ /g')
  _jfix=$(printf '%s' "$fix" | sed 's/"/\\"/g; s/\n/ /g')
  _jentry="{\"criterion_id\":\"CR-X7\",\"file\":\"${_jfile}\",\"severity\":\"${severity}\",\"description\":\"${_jtitle}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi

  VIOLATION_COUNT=$(( VIOLATION_COUNT + 1 ))
  if [ "$severity" = "blocker" ]; then
    HAS_BLOCKER=1
  fi
}

# ─── PHASE 1: SCAN — extract Data Model definitions from relevant files ────────
#
# We scan:
#   modules/M-*.md
#   api/API-*.md
#   README.md
#
# For each file we look for a "## Data Models" section (H2 exactly).
# Inside that section we search for TypeScript-style type definitions:
#   (export )(interface|type|class|enum|struct) <Name>[<Generics>] [extends ...] {
#   ...
#   }
# or for type aliases:
#   (export )type <Name> = ...;
#
# We capture:
#   - the type name
#   - the full definition text (normalised: trailing whitespace trimmed per line)
#   - the source file (relative path)
#
# Storage: temporary files in /tmp/ to avoid bash associative-array size limits
# and to stay POSIX-compatible for the inner awk parsing loop.
#
# Format of the record file:
#   One record per line — but definitions can be multi-line, so we use a
#   separator-based approach with awk writing to per-type temp files.
#
# Implementation strategy:
#   Use awk to parse each file, detect the ## Data Models section, extract
#   type definitions, and write each one to a temp record file:
#     /tmp/x7-types/<TypeName>/<relfile-slug>
#   The content of each temp file is the normalised definition text.
#   After all files are scanned, we iterate the /tmp/x7-types/ directory,
#   find any TypeName with >1 entry, and perform the checks.

TMP_TYPES_DIR=$(mktemp -d /tmp/x7-types-XXXXXX)

# build_scan_list: collect all files to scan
scan_files=()
[ -f "$README" ] && scan_files+=("$README")
if [ -d "$MODULES_DIR" ]; then
  while IFS= read -r f; do
    scan_files+=("$f")
  done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' 2>/dev/null | sort)
fi
if [ -d "$API_DIR" ]; then
  while IFS= read -r f; do
    scan_files+=("$f")
  done < <(find "$API_DIR" -maxdepth 1 -name 'API-*.md' 2>/dev/null | sort)
fi

# parse_file_for_models: awk script that extracts type definitions from a file.
# Prints records in the format:
#   __TYPE__ <TypeName>
#   <definition line 1>
#   <definition line 2>
#   ...
#   __END__
# Only runs inside a "## Data Models" section (H2 exact match).
AWK_EXTRACTOR='
BEGIN {
  in_data_models = 0
  in_code_block  = 0
  in_definition  = 0
  brace_depth    = 0
  type_name      = ""
  def_lines      = ""
  is_type_alias  = 0   # 1 when we are collecting a "type X = ..." alias (ends at ;)
}

# Detect H2 section boundaries
/^## / {
  # Close any open definition (safety net)
  if (in_definition) {
    print "__TYPE__ " type_name
    print def_lines
    print "__END__"
    in_definition  = 0
    type_name      = ""
    def_lines      = ""
    brace_depth    = 0
    is_type_alias  = 0
  }

  if ($0 ~ /^## Data Models[[:space:]]*$/ || $0 ~ /^## Data Model[[:space:]]*$/) {
    in_data_models = 1
  } else {
    in_data_models = 0
  }
  next
}

!in_data_models { next }

# Track fenced code blocks (``` ... ```)
/^```/ {
  if (in_code_block) {
    # Closing fence — flush any in-progress definition
    if (in_definition) {
      print "__TYPE__ " type_name
      print def_lines
      print "__END__"
      in_definition  = 0
      type_name      = ""
      def_lines      = ""
      brace_depth    = 0
      is_type_alias  = 0
    }
    in_code_block = 0
  } else {
    in_code_block = 1
  }
  next
}

!in_code_block { next }

# ── inside a fenced code block inside ## Data Models ──────────────────────

# Detect the start of a type definition:
#   (export )?(interface|type|class|enum|struct) <Name>[...] [{|=]
{
  line = $0
  # trim trailing whitespace
  gsub(/[[:space:]]+$/, "", line)

  if (!in_definition) {
    # Try to match a start line
    # Pattern: optional "export " then keyword then whitespace then identifier
    if (match(line, /^(export[[:space:]]+)?(interface|type|class|enum|struct)[[:space:]]+([A-Za-z_][A-Za-z0-9_<>,[:space:]]*)/, arr) ||
        match(line, /^(export[[:space:]]+)?(interface|type|class|enum|struct)[[:space:]]+([A-Za-z_][A-Za-z0-9_<>, ]*)/)) {
      # Extract keyword and name using split on whitespace
      # We need the identifier right after the keyword (skip "export" if present)
      n = split(line, parts, /[[:space:]]+/)
      idx = 1
      if (parts[idx] == "export") idx++
      kw = parts[idx]   # interface / type / class / enum / struct
      idx++
      name = parts[idx]
      # Strip any trailing generics from name (e.g. "Foo<T>" → "Foo")
      gsub(/<.*/, "", name)
      gsub(/[^A-Za-z0-9_]/, "", name)   # keep only identifier chars
      if (name == "") next

      type_name     = name
      in_definition = 1
      def_lines     = line

      # Determine if this is a type alias (no braces expected — ends with ;)
      is_type_alias = (kw == "type") ? 1 : 0

      # Count opening braces on the start line
      brace_depth = 0
      tmp = line
      while (match(tmp, /\{/)) { brace_depth++; tmp = substr(tmp, RSTART+1) }
      tmp = line
      while (match(tmp, /\}/)) { brace_depth--; tmp = substr(tmp, RSTART+1) }

      # For type aliases: if the line ends with ";" → single-line definition
      if (is_type_alias && line ~ /;[[:space:]]*$/) {
        print "__TYPE__ " type_name
        print def_lines
        print "__END__"
        in_definition  = 0
        type_name      = ""
        def_lines      = ""
        brace_depth    = 0
        is_type_alias  = 0
      } else if (!is_type_alias && brace_depth <= 0 && line ~ /\{[^}]*\}/) {
        # Single-line brace definition like  interface Foo { x: number }
        print "__TYPE__ " type_name
        print def_lines
        print "__END__"
        in_definition  = 0
        type_name      = ""
        def_lines      = ""
        brace_depth    = 0
        is_type_alias  = 0
      }
    }
    next
  }

  # ── in_definition == 1 ────────────────────────────────────────────────────
  def_lines = def_lines "\n" line

  if (is_type_alias) {
    if (line ~ /;[[:space:]]*$/) {
      print "__TYPE__ " type_name
      print def_lines
      print "__END__"
      in_definition  = 0
      type_name      = ""
      def_lines      = ""
      is_type_alias  = 0
    }
  } else {
    # Count braces
    tmp = line
    while (match(tmp, /\{/)) { brace_depth++; tmp = substr(tmp, RSTART+1) }
    tmp = line
    while (match(tmp, /\}/)) { brace_depth--; tmp = substr(tmp, RSTART+1) }

    if (brace_depth <= 0) {
      print "__TYPE__ " type_name
      print def_lines
      print "__END__"
      in_definition  = 0
      type_name      = ""
      def_lines      = ""
      brace_depth    = 0
    }
  }
}
'

# ─── run the awk extractor on every scan file ─────────────────────────────────
for scan_file in "${scan_files[@]+"${scan_files[@]}"}"; do
  rel_file="${scan_file#"$DESIGN_DIR/"}"
  # Produce a safe slug for use as a filename component: replace / and spaces
  file_slug="${rel_file//\//__}"
  file_slug="${file_slug// /_}"

  # Run extractor; capture output
  extractor_out=$(awk "$AWK_EXTRACTOR" "$scan_file" 2>/dev/null || true)
  [ -z "$extractor_out" ] && continue

  # Parse the records written by awk
  # Records are delimited by __TYPE__ <Name> ... __END__
  current_type=""
  current_def=""
  in_record=0

  while IFS= read -r rec_line; do
    if [[ "$rec_line" =~ ^__TYPE__[[:space:]](.+)$ ]]; then
      current_type="${BASH_REMATCH[1]}"
      current_def=""
      in_record=1
    elif [ "$rec_line" = "__END__" ] && [ "$in_record" -eq 1 ]; then
      # Sanitise type name for use as a directory name (keep only safe chars)
      safe_type="${current_type//[^A-Za-z0-9_]/_}"
      [ -z "$safe_type" ] || [ -z "$current_type" ] && { in_record=0; continue; }

      type_dir="$TMP_TYPES_DIR/$safe_type"
      mkdir -p "$type_dir"

      # Store:
      #   <type_dir>/<file_slug>.def   — normalised definition text
      #   <type_dir>/<file_slug>.meta  — one line: "TypeName|rel_file"
      def_file="$type_dir/${file_slug}.def"
      meta_file="$type_dir/${file_slug}.meta"

      printf '%s' "$current_def" > "$def_file"
      printf '%s|%s\n' "$current_type" "$rel_file" > "$meta_file"

      in_record=0
      current_type=""
      current_def=""
    elif [ "$in_record" -eq 1 ]; then
      if [ -z "$current_def" ]; then
        current_def="$rec_line"
      else
        current_def="$current_def
$rec_line"
      fi
    fi
  done <<< "$extractor_out"
done

# ─── PHASE 2: GROUP + CHECK ───────────────────────────────────────────────────
#
# For each TypeName directory in TMP_TYPES_DIR:
#   - Count the number of .meta files.  If 1 → no finding.
#   - If >1 → check content equality and excerpt markers.

for type_dir in "$TMP_TYPES_DIR"/*/; do
  [ -d "$type_dir" ] || continue

  # Collect all meta files
  meta_files=()
  while IFS= read -r mf; do
    meta_files+=("$mf")
  done < <(find "$type_dir" -maxdepth 1 -name '*.meta' 2>/dev/null | sort)

  count="${#meta_files[@]}"
  [ "$count" -le 1 ] && continue

  # ── read all occurrences ───────────────────────────────────────────────────
  # Parallel arrays: occ_file[] occ_type[] occ_def[]
  occ_files=()
  occ_types=()
  occ_defs=()

  for mf in "${meta_files[@]}"; do
    IFS='|' read -r t_name t_relfile < "$mf"
    def_file="${mf%.meta}.def"
    t_def=""
    [ -f "$def_file" ] && t_def="$(cat "$def_file")"

    occ_types+=("$t_name")
    occ_files+=("$t_relfile")
    occ_defs+=("$t_def")
  done

  # Use the true type name from the first occurrence
  type_name="${occ_types[0]}"

  # ── determine the "primary" (canonical) file ──────────────────────────────
  # The primary is the module/api file with the lowest sort-order filename
  # (modules sort before api which sorts before README; within modules the
  # lowest M-NNN wins).  We use the occ_files[] sorted order (already sorted
  # from find | sort above).
  primary_rel="${occ_files[0]}"
  primary_def="${occ_defs[0]}"

  # ── check 1: content equality ─────────────────────────────────────────────
  content_diverged=0
  for (( i=1; i<count; i++ )); do
    dup_rel="${occ_files[$i]}"
    dup_def="${occ_defs[$i]}"

    if [ "$primary_def" != "$dup_def" ]; then
      content_diverged=1
      emit_issue \
        "blocker" \
        "$primary_rel" \
        "$dup_rel" \
        "$type_name" \
        "Data model \`${type_name}\` has divergent definitions in ${primary_rel} and ${dup_rel}" \
        "Type \`${type_name}\` is defined in at least two files with non-identical content.

Per CR-X7 (structural-lint.md §X7), every data-model definition MUST have exactly one canonical home.  Cross-file copies that differ in content violate the single-source-of-truth invariant: consuming coding agents cannot know which definition is authoritative, leading to implementation drift.

Primary: \`${primary_rel}\`
Duplicate (different): \`${dup_rel}\`" \
        "Choose the authoritative definition and do one of:
A) Remove the duplicate in \`${dup_rel}\` and import the type from the canonical module.
B) If \`${dup_rel}\` intentionally carries a quoted excerpt, make the content byte-equal to \`${primary_rel}\` and add the marker \`<!-- excerpt-from: $(basename "${primary_rel%.md}") -->\` immediately above the definition in \`${dup_rel}\`."
    fi
  done

  # ── check 2: excerpt marker (only for byte-equal copies) ──────────────────
  # Skip if content diverged (already emitted a blocker above; don't pile on).
  [ "$content_diverged" -eq 1 ] && continue

  for (( i=1; i<count; i++ )); do
    dup_rel="${occ_files[$i]}"
    dup_abs="$DESIGN_DIR/$dup_rel"
    primary_slug="$(basename "${primary_rel%.md}")"

    # Check for excerpt marker anywhere in the file
    if ! grep -qF "<!-- excerpt-from: ${primary_slug} -->" "$dup_abs" 2>/dev/null; then
      emit_issue \
        "mechanical" \
        "$primary_rel" \
        "$dup_rel" \
        "$type_name" \
        "Data model \`${type_name}\` copied in ${dup_rel} without \`<!-- excerpt-from: ${primary_slug} -->\` marker" \
        "Type \`${type_name}\` appears with identical content in both \`${primary_rel}\` (canonical) and \`${dup_rel}\` (copy), but \`${dup_rel}\` does not contain the required HTML comment \`<!-- excerpt-from: ${primary_slug} -->\`.

Per CR-X7 (structural-lint.md §X7), cross-file copies of a canonical definition MUST be marked as quoted excerpts so that future editors know the copy must stay in sync with the source of truth.  An unmarked copy looks like an independent definition and will silently drift when the canonical is updated." \
        "Add the following HTML comment immediately above the \`${type_name}\` definition block in \`${dup_rel}\`:

\`\`\`
<!-- excerpt-from: ${primary_slug} -->
\`\`\`

This marks the block as a quoted excerpt of the canonical definition in \`${primary_rel}\`, signalling to editors that changes to the canonical MUST be mirrored here."
    fi
  done
done

# ─── cleanup ──────────────────────────────────────────────────────────────────
rm -rf "$TMP_TYPES_DIR"

# ─── summary ──────────────────────────────────────────────────────────────────
if [ "$VIOLATION_COUNT" -eq 0 ]; then
  [ "$QUIET" -eq 0 ] && printf 'OK 0 findings\n' >&2
  printf '[]\n'
  exit 0
fi

[ "$QUIET" -eq 0 ] && printf 'FAIL %d finding(s)\n' "$VIOLATION_COUNT" >&2
printf '[%s]\n' "$JSON_FINDINGS"

if [ "$HAS_BLOCKER" -eq 1 ] || [ "$STRICT" -eq 1 ]; then
  exit 1
fi
exit 0
