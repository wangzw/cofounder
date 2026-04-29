#!/usr/bin/env bash
# check-revise-completeness.sh — phase gate at end of a revise pass
#
# Per guide §7.3: "revise 阶段结束时 — 扫描本轮所有 issue, 确认状态 ∈ {fixed,
# false-positive, deferred, superseded}, 否则 exit 1
# 含义: 必须全部离开 'new' 状态才能 close 本轮 revise"
#
# Usage: check-revise-completeness.sh <artifact-root> <round-number>
#
# Scans .review/round-<N>/issues/*.md only. If any is still state=new, exit 1.
#
# Exit codes (per guide §9.1):
#   0  all issues in this round have left state=new — revise is complete
#   1  one or more issues still in state=new — revise must continue
#   2  script error / bad input

set -euo pipefail

ARTIFACT_ROOT="${1:-}"
ROUND_NUM="${2:-}"

if [ -z "$ARTIFACT_ROOT" ] || [ ! -d "$ARTIFACT_ROOT" ]; then
  echo "ERROR: artifact root not found: ${ARTIFACT_ROOT:-<empty>}" >&2
  echo "Usage: check-revise-completeness.sh <artifact-root> <round-number>" >&2
  exit 2
fi
if [ -z "$ROUND_NUM" ] || ! echo "$ROUND_NUM" | grep -qE '^[0-9]+$'; then
  echo "ERROR: round number must be a positive integer; got '${ROUND_NUM:-<empty>}'" >&2
  echo "Usage: check-revise-completeness.sh <artifact-root> <round-number>" >&2
  exit 2
fi

ARTIFACT_ROOT="${ARTIFACT_ROOT%/}"
ROUND_DIR="$ARTIFACT_ROOT/.review/round-${ROUND_NUM}"

if [ ! -d "$ROUND_DIR" ]; then
  echo "ERROR: round directory not found: $ROUND_DIR" >&2
  exit 2
fi

ISSUES_DIR="$ROUND_DIR/issues"
if [ ! -d "$ISSUES_DIR" ]; then
  # No issues in this round at all — vacuously complete.
  echo "COMPLETE 0 issues in round-${ROUND_NUM}"
  exit 0
fi

python3 - "$ISSUES_DIR" "$ROUND_NUM" <<'PYEOF'
import os, sys, re, json

issues_dir = sys.argv[1]
round_num = sys.argv[2]
new_issues = []
total = 0

state_re = re.compile(r'^state:\s*(\S+)\s*$', re.M)
id_re = re.compile(r'^id:\s*(\S+)\s*$', re.M)
crit_re = re.compile(r'^criterion_id:\s*(\S+)\s*$', re.M)

for fname in sorted(os.listdir(issues_dir)):
    if not fname.endswith('.md'):
        continue
    fpath = os.path.join(issues_dir, fname)
    total += 1
    try:
        with open(fpath, 'r', encoding='utf-8') as f:
            text = f.read()
    except OSError as e:
        print(f"ERROR: cannot read issue file {fpath}: {e}", file=sys.stderr)
        sys.exit(2)
    if not text.startswith('---'):
        print(f"ERROR: issue file missing frontmatter: {fpath}", file=sys.stderr)
        sys.exit(2)
    end = text.find('\n---', 3)
    if end < 0:
        print(f"ERROR: unterminated frontmatter in {fpath}", file=sys.stderr)
        sys.exit(2)
    fm = text[3:end]
    m_state = state_re.search(fm)
    if not m_state:
        print(f"ERROR: missing 'state:' in {fpath}", file=sys.stderr)
        sys.exit(2)
    state_val = m_state.group(1).strip().strip('"\'')
    if state_val == 'new':
        m_id = id_re.search(fm)
        m_crit = crit_re.search(fm)
        new_issues.append({
            'id': m_id.group(1).strip().strip('"\'') if m_id else os.path.basename(fpath),
            'criterion_id': m_crit.group(1).strip().strip('"\'') if m_crit else '',
            'path': fpath,
        })

if new_issues:
    print(f"INCOMPLETE {len(new_issues)} of {total} issue(s) in round-{round_num} still in state=new:")
    print(json.dumps(new_issues, indent=2))
    sys.exit(1)

print(f"COMPLETE all {total} issue(s) in round-{round_num} have left state=new")
sys.exit(0)
PYEOF
