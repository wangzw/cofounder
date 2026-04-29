#!/usr/bin/env bash
# check-prd-formal.sh — PRD-shape formal review (guide §1.1, §9)
#
# Runs every formal (script-tier) check against a generated PRD bundle and
# emits a single JSON document on stdout in the same shape that
# create-issues.sh consumes — so writer self-audit can pipe directly:
#
#   scripts/check-prd-formal.sh <prd-dir> | scripts/create-issues.sh <prd-dir> <round> --dry-run
#
# Sub-checks:
#   CR-PP01  prd-directory-structure          — required layout
#   CR-PP02  id-format-monotonic              — F-NNN / J-NNN format & no gaps
#   CR-PP03  readme-index-complete            — leaf ↔ README index mapping
#   CR-PP04  no-tbd-remaining                 — TBD / TODO / FIXME absent
#   CR-PP05  version-chain-integrity          — REVISIONS.md paths resolve
#   CR-PP15  acceptance-criteria-format       — features carry BDD blocks
#   CR-FM01  frontmatter-required-fields      — leaf frontmatter fields
#
# Per guide §9.1 (3-state returncode) and §9.2 (stdout restates the meaning):
#   0  all pass  (`PASS 0 issues found` on stdout)
#   1  issues found  (`FOUND <N> issues:` followed by the JSON document)
#   2  script error  (diagnostic on stderr)
#
# The script is idempotent (guide §9.5): same input → same JSON output.

set -euo pipefail

PRD_ROOT="${1:-}"

if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: PRD root not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: check-prd-formal.sh <prd-dir>" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"

python3 - "$PRD_ROOT" <<'PYEOF'
import os, re, sys, json

prd_root = sys.argv[1]
findings = []

def add(crid, severity, file_, description, suggested_fix):
    findings.append({
        "criterion_id": crid,
        "file": file_,
        "severity": severity,
        "description": description,
        "suggested_fix": suggested_fix,
    })

def list_dir(rel):
    p = os.path.join(prd_root, rel)
    return sorted(os.listdir(p)) if os.path.isdir(p) else []

def read_text(rel):
    p = os.path.join(prd_root, rel)
    if not os.path.isfile(p):
        return None
    with open(p, 'r', encoding='utf-8', errors='replace') as f:
        return f.read()

def parse_frontmatter(text):
    if not text or not text.startswith('---'):
        return {}, text or ''
    end = text.find('\n---', 3)
    if end < 0:
        return {}, text
    fm = {}
    for raw in text[3:end].splitlines():
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$', raw.strip())
        if not m:
            continue
        v = m.group(2).strip()
        if v.startswith('"') and v.endswith('"'):
            v = v[1:-1]
        elif v.startswith("'") and v.endswith("'"):
            v = v[1:-1]
        fm[m.group(1)] = v
    return fm, text[end + 4:]

# ─── CR-PP01 layout ───────────────────────────────────────────────────
required_top = ['README.md']
required_dirs = ['journeys', 'features']

for top in required_top:
    if not os.path.isfile(os.path.join(prd_root, top)):
        add('CR-PP01', 'critical', top,
            f"required top-level file missing: {top}",
            f"create {top} from common/templates/prd-template.md")

for d in required_dirs:
    p = os.path.join(prd_root, d)
    if not os.path.isdir(p):
        add('CR-PP01', 'critical', d + '/',
            f"required directory missing: {d}/",
            f"create {d}/ and add at least one leaf file")
    else:
        entries = [f for f in os.listdir(p) if not f.startswith('.')]
        if not entries:
            add('CR-PP01', 'error', d + '/',
                f"directory {d}/ is empty",
                f"add at least one leaf file under {d}/")

arch_md = os.path.isfile(os.path.join(prd_root, 'architecture.md'))
arch_dir = os.path.isdir(os.path.join(prd_root, 'architecture'))
if not (arch_md or arch_dir):
    add('CR-PP01', 'error', 'architecture',
        "neither architecture.md nor architecture/ directory exists",
        "create architecture.md (index) and architecture/ topic files per "
        "common/templates/architecture-template.md")

# ─── CR-PP02 ID format & monotonicity ─────────────────────────────────
journey_re = re.compile(r'^J-(\d{3,})(?:-[a-z0-9-]+)?\.md$')
feature_re = re.compile(r'^F-(\d{3,})(?:-[a-z0-9-]+)?\.md$')

def check_ids(rel_dir, kind, prefix, regex):
    nums = []
    bad_format = []
    for fname in list_dir(rel_dir):
        if fname.startswith('.') or not fname.endswith('.md'):
            continue
        m = regex.match(fname)
        if not m:
            bad_format.append(fname)
            continue
        nums.append((int(m.group(1)), fname))
    for fname in bad_format:
        add('CR-PP02', 'error', f"{rel_dir}/{fname}",
            f"{kind} filename {fname!r} does not match expected pattern "
            f"{prefix}-NNN[-slug].md",
            f"rename to {prefix}-NNN[-slug].md (zero-padded 3-digit id)")
    nums.sort()
    seen = set()
    for n, fname in nums:
        if n in seen:
            add('CR-PP02', 'error', f"{rel_dir}/{fname}",
                f"duplicate {kind} id {prefix}-{n:03d}",
                f"rename one occurrence to a unique id")
        seen.add(n)
    if nums:
        ids = sorted({n for n, _ in nums})
        if ids[0] != 1:
            add('CR-PP02', 'warning', f"{rel_dir}/",
                f"{kind} ids start at {prefix}-{ids[0]:03d}, expected {prefix}-001",
                f"renumber the first {kind} to {prefix}-001 unless prior "
                f"versions are tombstoned")
        for i in range(len(ids) - 1):
            if ids[i + 1] - ids[i] > 1:
                missing = list(range(ids[i] + 1, ids[i + 1]))
                add('CR-PP02', 'warning', f"{rel_dir}/",
                    f"gap in {kind} ids: missing "
                    f"{', '.join(f'{prefix}-{m:03d}' for m in missing)}",
                    "either fill the gap or add tombstone entries explaining "
                    "the deprecated ids")

check_ids('journeys', 'journey', 'J', journey_re)
check_ids('features', 'feature', 'F', feature_re)

# ─── CR-PP03 README index completeness ────────────────────────────────
readme = read_text('README.md')
if readme is not None:
    journey_files = [f for f in list_dir('journeys') if journey_re.match(f or '')]
    feature_files = [f for f in list_dir('features') if feature_re.match(f or '')]

    for fname in journey_files:
        if f"journeys/{fname}" not in readme and f"({fname})" not in readme:
            add('CR-PP03', 'error', 'README.md',
                f"journey leaf {fname} not referenced from README.md",
                f"add a link to journeys/{fname} in the journey index section")
    for fname in feature_files:
        if f"features/{fname}" not in readme and f"({fname})" not in readme:
            add('CR-PP03', 'error', 'README.md',
                f"feature leaf {fname} not referenced from README.md",
                f"add a link to features/{fname} in the feature index section")

    # Reverse direction: links in README that don't resolve
    for m in re.finditer(r'\(((?:journeys|features)/[^)]+\.md)\)', readme):
        rel = m.group(1)
        if not os.path.isfile(os.path.join(prd_root, rel)):
            add('CR-PP03', 'error', 'README.md',
                f"README link {rel!r} does not resolve to an existing file",
                f"create the file at {rel} or remove the link")

# ─── CR-PP04 no TBD / TODO / FIXME ────────────────────────────────────
forbidden = re.compile(r'\b(TBD|TODO|FIXME)\b')
for dirpath, dirnames, filenames in os.walk(prd_root):
    rel_dir = os.path.relpath(dirpath, prd_root).replace('\\', '/')
    # Prune subdirs that are hidden or vendored skeleton trees.
    dirnames[:] = [d for d in dirnames
                   if not d.startswith('.')
                   and not (rel_dir == 'common' and d == 'skeleton')]
    for fname in filenames:
        if not fname.endswith('.md'):
            continue
        rel = (fname if rel_dir == '.' else f"{rel_dir}/{fname}")
        text = read_text(rel)
        if text is None:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            if forbidden.search(line):
                snippet = line.strip()[:80]
                add('CR-PP04', 'error', rel,
                    f"placeholder marker on line {i}: {snippet!r}",
                    "replace with a concrete value or remove the section if "
                    "not applicable")
                break

# ─── CR-PP05 version chain ────────────────────────────────────────────
revisions = read_text('REVISIONS.md')
if revisions is not None:
    for m in re.finditer(r'(?im)^\s*(?:Previous Version|Predecessor)\s*:\s*[`\'"]?([^`\'"\n]+)', revisions):
        path = m.group(1).strip()
        if not path:
            continue
        candidate = os.path.expanduser(path)
        if not os.path.isabs(candidate):
            candidate = os.path.normpath(os.path.join(prd_root, '..', candidate))
        if not os.path.exists(candidate):
            add('CR-PP05', 'error', 'REVISIONS.md',
                f"Previous Version path {path!r} does not resolve",
                "fix the path or remove the entry; relative paths are "
                "interpreted from the parent of the PRD directory")

# ─── CR-PP15 acceptance-criteria format ───────────────────────────────
for fname in list_dir('features'):
    if not feature_re.match(fname or ''):
        continue
    rel = f"features/{fname}"
    text = read_text(rel)
    if text is None:
        continue
    fm, body = parse_frontmatter(text)
    m_ac = re.search(r'(?im)^\s*##\s+Acceptance\s+Criteria\b', body)
    if not m_ac:
        add('CR-PP15', 'error', rel,
            "feature missing '## Acceptance Criteria' section",
            "add '## Acceptance Criteria' with at least one Given/When/Then "
            "block")
        continue
    ac_block = body[m_ac.start():]
    next_h2 = re.search(r'\n##\s', ac_block[2:])
    if next_h2:
        ac_block = ac_block[:next_h2.start() + 2]
    has_given = re.search(r'\bGiven\b', ac_block)
    has_when = re.search(r'\bWhen\b', ac_block)
    has_then = re.search(r'\bThen\b', ac_block)
    if not (has_given and has_when and has_then):
        missing = [k for k, v in [('Given', has_given), ('When', has_when), ('Then', has_then)] if not v]
        add('CR-PP15', 'error', rel,
            f"Acceptance Criteria section missing BDD keyword(s): "
            f"{', '.join(missing)}",
            "rewrite the section with at least one Given/When/Then block")

# ─── CR-FM01 frontmatter required fields ──────────────────────────────
def check_fm(rel, required):
    text = read_text(rel)
    if text is None:
        return
    fm, _ = parse_frontmatter(text)
    if not fm:
        add('CR-FM01', 'error', rel,
            "file missing leading frontmatter block",
            "add a frontmatter block (--- delimiters) with required fields: "
            f"{', '.join(required)}")
        return
    missing = [k for k in required if not fm.get(k)]
    if missing:
        add('CR-FM01', 'error', rel,
            f"frontmatter missing field(s): {', '.join(missing)}",
            f"add the missing field(s) to the frontmatter block")

for fname in list_dir('features'):
    if feature_re.match(fname or ''):
        check_fm(f"features/{fname}", ['id', 'title', 'status'])
for fname in list_dir('journeys'):
    if journey_re.match(fname or ''):
        check_fm(f"journeys/{fname}", ['id', 'title', 'persona'])

# ─── Output ───────────────────────────────────────────────────────────
findings.sort(key=lambda f: (f['criterion_id'], f['file'], f['description']))

if not findings:
    print("PASS 0 issues found")
    sys.exit(0)

worst = 'info'
order = {'info': 0, 'warning': 1, 'error': 2, 'critical': 3}
for f in findings:
    if order[f['severity']] > order[worst]:
        worst = f['severity']

print(f"FOUND {len(findings)} issue(s) (worst severity: {worst}):")
print(json.dumps({"issues": findings}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
