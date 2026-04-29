#!/usr/bin/env bash
# check-module.sh — formal review of <design-dir>/modules/M-NNN-*.md files.
#
# Implements:
#   CR-SD04    module-id-monotonic               — IDs M-001, M-002, ... no gaps
#   CR-SD06    module-required-sections          — canonical section headings
#   CR-SD07    module-interface-types            — every Public Interface bullet has type sig
#   CR-SD08    module-deps-vs-protocols          — every depends_on entry references a contract
#   CR-SD09    boundary-enforcement-cols         — boundary table has required columns
#   CR-SD03    no-tbd-remaining                  — no TBD/TODO/FIXME placeholders
#   CR-SDFM02  module-frontmatter                — required frontmatter keys
#
# Refactor of legacy check-module-interface-types.sh, check-module-deps-vs-protocols.sh,
# and check-boundary-enforcement-cols.sh, consolidated into a single per-artifact script.
#
# Usage: check-module.sh <design-dir>

set -euo pipefail

DESIGN_ROOT="${1:-}"
if [ -z "$DESIGN_ROOT" ] || [ ! -d "$DESIGN_ROOT" ]; then
  echo "ERROR: design root not found: ${DESIGN_ROOT:-<empty>}" >&2
  echo "Usage: check-module.sh <design-dir>" >&2
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
REQUIRED_SECTIONS = (
    "## Responsibilities",
    "## Public Interfaces",
    "## Data Models",
    "## Dependencies",
    "## Boundary Enforcement",
)
REQUIRED_FM = ("id", "title", "owner", "status", "version", "depends_on")
BOUNDARY_REQUIRED_COLS = ("Boundary", "Mechanism", "Enforced At", "Failure Mode")


def extract_section(body: str, heading: str):
    """Return text inside the section starting at `heading` until the next
    same-or-higher-level heading, or None if heading not found."""
    pat = re.compile(r"^" + re.escape(heading) + r"\s*$", re.M)
    m = pat.search(body)
    if not m:
        return None
    rest = body[m.end():]
    nxt = re.search(r"\n##\s+", rest)
    return rest[:nxt.start()] if nxt else rest


def extract_frontmatter_list(text: str, key: str) -> list[str]:
    """Best-effort extraction of a YAML list value for `key` from frontmatter.
    Supports inline `key: [a, b]` and block-form list under `key:`.
    Returns [] if not present.
    """
    if not text.startswith("---"):
        return []
    end = text.find("\n---", 3)
    if end < 0:
        return []
    fm_text = text[3:end]
    lines = fm_text.splitlines()
    items: list[str] = []
    for i, raw in enumerate(lines):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", raw)
        if not m or m.group(1) != key:
            continue
        rest = m.group(2).strip()
        # Inline form: key: [a, b]
        if rest.startswith("[") and rest.endswith("]"):
            inner = rest[1:-1].strip()
            if inner:
                for tok in re.split(r"\s*,\s*", inner):
                    tok = tok.strip().strip("'\"")
                    if tok:
                        items.append(tok)
            return items
        if rest and rest != "":
            # Single string value, e.g. `key: foo`
            items.append(rest.strip("'\""))
            return items
        # Block form: subsequent indented `- item` lines
        for sub in lines[i + 1:]:
            if not sub.strip():
                continue
            if sub.startswith((" ", "\t")):
                m2 = re.match(r"^\s*-\s*(.+?)\s*$", sub)
                if m2:
                    items.append(m2.group(1).strip("'\""))
                else:
                    break
            else:
                break
        return items
    return items


findings: list[Finding] = []

modules_dir = os.path.join(design_root, "modules")
files = sorted(f for f in list_dir(design_root, "modules") if MODULE_FILE_RE.match(f or ""))

# ─── CR-SD04 monotonicity ────────────────────────────────────────────
ids = [int(MODULE_FILE_RE.match(f).group(1)) for f in files]
if files:
    seen = set()
    expected = 1
    for n, fname in zip(ids, files):
        if n in seen:
            findings.append(Finding(
                criterion_id="CR-SD04",
                file=f"modules/{fname}",
                severity="error",
                description=f"duplicate module id M-{n:03d}",
                suggested_fix=f"renumber one of the M-{n:03d} files to the next free slot",
            ))
        seen.add(n)
        if n != expected:
            findings.append(Finding(
                criterion_id="CR-SD04",
                file=f"modules/{fname}",
                severity="error",
                description=f"module ids not monotonic from M-001: expected M-{expected:03d}, got M-{n:03d}",
                suggested_fix="renumber so module ids form a gap-free sequence M-001, M-002, ...",
            ))
        expected = n + 1

# ─── per-file checks ─────────────────────────────────────────────────
for fname in files:
    rel = f"modules/{fname}"
    text = read_text(os.path.join(modules_dir, fname))
    if text is None:
        continue
    expected_id = f"M-{int(MODULE_FILE_RE.match(fname).group(1)):03d}"

    fm_err = frontmatter_error(text)
    if fm_err:
        findings.append(Finding(
            criterion_id="CR-SDFM02",
            file=rel,
            severity="error",
            description=f"frontmatter problem: {fm_err}",
            suggested_fix="add a YAML frontmatter block with id, title, owner, status, version, depends_on",
        ))
        fm = {}
        body = text
    else:
        fm, body = parse_frontmatter(text)

    if not fm_err:
        for key in ("id", "title", "owner", "status", "version"):
            if key not in fm or not str(fm.get(key, "")).strip():
                findings.append(Finding(
                    criterion_id="CR-SDFM02",
                    file=rel,
                    severity="error",
                    description=f"frontmatter missing required key: {key!r}",
                    suggested_fix=f"add `{key}: <value>` to the module frontmatter block",
                ))
        # depends_on: presence-only check (value may be empty list)
        # Re-detect using raw frontmatter text for robustness against list forms.
        end_idx = text.find("\n---", 3)
        fm_raw = text[3:end_idx] if end_idx > 0 else ""
        if not re.search(r"^depends_on\s*:", fm_raw, re.M):
            findings.append(Finding(
                criterion_id="CR-SDFM02",
                file=rel,
                severity="error",
                description="frontmatter missing required key: 'depends_on'",
                suggested_fix="add `depends_on: []` (or a YAML list of M-NNN ids) to the frontmatter",
            ))
        if fm.get("id") and fm["id"] != expected_id:
            findings.append(Finding(
                criterion_id="CR-SDFM02",
                file=rel,
                severity="error",
                description=f"frontmatter id {fm['id']!r} does not match filename id {expected_id!r}",
                suggested_fix=f"change frontmatter `id` to {expected_id!r} or rename the file",
            ))

    # CR-SD06: required section headings
    for s in REQUIRED_SECTIONS:
        if s not in body:
            findings.append(Finding(
                criterion_id="CR-SD06",
                file=rel,
                severity="error",
                description=f"missing required section heading: {s!r}",
                suggested_fix=f"add a `{s}` section to the module file",
            ))

    # CR-SD03: forbidden tokens
    for i, line in enumerate(body.splitlines(), 1):
        if re.search(r"\b(TBD|TODO|FIXME|PLACEHOLDER)\b", line):
            findings.append(Finding(
                criterion_id="CR-SD03",
                file=rel,
                severity="error",
                description=f"placeholder marker on line {i}: {line.strip()[:80]!r}",
                suggested_fix="replace with a concrete value or drop the section",
            ))
            break

    # ── CR-SD07: every Public Interfaces bullet has a type signature ──
    pi_section = extract_section(body, "## Public Interfaces")
    if pi_section is not None:
        for raw in pi_section.splitlines():
            line = raw.strip()
            if not line.startswith(("- ", "* ", "+ ")):
                continue
            after = line[2:].strip()
            if not after:
                continue
            has_sig = (
                "`" in after
                or ("(" in after and ")" in after)
                or "->" in after
                or re.search(r"\w+\s*:\s*\w", after) is not None
            )
            if not has_sig:
                findings.append(Finding(
                    criterion_id="CR-SD07",
                    file=rel,
                    severity="error",
                    description=f"public interface bullet has no type signature: {after[:80]!r}",
                    suggested_fix="declare the interface's type signature in backticks or `name(args) -> Result` form",
                ))

    # ── CR-SD08: depends_on entries must reference a contract ─────────
    deps_list = extract_frontmatter_list(text, "depends_on") if not fm_err else []
    deps_section = extract_section(body, "## Dependencies") or ""
    for dep in deps_list:
        token = dep.strip()
        if not token:
            continue
        if token not in deps_section:
            findings.append(Finding(
                criterion_id="CR-SD08",
                file=rel,
                severity="error",
                description=f"depends_on entry {token!r} not described in '## Dependencies' section",
                suggested_fix=f"add a bullet under `## Dependencies` describing what {token} protocol/contract is consumed",
            ))
            continue
        idx = deps_section.find(token)
        tail = deps_section[idx:idx + 400]
        has_protocol = bool(re.search(r"[(`/]|->|\b(GET|POST|PUT|DELETE|PATCH)\b", tail))
        if not has_protocol:
            findings.append(Finding(
                criterion_id="CR-SD08",
                file=rel,
                severity="error",
                description=f"depends_on entry {token!r} has no protocol/contract reference (no signature, no endpoint literal)",
                suggested_fix=f"in `## Dependencies`, document the specific contract used from {token} (interface signature or `METHOD /path`)",
            ))

    # ── CR-SD09: boundary-enforcement table required columns ──────────
    be_section = extract_section(body, "## Boundary Enforcement")
    if be_section is not None:
        header_match = re.search(r"^\s*\|(.+)\|\s*$", be_section, re.M)
        if not header_match:
            findings.append(Finding(
                criterion_id="CR-SD09",
                file=rel,
                severity="error",
                description="'## Boundary Enforcement' has no markdown table",
                suggested_fix="add a pipe-delimited table with columns: " + " | ".join(BOUNDARY_REQUIRED_COLS),
            ))
        else:
            header_cells = [c.strip().lower() for c in header_match.group(1).split("|")]
            for col in BOUNDARY_REQUIRED_COLS:
                if col.lower() not in header_cells:
                    findings.append(Finding(
                        criterion_id="CR-SD09",
                        file=rel,
                        severity="error",
                        description=f"boundary table missing required column: {col!r}",
                        suggested_fix=f"add a `{col}` column to the boundary-enforcement table",
                    ))

emit(findings, scope_label="(modules/)")
PYEOF
