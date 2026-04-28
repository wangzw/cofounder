#!/usr/bin/env bash
# check-module-interface-types.sh — CR-L5 (module-interface-type-resolution)
#
# Usage:
#   check-module-interface-types.sh <design-dir> [--quiet] [--strict]
#
# What it does:
#   For every <design-dir>/modules/M-*.md, parses the "## Interfaces" or
#   "## Interface Definition" section and extracts PascalCase type names that
#   appear in TypeScript-style signatures (after ":", in generic brackets, or
#   as standalone PascalCase identifiers in arg/return positions).
#
#   For each extracted type, it verifies the type is:
#     1. In the primitive/built-in exemption set (string, number, boolean, …), OR
#     2. Defined inline in the same file via "interface <Type>" or "type <Type>" OR
#        an enum/class declaration, OR
#     3. Declared in a sibling module that is explicitly listed in this module's
#        "## Module Deps" section (or "## Dependencies") — detected by grepping for
#        the type definition in sibling M-*.md files that appear in the Deps listing.
#
#   Unresolved types → issue files at <design-dir>/.reviews/LINT-<NNN>.md
#   (three-digit zero-padded, sequential within this run; continues from the
#   highest existing LINT-NNN.md in .reviews/).
#
# Flags:
#   --quiet   Suppress per-issue stdout progress lines; only final summary.
#   --strict  Treat unresolved types as blockers (default: advisory/mechanical).
#             In strict mode the script exits 1 if any issues are found.
#             Without --strict the script exits 0 even when issues are written
#             (advisory run — findings documented but not treated as gate failures).
#
# Limitations (heuristic check — false positives are possible):
#   - Type extraction uses regex on fenced code blocks; deeply nested generics
#     (e.g. Record<string, Map<K, Promise<V[]>>>) may yield spurious inner tokens.
#   - Language detection is not attempted — the script treats any PascalCase token
#     in a parameter/return-type position as a candidate type name. Go primitive
#     types (int, string, error, etc.) and Python built-ins are on the exemption
#     list, but project-local aliases or unusual casing may produce false positives.
#   - Sibling-import resolution looks for type definitions in all M-*.md files
#     whose module ID appears in the importing module's Deps section; it does NOT
#     parse import statements or namespace qualifiers.
#   - For polyglot designs, run with --strict only if the project has a single
#     primary language; otherwise treat output as advisory.
#
# Output contract:
#   Exit 0  — no issues found (or --strict not set and issues were advisory-only)
#   Exit 1  — issues found AND --strict was set
#   Exit 2  — usage/environment error
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Primitive / built-in exemption set
# Tokens in this set are never reported as unresolved.
# Covers: TypeScript, Go, Python, Rust common primitives + common utility types.
# ---------------------------------------------------------------------------
PRIMITIVES=(
  # TypeScript / JavaScript primitives and utility types
  string String number Number boolean Boolean
  integer Integer float Float double Double
  void Void null Null undefined Undefined
  never Never any Any unknown Unknown object Object
  symbol Symbol bigint BigInt
  Date ISODateString UUID
  # Generic wrappers (base names only; angle-bracket forms stripped separately)
  Record Array Map Set Tuple Enum
  Promise Optional Result Either
  Partial Required Readonly ReadonlyArray NonNullable
  ReturnType InstanceType Parameters ConstructorParameters
  Awaited Extract Exclude Pick Omit
  # Go primitives and common stdlib types
  int int8 int16 int32 int64
  uint uint8 uint16 uint32 uint64
  byte rune uintptr
  float32 float64
  complex64 complex128
  bool error
  # Python built-ins (capitalised form as used in type hints)
  list dict tuple set frozenset
  bytes bytearray memoryview
  type
  # Common cross-language abbreviations / shorthands
  id ID Id
  ok Ok OK
  err Err
  ctx Ctx
  buf Buf
  msg Msg
  req Req
  resp Resp
)

# Build a lookup string for fast membership test via grep
# Use tr + sed instead of paste -sd to stay compatible with BSD (macOS) and GNU.
PRIMITIVES_PATTERN=$(printf '%s\n' "${PRIMITIVES[@]}" | sort -u | tr '\n' '|' | sed 's/|$//')

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DESIGN_DIR=""
QUIET=false
STRICT=false

for arg in "$@"; do
  case "$arg" in
    --quiet)  QUIET=true  ;;
    --strict) STRICT=true ;;
    --*)
      echo "ERROR: unknown flag: $arg" >&2
      echo "Usage: check-module-interface-types.sh <design-dir> [--quiet] [--strict]" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then
        DESIGN_DIR="$arg"
      else
        echo "ERROR: unexpected positional argument: $arg" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$DESIGN_DIR" ]; then
  echo "ERROR: <design-dir> is required." >&2
  echo "Usage: check-module-interface-types.sh <design-dir> [--quiet] [--strict]" >&2
  exit 2
fi

if [ ! -d "$DESIGN_DIR" ]; then
  echo "ERROR: design directory not found: $DESIGN_DIR" >&2
  exit 2
fi

DESIGN_DIR="${DESIGN_DIR%/}"
MODULES_DIR="$DESIGN_DIR/modules"

if [ ! -d "$MODULES_DIR" ]; then
  [ "$QUIET" = false ] && echo "INFO: no modules/ directory found under $DESIGN_DIR — nothing to check." >&2
  printf '[]\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Ensure .reviews/ directory exists
# ---------------------------------------------------------------------------
REVIEWS_DIR="$DESIGN_DIR/.reviews"
mkdir -p "$REVIEWS_DIR"

# Determine starting sequence number (continue from highest existing LINT-NNN.md)
_next_seq() {
  local max=0
  local f seq
  # Nullglob-safe: test each match with -f
  for f in "$REVIEWS_DIR"/LINT-*.md; do
    [ -f "$f" ] || continue
    seq="${f##*/LINT-}"
    seq="${seq%.md}"
    # Strip leading zeros to avoid octal interpretation in arithmetic
    seq=$(echo "$seq" | sed 's/^0*//')
    seq="${seq:-0}"
    if [ "$seq" -gt "$max" ]; then max="$seq"; fi
  done
  echo "$max"
}

SEQ=$(_next_seq)

# ── JSON findings accumulator ─────────────────────────────────────────────────
JSON_FINDINGS=""

# ---------------------------------------------------------------------------
# Helper: emit one LINT issue file
# ---------------------------------------------------------------------------
# Args: module_file  line_hint  type_name  severity  suggested_fix
emit_issue() {
  local module_file="$1"
  local line_hint="$2"
  local type_name="$3"
  local severity="$4"
  local suggested_fix="$5"

  SEQ=$(( SEQ + 1 ))
  local seq_str
  seq_str=$(printf '%03d' "$SEQ")
  local issue_file="$REVIEWS_DIR/LINT-${seq_str}.md"
  local rel_module
  rel_module="${module_file#"$DESIGN_DIR/"}"

  cat > "$issue_file" <<ISSUE
# Lint Issue LINT-${seq_str}

**CR-id:** CR-L5
**Severity:** ${severity}
**File:** ${rel_module}
**Line (approx):** ${line_hint}
**Unresolved type:** \`${type_name}\`

## Description

Type \`${type_name}\` is referenced in the \`## Interface Definition\` (or
\`## Interfaces\`) section of \`${rel_module}\` but could not be resolved to:

1. A primitive / built-in type in the exemption set, OR
2. An inline definition in the same file (i.e. \`interface ${type_name}\`,
   \`type ${type_name}\`, \`class ${type_name}\`, or \`enum ${type_name}\`), OR
3. A definition in an explicitly-imported sibling module listed in this
   module's \`## Module Deps\` (or \`## Dependencies\`) section.

## Suggested Fix

- **Option A — define inline:** Add a \`## Data Models\` section (or extend
  the existing one) in \`${rel_module}\` and declare:
  \`\`\`ts
  interface ${type_name} { /* fields */ }
  // or
  type ${type_name} = /* … */;
  \`\`\`
- **Option B — import from sibling:** Add the owning module to this module's
  \`## Module Deps\` section, then add an inline comment in the Interface
  Definition block:
  \`\`\`
  // Imported from M-XXX: ${type_name}
  \`\`\`
  so the source module name is explicitly recorded in this file.

${suggested_fix}
ISSUE

  if [ "$QUIET" = false ]; then
    echo "  [CR-L5] ${severity}: ${rel_module}:${line_hint} — unresolved type \`${type_name}\` → ${issue_file##*/}" >&2
  fi

  # Accumulate JSON finding
  _jfile=$(printf '%s' "$rel_module" | sed 's/"/\\"/g')
  _jtype=$(printf '%s' "$type_name" | sed 's/"/\\"/g')
  _jdesc="Unresolved type reference \`${_jtype}\` in interface section at line ${line_hint}"
  _jdesc=$(printf '%s' "$_jdesc" | sed 's/"/\\"/g')
  _jfix="Define the type inline in the same file or list the owning module in Module Deps"
  _jfix=$(printf '%s' "$_jfix" | sed 's/"/\\"/g')
  _jentry="{\"criterion_id\":\"CR-L5\",\"file\":\"${_jfile}\",\"severity\":\"${severity}\",\"description\":\"${_jdesc}\",\"suggested_fix\":\"${_jfix}\"}"
  if [ -z "$JSON_FINDINGS" ]; then JSON_FINDINGS="$_jentry"; else JSON_FINDINGS="${JSON_FINDINGS},${_jentry}"; fi
}

# ---------------------------------------------------------------------------
# Helper: check whether a token is in the primitives exemption set
# ---------------------------------------------------------------------------
is_primitive() {
  local token="$1"
  echo "$token" | grep -qE "^(${PRIMITIVES_PATTERN})$"
}

# ---------------------------------------------------------------------------
# Helper: extract dep module IDs (M-NNN) from a module file's Deps section
# ---------------------------------------------------------------------------
extract_dep_ids() {
  local file="$1"
  # Look for "## Module Deps", "## Dependencies", "## Deps" sections and grab M-NNN patterns
  grep -Eo '\bM-[0-9]{3}\b' "$file" 2>/dev/null | sort -u || true
}

# ---------------------------------------------------------------------------
# Helper: extract type definitions from a file (interface/type/class/enum decls)
# ---------------------------------------------------------------------------
defined_types_in_file() {
  local file="$1"
  # Matches: interface Foo, type Foo, class Foo, enum Foo (Go/TS/Rust style)
  grep -Eo '\b(interface|type|class|enum|struct)\s+[A-Z][A-Za-z0-9_]*' "$file" 2>/dev/null \
    | grep -Eo '[A-Z][A-Za-z0-9_]*$' | sort -u || true
}

# ---------------------------------------------------------------------------
# Helper: extract the Interfaces/Interface Definition section from a module file
# Returns lines in that section (until next ## heading or EOF)
# ---------------------------------------------------------------------------
extract_interface_section() {
  local file="$1"
  # Use awk to extract lines between "## Interface" heading and next "## " heading
  awk '
    /^##[[:space:]]+(Interface[[:space:]]Definition|Interfaces)[[:space:]]*$/ { in_section=1; next }
    in_section && /^##[[:space:]]/ { in_section=0 }
    in_section { print }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Helper: extract PascalCase type tokens from a signature block
# Strips primitives and common noise.
# ---------------------------------------------------------------------------
extract_type_tokens() {
  # Read from stdin
  # Strategy:
  #  1. Remove string literals (quoted values)
  #  2. Remove line comments (// ... and # ...)
  #  3. Find tokens after ": " (TypeScript type annotation pattern)
  #  4. Find tokens in generic brackets < >
  #  5. Find tokens after "->" or "=>" (return type annotations)
  #  6. Retain only PascalCase tokens (start with uppercase, at least 2 chars)
  #  7. Strip trailing punctuation [,;(){}[\]|&]
  grep -Eo ':[[:space:]]+[A-Z][A-Za-z0-9_<>\[\], ]+|<[A-Z][A-Za-z0-9_<>, ]+>|->[[:space:]]*[A-Z][A-Za-z0-9_]+|=>[[:space:]]*[A-Z][A-Za-z0-9_]+|\([^)]*\)[[:space:]]*:[[:space:]]*[A-Z][A-Za-z0-9_]+' \
  | grep -Eo '[A-Z][A-Za-z0-9_]+' \
  | sort -u \
  || true
}

# ---------------------------------------------------------------------------
# Main loop: iterate over all M-*.md files
# ---------------------------------------------------------------------------
TOTAL_ISSUES=0
MODULE_FILES=()

# Collect module files
while IFS= read -r -d '' f; do
  MODULE_FILES+=("$f")
done < <(find "$MODULES_DIR" -maxdepth 1 -name 'M-*.md' -print0 2>/dev/null | sort -z)

if [ "${#MODULE_FILES[@]}" -eq 0 ]; then
  [ "$QUIET" = false ] && echo "INFO: no M-*.md files found in $MODULES_DIR — nothing to check." >&2
  printf '[]\n'
  exit 0
fi

[ "$QUIET" = false ] && echo "CR-L5 — checking module interface types in: $DESIGN_DIR" >&2
[ "$QUIET" = false ] && echo "        modules found: ${#MODULE_FILES[@]}" >&2
[ "$QUIET" = false ] && echo "" >&2

# Pre-build: map of module ID -> file path for sibling resolution
declare -A MOD_ID_TO_FILE
for f in "${MODULE_FILES[@]}"; do
  base="${f##*/}"            # M-001-slug.md
  mod_id="${base%%-*}"       # crude: first segment; handle M-NNN pattern
  # More robust: extract M-NNN from basename
  mod_id=$(echo "$base" | grep -Eo '^M-[0-9]+' || true)
  if [ -n "$mod_id" ]; then
    MOD_ID_TO_FILE["$mod_id"]="$f"
  fi
done

for module_file in "${MODULE_FILES[@]}"; do
  # -----------------------------------------------------------------------
  # 1. Extract the Interface Definition section
  # -----------------------------------------------------------------------
  iface_section=$(extract_interface_section "$module_file")

  if [ -z "$iface_section" ]; then
    # No interface section — nothing to check in this file
    continue
  fi

  # -----------------------------------------------------------------------
  # 2. Collect type tokens from the section
  # -----------------------------------------------------------------------
  type_tokens=$(echo "$iface_section" | extract_type_tokens)

  if [ -z "$type_tokens" ]; then
    continue
  fi

  # -----------------------------------------------------------------------
  # 3. Build set of locally defined types in this file
  # -----------------------------------------------------------------------
  local_types=$(defined_types_in_file "$module_file")

  # -----------------------------------------------------------------------
  # 4. Build set of types available from dep modules
  # -----------------------------------------------------------------------
  dep_ids=$(extract_dep_ids "$module_file")
  dep_types=""
  if [ -n "$dep_ids" ]; then
    while IFS= read -r dep_id; do
      [ -z "$dep_id" ] && continue
      dep_file="${MOD_ID_TO_FILE[$dep_id]:-}"
      if [ -n "$dep_file" ] && [ -f "$dep_file" ]; then
        dep_types+=$'\n'"$(defined_types_in_file "$dep_file")"
      fi
    done <<< "$dep_ids"
  fi
  dep_types=$(echo "$dep_types" | sort -u)

  # -----------------------------------------------------------------------
  # 5. For each candidate type token, check resolution
  # -----------------------------------------------------------------------
  # Approximate line number: find first occurrence of the type in the file
  while IFS= read -r type_token; do
    [ -z "$type_token" ] && continue

    # Skip primitives
    if is_primitive "$type_token"; then
      continue
    fi

    # Skip very short tokens (single char — false positives from generic T, K, V)
    if [ "${#type_token}" -le 1 ]; then
      continue
    fi

    # Common generic type parameters: T, K, V, E, R, S, U, N, P — skip
    if echo "$type_token" | grep -qE '^[TKVERSPUN]$'; then
      continue
    fi

    # Check local definition
    if echo "$local_types" | grep -qE "^${type_token}$"; then
      continue
    fi

    # Check dep-imported definition
    if [ -n "$dep_types" ] && echo "$dep_types" | grep -qE "^${type_token}$"; then
      continue
    fi

    # Unresolved — determine approximate line number
    line_hint=$(grep -n "$type_token" "$module_file" 2>/dev/null | head -1 | cut -d: -f1 || echo "?")

    # Severity depends on --strict flag
    if [ "$STRICT" = true ]; then
      severity="blocker"
    else
      severity="advisory"
    fi

    extra_note=""
    if [ "$STRICT" = false ]; then
      extra_note="**Note:** This is an advisory (best-effort) finding. Run with \`--strict\` to treat as a gate blocker."
    fi

    emit_issue "$module_file" "$line_hint" "$type_token" "$severity" "$extra_note"
    TOTAL_ISSUES=$(( TOTAL_ISSUES + 1 ))

  done <<< "$type_tokens"

done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
[ "$QUIET" = false ] && echo "" >&2
if [ "$TOTAL_ISSUES" -eq 0 ]; then
  [ "$QUIET" = false ] && echo "CR-L5 PASS — all interface type references resolve (${#MODULE_FILES[@]} modules checked)." >&2
  printf '[]\n'
  exit 0
else
  [ "$QUIET" = false ] && echo "CR-L5 FINDINGS — ${TOTAL_ISSUES} unresolved type reference(s) across ${#MODULE_FILES[@]} modules." >&2
  [ "$QUIET" = false ] && echo "  Issue files written to: $REVIEWS_DIR" >&2
  printf '[%s]\n' "$JSON_FINDINGS"
  if [ "$STRICT" = true ]; then
    exit 1
  else
    # Advisory mode: issues documented but not a gate failure
    exit 0
  fi
fi
