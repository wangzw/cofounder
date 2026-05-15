#!/usr/bin/env bash
# check-mermaid.sh — formal review of ```mermaid block syntax in PRD leaves.
#
# Per guide §1.1 + §9: emits one issue per finding in JSON; 3-state
# returncode; idempotent. Implements:
#
#   CR-PP-MM01  mermaid-label-syntax — every ```mermaid block in every PRD
#               leaf (README, journeys/, features/, architecture/) MUST
#               satisfy three constraints derived from observed render
#               failures:
#                 1. NO `\n` literal in node/edge/state labels. Mermaid
#                    renders `\n` as the two-character string "\n";
#                    line breaks MUST use `<br/>`.
#                 2. Labels containing a path that starts with `/` MUST
#                    be quoted. `NodeId[/var/run/docker.sock]` collides
#                    with Mermaid's parallelogram `[/text/]` shape syntax.
#                    Quote them: `NodeId["/var/run/docker.sock"]`.
#                 3. `stateDiagram-v2` transition descriptions MUST NOT
#                    contain `:` inside parentheses. Mermaid v10+ parsers
#                    treat the inner `:` as a second state-description
#                    boundary. Convert `(key: value)` to `(key=value)` or
#                    `— key value`. URL path-parameter syntax such as
#                    `/sessions/:id` inside the same line is excluded.
#
# Auto-discovered by run-checkers.sh; participates in the formal hard gate
# enforced by `verify-phase-entry.sh read`.
#
# Usage: check-mermaid.sh <prd-dir>

set -uo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-mermaid.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import Finding, read_text, emit, enumerate_leaves

CR_ID = "CR-PP-MM01"

MERMAID_BLOCK_RE = re.compile(r"```mermaid\b[^\n]*\n(.*?)```", re.DOTALL)
# Comment lines in Mermaid start with `%%`.
COMMENT_RE = re.compile(r"^\s*%%")
# Diagram header detection: first non-comment, non-blank line.
STATE_DIAGRAM_HEADER_RE = re.compile(r"^\s*stateDiagram(?:-v2)?\b")
# Transition lines inside stateDiagram blocks: `A --> B : description`.
TRANSITION_LINE_RE = re.compile(r"^\s*(\S.*?)-->\s*(\S+)\s*(?::\s*(.*))?$")
# Bracketed labels: capture inner text. Skip already-quoted labels and the
# valid parallelogram form `[/text/]` (which both starts AND ends with `/`).
BRACKET_LABEL_RE = re.compile(r"\[([^\]\n]+)\]")
# Match parens containing `:` not immediately preceded by `/` (i.e. exclude
# URL path-parameter syntax `/sessions/:id` from the violation set).
PAREN_COLON_RE = re.compile(r"\(([^()\n]*)\)")
URL_PATH_PARAM_RE = re.compile(r"/:[A-Za-z_][\w-]*")


def _detect_block_kind(body: str) -> str:
    """Return the diagram kind for a mermaid block body, or '' if unknown.

    The kind is the first non-comment, non-blank token (e.g. 'flowchart',
    'stateDiagram-v2', 'sequenceDiagram'). We only special-case
    `stateDiagram-v2` because the `:`-in-parens rule is scoped to it.
    """
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or COMMENT_RE.match(line):
            continue
        if STATE_DIAGRAM_HEADER_RE.match(line):
            return "stateDiagram-v2"
        return stripped.split()[0] if stripped else ""
    return ""


def _line_offset(text: str, char_offset: int) -> int:
    """Return 1-indexed line number of the given character offset in text."""
    return text.count("\n", 0, char_offset) + 1


findings: list[Finding] = []

for rel in enumerate_leaves(prd_root):
    text = read_text(os.path.join(prd_root, rel))
    if text is None:
        continue

    for m_block in MERMAID_BLOCK_RE.finditer(text):
        block_body = m_block.group(1)
        block_start_offset = m_block.start(1)
        kind = _detect_block_kind(block_body)

        # Walk the block line-by-line, accumulating per-line offsets so the
        # reported line number stays correct even when the same label text
        # repeats on multiple lines (a naive `block_body.find(line)` would
        # always return the first occurrence).
        cur_local_offset = 0
        for raw_line_with_nl in block_body.splitlines(keepends=True):
            raw_line = raw_line_with_nl.rstrip("\n")
            abs_line = _line_offset(text, block_start_offset + cur_local_offset)
            cur_local_offset += len(raw_line_with_nl)

            # Skip Mermaid comments entirely — `\n` and `:` inside a comment
            # cannot break the diagram.
            if COMMENT_RE.match(raw_line):
                continue

            # ─── Rule 1: `\n` literal in any non-comment line ──────────
            if "\\n" in raw_line:
                findings.append(Finding(
                    criterion_id=CR_ID,
                    file=rel,
                    severity="error",
                    description=(
                        f"line {abs_line}: ```mermaid block contains the "
                        f"two-character escape '\\n' — Mermaid renders this "
                        f"as the literal string \"\\n\" instead of a line "
                        f"break, so the diagram visibly breaks. Line content: "
                        f"{raw_line.strip()!r}"
                    ),
                    suggested_fix=(
                        "replace '\\n' with '<br/>' inside every node, edge, "
                        "or state label. Quoted labels are most robust: "
                        "`NodeId[\"Line1<br/>Line2\"]`"
                    ),
                ))

            # ─── Rule 2: unquoted leading-`/` label collides with `[/.../]` ─
            for m_lbl in BRACKET_LABEL_RE.finditer(raw_line):
                label = m_lbl.group(1)
                # Quoted form is safe.
                if label.startswith('"') and label.endswith('"'):
                    continue
                # The valid parallelogram shape `[/text/]` is intentional.
                if label.startswith("/") and label.endswith("/"):
                    continue
                # Bug pattern: leading `/`, unquoted, doesn't close as
                # parallelogram. The writer almost certainly meant a path.
                if label.startswith("/"):
                    findings.append(Finding(
                        criterion_id=CR_ID,
                        file=rel,
                        severity="error",
                        description=(
                            f"line {abs_line}: unquoted bracket label "
                            f"`[{label}]` starts with '/' — collides with "
                            f"Mermaid's parallelogram syntax `[/text/]` and "
                            f"corrupts parsing"
                        ),
                        suggested_fix=(
                            f'quote the label: `[\"{label}\"]` (the leading '
                            f"slash is now treated as part of the label text, "
                            f"not as a shape declaration)"
                        ),
                    ))

            # ─── Rule 3: `:` inside parens in stateDiagram-v2 transitions ──
            if kind == "stateDiagram-v2":
                m_tx = TRANSITION_LINE_RE.match(raw_line)
                if m_tx and m_tx.group(3):
                    description = m_tx.group(3)
                    for m_par in PAREN_COLON_RE.finditer(description):
                        inner = m_par.group(1)
                        # URL path-parameter syntax (`/:id`) is preserved.
                        inner_no_url = URL_PATH_PARAM_RE.sub("", inner)
                        if ":" in inner_no_url:
                            findings.append(Finding(
                                criterion_id=CR_ID,
                                file=rel,
                                severity="error",
                                description=(
                                    f"line {abs_line}: stateDiagram-v2 "
                                    f"transition description contains "
                                    f"`({inner})` — the ':' inside "
                                    f"parentheses is parsed as a second "
                                    f"state-description boundary by Mermaid "
                                    f"v10+ and rejects the line"
                                ),
                                suggested_fix=(
                                    "rewrite the parenthetical to use '=' "
                                    "(e.g. `(key=value)`) or drop the parens "
                                    "(e.g. `— key value`). Preserve URL "
                                    "path-parameter syntax like '/v1/x/:id' "
                                    "verbatim — only the `(...:...)` form "
                                    "inside the transition description is "
                                    "the violation"
                                ),
                            ))

emit(findings, scope_label="(mermaid blocks)")
PYEOF
