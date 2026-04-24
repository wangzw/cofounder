#!/usr/bin/env bash
# run-checkers.sh — master checker runner §12.5 Phase A + Phase B
# Usage: run-checkers.sh [--full] <target-skill-dir> <round-N>
# Flags:
#   --full   forced-full review (guide §8.6): skip-set includes every leaf in
#            single_file_focus AND cross_reviewer_focus; skip lists empty;
#            depgraph propagation short-circuited. Triggers: criteria major
#            version bump, new-version first round, converged→first --review,
#            distance since last full review ≥ N, user --full.
# Writes: manifest.yml, depgraph.yml, skip-set.yml, issues/round-checker-output.json
# Exit: 0=no critical/error issues, 1=has critical/error issues, 2=script error
set -euo pipefail

# ====================================================================
# VARIANT: schema
# Phase B SHOULD additionally invoke (when target is schema-type):
#   - `jsonschema validate <schema>`       (JSON Schema validity)
#   - breaking-change detection vs prev delivery
# These are not wired for v1 — writer sub-agent adds them during generate.
# ====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCED_FULL=0
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FORCED_FULL=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done ;;
    -*) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

TARGET="${1:-}"
ROUND="${2:-}"

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi
if [ -z "$ROUND" ]; then
  echo "ERROR: round argument required (e.g. round-1)" >&2
  exit 2
fi

TARGET="${TARGET%/}"

if ! echo "$ROUND" | grep -qE '^round-[0-9]+$'; then
  echo "ERROR: round must be 'round-N' format; got '$ROUND'" >&2
  exit 2
fi

ROUND_NUM="${ROUND#round-}"
PREV_ROUND_NUM=$((ROUND_NUM - 1))
ROUND_DIR="${TARGET}/.review/${ROUND}"
PREV_ROUND_DIR="${TARGET}/.review/round-${PREV_ROUND_NUM}"

mkdir -p "${ROUND_DIR}/issues"

# ─────────────────────────────────────────────
# Phase A: manifest + depgraph + skip-set
# ─────────────────────────────────────────────

FORCED_FULL="$FORCED_FULL" python3 - "$TARGET" "$ROUND_DIR" "$PREV_ROUND_DIR" <<'PYEOF'
import sys, os, hashlib, json
from datetime import datetime, timezone

target = sys.argv[1]
round_dir = sys.argv[2]
forced_full = os.environ.get('FORCED_FULL', '0') == '1'
prev_round_dir = sys.argv[3]

def should_exclude(rel_path):
    parts = rel_path.replace('\\', '/').split('/')
    if parts[0] == '.review':
        return True
    if len(parts) >= 2 and parts[0] == 'common' and parts[1] == 'skeleton':
        return True
    return False

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

# Build manifest
leaves = {}
for dirpath, dirnames, filenames in os.walk(target):
    rel_dir = os.path.relpath(dirpath, target)
    if should_exclude(rel_dir):
        dirnames.clear()
        continue
    dirnames[:] = [d for d in dirnames if not d.startswith('.') and
                   not should_exclude(os.path.join(rel_dir, d).lstrip('./'))]
    for fname in filenames:
        fpath = os.path.join(dirpath, fname)
        rel_file = os.path.relpath(fpath, target).replace('\\', '/')
        if should_exclude(rel_file):
            continue
        try:
            sha = sha256_file(fpath)
            line_count = sum(1 for _ in open(fpath, 'rb'))
            leaves[rel_file] = {'sha256': sha, 'line_count': line_count}
        except OSError:
            pass

now_iso = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Write manifest.yml
manifest_path = os.path.join(round_dir, 'manifest.yml')
with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(f"generated_at: {now_iso}\n")
    f.write("leaves:\n")
    for rel_file in sorted(leaves.keys()):
        info = leaves[rel_file]
        f.write(f'  "{rel_file}":\n')
        f.write(f'    sha256: "{info["sha256"]}"\n')
        f.write(f'    line_count: {info["line_count"]}\n')

# Load previous manifest if exists
prev_manifest_path = os.path.join(prev_round_dir, 'manifest.yml') if prev_round_dir != os.path.join(os.path.dirname(round_dir), 'round-0') else ''
prev_leaves = {}
if os.path.isfile(prev_manifest_path):
    import re
    current_file = None
    with open(prev_manifest_path, 'r', encoding='utf-8') as f:
        for line in f:
            m_file = re.match(r'^\s+"([^"]+)":\s*$', line)
            m_sha = re.match(r'^\s+sha256:\s+"([^"]+)"', line)
            if m_file:
                current_file = m_file.group(1)
            elif m_sha and current_file:
                prev_leaves[current_file] = m_sha.group(1)

# Write unchanged files to skip-set
# (skip-set used by Phase B for per_file criteria)
# Forced-full (§8.6) short-circuits: no leaf is "unchanged" for skip purposes even if
# hash matches — the whole target gets re-reviewed.
if forced_full:
    unchanged = []
else:
    unchanged = [f for f, info in leaves.items() if prev_leaves.get(f) == info['sha256']]

# We'll write skip-set after loading criteria (Phase B will use it)
# For now, emit as JSON for the Phase B python to read
state = {
    'leaves': leaves,
    'unchanged': unchanged,
    'manifest_path': manifest_path,
    'round_dir': round_dir,
    'now_iso': now_iso,
    'forced_full': forced_full,
}
state_path = os.path.join(round_dir, '_phase_a_state.json')
with open(state_path, 'w') as f:
    json.dump(state, f)
print(f"OK manifest written: {manifest_path}")
PYEOF

# Run depgraph
"${SCRIPT_DIR}/build-depgraph.sh" "$TARGET" "$ROUND" >/dev/null 2>&1 || true

# ─────────────────────────────────────────────
# Phase B: extract criteria, run script checkers
# ─────────────────────────────────────────────

CRITERIA_JSON=$("${SCRIPT_DIR}/extract-criteria.sh" "$TARGET" 2>/dev/null) || {
  echo "ERROR: failed to extract criteria from target" >&2
  exit 2
}

set +e
SKILL_FORGE_SCRIPTS_DIR="$SCRIPT_DIR" python3 - "$TARGET" "$ROUND_DIR" "$CRITERIA_JSON" <<'PYEOF'
import sys, os, json, subprocess, re

target = sys.argv[1]
round_dir = sys.argv[2]
criteria_json = sys.argv[3]

try:
    criteria = json.loads(criteria_json)
except json.JSONDecodeError as e:
    sys.stderr.write(f"ERROR: bad criteria JSON: {e}\n")
    sys.exit(2)

# Load phase A state
state_path = os.path.join(round_dir, '_phase_a_state.json')
with open(state_path, 'r') as f:
    state = json.load(f)
leaves = state['leaves']
unchanged = state['unchanged']
now_iso = state.get('now_iso', '')
forced_full = state.get('forced_full', False)

# Build skip-set
# Per guide §8.5 / §12.5.1, skip-set has two granularities:
#   (a) single_file_focus/skip: per-file hash unchanged → safe for single-file checkers
#   (b) cross_reviewer_focus/skip: hash AND transitive dependencies unchanged → safe for
#       cross-reviewer LLM (else a dependency change leaves stale cross-refs unchecked)

all_leaves = set(leaves.keys())
unchanged_set = set(unchanged)
changed_set = all_leaves - unchanged_set

# Load depgraph if available (built by build-depgraph.sh between Phase A and Phase B)
depgraph_path = os.path.join(round_dir, 'depgraph.yml')
depgraph = {}
depgraph_available = False
if os.path.isfile(depgraph_path):
    try:
        with open(depgraph_path, 'r', encoding='utf-8') as f:
            dep_txt = f.read()
        in_graph = False
        current_file = None
        current_deps = []
        for line in dep_txt.split('\n'):
            if line.strip() == 'graph:':
                in_graph = True
                continue
            if not in_graph:
                continue
            m_file = re.match(r'^\s{2}"([^"]+)":\s*\[\]', line)
            if m_file:
                # Inline empty list
                depgraph[m_file.group(1)] = []
                continue
            m_file_open = re.match(r'^\s{2}"([^"]+)":\s*$', line)
            if m_file_open:
                current_file = m_file_open.group(1)
                depgraph[current_file] = []
                continue
            m_dep = re.match(r'^\s+-\s+"([^"]+)"', line)
            if m_dep and current_file:
                depgraph[current_file].append(m_dep.group(1))
        depgraph_available = True
    except Exception:
        depgraph_available = False

# Build reverse deps: for each file, who references it
reverse_deps = {f: set() for f in all_leaves}
for src, deps in depgraph.items():
    for dep in deps:
        if dep in reverse_deps:
            reverse_deps[dep].add(src)

# Compute transitive closure of "tainted" files for cross-reviewer:
# A file is tainted if it changed, OR any file it references changed, OR any file
# that references it changed. Tainted files go to cross_reviewer_focus; untainted to skip.
tainted = set(changed_set)
# Propagate both directions via BFS
frontier = set(changed_set)
while frontier:
    next_frontier = set()
    for f in frontier:
        # Files this file depends on (if they're our problem we already know)
        for dep in depgraph.get(f, []):
            if dep in all_leaves and dep not in tainted:
                tainted.add(dep)
                next_frontier.add(dep)
        # Files that depend on this file (changes here could invalidate them)
        for rev in reverse_deps.get(f, set()):
            if rev not in tainted:
                tainted.add(rev)
                next_frontier.add(rev)
    frontier = next_frontier

cross_reviewer_focus = sorted(tainted)
cross_reviewer_skip  = sorted(all_leaves - tainted)

single_file_focus = sorted(changed_set)
single_file_skip  = sorted(unchanged_set)

# Back-compat per_file_skips: per-CR list (same as before). Script checkers
# still consume this rather than single_file_*. Identical semantics for per_file CRs.
per_file_skips = {}
for c in criteria:
    cid = c.get('id', '')
    skip = c.get('incremental_skip', 'full_scan')
    if skip == 'per_file':
        per_file_skips[cid] = single_file_skip

# Helper: write a YAML list field, inline `[]` when empty
def write_list(f, key, values):
    if not values:
        f.write(f"{key}: []\n")
    else:
        f.write(f"{key}:\n")
        for v in values:
            f.write(f'  - "{v}"\n')

# Write skip-set.yml per guide §12.5.1 schema
skip_set_path = os.path.join(round_dir, 'skip-set.yml')
round_num = int(round_dir.rstrip('/').split('round-')[-1])
total_leaves = len(all_leaves)

with open(skip_set_path, 'w', encoding='utf-8') as f:
    f.write(f"round: {round_num}\n")
    f.write(f"generated_at: {now_iso}\n")
    f.write(f"depgraph_available: {'true' if depgraph_available else 'false'}\n")
    f.write(f"forced_full: {'true' if forced_full else 'false'}\n")
    write_list(f, "single_file_focus", single_file_focus)
    write_list(f, "single_file_skip",  single_file_skip)
    write_list(f, "cross_reviewer_focus", cross_reviewer_focus)
    write_list(f, "cross_reviewer_skip",  cross_reviewer_skip)
    # coverage check sums — union must equal total_leaves for each granularity
    f.write("coverage_check:\n")
    f.write(f"  total_leaves: {total_leaves}\n")
    f.write(f"  single_file_focus_count: {len(single_file_focus)}\n")
    f.write(f"  single_file_skip_count: {len(single_file_skip)}\n")
    f.write(f"  single_file_union_complete: {str(len(single_file_focus) + len(single_file_skip) == total_leaves).lower()}\n")
    f.write(f"  cross_reviewer_focus_count: {len(cross_reviewer_focus)}\n")
    f.write(f"  cross_reviewer_skip_count: {len(cross_reviewer_skip)}\n")
    f.write(f"  cross_reviewer_union_complete: {str(len(cross_reviewer_focus) + len(cross_reviewer_skip) == total_leaves).lower()}\n")
    # Per-criterion skip lists (back-compat for script checkers).
    # Script checkers that care about per_file granularity consume this; LLM reviewers
    # should consume cross_reviewer_focus instead.
    f.write("per_file_skips:\n")
    for cid in sorted(per_file_skips.keys()):
        skipped = per_file_skips[cid]
        if skipped:
            f.write(f'  "{cid}":\n')
            for sf in sorted(skipped):
                f.write(f'    - "{sf}"\n')
        else:
            f.write(f'  "{cid}": []\n')

# Run script-type checkers
all_issues = []
scripts_dir = os.path.join(os.path.dirname(__file__) if '__file__' in dir() else os.getcwd())

# Resolve scripts dir from the script itself
scripts_dir = os.path.join(target, '..', '..', 'scripts')
# Actually use the this skill scripts dir
# We need to find the scripts dir relative to run-checkers.sh
# run-checkers.sh is in skills/this skill/scripts/ — same dir as the checkers
# Pass it as an env var
scripts_dir = os.environ.get('SKILL_FORGE_SCRIPTS_DIR', '')
if not scripts_dir or not os.path.isdir(scripts_dir):
    # Fallback: find scripts dir relative to target or via PATH
    scripts_dir = os.path.join(target, 'scripts')

for c in criteria:
    cid = c.get('id', '')
    checker_type = c.get('checker_type', '')
    script_path = c.get('script_path', '')
    incr_skip = c.get('incremental_skip', 'full_scan')

    # Only run script-type criteria
    if checker_type != 'script':
        continue

    if not script_path:
        continue

    # Resolve script path relative to target
    full_script = os.path.join(target, script_path)
    if not os.path.isfile(full_script):
        # Also try relative to scripts_dir (this skill's scripts)
        full_script = os.path.join(scripts_dir, os.path.basename(script_path))
    if not os.path.isfile(full_script):
        # Missing checker => structured meta-issue so it surfaces in review loop
        # and the judge sees a real 'error' until the script is authored or the CR is
        # re-classified / deprecated. (Previously this only emitted a stderr WARNING
        # that was silently skipped — allowing converged verdicts despite unchecked CRs.)
        all_issues.append({
            "criterion_id": "CR-META-missing-checker",
            # The revisable artifact is the criteria file where the CR is declared,
            # NOT the missing script path (scripts/ is skeleton-protected — reviser
            # cannot author new scripts). Carry the missing script path as a separate
            # field so the reviser can surface it in the rewrite rationale.
            "file": "common/review-criteria.md",
            "missing_script_path": script_path,
            "severity": "error",
            "description": (
                f"{cid} declares script_path {script_path!r} but no such script exists "
                f"in the target or this skill scripts/ directory; criterion was not evaluated"
            ),
            "suggested_fix": (
                f"Edit common/review-criteria.md: change {cid}.checker_type to 'llm' if the "
                f"check genuinely requires LLM judgment, OR add deprecated: true to {cid} if the "
                f"rule is no longer applicable. Authoring new scripts under scripts/ is NOT the "
                f"reviser's job (skeleton-protected); escalate via HITL if a new script is required."
            ),
        })
        continue

    try:
        result = subprocess.run(
            [full_script, target],
            capture_output=True, timeout=60
        )
        if result.returncode == 2:
            stderr_snippet = result.stderr.decode("utf-8", errors="replace").strip()[:200]
            all_issues.append({
                "criterion_id": cid,
                "file": "scripts/" + script_path.rsplit("/", 1)[-1],
                "severity": "error",
                "description": f"{cid} checker script exited 2 (internal error); criterion not evaluated: {stderr_snippet}",
                "suggested_fix": f"inspect script {script_path} stderr for root cause"
            })
            continue
        stdout = result.stdout.decode("utf-8", errors="replace").strip()
        if stdout:
            try:
                checker_issues = json.loads(stdout)
                if isinstance(checker_issues, list):
                    all_issues.extend(checker_issues)
            except json.JSONDecodeError:
                # Non-JSON stdout is a contract violation — emit meta-issue
                # instead of silent warning, so it's visible to judge + revise loop.
                all_issues.append({
                    "criterion_id": "CR-META-checker-contract-violation",
                    "file": script_path,
                    "severity": "error",
                    "description": (
                        f"{cid} checker stdout is not valid JSON (first 100 chars: "
                        f"{stdout[:100]!r}); expected JSON array per §12.4"
                    ),
                    "suggested_fix": (
                        f"fix {script_path} to emit JSON array on stdout (empty list [] on pass, "
                        f"list of issue dicts on findings); all diagnostic output must go to stderr"
                    ),
                })
    except subprocess.TimeoutExpired:
        all_issues.append({
            "criterion_id": "CR-META-checker-timeout",
            "file": script_path,
            "severity": "error",
            "description": f"{cid} checker timed out after 60s; criterion not evaluated",
            "suggested_fix": f"profile {script_path} and optimize, or split into per-file invocations",
        })
    except Exception as e:
        all_issues.append({
            "criterion_id": "CR-META-checker-error",
            "file": script_path,
            "severity": "error",
            "description": f"{cid} checker raised unexpected exception: {type(e).__name__}: {e}",
            "suggested_fix": f"inspect {script_path} for robustness; catch the underlying cause",
        })

# Write output
out_path = os.path.join(round_dir, 'issues', 'round-checker-output.json')
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(all_issues, f, indent=2)

# Expand each issue into an individual <issue-id>.md file so downstream
# summarizer/judge/reviser (which all read `issues/*.md` frontmatter) can
# pick them up. Number monotonically within the round starting at 001;
# cross-reviewer picks up from max+1 when it dispatches later.
issues_dir = os.path.join(round_dir, 'issues')
existing_ids = set()
for fname in os.listdir(issues_dir):
    m = re.match(r'^R(\d+)-(\d{3})\.md$', fname)
    if m:
        existing_ids.add(int(m.group(2)))
next_seq = max(existing_ids) + 1 if existing_ids else 1

def _yaml_escape(s):
    if s is None:
        return '""'
    s = str(s).replace('\\', '\\\\').replace('"', '\\"')
    # collapse newlines for frontmatter scalars
    s = s.replace('\n', ' ').replace('\r', ' ')
    return '"' + s + '"'

for issue in all_issues:
    issue_id = f"R{round_num}-{next_seq:03d}"
    next_seq += 1
    md_path = os.path.join(issues_dir, issue_id + '.md')
    criterion_id = issue.get('criterion_id', 'UNKNOWN')
    severity     = issue.get('severity', 'error')
    file_field   = issue.get('file', '')
    description  = issue.get('description', '')
    suggested    = issue.get('suggested_fix', '')
    extra_fm_lines = []
    if 'missing_script_path' in issue:
        extra_fm_lines.append(f'missing_script_path: {_yaml_escape(issue["missing_script_path"])}')
    extra_fm = ('\n' + '\n'.join(extra_fm_lines)) if extra_fm_lines else ''
    frontmatter = (
        '---\n'
        f'id: {issue_id}\n'
        f'status: new\n'
        f'severity: {severity}\n'
        f'criterion_id: {criterion_id}\n'
        f'file: {_yaml_escape(file_field)}\n'
        f'round: {round_num}\n'
        f'source: script'
        f'{extra_fm}\n'
        '---\n\n'
    )
    body = f'# {criterion_id}\n\n{description}\n'
    if suggested:
        body += f'\n## Suggested Fix\n\n{suggested}\n'
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(frontmatter + body)

print(f"OK checker output written: {out_path} ({len(all_issues)} issues)")

# Clean up temp state
try:
    os.remove(state_path)
except OSError:
    pass

has_blocking = any(i.get('severity') in ('critical', 'error') for i in all_issues)
if has_blocking:
    sys.exit(1)
PYEOF
EXIT_CODE=$?
set -e
if [ $EXIT_CODE -eq 1 ]; then
  echo "INFO: checkers found critical/error issues (exit 1)" >&2
fi
exit $EXIT_CODE
