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
import subprocess
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


def run_cmd(cmd: list[str], cwd: str | None = None) -> tuple[int, str, str]:
    """Run a subprocess and return (returncode, stdout, stderr) with
    trailing newlines stripped. Used by every checker that shells out
    to git — keeping the one-liner in the lib stops each checker from
    growing its own copy with subtly different stderr/text handling.
    """
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return p.returncode, p.stdout.rstrip("\n"), p.stderr.rstrip("\n")


def parse_worktree_list(porcelain_output: str) -> list[dict]:
    """Shared by every checker that walks `git worktree list`. Keeping
    the parser in one place stops checkers from drifting into subtly
    different worktree-membership semantics — a divergence would cause
    one checker to skip a worktree another inspects, with no
    compile-time signal. Output keys: path, head, branch, detached, bare.
    """
    worktrees: list[dict] = []
    current: dict = {}
    for line in porcelain_output.splitlines():
        if not line.strip():
            if current:
                worktrees.append(current)
                current = {}
            continue
        parts = line.split(" ", 1)
        key = parts[0]
        val = parts[1] if len(parts) == 2 else ""
        if key == "worktree":
            current["path"] = val
        elif key == "HEAD":
            current["head"] = val
        elif key == "branch":
            current["branch"] = val
        elif key == "detached":
            current["detached"] = True
        elif key == "bare":
            current["bare"] = True
    if current:
        worktrees.append(current)
    return worktrees


def branch_short(worktree_entry: dict) -> str:
    """Strip the `refs/heads/` prefix git uses in porcelain worktree
    output; returns "" for detached / bare entries.
    """
    ref = worktree_entry.get("branch", "")
    if ref.startswith("refs/heads/"):
        return ref[len("refs/heads/"):]
    return ref


def parse_porcelain_line(line: str) -> tuple[str, str] | None:
    """Parse one line of `git status --porcelain` into (status_code, path).
    Handles the rename / copy form (`R  old -> new`) by returning the
    destination path, and strips the surrounding double-quotes git uses
    for paths containing spaces or shell-special characters. Returns
    None when the line is malformed (too short, or yields an empty
    path after stripping) — callers must treat None as "skip", never
    record a Finding for it.
    """
    if len(line) < 4:
        return None
    status_code = line[:2]
    rest = line[3:]
    if " -> " in rest:
        rest = rest.split(" -> ", 1)[1]
    if rest.startswith('"') and rest.endswith('"'):
        rest = rest[1:-1]
    path = rest.strip()
    if not path:
        return None
    return status_code, path


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
