"""sd_lint — shared utilities for system-design formal-review scripts.

Each per-artifact check-*.sh script imports the helpers below to avoid
re-implementing frontmatter parsing, finding construction, and the
guide §9 contract (3-state returncode + stdout restates the meaning +
agent-actionable issue dicts).

Usage from a check-*.sh script:

    python3 - "$ARG" <<'PYEOF'
    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
    from sd_lint import Finding, parse_frontmatter, emit, walk_md, ROUND_RE

    findings = []
    findings.append(Finding(
        criterion_id="CR-SD01",
        file="README.md",
        severity="error",
        description="...",
        suggested_fix="...",
    ))
    emit(findings)
    PYEOF
"""

from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass, asdict
from typing import Iterable, Optional


# ─── Constants ────────────────────────────────────────────────────────

VALID_SEVERITIES = ("critical", "error", "warning", "info")
SEVERITY_ORDER = {"info": 0, "warning": 1, "error": 2, "critical": 3}

# Reusable regex patterns
ROUND_RE = re.compile(r"^round-(\d+)$")
JOURNEY_FILE_RE = re.compile(r"^J-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
FEATURE_FILE_RE = re.compile(r"^F-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
ISSUE_ID_RE = re.compile(r"^I-\d{3,}$")

# YAML frontmatter line scanner — single-key/value pairs only (no nested
# blocks, no list items). Adequate for the schemas system-design defines.
_FM_LINE_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$")


# ─── Finding type ─────────────────────────────────────────────────────

@dataclass
class Finding:
    criterion_id: str
    file: str
    severity: str
    description: str
    suggested_fix: str

    def __post_init__(self):
        if self.severity not in VALID_SEVERITIES:
            raise ValueError(
                f"invalid severity {self.severity!r}; "
                f"must be one of {VALID_SEVERITIES}"
            )
        if not self.criterion_id.startswith("CR-"):
            raise ValueError(
                f"criterion_id must start with CR-: got {self.criterion_id!r}"
            )
        if len(self.description.strip()) < 5:
            raise ValueError("description must be >= 5 characters")
        if len(self.suggested_fix.strip()) < 5:
            raise ValueError("suggested_fix must be >= 5 characters")

    def as_dict(self) -> dict:
        return asdict(self)


# ─── Frontmatter parser ───────────────────────────────────────────────

def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Parse the leading YAML frontmatter of a markdown file.

    Returns (frontmatter_dict, body_text). Returns (empty dict, text)
    if no frontmatter block is present. Returns (empty dict, '') on
    unterminated frontmatter — caller should detect this case via the
    `frontmatter_error` helper if it matters.

    The parser is line-based and intentionally minimal: nested YAML
    structures (lists, mappings) are NOT extracted into the returned
    dict — only single-line `key: value` pairs are captured. Lines
    that start with whitespace (indented list items / nested blocks)
    are skipped.

    Quoted string values are unwrapped (matching pairs of `"` or `'`).
    """
    if not text or not text.startswith("---"):
        return {}, text or ""
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    fm: dict = {}
    for raw in text[3:end].splitlines():
        # Skip indented lines (list items, nested blocks)
        if raw.startswith((" ", "\t")):
            continue
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = _FM_LINE_RE.match(line)
        if not m:
            continue
        key, value = m.group(1), m.group(2).strip()
        if value.startswith('"') and value.endswith('"') and len(value) >= 2:
            value = value[1:-1]
        elif value.startswith("'") and value.endswith("'") and len(value) >= 2:
            value = value[1:-1]
        fm[key] = value
    body = text[end + 4:]
    return fm, body


def frontmatter_error(text: str) -> Optional[str]:
    """Return a one-line error string if frontmatter is missing /
    unterminated, else None.

    Use when frontmatter is required (e.g. for a leaf file). Does NOT
    treat missing required keys as an error — that is the caller's job.
    """
    if not text:
        return "file is empty"
    if not text.startswith("---"):
        return "missing leading '---' frontmatter delimiter"
    if text.find("\n---", 3) < 0:
        return "unterminated frontmatter (no closing '---' delimiter)"
    return None


# ─── File-walking helpers ─────────────────────────────────────────────

def list_dir(root: str, relative_subdir: str = ".") -> list[str]:
    """List visible files in root/relative_subdir, sorted."""
    full = os.path.join(root, relative_subdir) if relative_subdir != "." else root
    if not os.path.isdir(full):
        return []
    return sorted(f for f in os.listdir(full) if not f.startswith("."))


def read_text(path: str) -> Optional[str]:
    """Read file, returning None if absent. Decodes as UTF-8 with replace."""
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def walk_md(root: str, exclude_dirs: tuple[str, ...] = (".review",)) -> Iterable[str]:
    """Yield relative paths to every .md file under root, excluding the
    specified subdirectories at the top level. The walk descends
    everywhere else.
    """
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root).replace("\\", "/")
        # Prune top-level excluded dirs and any hidden dirs
        dirnames[:] = [
            d for d in dirnames
            if not d.startswith(".") and not (rel_dir == "." and d in exclude_dirs)
        ]
        for fname in filenames:
            if not fname.endswith(".md"):
                continue
            yield fname if rel_dir == "." else f"{rel_dir}/{fname}"


def find_round_dirs(prd_root: str) -> list[tuple[int, str]]:
    """Return sorted list of (round_number, full_path) for every
    `<prd_root>/.review/round-<N>` directory.
    """
    review_dir = os.path.join(prd_root, ".review")
    if not os.path.isdir(review_dir):
        return []
    out: list[tuple[int, str]] = []
    for entry in sorted(os.listdir(review_dir)):
        m = ROUND_RE.match(entry)
        if not m:
            continue
        full = os.path.join(review_dir, entry)
        if os.path.isdir(full):
            out.append((int(m.group(1)), full))
    return sorted(out)


# ─── Output emit (guide §9 contract) ──────────────────────────────────

def emit(findings: list[Finding], scope_label: str = "") -> None:
    """Print PASS / FOUND summary + JSON document, then exit with the
    appropriate code per guide §9.1.

    - 0 issues  → stdout `PASS 0 issues found <scope_label>`, exit 0.
    - >0 issues → stdout `FOUND <N> issue(s) <scope_label> (worst severity: ...):`
                  followed by the JSON document, exit 1.
    """
    if not findings:
        suffix = f" {scope_label}".rstrip()
        print(f"PASS 0 issues found{suffix}")
        sys.exit(0)
    sorted_findings = sorted(
        findings,
        key=lambda f: (f.criterion_id, f.file, f.description),
    )
    worst = "info"
    for f in sorted_findings:
        if SEVERITY_ORDER.get(f.severity, 0) > SEVERITY_ORDER[worst]:
            worst = f.severity
    suffix = f" {scope_label}".rstrip() if scope_label else ""
    print(f"FOUND {len(sorted_findings)} issue(s){suffix} (worst severity: {worst}):")
    out = {"issues": [f.as_dict() for f in sorted_findings]}
    print(json.dumps(out, indent=2, ensure_ascii=False))
    sys.exit(1)


def fail_with_script_error(message: str) -> "None":
    """Print ERROR to stderr and exit 2 (script error per guide §9.1)."""
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(2)


# ─── Issue-file helpers ───────────────────────────────────────────────

def parse_issue_file(path: str) -> tuple[Optional[dict], Optional[str], Optional[str]]:
    """Parse an issue file at the given absolute path.

    Returns (frontmatter_dict, body_text, error_message). On parse error,
    frontmatter_dict is None and error_message describes the problem.
    """
    text = read_text(path)
    if text is None:
        return None, None, f"cannot read file"
    err = frontmatter_error(text)
    if err:
        return None, None, err
    fm, body = parse_frontmatter(text)
    if not fm:
        return None, None, "frontmatter present but no valid key-value pairs"
    return fm, body, None
