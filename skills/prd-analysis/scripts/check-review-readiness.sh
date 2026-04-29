#!/usr/bin/env bash
# check-review-readiness.sh — phase gate before entering a new review round
#
# Per guide §7.3: "进入下一轮 review 前 — 扫描历史所有 issue, 发现任何 status: new → exit 1
# 含义: 上一轮 revise 没做完就要进下一轮 review, 禁止"
#
# Scans .review/round-*/issues/*.md across all prior rounds. If any issue is
# still in state=new, exits 1 — this means a prior revise pass left an issue
# unresolved and a new review must not start.
#
# Usage: check-review-readiness.sh <artifact-root>
#
# Exit codes (per guide §9.1):
#   0  all prior issues are resolved (none in state=new) — OK to enter review
#   1  one or more issues still in state=new — revise must run first
#   2  script error / bad input
#
# Stdout (per guide §9.2): always restate the returncode semantics.

set -euo pipefail

ARTIFACT_ROOT="${1:-}"

if [ -z "$ARTIFACT_ROOT" ] || [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "ERROR: artifact root not found or not a directory: ${ARTIFACT_ROOT:-<empty>}" >&2
  echo "Usage: check-review-readiness.sh <artifact-root>" >&2
  exit 2
fi

ARTIFACT_ROOT="${ARTIFACT_ROOT%/}"
REVIEW_DIR="$ARTIFACT_ROOT/.review"

if [ ! -d "$REVIEW_DIR" ]; then
  # No history at all — first review is always ready.
  echo "READY 0 issues outstanding (no prior review history)"
  exit 0
fi

python3 - "$REVIEW_DIR" <<'PYEOF'
import os, sys, re, json

review_dir = sys.argv[1]
new_issues = []

# Walk every round-*/issues/ directory and parse frontmatter for state.
state_re = re.compile(r'^state:\s*(\S+)\s*$', re.M)
id_re = re.compile(r'^id:\s*(\S+)\s*$', re.M)
crit_re = re.compile(r'^criterion_id:\s*(\S+)\s*$', re.M)
file_re = re.compile(r'^file:\s*(.*)$', re.M)
round_re = re.compile(r'^created_in_round:\s*(\d+)\s*$', re.M)

if os.path.isdir(review_dir):
    for entry in sorted(os.listdir(review_dir)):
        if not entry.startswith('round-'):
            continue
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
                print(f"ERROR: cannot read issue file {fpath}: {e}", file=sys.stderr)
                sys.exit(2)
            # Extract frontmatter block (between leading --- and next ---)
            if not text.startswith('---'):
                print(f"ERROR: issue file missing frontmatter: {fpath}", file=sys.stderr)
                sys.exit(2)
            end = text.find('\n---', 3)
            if end < 0:
                print(f"ERROR: unterminated frontmatter in: {fpath}", file=sys.stderr)
                sys.exit(2)
            fm = text[3:end]
            m_state = state_re.search(fm)
            if not m_state:
                print(f"ERROR: missing 'state:' field in {fpath}", file=sys.stderr)
                sys.exit(2)
            if m_state.group(1).strip().strip('"\'') != 'new':
                continue
            m_id = id_re.search(fm)
            m_crit = crit_re.search(fm)
            m_file = file_re.search(fm)
            m_round = round_re.search(fm)
            new_issues.append({
                'id': m_id.group(1).strip().strip('"\'') if m_id else os.path.basename(fpath),
                'criterion_id': m_crit.group(1).strip().strip('"\'') if m_crit else '',
                'file': (m_file.group(1).strip().strip('"\'') if m_file else ''),
                'created_in_round': int(m_round.group(1)) if m_round else None,
                'path': os.path.relpath(fpath, os.path.dirname(review_dir)),
            })

if new_issues:
    print(f"NOT_READY {len(new_issues)} issue(s) still in state=new — revise must run before next review:")
    print(json.dumps(new_issues, indent=2))
    sys.exit(1)

print(f"READY 0 issues outstanding")
sys.exit(0)
PYEOF
