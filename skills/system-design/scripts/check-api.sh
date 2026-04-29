#!/usr/bin/env bash
# check-api.sh — formal review of <design-dir>/api/API-NNN-*.md files.
#
# Implements:
#   CR-SD10    api-id-monotonic              — IDs API-001, API-002, ... no gaps
#   CR-SD11    api-per-endpoint-blocks       — each endpoint declares Method/Path/Request/Response/Errors
#   CR-SD12    api-surface-cols              — top-level surface table has required columns
#   CR-SD13    endpoint-literal-vs-api       — every literal METHOD /path in modules appears in some API doc
#   CR-SD03    no-tbd-remaining
#   CR-SDFM03  api-frontmatter
#
# Refactor of legacy check-api-per-endpoint-blocks.sh, check-api-surface-cols.sh,
# and check-endpoint-literal-vs-api.sh into a single per-artifact script.
#
# Skips silently with PASS when api/ does not exist (APIs are optional in the
# system-design output structure).
#
# Usage: check-api.sh <design-dir>

set -euo pipefail

DESIGN_ROOT="${1:-}"
if [ -z "$DESIGN_ROOT" ] || [ ! -d "$DESIGN_ROOT" ]; then
  echo "ERROR: design root not found: ${DESIGN_ROOT:-<empty>}" >&2
  echo "Usage: check-api.sh <design-dir>" >&2
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

API_FILE_RE = re.compile(r"^API-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
MODULE_FILE_RE = re.compile(r"^M-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
ENDPOINT_LITERAL_RE = re.compile(
    r"\b(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\s+(/[A-Za-z0-9_/{}.\-:?]+)"
)
SURFACE_REQUIRED_COLS = ("Endpoint", "Method", "Auth", "Idempotent")
ENDPOINT_REQUIRED_SLOTS = ("Method", "Path", "Request", "Response", "Errors")


findings: list[Finding] = []

api_dir = os.path.join(design_root, "api")
if not os.path.isdir(api_dir):
    # API surfaces are optional. Still run the cross-check from modules
    # against the (empty) set of declared endpoints — but only emit
    # findings if a literal endpoint exists in modules.
    pass

api_files = sorted(f for f in list_dir(design_root, "api") if API_FILE_RE.match(f or ""))

# Set of endpoints declared across all API docs: (METHOD, PATH)
declared_endpoints: set[tuple[str, str]] = set()

# ─── CR-SD10 monotonicity ────────────────────────────────────────────
if api_files:
    expected = 1
    seen = set()
    for fname in api_files:
        n = int(API_FILE_RE.match(fname).group(1))
        if n in seen:
            findings.append(Finding(
                criterion_id="CR-SD10",
                file=f"api/{fname}",
                severity="error",
                description=f"duplicate API id API-{n:03d}",
                suggested_fix="renumber so the API id is unique",
            ))
        seen.add(n)
        if n != expected:
            findings.append(Finding(
                criterion_id="CR-SD10",
                file=f"api/{fname}",
                severity="error",
                description=f"API ids not monotonic from API-001: expected API-{expected:03d}, got API-{n:03d}",
                suggested_fix="renumber so API ids form a gap-free sequence API-001, API-002, ...",
            ))
        expected = n + 1

# ─── per-file checks ─────────────────────────────────────────────────
for fname in api_files:
    rel = f"api/{fname}"
    text = read_text(os.path.join(api_dir, fname))
    if text is None:
        continue
    expected_id = f"API-{int(API_FILE_RE.match(fname).group(1)):03d}"

    fm_err = frontmatter_error(text)
    if fm_err:
        findings.append(Finding(
            criterion_id="CR-SDFM03",
            file=rel,
            severity="error",
            description=f"frontmatter problem: {fm_err}",
            suggested_fix="add a YAML frontmatter block with id, title, owner, status, version, module_ref",
        ))
        fm = {}
        body = text
    else:
        fm, body = parse_frontmatter(text)

    if not fm_err:
        for key in ("id", "title", "owner", "status", "version", "module_ref"):
            if key not in fm or not str(fm.get(key, "")).strip():
                findings.append(Finding(
                    criterion_id="CR-SDFM03",
                    file=rel,
                    severity="error",
                    description=f"frontmatter missing required key: {key!r}",
                    suggested_fix=f"add `{key}: <value>` to the API frontmatter",
                ))
        if fm.get("id") and fm["id"] != expected_id:
            findings.append(Finding(
                criterion_id="CR-SDFM03",
                file=rel,
                severity="error",
                description=f"frontmatter id {fm['id']!r} does not match filename id {expected_id!r}",
                suggested_fix=f"change frontmatter `id` to {expected_id!r} or rename the file",
            ))

    # CR-SD03 forbidden tokens
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

    # ── CR-SD12: surface table columns ────────────────────────────────
    surface_match = re.search(
        r"^#{1,6}\s+Surface\s*$", body, re.M | re.I
    )
    if not surface_match:
        findings.append(Finding(
            criterion_id="CR-SD12",
            file=rel,
            severity="error",
            description="missing top-level 'Surface' section",
            suggested_fix="add a `## Surface` heading followed by a table with columns: " + " | ".join(SURFACE_REQUIRED_COLS),
        ))
    else:
        rest = body[surface_match.end():]
        nxt = re.search(r"\n##\s+", rest)
        section = rest[:nxt.start()] if nxt else rest
        header_match = re.search(r"^\s*\|(.+)\|\s*$", section, re.M)
        if not header_match:
            findings.append(Finding(
                criterion_id="CR-SD12",
                file=rel,
                severity="error",
                description="'Surface' section has no markdown table",
                suggested_fix="add a pipe-delimited table with columns: " + " | ".join(SURFACE_REQUIRED_COLS),
            ))
        else:
            cols = [c.strip().lower() for c in header_match.group(1).split("|")]
            for c in SURFACE_REQUIRED_COLS:
                if c.lower() not in cols:
                    findings.append(Finding(
                        criterion_id="CR-SD12",
                        file=rel,
                        severity="error",
                        description=f"surface table missing required column: {c!r}",
                        suggested_fix=f"add a `{c}` column to the surface table",
                    ))

    # ── CR-SD11: per-endpoint blocks must declare all required slots ──
    # An endpoint section is heading "### <something>" followed by a body.
    # We split on `^### ` and inspect each.
    endpoint_blocks = re.split(r"(?m)^###\s+", body)
    # The first split chunk is everything before any ### heading; skip it.
    for idx, blk in enumerate(endpoint_blocks[1:], start=1):
        first_line, _, rest = blk.partition("\n")
        # An endpoint block is one where the heading or body contains
        # "Method:" / "Path:" or a literal METHOD /path pattern.
        if not (
            re.search(r"\bMethod\s*:", blk)
            or ENDPOINT_LITERAL_RE.search(blk)
        ):
            continue
        for slot in ENDPOINT_REQUIRED_SLOTS:
            slot_re = re.compile(rf"(^|\n){re.escape(slot)}\s*:", re.I)
            if not slot_re.search(blk):
                findings.append(Finding(
                    criterion_id="CR-SD11",
                    file=rel,
                    severity="error",
                    description=f"endpoint block '### {first_line.strip()[:60]}' missing slot: {slot!r}",
                    suggested_fix=f"add a `{slot}: <...>` line under the endpoint heading",
                ))
        # collect declared endpoints for the cross-check (literal pattern)
        for em in ENDPOINT_LITERAL_RE.finditer(blk):
            declared_endpoints.add((em.group(1).upper(), em.group(2)))
        # also collect from Method:/Path: slot pairs
        m_method = re.search(r"(?im)^\s*Method\s*:\s*(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b", blk)
        m_path = re.search(r"(?im)^\s*Path\s*:\s*(\S+)", blk)
        if m_method and m_path:
            declared_endpoints.add((m_method.group(1).upper(), m_path.group(1).rstrip("?:.,")))

# ─── CR-SD13: every literal METHOD /path in modules must be declared ──
modules_dir = os.path.join(design_root, "modules")
mfiles = sorted(f for f in list_dir(design_root, "modules") if MODULE_FILE_RE.match(f or ""))
seen_pairs: set[tuple[str, str, str]] = set()
for fname in mfiles:
    rel = f"modules/{fname}"
    text = read_text(os.path.join(modules_dir, fname))
    if text is None:
        continue
    for em in ENDPOINT_LITERAL_RE.finditer(text):
        method = em.group(1).upper()
        path = em.group(2).rstrip("?:.,")  # trim trailing punctuation
        if (rel, method, path) in seen_pairs:
            continue
        seen_pairs.add((rel, method, path))
        if (method, path) not in declared_endpoints:
            findings.append(Finding(
                criterion_id="CR-SD13",
                file=rel,
                severity="error",
                description=f"endpoint literal {method} {path} mentioned in module but not declared in any api/ file",
                suggested_fix=f"add the endpoint to an `api/API-NNN-*.md` doc with Method/Path/Request/Response/Errors slots",
            ))

emit(findings, scope_label="(api/)")
PYEOF
