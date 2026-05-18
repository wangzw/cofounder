#!/usr/bin/env bash
# check-readme-references.sh — CR-SD18 (readme-references)
# Usage: check-readme-references.sh <design-dir> [--quiet] [--strict]
#
# Lint check CR-SD18: every relative path referenced from <design-dir>/README.md
# MUST resolve to an existing file.
#
# Detection (in embedded Python — structurally immune to the bash
# `grep -oE | … under set -euo pipefail` pitfall that caused the silent-exit
# regression in bugs/2026-05-06-check-readme-references-silent-exit.md):
#   1. Parse <design-dir>/README.md for markdown links: [text](path).
#   2. For each link target:
#      - Skip external URLs (http:// / https:// / mailto:).
#      - Skip anchor-only links (#...).
#      - Strip query/fragment suffix (?... / #...) for resolution.
#      - Resolve path relative to README.md's directory (= <design-dir>).
#        Absolute paths (leading /) are used as-is.
#      - Normalise via os.path.normpath (collapses ./ and ../ components).
#      - Verify the resolved path exists.
#
# Special-case severities:
#   - any path that escapes <design-dir> via "../" AND contains a "prd/"
#     component       → warning   (PRD may not be in same checkout — was the
#                                  legacy "mechanical" classification)
#   - all other broken relative paths → error  (was the legacy "blocker"
#                                               classification)
#   - Anchor-only (#...)              → skip (no file to resolve)
#
# Findings are emitted on stdout via the §9 contract (`PASS … / FOUND …
# {"issues":[…]}` produced by `lib/sd_lint.py`'s `emit()`); run-checkers.sh
# writes per-finding issue files to .review/round-<N>/issues/<issue-id>.md.
#
# Exit codes (per guide §9.1):
#   0 — no findings
#   1 — at least one finding of any severity
#   2 — usage / I/O error
#
# Flags:
#   --quiet   Currently a no-op (kept for argv compatibility — the §9 contract
#             does not emit per-violation chatter on stdout/stderr; only the
#             summary line + JSON document are printed).
#   --strict  Accepted as a no-op for backward compatibility. The historical
#             "warnings stay at exit 0 by default" semantics was never wired
#             up — sd_lint.emit() exits 1 on any non-empty findings list
#             regardless of severity. See the in-code comment near `_ = strict`
#             below for the runtime acknowledgment.
#
# Limitations:
#   1. Multi-line markdown links (link text spanning multiple lines) are not
#      parsed — only single-line [text](path) forms are matched.
#   2. Links inside fenced code blocks (``` ... ```) are still parsed; add a
#      known-exception mechanism if needed.
#   3. Only existence is checked — a path that resolves to a directory passes.
#   4. Fragment-only suffix stripping removes the FIRST occurrence of `#` /
#      `?`; paths with literal `#` or `?` characters are not supported.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── argument parsing ──────────────────────────────────────────────────────────
DESIGN_DIR=""
QUIET=1
STRICT=0

for arg in "$@"; do
  case "$arg" in
    --quiet)  QUIET=1 ;;
    --strict) STRICT=1 ;;
    -*)
      printf 'ERROR: unknown flag: %s\n' "$arg" >&2
      printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
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
  printf 'Usage: %s <design-dir> [--quiet] [--strict]\n' "$(basename "$0")" >&2
  exit 2
fi
if [ ! -d "$DESIGN_DIR" ]; then
  printf 'ERROR: design directory not found: %s\n' "$DESIGN_DIR" >&2
  exit 2
fi
DESIGN_DIR="${DESIGN_DIR%/}"

python3 - "$DESIGN_DIR" "$SCRIPT_DIR/lib" "$STRICT" <<'PYEOF'
import os, re, sys
sys.path.insert(0, sys.argv[2])
from sd_lint import Finding, emit

design_dir = sys.argv[1]
strict = sys.argv[3] == "1"

readme_path = os.path.join(design_dir, "README.md")
try:
    with open(readme_path, "r", encoding="utf-8") as f:
        readme = f.read()
except FileNotFoundError:
    # Pre-§9 behaviour: README absent → SKIP (PASS), not a finding here.
    # CR-SD01 (check-readme.sh) is responsible for "README must exist".
    emit([], scope_label="(check-readme-references)")

findings: list[Finding] = []

# Markdown link pattern: [text](target).  Greedy-but-stop-at-`)` capture for
# the target.  Brackets in link text are not supported (same limitation as
# the original bash version).
link_re = re.compile(r"\[[^\]]*\]\(([^)]*)\)")

for lineno, line in enumerate(readme.splitlines(), 1):
    for m in link_re.finditer(line):
        raw_target = m.group(1).strip()
        if not raw_target:
            continue

        # Skip external URLs.
        if raw_target.startswith(("http://", "https://", "mailto:")):
            continue
        # Skip anchor-only links.
        if raw_target.startswith("#"):
            continue

        # Strip ?query and #fragment for resolution.
        stripped = raw_target.split("?", 1)[0].split("#", 1)[0]
        if not stripped:
            continue

        # Resolve.
        if stripped.startswith("/"):
            local_abs = stripped
        else:
            local_abs = os.path.join(design_dir, stripped)
        local_abs = os.path.normpath(local_abs)

        if os.path.exists(local_abs):
            continue

        # Classify severity.
        # Cross-doc refs that escape design-dir to a sibling prd/ tree are
        # the legacy "mechanical" class (PRD may not be checked out).
        # Detected by raw target traversing up (../) AND mentioning prd/.
        is_cross_prd = (
            ".." in raw_target.split("/") and "prd" in raw_target.split("/")
        )
        severity = "warning" if is_cross_prd else "error"

        findings.append(Finding(
            criterion_id="CR-SD18",
            file="README.md",
            severity=severity,
            description=(
                f"Broken link: relative path {raw_target!r} at line {lineno} "
                f"does not resolve to an existing file"
            ),
            suggested_fix=(
                "Fix the path, remove the broken link, or create the "
                "referenced file"
            ),
        ))

# --strict: promote a warning-only finding set to exit-1 by emitting it.
# emit() already exits 1 whenever findings is non-empty, so --strict only
# matters as a documented contract here — there is no "blocker present"
# short-circuit in the canonical §9 protocol.  We keep the flag for argv
# compatibility with the legacy bash version.
_ = strict  # accepted for compat; see comment above.

emit(findings, scope_label="(check-readme-references)")
PYEOF
