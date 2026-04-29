#!/usr/bin/env bash
# create-issues.sh — assemble schema-conformant issue files from LLM raw output
#
# Per guide §7.1: review-stage issues "必须通过脚本创建 — LLM reviewer 输出原始
# 判断, 由脚本组装为符合 schema 的 issue 文件落盘". This script is that
# assembler. Reviewers (cross / adversarial) write JSON documents to
# .review/round-<N>/reviewer-output/<trace_id>.json (per the IPC contract in
# review/cross-reviewer-subagent.md); the orchestrator runs this script to
# walk those files and materialize per-issue .md files.
#
# Usage:
#   create-issues.sh <artifact-root> <round-number> [--dry-run]
#       reads every <artifact-root>/.review/round-<N>/reviewer-output/*.json
#       (default mode after the cross-reviewer / adversarial-reviewer have
#       ACKed)
#
#   create-issues.sh <artifact-root> <round-number> --stdin [--dry-run]
#       reads ONE JSON document from stdin (legacy mode for tests / direct
#       callers)
#
# JSON schema (per common/issue-schema.md):
#   { "round": <N>, "reviewer_variant": "cross|adversarial",
#     "trace_id": "...", "issues": [
#       { "criterion_id": "CR-...", "file": "...", "severity": "...",
#         "description": "...", "suggested_fix": "...",
#         "recurrence_of": "I-NNN"  # optional
#       }, ...]}
#
# Output: writes one file per accepted issue at
#   <artifact-root>/.review/round-<N>/issues/<id>.md
# Stdout: line-delimited list of created issue ids on success.
#
# Exit codes:
#   0  success — all issues written (count printed on stdout)
#   1  input violates raw-output schema — no files written
#   2  script / IO error

set -euo pipefail

ARTIFACT_ROOT="${1:-}"
ROUND_NUM="${2:-}"
INPUT_MODE="from-dir"   # default
DRY_RUN=0

# Parse remaining flags (--dry-run, --stdin)
shift 2 2>/dev/null || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --stdin) INPUT_MODE="stdin"; shift ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ARTIFACT_ROOT" ] || [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "ERROR: artifact root not found: ${ARTIFACT_ROOT:-<empty>}" >&2
  echo "Usage: create-issues.sh <artifact-root> <round-number> [--dry-run] [--stdin]" >&2
  exit 2
fi
if [ -z "$ROUND_NUM" ] || ! echo "$ROUND_NUM" | grep -qE '^[0-9]+$'; then
  echo "ERROR: round number must be a positive integer; got '${ROUND_NUM:-<empty>}'" >&2
  exit 2
fi

ARTIFACT_ROOT="${ARTIFACT_ROOT%/}"

if [ "$INPUT_MODE" = "stdin" ]; then
  INPUT="$(cat)"
  if [ -z "$INPUT" ]; then
    echo "ERROR: --stdin specified but stdin is empty" >&2
    exit 2
  fi
else
  # Walk every reviewer-output/*.json and merge their `issues` lists into
  # a single document. If the dir is missing or empty, treat as no issues.
  REVIEWER_OUTPUT_DIR="$ARTIFACT_ROOT/.review/round-${ROUND_NUM}/reviewer-output"
  if [ ! -d "$REVIEWER_OUTPUT_DIR" ] || [ -z "$(ls -A "$REVIEWER_OUTPUT_DIR" 2>/dev/null)" ]; then
    echo "OK created 0 issue(s) in round-${ROUND_NUM} (no reviewer-output files found)"
    exit 0
  fi
  INPUT=$(python3 - "$REVIEWER_OUTPUT_DIR" <<'PYEOF'
import json, os, sys
out_dir = sys.argv[1]
merged = {"issues": []}
for fname in sorted(os.listdir(out_dir)):
    if not fname.endswith(".json"):
        continue
    fpath = os.path.join(out_dir, fname)
    try:
        with open(fpath, "r", encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR: cannot parse {fpath}: {e}", file=sys.stderr)
        sys.exit(2)
    if isinstance(doc, dict):
        merged["issues"].extend(doc.get("issues", []) or [])
print(json.dumps(merged, ensure_ascii=False))
PYEOF
)
  if [ -z "$INPUT" ]; then
    echo "ERROR: failed to merge reviewer-output JSON files" >&2
    exit 2
  fi
fi

DRY_RUN="$DRY_RUN" python3 - "$ARTIFACT_ROOT" "$ROUND_NUM" "$INPUT" <<'PYEOF'
import os, sys, json, re

artifact_root = sys.argv[1]
round_num = int(sys.argv[2])
raw = sys.argv[3]
dry_run = os.environ.get('DRY_RUN', '0') == '1'

# ─── Parse and validate input schema ──────────────────────────────────
try:
    doc = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"ERROR: stdin is not valid JSON: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(doc, dict):
    print("ERROR: input must be a JSON object", file=sys.stderr)
    sys.exit(1)

issues_in = doc.get('issues', [])
if not isinstance(issues_in, list):
    print("ERROR: 'issues' must be a list", file=sys.stderr)
    sys.exit(1)

VALID_SEV = {'critical', 'error', 'warning', 'info'}
REQUIRED = ['criterion_id', 'file', 'severity', 'description', 'suggested_fix']

errors = []
for idx, it in enumerate(issues_in):
    if not isinstance(it, dict):
        errors.append(f"issues[{idx}]: not an object")
        continue
    for f in REQUIRED:
        v = it.get(f, '')
        if v is None or (isinstance(v, str) and not v.strip() and f != 'file'):
            # 'file' may be empty for repo-wide issues
            errors.append(f"issues[{idx}].{f}: required field empty/missing")
    if it.get('severity') and it['severity'] not in VALID_SEV:
        errors.append(f"issues[{idx}].severity: {it['severity']!r} not in {sorted(VALID_SEV)}")
    desc = it.get('description', '')
    if isinstance(desc, str) and len(desc.strip()) < 5:
        errors.append(f"issues[{idx}].description: must be at least 5 chars")
    fix = it.get('suggested_fix', '')
    if isinstance(fix, str) and len(fix.strip()) < 5:
        errors.append(f"issues[{idx}].suggested_fix: must be at least 5 chars")

if errors:
    print(f"ERROR: input violates schema ({len(errors)} problem(s)):", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

# ─── Load existing issues to allocate next id and dedupe ──────────────
review_dir = os.path.join(artifact_root, '.review')
existing_ids = set()
existing_signatures = {}      # (criterion_id, file, description-prefix) → id
existing_in_this_round = set()
recurrence_counts = {}        # id → recurrence_count value (int) from frontmatter

id_re = re.compile(r'^id:\s*(\S+)\s*$', re.M)
crit_re = re.compile(r'^criterion_id:\s*(\S+)\s*$', re.M)
file_re = re.compile(r'^file:\s*(.*)$', re.M)
rec_count_re = re.compile(r'^recurrence_count:\s*(\d+)\s*$', re.M)
desc_re = re.compile(r'## Description\s*\n(.*?)(?=\n## |\Z)', re.S)

if os.path.isdir(review_dir):
    for entry in sorted(os.listdir(review_dir)):
        if not entry.startswith('round-'):
            continue
        idir = os.path.join(review_dir, entry, 'issues')
        if not os.path.isdir(idir):
            continue
        for fname in sorted(os.listdir(idir)):
            if not fname.endswith('.md'):
                continue
            fpath = os.path.join(idir, fname)
            try:
                with open(fpath, 'r', encoding='utf-8') as f:
                    text = f.read()
            except OSError:
                continue
            m_id = id_re.search(text)
            if m_id:
                iid = m_id.group(1).strip().strip('"\'')
                existing_ids.add(iid)
                if entry == f"round-{round_num}":
                    existing_in_this_round.add(iid)
                m_rec_count = rec_count_re.search(text)
                if m_rec_count:
                    recurrence_counts[iid] = int(m_rec_count.group(1))
                m_crit = crit_re.search(text)
                m_file = file_re.search(text)
                m_desc = desc_re.search(text)
                if m_crit and m_file and m_desc:
                    sig = (m_crit.group(1).strip().strip('"\''),
                           m_file.group(1).strip().strip('"\''),
                           m_desc.group(1).strip()[:120])
                    existing_signatures[sig] = iid

def next_id():
    n = 1
    while f"I-{n:03d}" in existing_ids:
        n += 1
    nid = f"I-{n:03d}"
    existing_ids.add(nid)
    return nid

# ─── Write issue files ────────────────────────────────────────────────
round_dir = os.path.join(review_dir, f"round-{round_num}", 'issues')
if not dry_run:
    try:
        os.makedirs(round_dir, exist_ok=True)
    except OSError as e:
        print(f"ERROR: cannot create {round_dir}: {e}", file=sys.stderr)
        sys.exit(2)

written = []
deduped = []
for it in issues_in:
    sig = (it['criterion_id'], it.get('file', ''), it['description'].strip()[:120])
    rec_of = it.get('recurrence_of', '').strip() if isinstance(it.get('recurrence_of', ''), str) else ''
    if sig in existing_signatures and not rec_of:
        rec_of = existing_signatures[sig]
    # Dedupe against any issue already filed in this round, whether pre-existing or
    # written earlier in this same batch (existing_in_this_round is updated below).
    if sig in existing_signatures and existing_signatures[sig] in existing_in_this_round:
        deduped.append(existing_signatures[sig])
        continue

    iid = next_id()
    fm_lines = [
        f"id: {iid}",
        f"criterion_id: {it['criterion_id']}",
        f"file: {it.get('file', '')}",
        f"severity: {it['severity']}",
        "state: new",
        f"created_in_round: {round_num}",
    ]
    if rec_of:
        # Per guide §7.5.1, recurrence_count tracks how many times this signature has
        # surfaced after the original (count >= 2 triggers HITL). Look up the prior
        # issue's count and increment so chains accumulate correctly.
        prior_count = recurrence_counts.get(rec_of, 0)
        new_count = prior_count + 1
        fm_lines.append(f"recurrence_of: {rec_of}")
        fm_lines.append(f"recurrence_count: {new_count}")
        recurrence_counts[iid] = new_count
    fm_lines.append("history:")
    fm_lines.append(f"  - {{round: {round_num}, action: created}}")
    fm_lines.append("fix_history: []")

    desc = it['description'].strip()
    fix = it['suggested_fix'].strip()
    body = (
        f"---\n" + "\n".join(fm_lines) + "\n---\n\n"
        f"## Description\n{desc}\n\n"
        f"## Suggested fix\n{fix}\n"
    )
    out_path = os.path.join(round_dir, f"{iid}.md")
    if not dry_run:
        try:
            with open(out_path, 'w', encoding='utf-8') as f:
                f.write(body)
        except OSError as e:
            print(f"ERROR: cannot write {out_path}: {e}", file=sys.stderr)
            sys.exit(2)
    written.append(iid)
    existing_signatures[sig] = iid
    existing_in_this_round.add(iid)

if dry_run:
    print(f"DRY-RUN would create {len(written)} issue(s); deduped {len(deduped)} duplicate(s)")
else:
    print(f"OK created {len(written)} issue(s) in round-{round_num} (deduped {len(deduped)} duplicate(s))")
for iid in written:
    print(f"  {iid}")
sys.exit(0)
PYEOF
