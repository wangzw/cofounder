#!/usr/bin/env bash
# test-cr-id-references.sh — guard rail against fabricated CR-IDs
#
# Round-6 audit residual: across rounds 4–6 we found multiple cases where
# templates / subagent prompts cited CR-IDs that did NOT appear in
# common/review-criteria.md (CR-L05, CR-D07, CR-D01..CR-D10, CR-L02,
# CR-L06, CR-PP07-mis-cited as covering cross-journey). These silently
# mislead writer / reviewer subagents that try to ground their output
# against the catalog.
#
# This test treats common/review-criteria.md as the source of truth for
# valid CR-IDs in this skill, plus an explicit allowlist of cross-skill
# IDs (PRD references its sister skill system-design, and vice versa)
# and legacy emit-side IDs that scripts/lib/sd_emit.sh is allowed to
# remap at runtime. Any other CR-ID found in the auditable file set is
# flagged.
#
# Auditable file set: SKILL.md, common/templates/*.md, generate/*.md,
# review/*.md, revise/*.md, evolve/*.md, compact/*.md, clarify/*.md,
# planner/*.md, mode-routing.md (when present).
#
# Skipped: CHANGELOG.md (historical record may reference now-removed
# IDs), common/review-criteria.md (the source itself), README.md (the
# skill-level README documents legacy mapping behaviour for human
# readers), tests/ (test fixtures intentionally use synthetic IDs).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/test_helpers.sh"

SKILL_DIR="$SKILL_ROOT"
SKILL_NAME="$(basename "$SKILL_DIR")"

test_case "every CR-ID referenced in templates / subagent prompts is defined in common/review-criteria.md"

if python3 - "$SKILL_DIR" "$SKILL_NAME" <<'PYEOF'
import os, re, sys

skill_dir = sys.argv[1]
skill_name = sys.argv[2]

# ─── Defined-IDs source-of-truth ─────────────────────────────────────
crit_path = os.path.join(skill_dir, "common", "review-criteria.md")
with open(crit_path, "r", encoding="utf-8") as f:
    crit_text = f.read()
defined = set(re.findall(r"\bCR-[A-Z]+(?:-[A-Z]+)?\d+\b", crit_text))

# ─── Cross-skill + structural-lint + legacy allowlist ────────────────
# Cross-skill refs: prd cites sd's CR-SD*; sd cites prd's CR-PP*/CR-FM*.
# Legacy emit-side IDs: sd_emit.sh's CR_MAP keys (CR-X3/X4/X6/X7, CR-L2)
# are intentionally referenced by check-placeholder-json.sh etc. and by
# README.md describing the remap. These are not in review-criteria.md
# but must still be permitted in templates/prompts when explaining the
# pipeline. Conversely, structural-lint shorthand (L1..L5, X1..X8) are
# not CR-IDs and never match the regex.
CROSS_SKILL = {
    "prd-analysis": {
        # No SD CR-IDs are expected in PRD prompts/templates today; if any
        # appear they are likely accidental (PRD authoring should not depend
        # on SD criteria). Leave empty to flag any drift here too.
    },
    "system-design": {
        # PRD CR-IDs the design templates may reference when explaining how
        # the design files satisfy upstream PRD constraints.
        "CR-PP06",   # traceability-chain (cross-journey patterns)
        "CR-SDFM01", # frontmatter contract (defined in this skill)
        "CR-SDFM02",
        "CR-SDFM03",
    },
}
LEGACY_EMIT_IDS = {
    # From scripts/lib/sd_emit.sh CR_MAP (system-design only). PRD has no
    # equivalent legacy mapping today.
    "CR-X3", "CR-X4", "CR-X6", "CR-X7", "CR-L2",
}

allowed = set(defined)
allowed.update(CROSS_SKILL.get(skill_name, set()))
if skill_name == "system-design":
    allowed.update(LEGACY_EMIT_IDS)

# ─── Auditable file set ─────────────────────────────────────────────
auditable_dirs = ["common/templates", "generate", "review", "revise",
                  "evolve", "compact", "clarify", "planner"]
auditable_files = ["SKILL.md", "mode-routing.md"]

paths_to_scan = []
for top in auditable_files:
    p = os.path.join(skill_dir, top)
    if os.path.isfile(p):
        paths_to_scan.append(p)
for sub in auditable_dirs:
    sub_path = os.path.join(skill_dir, sub)
    if not os.path.isdir(sub_path):
        continue
    for root, _, files in os.walk(sub_path):
        for fn in files:
            if fn.endswith(".md"):
                paths_to_scan.append(os.path.join(root, fn))

# ─── Scan ────────────────────────────────────────────────────────────
id_re = re.compile(r"\bCR-[A-Z]+(?:-[A-Z]+)?\d+\b")
violations = []
for p in sorted(paths_to_scan):
    rel = os.path.relpath(p, skill_dir)
    with open(p, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            for m in id_re.finditer(line):
                cid = m.group(0)
                if cid in allowed:
                    continue
                violations.append((rel, lineno, cid, line.strip()[:100]))

if violations:
    print("FABRICATED CR-IDs detected:", file=sys.stderr)
    for rel, lineno, cid, ctx in violations:
        print(f"  {rel}:{lineno}  {cid}  | {ctx}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PYEOF
then
    _record_pass
else
    _record_fail "fabricated CR-IDs detected — see stderr above"
fi

# ─── Test 2: linked_issues namespace must be I-NNN (issue-IDs), not R<N>- ─
#
# Round-7 surfaced a recurring conflation between the on-disk issue-ID
# namespace (`I-NNN`, per common/issue-schema.md and emitted by
# scripts/create-issues.sh as f"I-{n:03d}") and the dispatch trace_id
# namespace (`R<N>-<role>-<NNN>` like R3-W-007, R3-V-001). Round-8
# uncovered that round-7 missed 6 sites in higher-traffic SKILL.md and
# writer-subagent.md examples. Mechanically guard the entire auditable
# file set so future drift is rejected at test time.
test_case "every linked_issues token in templates / subagent prompts uses canonical I-NNN issue-IDs"

if python3 - "$SKILL_DIR" <<'PYEOF'
import os, re, sys

skill_dir = sys.argv[1]
auditable_dirs = ["common/templates", "generate", "review", "revise",
                  "evolve", "compact", "clarify", "planner"]
auditable_files = ["SKILL.md", "mode-routing.md"]

paths_to_scan = []
for top in auditable_files:
    p = os.path.join(skill_dir, top)
    if os.path.isfile(p):
        paths_to_scan.append(p)
for sub in auditable_dirs:
    sub_path = os.path.join(skill_dir, sub)
    if not os.path.isdir(sub_path):
        continue
    for root, _, files in os.walk(sub_path):
        for fn in files:
            if fn.endswith(".md"):
                paths_to_scan.append(os.path.join(root, fn))

# Match three syntactic forms:
#   "linked_issues": ["I-007", "I-012"]   (JSONL launched/completed events)
#   linked_issues=I-007,I-012             (ACK envelope text)
#   linked_issues: [I-007, I-012]         (YAML / tabular)
# The capture group is the value text up to ] or whitespace / line end.
forms = [
    re.compile(r'"linked_issues"\s*:\s*\[([^\]]*)\]'),
    re.compile(r'linked_issues\s*=\s*([^\s|]+)'),
    re.compile(r'(?<!")\blinked_issues\s*:\s*\[([^\]]*)\]'),
]
token_re = re.compile(r"[A-Za-z][A-Za-z0-9-]*\d")
issue_id_re = re.compile(r"^I-\d{3,}$")

violations = []
for p in sorted(paths_to_scan):
    rel = os.path.relpath(p, skill_dir)
    with open(p, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            for form in forms:
                for m in form.finditer(line):
                    val = m.group(1)
                    # Permit placeholder / schema-doc shapes that carry
                    # no real values: empty array, schema metavars in
                    # angle brackets, or `<comma-separated or empty>`.
                    if "<" in val or "..." in val:
                        continue
                    tokens = [t.strip().strip('"\'') for t in val.split(",") if t.strip()]
                    for t in tokens:
                        # strip enclosing quotes if any
                        if not token_re.search(t):
                            continue  # not an ID-shaped token, ignore
                        if not issue_id_re.match(t):
                            violations.append((rel, lineno, t, line.strip()[:120]))

if violations:
    print("WRONG-NAMESPACE linked_issues tokens (expected I-NNN):", file=sys.stderr)
    for rel, lineno, tok, ctx in violations:
        print(f"  {rel}:{lineno}  {tok}  | {ctx}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PYEOF
then
    _record_pass
else
    _record_fail "linked_issues uses non-I-NNN tokens — see stderr above"
fi

end_tests
