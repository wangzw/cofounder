#!/usr/bin/env bash
# check-cross-leaf.sh — bundle-level cross-leaf consistency checks.
#
# Per guide §1.1 + §9: emits one issue per finding in JSON; 3-state
# returncode; idempotent. Implements three mechanically-checkable
# cross-leaf rules that historically only an LLM cross-reviewer caught
# (e.g. chaos round-1 I-007, I-036, I-066, I-067):
#
#   CR-PP27   cross-feature contract — CLI flag underscore-vs-kebab
#             inconsistency (same logical flag spelled both `--foo_bar`
#             and `--foo-bar` across leaves; Go cobra convention is
#             kebab-case)
#   CR-PP27   cross-feature contract — JSON-RPC error code numeric
#             assignment conflict (same UPPER_SNAKE_CASE error name
#             mapped to ≥2 different `-32NNN` integers across leaves)
#   CR-PP06   feature-traceability — dangling F-NNN / J-NNN reference
#             (a leaf references an id that no file in the bundle
#             defines)
#
# For Rule 1 / Rule 2 conflicts, the script emits ONE finding PER
# affected leaf — not a single finding with an arbitrary "first leaf".
# This ensures the Step 8d fix-up loop (generate/from-scratch.md) can
# dispatch a writer for every leaf participating in the conflict; the
# writer for the canonical-authority leaf may legitimately ACK without
# edit (see writer-subagent.md "Lint-Fixup Mode" no-op path).
#
# Symbol-reference dangling (e.g. F-006 referencing
# `EgressManager.Subscribe` on F-003 when F-003 does not expose that
# method) is OUT OF SCOPE — that requires parsing each feature's
# Implementation Notes / Component Contracts and is reserved for the
# LLM cross-reviewer.
#
# Auto-discovered by run-checkers.sh; participates in the formal hard
# gate enforced post-fan-out before review entry. Designed to NOT run
# at per-writer dispatch time — writers only invoke their per-leaf
# script (see generate/writer-subagent.md "Formal pre-check" table).
#
# Usage: check-cross-leaf.sh <prd-dir>

set -uo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-cross-leaf.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys
from collections import defaultdict

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import (
    Finding, read_text, emit, enumerate_leaves,
    JOURNEY_FILE_RE, FEATURE_FILE_RE,
)

leaves = enumerate_leaves(prd_root)
if not leaves:
    emit([], scope_label="(no leaves to compare)")

# Build leaf-content map.
texts: dict[str, str] = {}
for rel in leaves:
    t = read_text(os.path.join(prd_root, rel))
    if t is not None:
        texts[rel] = t

findings: list[Finding] = []

# ─── Pre-compute the set of defined F-NNN / J-NNN ids ───────────────
defined_fids: set[str] = set()
defined_jids: set[str] = set()
for rel in leaves:
    if rel.startswith("features/"):
        m = FEATURE_FILE_RE.match(rel[len("features/"):])
        if m:
            defined_fids.add(f"F-{int(m.group(1)):03d}")
    elif rel.startswith("journeys/"):
        m = JOURNEY_FILE_RE.match(rel[len("journeys/"):])
        if m:
            defined_jids.add(f"J-{int(m.group(1)):03d}")

# ─── Strip code fences (``` ... ```) and inline backtick spans from a
#     leaf for "narrative" scanning, while keeping the original text
#     for line-level inspection where backticks ARE meaningful (CLI
#     flag names are typically written inside backticks in markdown
#     prose, so flag detection deliberately runs on the un-stripped
#     text).
fence_re = re.compile(r"```.*?```", re.DOTALL)

def strip_code(text: str) -> str:
    return fence_re.sub("", text)

# ─── Rule 1: CLI flag underscore-vs-kebab consistency ──────────────
#
# A flag spelled both `--foo_bar` and `--foo-bar` across leaves is a
# cross-leaf contract violation — the same operator-facing string
# must be byte-identical across journey touchpoints and the CLI
# feature's command surface, otherwise users following journey docs
# hit "unknown flag" errors (chaos round-1 I-007).
flag_re = re.compile(r"--([a-zA-Z][a-zA-Z0-9][a-zA-Z0-9_-]*)\b")
flags_by_canonical: dict[str, dict[str, set[str]]] = defaultdict(
    lambda: defaultdict(set)
)  # canonical → {spelling → {leaves}}
for rel, text in texts.items():
    for m in flag_re.finditer(text):
        name = m.group(1)
        if "_" not in name and "-" not in name:
            continue  # single-token flags can't differ in casing
        canonical = name.replace("_", "-")
        flags_by_canonical[canonical][f"--{name}"].add(rel)

for canonical, spellings in sorted(flags_by_canonical.items()):
    if len(spellings) > 1:
        leaves_affected = sorted({
            leaf for variants in spellings.values() for leaf in variants
        })
        spelling_summary = ", ".join(
            f"{sp} ({', '.join(sorted(ls))})" for sp, ls in sorted(spellings.items())
        )
        # Emit one finding per affected leaf so the Step 8d fix-up
        # loop dispatches a writer for each side of the conflict; the
        # writer whose leaf already uses the kebab-case form will
        # legitimately ACK no-op.
        for leaf in leaves_affected:
            findings.append(Finding(
                criterion_id="CR-PP27",
                file=leaf,
                severity="error",
                description=(
                    f"CLI flag --{canonical} has inconsistent spellings "
                    f"across leaves: {spelling_summary}. Same operator-"
                    f"facing string must be byte-identical everywhere or "
                    f"users following one doc hit 'unknown flag' errors "
                    f"when they switch to another."
                ),
                suggested_fix=(
                    f"if this leaf already uses kebab-case --{canonical}, "
                    f"no edit is needed (Lint-Fixup Mode no-op); otherwise "
                    f"rewrite every underscore variant in this leaf to "
                    f"--{canonical}. Go cobra convention is kebab-case."
                ),
            ))

# ─── Rule 2: JSON-RPC error code numeric assignment conflicts ──────
#
# JSON-RPC error codes ("-32NNN") declared with different UPPER_SNAKE
# names across leaves produce incompatible runtime contracts. The
# regex pairs an UPPER_SNAKE identifier (≥3 chars) with a nearby
# `-32NNN` occurrence (within 1-12 separator chars: whitespace, pipe,
# equals, colon, backtick, parenthesis, dash).
code_pair_re = re.compile(
    r"([A-Z][A-Z_0-9]{2,})"      # error name
    r"[`\s|=:()\-]{1,12}?"        # separator
    r"(-32\d{3})\b"               # JSON-RPC code
)
code_assignments: dict[str, dict[str, set[str]]] = defaultdict(
    lambda: defaultdict(set)
)  # name → {code → {leaves}}
for rel, text in texts.items():
    for m in code_pair_re.finditer(text):
        name, code = m.group(1), m.group(2)
        code_assignments[name][code].add(rel)

SHARED_CONVENTIONS_LEAF = "architecture/shared-conventions.md"

for name, by_code in sorted(code_assignments.items()):
    if len(by_code) > 1:
        leaves_affected = sorted({
            leaf for ls in by_code.values() for leaf in ls
        })
        summary = "; ".join(
            f"{c} in [{', '.join(sorted(ls))}]"
            for c, ls in sorted(by_code.items())
        )
        # Emit one finding per affected leaf. Resolution depends on
        # whether the canonical authority (shared-conventions.md) is
        # part of the conflict set:
        #
        #   - In conflict → its writer ACKs no-op (canonical authority
        #     path); the non-canonical writers rewrite to align.
        #   - NOT in conflict → no leaf carries authoritative value;
        #     writers cannot pick a winner unilaterally, so the
        #     suggested_fix explicitly routes to HITL. The Step-8d
        #     lint loop will exhaust iterations and surface to the
        #     user, who decides whether to add the code to
        #     shared-conventions or canonize one of the existing
        #     values.
        canonical_present = SHARED_CONVENTIONS_LEAF in leaves_affected
        for leaf in leaves_affected:
            if canonical_present:
                fix = (
                    f"architecture/shared-conventions.md is the "
                    f"canonical source of truth for the error-code "
                    f"catalogue. If this leaf is shared-conventions.md, "
                    f"no edit needed (Lint-Fixup Mode no-op); otherwise "
                    f"rewrite this leaf's {name} mapping to match "
                    f"shared-conventions."
                )
            else:
                fix = (
                    f"no canonical authority "
                    f"(architecture/shared-conventions.md) participates "
                    f"in this conflict — a Lint-Fixup writer cannot "
                    f"unilaterally pick a winner. ACK no-op (PARTIAL "
                    f"with blocker_scope: needs-human-decision); the "
                    f"orchestrator's lint loop will exhaust iterations "
                    f"and surface this finding to HITL. The user must "
                    f"add the {name} mapping to shared-conventions.md "
                    f"(preferred) or canonize one of the existing "
                    f"values across all leaves."
                )
            findings.append(Finding(
                criterion_id="CR-PP27",
                file=leaf,
                severity="critical",
                description=(
                    f"JSON-RPC error code {name} has conflicting numeric "
                    f"assignments across leaves: {summary}. Any client "
                    f"built from one leaf will fail conformance with "
                    f"another."
                ),
                suggested_fix=fix,
            ))

# ─── Rule 3: dangling F-NNN / J-NNN references ─────────────────────
#
# A leaf that references an id no file in the bundle defines breaks
# traceability. The reference may appear in markdown link syntax,
# inline code, or plain prose — we accept any of them and only check
# membership against the defined set.
fid_ref_re = re.compile(r"\b(F-\d{3,})\b")
jid_ref_re = re.compile(r"\b(J-\d{3,})\b")

dangling: dict[tuple[str, str], set[str]] = defaultdict(set)  # (kind, id) → {leaves}
for rel, text in texts.items():
    stripped = strip_code(text)  # avoid noise from embedded examples
    for m in fid_ref_re.finditer(stripped):
        ref = m.group(1)
        if ref not in defined_fids:
            dangling[("F", ref)].add(rel)
    for m in jid_ref_re.finditer(stripped):
        ref = m.group(1)
        if ref not in defined_jids:
            dangling[("J", ref)].add(rel)

for (kind, ref), refs_in in sorted(dangling.items()):
    leaves_affected = sorted(refs_in)
    findings.append(Finding(
        criterion_id="CR-PP06",
        file=leaves_affected[0],
        severity="error",
        description=(
            f"dangling reference to {ref}: id is mentioned by "
            f"{', '.join(leaves_affected)} but no "
            f"{'features' if kind == 'F' else 'journeys'}/ leaf defines "
            f"it."
        ),
        suggested_fix=(
            f"either create the missing {ref} leaf, fix the reference to "
            f"a valid id present in the bundle, or remove the reference if "
            f"the dependency is no longer in scope"
        ),
    ))

emit(findings, scope_label="(cross-leaf)")
PYEOF
