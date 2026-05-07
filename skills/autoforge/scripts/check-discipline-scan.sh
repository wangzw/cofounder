#!/usr/bin/env bash
# check-discipline-scan.sh — grep source / test files for forbidden
# patterns enumerated in delivery-discipline.md §A (forbidden test
# patterns), §B (silent write paths), and §D (silent debt). Each match
# is emitted as a Finding so the orchestrator can surface them as REJECT
# signals before APPROVE.
#
#   CR-AF12  no-soft-pass-tests   (§A SP1..SP8)
#   CR-AF13  no-silent-debt       (§D — TODO/FIXME without issue link)
#   CR-AF14  no-skip-without-issue (§A — test.skip / pending / xit
#                                    without an issue reference)
#   CR-AF20  no-error-as-success  (§M — "no error == success" patterns
#                                    that omit a post-condition assertion)
#   CR-AF21  reserved for traceability (see check-traceability.sh)
#   CR-AF22  no-dependency-abandonment (§N — stub / pending / "waiting on
#                                       M-XXX" markers that abandon a
#                                       module instead of escalating)
#
# Usage: check-discipline-scan.sh <root-dir> [--include-glob <pat>] [...]
#
# By default scans every regular file under <root-dir>, excluding common
# vendored/build directories. Pass `--include-glob` repeatedly to restrict
# to e.g. `--include-glob '*.go' --include-glob '*.ts'`.

set -euo pipefail

usage() {
  echo "Usage: check-discipline-scan.sh <root-dir> [--include-glob PAT]..." >&2
}

ROOT="${1:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "ERROR: root not found: ${ROOT:-<empty>}" >&2
  usage
  exit 2
fi
shift

INCLUDES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --include-glob) INCLUDES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pass includes via env var (newline-separated) to keep heredoc clean.
export AF_INCLUDES="$(printf '%s\n' "${INCLUDES[@]+"${INCLUDES[@]}"}")"

python3 - "$ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import fnmatch
import os
import re
import sys

root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from autoforge_lint import Finding, emit, fail_with_script_error, ISSUE_REF_RE

includes = [p for p in os.environ.get("AF_INCLUDES", "").splitlines() if p]

EXCLUDE_DIRS = {
    ".git", "node_modules", "vendor", "dist", "build", "target",
    "__pycache__", ".venv", ".tox", ".pytest_cache", ".next", ".nuxt",
    "coverage", ".gradle", ".idea", ".vscode",
}

# Default scope: source-of-truth code & test extensions. The forbidden
# patterns in delivery-discipline.md describe runtime behaviour and test
# code, not project documentation. Skill docs and README files
# legitimately quote the patterns they forbid (otherwise authors can't
# describe them); scanning markdown by default produces false positives
# on every doc set that references the patterns. Callers who genuinely
# want to scan markdown can pass `--include-glob '*.md'` explicitly.
# Default scope: source-of-truth code & test extensions. Listed for
# documentation, not currently used (see matches_include below).
DEFAULT_CODE_EXTS = {
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".py", ".pyi",
    ".go",
    ".rs",
    ".java", ".kt", ".kts", ".scala", ".groovy",
    ".rb",
    ".cs",
    ".swift",
    ".php",
    ".ex", ".exs",
    ".clj", ".cljs", ".cljc",
    ".sh", ".bash", ".zsh",
    ".sql",
    ".vue", ".svelte",
}

# Cache of directories known to contain a SKILL.md file. Markdown files
# living next to a SKILL.md are skill prompt documentation that
# legitimately quotes the patterns this scanner forbids; flagging them
# would force prompt authors to obfuscate the very examples they need
# readers to recognize. Skipping them prevents that false-positive class
# without weakening enforcement on real code or status documents.
_skill_dir_cache: dict[str, bool] = {}

def is_skill_doc(full_path: str) -> bool:
    if not full_path.lower().endswith(".md"):
        return False
    parent = os.path.dirname(full_path)
    cached = _skill_dir_cache.get(parent)
    if cached is not None:
        return cached
    abs_root = os.path.abspath(root)
    cur = os.path.abspath(parent)
    found = False
    while True:
        if os.path.isfile(os.path.join(cur, "SKILL.md")):
            found = True
            break
        nxt = os.path.dirname(cur)
        if nxt == cur:
            break
        try:
            common = os.path.commonpath([nxt, abs_root])
        except ValueError:
            break
        if common != abs_root:
            break
        cur = nxt
    _skill_dir_cache[parent] = found
    return found

# delivery-discipline.md §A forbidden test patterns
SOFT_PASS_PATTERNS = [
    # SP1: multi-status tolerance — `expect([200, 400, ...]).toContain(status)`
    (re.compile(r"toContain\s*\(\s*(?:res(?:ponse)?\.)?status\b"), "soft-pass: assertion accepts any of multiple status codes"),
    (re.compile(r"\.\s*to\s*\.\s*be\s*\.\s*oneOf\s*\(\s*\["), "soft-pass: assertion accepts any of multiple values"),
    # SP2: in-test skip on missing precondition
    (re.compile(r"if\s*\(.*\b(?:status|statusCode)\b\s*===?\s*404\s*\)\s*\{?\s*(?:test|it)\.skip"), "soft-pass: test skips itself when precondition is unmet"),
    (re.compile(r"\bpending\s*\(\s*['\"]"), "soft-pass: pending() leaves test green without assertion"),
    # SP3: warn-and-continue
    (re.compile(r"console\.warn\s*\(\s*['\"](?:not\s+yet|will\s+assert|todo|tbd|skip)", re.IGNORECASE), "soft-pass: warn-and-continue masquerading as a test"),
    # SP5: literal placeholder comments
    (re.compile(r"//\s*will\s+assert", re.IGNORECASE), "soft-pass: comment defers assertion to a future change"),
    (re.compile(r"//\s*not\s+yet\s+implemented", re.IGNORECASE), "soft-pass: test acknowledges feature isn't built"),
    (re.compile(r"//\s*tracked\s+as\s+follow[- ]?up", re.IGNORECASE), "silent debt: deferred work in source comment"),
]

# §A SP6: try { ... } catch { /* swallow */ } around an assertion
EMPTY_CATCH_RE = re.compile(r"catch\s*\([^)]*\)\s*\{\s*\}")

# §D silent-debt markers without issue link
TODO_RE = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b\s*[:\-]?\s*(.*)$")

# §A SP4: test.skip / xit / xdescribe without an issue ref
SKIP_RE = re.compile(r"\b(?:test|it|describe)\.skip\b|\bxit\s*\(|\bxdescribe\s*\(")

# §M no-error-as-success — the test/spec only proves the absence of an
# error, never asserts the post-condition. Each line-level pattern is a
# strong smell on its own.
NO_ERROR_PATTERNS = [
    (re.compile(r"\.\s*not\s*\.\s*toThrow\s*\(\s*\)"), "no-error-as-success: `.not.toThrow()` is the only assertion (no post-condition checked)"),
    (re.compile(r"expect\s*\(\s*err(?:or)?\s*\)\s*\.\s*to(?:Be|Equal)\s*\(\s*(?:null|undefined|None|nil)\s*\)"), "no-error-as-success: asserts error is absent without asserting outcome"),
    (re.compile(r"expect\s*\(\s*err(?:or)?\s*\)\s*\.\s*toBe(?:Null|Undefined|Nil)\s*\(\s*\)"), "no-error-as-success: asserts error is absent without asserting outcome"),
    (re.compile(r"assert(?:Is)?Nil\s*\(\s*(?:t,\s*)?err\s*\)\s*$"), "no-error-as-success: Go test asserts err==nil with no post-condition follow-up"),
    (re.compile(r"^\s*assert\.NoError\s*\(\s*t\s*,\s*err\s*\)\s*$"), "no-error-as-success: bare assert.NoError without post-condition"),
    (re.compile(r"//\s*should not (raise|throw|error|fail)\b", re.IGNORECASE), "no-error-as-success: comment frames success as 'no error'"),
    (re.compile(r"#\s*should not (raise|throw|error|fail)\b", re.IGNORECASE), "no-error-as-success: comment frames success as 'no error'"),
    (re.compile(r"pytest\.raises\s*\([^)]*\)\s*:\s*pass\s*$"), "no-error-as-success: pytest.raises body is `pass` — exception type unverified"),
]

# §N abandonment markers — module abandons work because an in-scope
# dependency isn't built. The right action is escalate
# (PLAN_REVISION_NEEDED / UPSTREAM_NOT_IMPLEMENTED), not stub.
ABANDONMENT_PATTERNS = [
    (re.compile(r"//\s*stub\s+for\s+M-\d{3,}", re.IGNORECASE), "abandonment: stub left in place of an in-scope upstream module"),
    (re.compile(r"#\s*stub\s+for\s+M-\d{3,}", re.IGNORECASE), "abandonment: stub left in place of an in-scope upstream module"),
    (re.compile(r"//\s*pending\s+M-\d{3,}\s+implementation", re.IGNORECASE), "abandonment: 'pending M-XXX' marker — implement the dep, do not pause this module"),
    (re.compile(r"//\s*waiting\s+(?:on|for)\s+M-\d{3,}", re.IGNORECASE), "abandonment: 'waiting on M-XXX' — orchestrator must run the upstream now (delivery-discipline §N)"),
    (re.compile(r"#\s*waiting\s+(?:on|for)\s+M-\d{3,}", re.IGNORECASE), "abandonment: 'waiting on M-XXX' — orchestrator must run the upstream now (delivery-discipline §N)"),
    (re.compile(r"//\s*not\s+yet\s+implemented:\s*M-\d{3,}", re.IGNORECASE), "abandonment: 'not yet implemented: M-XXX' marker"),
    (re.compile(r"BLOCKED\s+on\s+M-\d{3,}", re.IGNORECASE), "abandonment: status row 'BLOCKED on M-XXX' for an in-scope dep — implement it instead"),
]


def is_excluded(rel_path: str) -> bool:
    parts = rel_path.split(os.sep)
    return any(p in EXCLUDE_DIRS for p in parts)


def matches_include(rel_path: str) -> bool:
    if not includes:
        return True
    base = os.path.basename(rel_path)
    return any(fnmatch.fnmatch(base, pat) or fnmatch.fnmatch(rel_path, pat) for pat in includes)


def is_text(path: str) -> bool:
    try:
        with open(path, "rb") as f:
            chunk = f.read(2048)
        if b"\x00" in chunk:
            return False
        return True
    except OSError:
        return False


findings: list[Finding] = []

for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
    for fname in filenames:
        full = os.path.join(dirpath, fname)
        rel = os.path.relpath(full, root)
        if is_excluded(rel) or not matches_include(rel):
            continue
        # Skip the discipline doc itself — it documents the patterns it bans.
        if rel.endswith("delivery-discipline.md"):
            continue
        # Skip Claude plugin skill prompts: a markdown file in or under
        # a directory that contains SKILL.md is a skill prompt that
        # legitimately quotes forbidden patterns as teaching examples.
        if is_skill_doc(full):
            continue
        if not is_text(full):
            continue
        try:
            with open(full, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError:
            continue
        for ln_no, line in enumerate(lines, start=1):
            for pat, label in SOFT_PASS_PATTERNS:
                if pat.search(line):
                    findings.append(Finding(
                        criterion_id="CR-AF12",
                        file=f"{rel}:{ln_no}",
                        severity="error",
                        description=f"{label}: `{line.strip()[:120]}`",
                        suggested_fix="replace with a strict assertion that "
                                      "matches the acceptance criterion exactly",
                    ))
            if EMPTY_CATCH_RE.search(line):
                findings.append(Finding(
                    criterion_id="CR-AF12",
                    file=f"{rel}:{ln_no}",
                    severity="error",
                    description=f"empty catch block swallows assertion: `{line.strip()[:120]}`",
                    suggested_fix="let the test fail on the unexpected error, "
                                  "or assert the specific exception type/message",
                ))
            for pat, label in NO_ERROR_PATTERNS:
                if pat.search(line):
                    findings.append(Finding(
                        criterion_id="CR-AF20",
                        file=f"{rel}:{ln_no}",
                        severity="error",
                        description=f"{label}: `{line.strip()[:120]}`",
                        suggested_fix=(
                            "after asserting no error, assert the user-visible "
                            "post-condition: response body shape, DB row "
                            "presence, UI state, redirect target, etc. "
                            "(delivery-discipline §M)"
                        ),
                    ))
            for pat, label in ABANDONMENT_PATTERNS:
                if pat.search(line):
                    findings.append(Finding(
                        criterion_id="CR-AF22",
                        file=f"{rel}:{ln_no}",
                        severity="error",
                        description=f"{label}: `{line.strip()[:120]}`",
                        suggested_fix=(
                            "do not abandon this module: either implement the "
                            "missing upstream surface in the same round, or "
                            "return PLAN_REVISION_NEEDED with issue type "
                            "UPSTREAM_NOT_IMPLEMENTED so the orchestrator "
                            "schedules the upstream module before this one "
                            "resumes (delivery-discipline §N)"
                        ),
                    ))
            if SKIP_RE.search(line):
                if not ISSUE_REF_RE.search(line) and "#" not in line:
                    findings.append(Finding(
                        criterion_id="CR-AF14",
                        file=f"{rel}:{ln_no}",
                        severity="error",
                        description=f"test skip without tracked issue: `{line.strip()[:120]}`",
                        suggested_fix="add `owner/repo#NNN` reference in the same "
                                      "comment, or remove the skip and let the test fail",
                    ))
            m = TODO_RE.search(line)
            if m:
                tail = m.group(2) or ""
                if not re.search(r"[\w.-]+/[\w.-]+#\d+|https?://", tail):
                    findings.append(Finding(
                        criterion_id="CR-AF13",
                        file=f"{rel}:{ln_no}",
                        severity="warning",
                        description=f"{m.group(1)} without issue link: `{line.strip()[:120]}`",
                        suggested_fix="open a tracked issue and reference it inline "
                                      "(`owner/repo#NNN`) or remove the marker",
                    ))

emit(findings, scope_label=f"(scanned {root})")
PYEOF
