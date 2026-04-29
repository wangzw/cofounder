#!/usr/bin/env bash
# update-summary.sh — maintain .review/issues/summary.yml for cross-round
# fingerprint matching (guide §7.6).
#
# Aggregates every issue file across all rounds into a single summary file
# that the cross-reviewer reads on its next dispatch to detect recurrence.
#
# Usage: update-summary.sh <artifact-root>
#
# Output: writes <artifact-root>/.review/issues/summary.yml.
# Stdout: one-line OK/FAIL message.
#
# Exit codes:
#   0  summary written
#   1  schema violation in input issue files (no summary written)
#   2  script error

set -euo pipefail

ARTIFACT_ROOT="${1:-}"
if [ -z "$ARTIFACT_ROOT" ] || [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "ERROR: artifact root not found: ${ARTIFACT_ROOT:-<empty>}" >&2
  echo "Usage: update-summary.sh <artifact-root>" >&2
  exit 2
fi

ARTIFACT_ROOT="${ARTIFACT_ROOT%/}"
REVIEW_DIR="$ARTIFACT_ROOT/.review"
SUMMARY_DIR="$REVIEW_DIR/issues"
SUMMARY_PATH="$SUMMARY_DIR/summary.yml"

if [ ! -d "$REVIEW_DIR" ]; then
  echo "OK summary unchanged (no .review history yet)"
  exit 0
fi

CONFIG_FILE="$ARTIFACT_ROOT/common/config.yml"
if [ ! -f "$CONFIG_FILE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CONFIG_FILE="$SCRIPT_DIR/../common/config.yml"
fi

python3 - "$REVIEW_DIR" "$SUMMARY_PATH" "$CONFIG_FILE" <<'PYEOF'
import os, sys, re, json
from datetime import datetime, timezone

review_dir = sys.argv[1]
out_path = sys.argv[2]
config_path = sys.argv[3]

# ─── Read retention config (defaults if missing) ──────────────────────
retention = 2
if os.path.isfile(config_path):
    with open(config_path, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^\s*summary_retention_deliveries\s*:\s*(\d+)\s*$', line)
            if m:
                retention = int(m.group(1))
                break

# ─── Frontmatter parser (minimal) ─────────────────────────────────────
def parse_frontmatter(text):
    """Returns (flat_dict, list_blocks_dict).

    - flat_dict: scalar key → value (single-line key: value pairs)
    - list_blocks_dict: list-key → list of strings (raw indented entries
      under that key, preserving the YAML form). Captures `history:` and
      `fix_history:` so consumers can re-emit them verbatim.
    """
    if not text.startswith('---'):
        return None, {}
    end = text.find('\n---', 3)
    if end < 0:
        return None, {}
    fm = {}
    list_blocks = {}
    current_list_key = None
    fm_lines = text[3:end].splitlines()
    for raw in fm_lines:
        if raw.startswith((' ', '\t')) and current_list_key:
            # indented line — part of the current list block
            list_blocks.setdefault(current_list_key, []).append(raw)
            continue
        # top-level line — terminates any list block in progress
        line = raw.rstrip()
        if not line.strip():
            current_list_key = None
            continue
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$', line)
        if not m:
            current_list_key = None
            continue
        k, v = m.group(1), m.group(2).strip()
        if not v:
            # top-level key with no inline value → likely a list/mapping block
            current_list_key = k
            list_blocks[k] = []
            continue
        current_list_key = None
        if v.startswith('"') and v.endswith('"'):
            v = v[1:-1]
        elif v.startswith("'") and v.endswith("'"):
            v = v[1:-1]
        fm[k] = v
    return fm, list_blocks

desc_re = re.compile(r'## Description\s*\n(.*?)(?=\n## |\Z)', re.S)

# ─── Walk all issue files ─────────────────────────────────────────────
records = {}    # id → record dict
errors = []

for entry in sorted(os.listdir(review_dir)):
    if not entry.startswith('round-'):
        continue
    rmatch = re.match(r'^round-(\d+)$', entry)
    if not rmatch:
        continue
    round_num = int(rmatch.group(1))
    issues_dir = os.path.join(review_dir, entry, 'issues')
    if not os.path.isdir(issues_dir):
        continue
    for fname in sorted(os.listdir(issues_dir)):
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(issues_dir, fname)
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                text = f.read()
        except OSError as e:
            errors.append(f"cannot read {fpath}: {e}")
            continue
        fm, list_blocks = parse_frontmatter(text)
        if not fm:
            errors.append(f"missing/bad frontmatter: {fpath}")
            continue
        iid = fm.get('id', '')
        if not iid:
            errors.append(f"missing id in frontmatter: {fpath}")
            continue
        m_desc = desc_re.search(text)
        summary_text = (m_desc.group(1).strip().splitlines()[0][:200] if m_desc else '')
        # Latest record wins (issue files are versioned by round; latest is canonical).
        # Cross-round consumers (judge oscillation detection, reviser fix-history
        # lookup) need history + fix_history + recurrence_* — propagate them.
        records[iid] = {
            'id': iid,
            'state': fm.get('state', ''),
            'criterion_id': fm.get('criterion_id', ''),
            'file': fm.get('file', ''),
            'severity': fm.get('severity', ''),
            'summary': summary_text,
            'created_in_round': fm.get('created_in_round', ''),
            'fixed_in_round': fm.get('fixed_in_round', ''),
            'defer_until': fm.get('defer_until', ''),
            'defer_reason': fm.get('defer_reason', ''),
            'dismissed_reason': fm.get('dismissed_reason', ''),
            'recurrence_of': fm.get('recurrence_of', ''),
            'recurrence_count': fm.get('recurrence_count', ''),
            'superseded_by': fm.get('superseded_by', ''),
            'history_lines': list_blocks.get('history', []),
            'fix_history_lines': list_blocks.get('fix_history', []),
            'last_seen_in_round': round_num,
        }

if errors:
    print(f"ERROR: {len(errors)} issue file(s) failed to parse:", file=sys.stderr)
    for e in errors[:10]:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

# ─── Apply retention policy ───────────────────────────────────────────
# Keep all `deferred` (any age) + `new` + recent fixed/false-positive.
# We don't have explicit delivery boundaries here, so use rounds-per-delivery
# as a proxy: assume ~5 rounds per delivery and prune fixed/fp records older
# than (latest_round - retention * 5).
all_round_nums = sorted({r['last_seen_in_round'] for r in records.values()})
cutoff_round = all_round_nums[-1] if all_round_nums else 0
ROUNDS_PER_DELIVERY_PROXY = 5
prune_before = max(0, cutoff_round - max(retention, 1) * ROUNDS_PER_DELIVERY_PROXY)

active = []
archive = []
for r in records.values():
    keep = True
    if r['state'] in ('fixed', 'false-positive', 'superseded') and r['last_seen_in_round'] < prune_before:
        keep = False
    (active if keep else archive).append(r)

# ─── Write summary.yml + archive.yml ──────────────────────────────────
def yaml_quote(v):
    if v is None:
        return '""'
    s = str(v)
    if not s:
        return '""'
    if re.search(r'[:#\n"\']', s) or s.startswith(('-', '*', '?', '!', '|', '>', '@', '`')):
        return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return s

now_iso = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

def render(records_list, header):
    lines = [f"# {header}", f"generated_at: {now_iso}", "issues:"]
    for r in sorted(records_list, key=lambda x: x['id']):
        lines.append(f"  - id: {yaml_quote(r['id'])}")
        lines.append(f"    state: {yaml_quote(r['state'])}")
        lines.append(f"    criterion_id: {yaml_quote(r['criterion_id'])}")
        lines.append(f"    file: {yaml_quote(r['file'])}")
        lines.append(f"    severity: {yaml_quote(r['severity'])}")
        lines.append(f"    summary: {yaml_quote(r['summary'])}")
        if r.get('created_in_round'):
            lines.append(f"    created_in_round: {yaml_quote(r['created_in_round'])}")
        if r['state'] == 'fixed' and r.get('fixed_in_round'):
            lines.append(f"    fixed_in_round: {yaml_quote(r['fixed_in_round'])}")
        if r['state'] == 'deferred':
            if r.get('defer_until'):
                lines.append(f"    defer_until: {yaml_quote(r['defer_until'])}")
            if r.get('defer_reason'):
                lines.append(f"    defer_reason: {yaml_quote(r['defer_reason'])}")
        if r['state'] == 'false-positive' and r.get('dismissed_reason'):
            lines.append(f"    dismissed_reason: {yaml_quote(r['dismissed_reason'])}")
        if r['state'] == 'superseded' and r.get('superseded_by'):
            lines.append(f"    superseded_by: {yaml_quote(r['superseded_by'])}")
        # Recurrence — judge uses this for oscillation detection (guide §7.5)
        if r.get('recurrence_of'):
            lines.append(f"    recurrence_of: {yaml_quote(r['recurrence_of'])}")
        if r.get('recurrence_count'):
            lines.append(f"    recurrence_count: {yaml_quote(r['recurrence_count'])}")
        # History / fix_history — reviser reads fix_history on recurrence to
        # avoid repeating the prior failed approach (guide §7.5.1).
        # Re-indent the captured 2-space-indent lines to match the 4-space
        # frame used inside summary.yml entries.
        for blk_key, raw_lines in (
            ('history', r.get('history_lines') or []),
            ('fix_history', r.get('fix_history_lines') or []),
        ):
            if not raw_lines:
                continue
            lines.append(f"    {blk_key}:")
            for src in raw_lines:
                # Source is "  - {round: 1, action: created}" → re-indent to
                # "      - {round: 1, action: created}"
                stripped = src.lstrip(' \t')
                lines.append(f"      {stripped}")
        lines.append(f"    last_seen_in_round: {yaml_quote(r['last_seen_in_round'])}")
    return "\n".join(lines) + "\n"

try:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(render(active, "summary.yml — active issues for cross-round fingerprint matching"))
    if archive:
        archive_path = os.path.join(os.path.dirname(out_path), 'archive.yml')
        with open(archive_path, 'w', encoding='utf-8') as f:
            f.write(render(archive, "archive.yml — pruned per retention policy"))
except OSError as e:
    print(f"ERROR: cannot write summary: {e}", file=sys.stderr)
    sys.exit(2)

print(f"OK wrote {len(active)} active issue(s) to summary.yml ({len(archive)} archived)")
sys.exit(0)
PYEOF
