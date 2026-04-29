#!/usr/bin/env bash
# check-feature-module-mapping.sh — formal review of the
# Feature-Module Mapping matrix in <design-dir>/README.md.
#
# Implements:
#   CR-SD05  feature-module-mapping-bidirectional
#     - every PRD feature F-NNN appears in the matrix with at least one ✦
#     - every module M-NNN declared under modules/ is referenced from at least
#       one matrix cell (✦ or △)
#
# PRD path resolution order:
#   1. --prd-dir <path>        explicit override flag
#   2. <design-dir>/.review/state.yml field `prd_ref:`
#   3. README.md frontmatter field `prd_ref:`
#
# If the PRD path cannot be resolved or its features/ directory does not exist,
# the script SKIPS the "every feature appears" check and only enforces the
# "every module is referenced" half — emitting a `warning` finding so the
# missing PRD link is visible but not a hard fail.
#
# Usage:
#   check-feature-module-mapping.sh <design-dir> [--prd-dir <prd-path>]

set -euo pipefail

DESIGN_DIR=""
PRD_DIR_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --prd-dir)
      shift
      PRD_DIR_OVERRIDE="${1:-}"
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$DESIGN_DIR" ]; then DESIGN_DIR="$1"; else
        echo "ERROR: unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
  shift || true
done

if [ -z "$DESIGN_DIR" ] || [ ! -d "$DESIGN_DIR" ]; then
  echo "ERROR: design root not found: ${DESIGN_DIR:-<empty>}" >&2
  echo "Usage: check-feature-module-mapping.sh <design-dir> [--prd-dir <prd-path>]" >&2
  exit 2
fi
DESIGN_DIR="${DESIGN_DIR%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$DESIGN_DIR" "$SCRIPT_DIR/lib" "$PRD_DIR_OVERRIDE" <<'PYEOF'
import os, re, sys

design_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
prd_override = sys.argv[3]
from sd_lint import (
    Finding, list_dir, read_text, parse_frontmatter, emit,
)

MODULE_FILE_RE = re.compile(r"^M-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
FEATURE_FILE_RE = re.compile(r"^F-(\d{3,})(?:-[a-z0-9-]+)?\.md$")

findings: list[Finding] = []

readme = read_text(os.path.join(design_root, "README.md"))
if readme is None:
    findings.append(Finding(
        criterion_id="CR-SD05",
        file="README.md",
        severity="critical",
        description="README.md missing — cannot validate Feature-Module Mapping",
        suggested_fix="create README.md with a Feature-Module Mapping section",
    ))
    emit(findings, scope_label="(feature-module mapping)")

# ─── Resolve PRD path ────────────────────────────────────────────────
def resolve_prd_path() -> str:
    if prd_override:
        return prd_override
    state_path = os.path.join(design_root, ".review", "state.yml")
    if os.path.isfile(state_path):
        with open(state_path, "r", encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^prd_ref\s*:\s*(.+)$", line.strip())
                if m:
                    val = m.group(1).strip().strip("'\"")
                    if val and val.lower() != "na":
                        return val
    fm, _ = parse_frontmatter(readme)
    val = fm.get("prd_ref", "")
    if val and val.lower() != "na":
        return val
    return ""

prd_path = resolve_prd_path()
prd_features_dir = ""
if prd_path:
    # Resolve relative to design_root if not absolute
    candidate = prd_path
    if not os.path.isabs(candidate):
        candidate = os.path.normpath(os.path.join(design_root, candidate))
    # If candidate ends in README.md, strip it
    if candidate.endswith("/README.md"):
        candidate = candidate[: -len("/README.md")]
    prd_features_dir = os.path.join(candidate, "features") if os.path.isdir(candidate) else ""

# ─── Extract matrix section from README ──────────────────────────────
matrix_re = re.compile(r"^#{1,6}\s+Feature-Module Mapping\b", re.M | re.I)
m = matrix_re.search(readme)
if not m:
    findings.append(Finding(
        criterion_id="CR-SD05",
        file="README.md",
        severity="error",
        description="missing 'Feature-Module Mapping' section — cannot validate bidirectional mapping",
        suggested_fix="add `## Feature-Module Mapping` followed by a table of features × modules",
    ))
    emit(findings, scope_label="(feature-module mapping)")
section = readme[m.end():]
nxt = re.search(r"\n##\s+", section)
section = section[:nxt.start()] if nxt else section

# Parse matrix: collect F-NNN ids row labels, M-NNN ids column headers,
# and which (F, M) cells contain ✦.
table_lines = [ln for ln in section.splitlines() if ln.lstrip().startswith("|")]
if not table_lines:
    findings.append(Finding(
        criterion_id="CR-SD05",
        file="README.md",
        severity="error",
        description="Feature-Module Mapping section has no markdown table",
        suggested_fix="add a pipe-delimited table with feature columns/rows and module rows/cols",
    ))
    emit(findings, scope_label="(feature-module mapping)")

# Split rows into cells
def split_row(line):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    return cells

# Identify header row: the first row with at least one M-NNN token
module_col_index: dict[str, int] = {}
header_row_idx = -1
for idx, line in enumerate(table_lines):
    cells = split_row(line)
    found = {}
    for i, cell in enumerate(cells):
        cm = re.search(r"M-(\d{3,})", cell)
        if cm:
            found[f"M-{int(cm.group(1)):03d}"] = i
    if found:
        module_col_index = found
        header_row_idx = idx
        break

if header_row_idx < 0:
    findings.append(Finding(
        criterion_id="CR-SD05",
        file="README.md",
        severity="error",
        description="Feature-Module Mapping has no row containing M-NNN module headers",
        suggested_fix="add a header row that names each module column with its M-NNN id",
    ))
    emit(findings, scope_label="(feature-module mapping)")

# Walk data rows for ✦ (and △ for the reverse-coverage check)
features_with_full_alloc: set[str] = set()
modules_referenced: set[str] = set()
for line in table_lines[header_row_idx + 1:]:
    cells = split_row(line)
    if not cells:
        continue
    # skip separator rows (e.g. |---|---|)
    if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
        continue
    # row label — first cell — may contain F-NNN id
    fid = None
    fm = re.search(r"F-(\d{3,})", cells[0])
    if fm:
        fid = f"F-{int(fm.group(1)):03d}"
    for mid, col_idx in module_col_index.items():
        if col_idx >= len(cells):
            continue
        cell = cells[col_idx]
        if "✦" in cell:
            modules_referenced.add(mid)
            if fid:
                features_with_full_alloc.add(fid)
        elif "△" in cell:
            modules_referenced.add(mid)

# ─── Check 1: every PRD feature appears with at least one ✦ ──────────
if prd_features_dir and os.path.isdir(prd_features_dir):
    prd_features: set[str] = set()
    for fname in os.listdir(prd_features_dir):
        fm2 = FEATURE_FILE_RE.match(fname)
        if fm2:
            prd_features.add(f"F-{int(fm2.group(1)):03d}")
    for fid in sorted(prd_features):
        if fid not in features_with_full_alloc:
            findings.append(Finding(
                criterion_id="CR-SD05",
                file="README.md",
                severity="critical",
                description=f"PRD feature {fid} has no ✦ allocation in Feature-Module Mapping matrix",
                suggested_fix=f"add a row for {fid} and mark at least one module column with ✦",
            ))
elif prd_path:
    findings.append(Finding(
        criterion_id="CR-SD05",
        file="README.md",
        severity="warning",
        description=f"prd_ref {prd_path!r} did not resolve to a directory with features/ — feature coverage check skipped",
        suggested_fix=f"correct prd_ref so it points at the PRD bundle directory containing features/",
    ))

# ─── Check 2: every module under modules/ appears in the matrix ──────
module_files = sorted(f for f in list_dir(design_root, "modules") if MODULE_FILE_RE.match(f or ""))
declared_modules = {f"M-{int(MODULE_FILE_RE.match(f).group(1)):03d}" for f in module_files}
for mid in sorted(declared_modules):
    if mid not in modules_referenced:
        findings.append(Finding(
            criterion_id="CR-SD05",
            file="README.md",
            severity="error",
            description=f"module {mid} declared under modules/ but not referenced from any matrix cell",
            suggested_fix=f"add a {mid} column to the matrix and mark its relationship to features with ✦/△",
        ))

emit(findings, scope_label="(feature-module mapping)")
PYEOF
