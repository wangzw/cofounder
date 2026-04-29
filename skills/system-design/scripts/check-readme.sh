#!/usr/bin/env bash
# check-readme.sh — formal review of <design-dir>/README.md.
#
# Implements:
#   CR-SD01    readme-shape                 — README.md exists with module/api index
#   CR-SD02    feature-module-matrix-present — Feature-Module mapping table present
#   CR-SD03    no-tbd-remaining             — no TBD/TODO/FIXME/PLACEHOLDER tokens
#   CR-SDFM01  readme-frontmatter           — required frontmatter keys
#
# Usage: check-readme.sh <design-dir>

set -euo pipefail

DESIGN_ROOT="${1:-}"
if [ -z "$DESIGN_ROOT" ] || [ ! -d "$DESIGN_ROOT" ]; then
  echo "ERROR: design root not found: ${DESIGN_ROOT:-<empty>}" >&2
  echo "Usage: check-readme.sh <design-dir>" >&2
  exit 2
fi
DESIGN_ROOT="${DESIGN_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$DESIGN_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

design_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from sd_lint import (
    Finding, list_dir, read_text, parse_frontmatter, frontmatter_error, emit,
)

MODULE_FILE_RE = re.compile(r"^M-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
API_FILE_RE = re.compile(r"^API-(\d{3,})(?:-[a-z0-9-]+)?\.md$")

findings: list[Finding] = []

readme_path = os.path.join(design_root, "README.md")
readme = read_text(readme_path)
if readme is None:
    findings.append(Finding(
        criterion_id="CR-SD01",
        file="README.md",
        severity="critical",
        description="required top-level file missing: README.md",
        suggested_fix="create README.md with frontmatter, module index, and Feature-Module Mapping matrix",
    ))
    emit(findings, scope_label="(README.md)")

# ─── CR-SDFM01: frontmatter ──────────────────────────────────────────
fm_err = frontmatter_error(readme)
if fm_err:
    findings.append(Finding(
        criterion_id="CR-SDFM01",
        file="README.md",
        severity="error",
        description=f"frontmatter problem: {fm_err}",
        suggested_fix="add a YAML frontmatter block with id, title, owner, status, version, prd_ref",
    ))
    fm = {}
    body = readme
else:
    fm, body = parse_frontmatter(readme)

REQUIRED_FM = ("id", "title", "owner", "status", "version", "prd_ref")
for key in REQUIRED_FM:
    if not fm_err and (key not in fm or not str(fm.get(key, "")).strip()):
        findings.append(Finding(
            criterion_id="CR-SDFM01",
            file="README.md",
            severity="error",
            description=f"frontmatter missing required key: {key!r}",
            suggested_fix=f"add `{key}: <value>` to the README frontmatter block",
        ))

# ─── CR-SD01: index of modules + apis ────────────────────────────────
module_files = [f for f in list_dir(design_root, "modules") if MODULE_FILE_RE.match(f or "")]
api_files = [f for f in list_dir(design_root, "api") if API_FILE_RE.match(f or "")]

# Bundle is required to have at least one module — the README must enumerate it.
if not module_files:
    findings.append(Finding(
        criterion_id="CR-SD01",
        file="modules/",
        severity="critical",
        description="no module files (M-NNN-{slug}.md) found under modules/",
        suggested_fix="create at least one modules/M-001-{slug}.md file or use --evolve to extend an existing design",
    ))

for fname in module_files:
    if f"modules/{fname}" not in body and f"({fname})" not in body:
        # Still allow plain mention of M-NNN id in the index
        m = MODULE_FILE_RE.match(fname)
        mid = f"M-{m.group(1)}"
        if mid not in body:
            findings.append(Finding(
                criterion_id="CR-SD01",
                file="README.md",
                severity="error",
                description=f"module leaf {fname} (id {mid}) not referenced from README",
                suggested_fix=f"add a link to modules/{fname} in the module index section",
            ))

for fname in api_files:
    if f"api/{fname}" not in body and f"({fname})" not in body:
        m = API_FILE_RE.match(fname)
        aid = f"API-{m.group(1)}"
        if aid not in body:
            findings.append(Finding(
                criterion_id="CR-SD01",
                file="README.md",
                severity="error",
                description=f"API leaf {fname} (id {aid}) not referenced from README",
                suggested_fix=f"add a link to api/{fname} in the API index section",
            ))

# ─── CR-SD02: Feature-Module Mapping matrix presence ─────────────────
matrix_heading_re = re.compile(r"^#{1,6}\s+Feature-Module Mapping\b", re.M | re.I)
has_matrix_heading = bool(matrix_heading_re.search(body))
if not has_matrix_heading:
    findings.append(Finding(
        criterion_id="CR-SD02",
        file="README.md",
        severity="error",
        description="missing 'Feature-Module Mapping' section",
        suggested_fix="add `## Feature-Module Mapping` followed by a table of features × modules with ✦/△ symbols",
    ))
else:
    # Extract section content until next heading of same/higher level
    m = matrix_heading_re.search(body)
    section = body[m.end():]
    nxt = re.search(r"\n#{1,6}\s+", section)
    section = section[:nxt.start()] if nxt else section
    # Must contain at least one ✦ or △ symbol AND a markdown table
    has_pipe_table = re.search(r"^\s*\|.+\|\s*$", section, re.M) is not None
    has_symbol = ("✦" in section) or ("△" in section)
    if not has_pipe_table:
        findings.append(Finding(
            criterion_id="CR-SD02",
            file="README.md",
            severity="error",
            description="Feature-Module Mapping section has no markdown table",
            suggested_fix="add a pipe-delimited table with feature columns and module rows",
        ))
    if not has_symbol:
        findings.append(Finding(
            criterion_id="CR-SD02",
            file="README.md",
            severity="error",
            description="Feature-Module Mapping table contains no ✦/△ symbols",
            suggested_fix="mark each feature × module intersection with ✦ (modifies data) or △ (read-only)",
        ))

# ─── CR-SD03: no TBD/TODO/FIXME/PLACEHOLDER ──────────────────────────
forbidden_re = re.compile(r"\b(TBD|TODO|FIXME|PLACEHOLDER)\b")
seen_placeholder_lines = 0
for i, line in enumerate(body.splitlines(), 1):
    if forbidden_re.search(line):
        findings.append(Finding(
            criterion_id="CR-SD03",
            file="README.md",
            severity="error",
            description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
            suggested_fix="replace with a concrete value or drop the section if not applicable",
        ))
        seen_placeholder_lines += 1
        if seen_placeholder_lines >= 1:
            break

emit(findings, scope_label="(README.md)")
PYEOF
