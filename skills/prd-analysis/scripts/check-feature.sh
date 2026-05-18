#!/usr/bin/env bash
# check-feature.sh — formal review of features/F-NNN-{slug}.md leaves.
#
# Per guide §1.1 + §9: emits one issue per finding in JSON; 3-state
# returncode; idempotent. Implements:
#
#   CR-PP02   id-format-monotonic — F-NNN format, no duplicates, no gaps
#   CR-PP04   no-tbd-remaining     — no TBD / TODO / FIXME tokens
#   CR-PP15F  acceptance-criteria-format — BDD Given/When/Then present;
#             also flags compound bullets whose "then" clause bundles
#             ≥3 independent assertions (split into individual
#             Given/When/Then triples)
#   CR-FM01   frontmatter-required-fields — id / title / status
#
# Usage: check-feature.sh <prd-dir>

set -euo pipefail

PRD_ROOT="${1:-}"
if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-feature.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$PRD_ROOT" "$SCRIPT_DIR/lib" <<'PYEOF'
import os, re, sys

prd_root = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from prd_lint import (
    Finding, parse_frontmatter, list_dir, read_text, emit,
    fail_with_script_error, FEATURE_FILE_RE,
)

features_dir = os.path.join(prd_root, "features")
if not os.path.isdir(features_dir):
    # No features/ dir: layout problem, but that is check-readme.sh's job to
    # surface (against the README index). check-feature has nothing to audit.
    emit([], scope_label="(no features/ directory)")

findings: list[Finding] = []

# ─── Collect feature files + parse IDs ────────────────────────────────
nums: list[tuple[int, str]] = []      # (id-int, filename)
bad_format: list[str] = []            # filenames that don't match F-NNN
for fname in list_dir(prd_root, "features"):
    if not fname.endswith(".md"):
        continue
    m = FEATURE_FILE_RE.match(fname)
    if not m:
        bad_format.append(fname)
        continue
    nums.append((int(m.group(1)), fname))

# CR-PP02: bad filename pattern
for fname in bad_format:
    findings.append(Finding(
        criterion_id="CR-PP02",
        file=f"features/{fname}",
        severity="error",
        description=(
            f"feature filename {fname!r} does not match the required "
            f"pattern F-NNN[-slug].md"
        ),
        suggested_fix=(
            "rename to F-NNN[-slug].md with a zero-padded 3-digit id "
            "(e.g. F-001-checkout.md)"
        ),
    ))

# CR-PP02: duplicate ids
seen: set[int] = set()
for n, fname in sorted(nums):
    if n in seen:
        findings.append(Finding(
            criterion_id="CR-PP02",
            file=f"features/{fname}",
            severity="error",
            description=f"duplicate feature id F-{n:03d} (same id used by another file)",
            suggested_fix="rename one occurrence to a unique id",
        ))
    seen.add(n)

# CR-PP02: monotonicity (must start at F-001, no gaps)
ids = sorted({n for n, _ in nums})
if ids:
    if ids[0] != 1:
        findings.append(Finding(
            criterion_id="CR-PP02",
            file="features/",
            severity="warning",
            description=f"feature ids start at F-{ids[0]:03d}, expected F-001",
            suggested_fix=(
                "renumber the first feature to F-001 unless prior versions "
                "are tombstoned"
            ),
        ))
    for i in range(len(ids) - 1):
        if ids[i + 1] - ids[i] > 1:
            missing = list(range(ids[i] + 1, ids[i + 1]))
            findings.append(Finding(
                criterion_id="CR-PP02",
                file="features/",
                severity="warning",
                description=(
                    "gap in feature ids: missing "
                    f"{', '.join(f'F-{m:03d}' for m in missing)}"
                ),
                suggested_fix=(
                    "either fill the gap or add tombstone entries "
                    "explaining the deprecated ids"
                ),
            ))

# ─── Per-file checks ──────────────────────────────────────────────────
forbidden_marker_re = re.compile(r"\b(TBD|TODO|FIXME)\b")
required_fm_fields = ("id", "title", "status")

for _, fname in sorted(nums):
    rel = f"features/{fname}"
    text = read_text(os.path.join(prd_root, rel))
    if text is None:
        continue
    fm, body = parse_frontmatter(text)

    # CR-FM01: frontmatter required fields
    if not fm:
        findings.append(Finding(
            criterion_id="CR-FM01",
            file=rel,
            severity="error",
            description="feature file missing leading frontmatter block",
            suggested_fix=(
                "add a frontmatter block delimited by '---' lines with "
                "required fields: id, title, status"
            ),
        ))
    else:
        missing = [f for f in required_fm_fields if not fm.get(f)]
        if missing:
            findings.append(Finding(
                criterion_id="CR-FM01",
                file=rel,
                severity="error",
                description=(
                    f"frontmatter missing required field(s): {', '.join(missing)}"
                ),
                suggested_fix=(
                    f"add the missing field(s) to the frontmatter block"
                ),
            ))

    # CR-PP04: no TBD/TODO/FIXME
    for i, line in enumerate(text.splitlines(), 1):
        if forbidden_marker_re.search(line):
            snippet = line.strip()[:80]
            findings.append(Finding(
                criterion_id="CR-PP04",
                file=rel,
                severity="error",
                description=f"placeholder marker on line {i}: {snippet!r}",
                suggested_fix=(
                    "replace with a concrete value or remove the section "
                    "if not applicable"
                ),
            ))
            break  # one finding per file is enough

    # CR-PP15F: acceptance-criteria-format
    m_ac = re.search(r"(?im)^\s*##\s+Acceptance\s+Criteria\b", body)
    if not m_ac:
        findings.append(Finding(
            criterion_id="CR-PP15F",
            file=rel,
            severity="error",
            description="feature missing '## Acceptance Criteria' section",
            suggested_fix=(
                "add '## Acceptance Criteria' with at least one "
                "Given/When/Then block"
            ),
        ))
    else:
        # Slice the section between this heading and the next H2 (or EOF)
        ac_block = body[m_ac.start():]
        next_h2 = re.search(r"\n##\s", ac_block[2:])
        if next_h2:
            ac_block = ac_block[:next_h2.start() + 2]
        missing = [
            kw for kw in ("Given", "When", "Then")
            if not re.search(rf"\b{kw}\b", ac_block)
        ]
        if missing:
            findings.append(Finding(
                criterion_id="CR-PP15F",
                file=rel,
                severity="error",
                description=(
                    "Acceptance Criteria section missing BDD keyword(s): "
                    f"{', '.join(missing)}"
                ),
                suggested_fix=(
                    "rewrite the section with at least one Given/When/Then block"
                ),
            ))

        # CR-PP15F compound-AC: each bullet that fuses ≥3 independent
        # post-conditions into a single Given/When/Then triple is harder
        # to debug (failure of any sub-step has no localization) and
        # routinely flagged by reviewers (e.g. chaos round-1 I-034,
        # I-043). Heuristic, applied per bullet:
        #
        #   strong  → "then:" with ≥2 commas in the then-clause
        #   weaker  → "then "  with ≥4 commas in the then-clause
        #
        # Commas inside backticks and parentheses are stripped before
        # counting so that code spans and parenthetical OS labels do
        # not trigger the rule.
        backtick_re = re.compile(r"`[^`]*`")
        paren_re = re.compile(r"\([^()]*\)")
        bullet_then_re = re.compile(
            r"(?i)^\s*[-*]\s+.*?\bthen(?P<sep>:?)\s+(?P<rest>.+?)\s*$"
        )
        for raw_line in ac_block.splitlines():
            m_bullet = bullet_then_re.match(raw_line)
            if not m_bullet:
                continue
            then_clause = m_bullet.group("rest")
            then_has_colon = m_bullet.group("sep") == ":"
            # Strip backtick code spans and parenthetical asides so
            # their commas do not count toward the comma threshold.
            stripped = backtick_re.sub("", then_clause)
            stripped = paren_re.sub("", stripped)
            comma_count = stripped.count(",")
            threshold = 2 if then_has_colon else 4
            if comma_count >= threshold:
                snippet = raw_line.strip()
                if len(snippet) > 100:
                    snippet = snippet[:100] + "…"
                findings.append(Finding(
                    criterion_id="CR-PP15F",
                    file=rel,
                    severity="warning",
                    description=(
                        f"compound Acceptance Criterion: 'then' clause bundles "
                        f"{comma_count + 1} comma-separated assertions in one "
                        f"Given/When/Then triple — failure of any sub-step has "
                        f"no localization. Bullet: {snippet!r}"
                    ),
                    suggested_fix=(
                        "split the bullet into one Given/When/Then triple per "
                        "observable post-condition; reserve a single aggregate "
                        "AC (e.g. timing budget) if a cross-step assertion is "
                        "genuinely required"
                    ),
                ))

emit(findings, scope_label="(features/)")
PYEOF
