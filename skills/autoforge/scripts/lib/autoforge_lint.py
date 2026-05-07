"""autoforge_lint — shared utilities for autoforge formal-review scripts.

Mirrors the design of prd-analysis/scripts/lib/prd_lint.py: every per-artifact
check-*.sh script imports the helpers below to share frontmatter parsing,
finding construction, and the 3-state returncode + JSON-on-stdout contract.

Output contract (matches prd-analysis):

  exit 0:  PASS — stdout `PASS 0 issues found <scope_label>`
  exit 1:  FOUND — stdout `FOUND <N> issue(s) <scope_label> (worst severity: …):`
                   followed by `{"issues": [Finding, ...]}`
  exit 2:  ERROR — stderr `ERROR: …`

Each Finding carries criterion_id (CR-AF<NN>), file, severity, description,
suggested_fix. The schema is identical to prd-analysis so downstream tooling
can consume both.
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

MODULE_ID_RE = re.compile(r"^M-\d{3,}$")
FEATURE_ID_RE = re.compile(r"^F-\d{3,}$")
JOURNEY_ID_RE = re.compile(r"^J-\d{3,}$")
MODULE_PLAN_FILE_RE = re.compile(r"^plan-M-(\d{3,})(?:-[a-z0-9-]+)?\.md$")
AC_REF_RE = re.compile(r"^F-\d{3,}/AC\d+$")
JOURNEY_TEST_REF_RE = re.compile(r"^J-\d{3,}(?:[-/](?:E2E|TP)\d+)?$")
ISSUE_REF_RE = re.compile(r"^[\w.-]+/[\w.-]+#\d+$")

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


# ─── File helpers ─────────────────────────────────────────────────────

def read_text(path: str) -> Optional[str]:
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def list_dir(root: str, sub: str = ".") -> list[str]:
    full = os.path.join(root, sub) if sub != "." else root
    if not os.path.isdir(full):
        return []
    return sorted(f for f in os.listdir(full) if not f.startswith("."))


def heading_set(body: str, level: int = 2) -> set[str]:
    """Return the set of `## …` (or `### …`) heading texts in body."""
    prefix = "#" * level + " "
    out: set[str] = set()
    for line in body.splitlines():
        if line.startswith(prefix) and not line.startswith(prefix + "#"):
            out.add(line[len(prefix):].strip())
    return out


def parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text or not text.startswith("---"):
        return {}, text or ""
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    fm: dict = {}
    for raw in text[3:end].splitlines():
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
    return fm, text[end + 4:]


# ─── Output emit (3-state contract) ───────────────────────────────────

def emit(findings: list[Finding], scope_label: str = "") -> None:
    if not findings:
        suffix = f" {scope_label}".rstrip() if scope_label else ""
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
    print(json.dumps({"issues": [f.as_dict() for f in sorted_findings]},
                     indent=2, ensure_ascii=False))
    sys.exit(1)


def fail_with_script_error(message: str) -> "None":
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(2)
