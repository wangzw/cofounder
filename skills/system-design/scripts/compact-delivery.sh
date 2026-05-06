#!/usr/bin/env bash
# compact-delivery.sh — compress intermediate review rounds of the current
# delivery into a single compacted-history.md, then delete the intermediate
# round-N/ directories and clean up trace dirs for any round whose round-N/
# directory does not survive.
#
# Trace cleanup scope:
#   - traces/round-N/ for every intermediate round of the current delivery
#     (these round-N/ dirs are deleted in the same run).
#   - traces/round-N/ orphans — round numbers whose .review/round-N/ dir
#     is already gone (e.g. compacted in a prior --compact run for an
#     older delivery). Any traces/<non-round-N> entry (e.g. metrics-cache)
#     is left untouched.
#   - The final (surviving) round's traces/round-<final>/ is PRESERVED
#     as the audit snapshot for the converged round.
#
# Scope: the CURRENT delivery only (the highest delivery_id observed in any
# round-N/index.md or round-N/verdict.yml frontmatter). Cross-delivery
# coarse-grained archival is out of scope here.
#
# Gating:
#   - The final (highest) round of the current delivery MUST have a
#     verdict.yml with verdict: converged. Otherwise the script refuses.
#   - If there are 0 or 1 intermediate rounds (current delivery has only
#     one round), the script is a no-op (exit 0 with message).
#
# Recovery:
#   - Original round-N content is preserved by git history when the user
#     has run commit-delivery.sh (delivery-<N>-<slug> tag). When no such
#     tag is found we print a warning before destructive work; --force
#     suppresses the warning.
#
# Usage:
#   compact-delivery.sh <prd-dir> [--dry-run] [--force]
#
# Exit codes:
#   0  success (or no-op)
#   1  refused (e.g. no converged verdict, or no current delivery found)
#   2  script-level error / bad input

set -uo pipefail

PRD_ROOT=""
DRY_RUN=0
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$PRD_ROOT" ]; then
        PRD_ROOT="$1"
      else
        echo "ERROR: unexpected positional arg: $1" >&2
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$PRD_ROOT" ] || [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: prd-dir not found: ${PRD_ROOT:-<empty>}" >&2
  echo "Usage: compact-delivery.sh <prd-dir> [--dry-run] [--force]" >&2
  exit 2
fi
PRD_ROOT="${PRD_ROOT%/}"

REVIEW_DIR="$PRD_ROOT/.review"
if [ ! -d "$REVIEW_DIR" ]; then
  echo "REFUSE: no .review/ directory under $PRD_ROOT — nothing to compact"
  exit 1
fi

# Optional warning when no delivery git tag exists for the current delivery.
# We compute this AFTER we know delivery_id; the variable below is the
# warning text accumulator.
GIT_TAG_WARN=""

python3 - "$PRD_ROOT" "$DRY_RUN" "$FORCE" <<'PYEOF'
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

prd_root = sys.argv[1]
dry_run = sys.argv[2] == "1"
force = sys.argv[3] == "1"

review_dir = os.path.join(prd_root, ".review")
traces_dir = os.path.join(review_dir, "traces")

ROUND_RE = re.compile(r"^round-(\d+)$")
FRONT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$")


def parse_frontmatter(path):
    """Return a flat dict of top-level key/value pairs from a YAML
    frontmatter block (---...---) or a plain YAML file. Nested blocks
    are skipped (we only need scalar fields)."""
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    body = text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end >= 0:
            body = text[4:end]
    fm = {}
    for line in body.splitlines():
        if line.startswith((" ", "\t")) or not line.strip() or line.startswith("#"):
            continue
        m = FRONT_RE.match(line)
        if m:
            v = m.group(2).strip()
            if v.startswith('"') and v.endswith('"'):
                v = v[1:-1]
            fm[m.group(1)] = v
    return fm


def list_rounds():
    out = []
    for name in os.listdir(review_dir):
        m = ROUND_RE.match(name)
        if m:
            p = os.path.join(review_dir, name)
            if os.path.isdir(p):
                out.append((int(m.group(1)), p))
    out.sort(key=lambda x: x[0])
    return out


def round_delivery_id(round_dir):
    """Best-effort: read delivery_id from verdict.yml first, then index.md.
    Returns int or None."""
    for fname in ("verdict.yml", "index.md"):
        fm = parse_frontmatter(os.path.join(round_dir, fname))
        v = fm.get("delivery_id")
        if v and v.isdigit():
            return int(v)
    return None


rounds = list_rounds()
if not rounds:
    print("REFUSE: no round-N/ directories found in .review/")
    sys.exit(1)

# Group rounds by delivery_id; rounds whose delivery_id we cannot determine
# are bucketed under None and never compacted (safer default).
by_delivery = {}
for n, path in rounds:
    d = round_delivery_id(path)
    by_delivery.setdefault(d, []).append((n, path))

known = {d: rs for d, rs in by_delivery.items() if d is not None}
if not known:
    print("REFUSE: no round-N/ directory has a usable delivery_id frontmatter "
          "field (looked in verdict.yml and index.md)")
    sys.exit(1)

current_delivery = max(known.keys())
delivery_rounds = sorted(known[current_delivery], key=lambda x: x[0])
final_round_num, final_round_dir = delivery_rounds[-1]

# Gate: final round must have verdict: converged
final_verdict = parse_frontmatter(os.path.join(final_round_dir, "verdict.yml"))
verdict = final_verdict.get("verdict", "")
if verdict != "converged":
    print(
        f"REFUSE: final round of delivery {current_delivery} is round-{final_round_num}, "
        f"but its verdict is {verdict!r} (need 'converged')"
    )
    sys.exit(1)

intermediate = delivery_rounds[:-1]
if not intermediate:
    print(
        f"OK no-op: delivery {current_delivery} has only round-{final_round_num} "
        "— nothing to compact"
    )
    sys.exit(0)

# Optional warning: no delivery git tag.
if not force:
    try:
        proc = subprocess.run(
            ["git", "-C", prd_root, "tag", "--list", f"delivery-{current_delivery}-*"],
            capture_output=True, text=True, check=False,
        )
        tags = (proc.stdout or "").strip()
        if not tags:
            sys.stderr.write(
                f"warn: no git tag matches 'delivery-{current_delivery}-*' — the "
                "intermediate rounds about to be deleted are NOT preserved in git "
                "history. Pass --force to proceed anyway, or run "
                "scripts/commit-delivery.sh first.\n"
            )
            if not dry_run:
                print(
                    "REFUSE: no delivery git tag (use --force to override, or "
                    "run commit-delivery.sh first)"
                )
                sys.exit(1)
    except FileNotFoundError:
        # git not available — don't block; commit-delivery would have failed too
        pass

# ─── Aggregate stats from intermediate rounds ──────────────────────────────

INT_FIELDS = (
    "total_issues", "new_count", "fixed_count", "false_positive_count",
    "deferred_count", "superseded_count",
    "critical_count", "error_count", "warning_count", "info_count",
    "recurrence_count",
    "writer_dispatch_count", "writer_fail_count_sum", "writer_full_pass_count",
)


def to_int(s, default=0):
    try:
        return int((s or "").strip())
    except (TypeError, ValueError):
        return default


per_round = []
totals = {k: 0 for k in INT_FIELDS}
all_cr_ids = {}
issue_ids_seen = set()

for n, path in intermediate:
    idx_fm = parse_frontmatter(os.path.join(path, "index.md"))
    vd_fm = parse_frontmatter(os.path.join(path, "verdict.yml"))

    counts = {k: to_int(idx_fm.get(k)) for k in INT_FIELDS}
    for k, v in counts.items():
        totals[k] += v

    # Scan issues/*.md for criterion_id and id
    issues_dir = os.path.join(path, "issues")
    round_cr_counts = {}
    if os.path.isdir(issues_dir):
        for fname in os.listdir(issues_dir):
            if not fname.endswith(".md"):
                continue
            ifm = parse_frontmatter(os.path.join(issues_dir, fname))
            iid = ifm.get("id", "")
            cr = ifm.get("criterion_id", "")
            if iid:
                issue_ids_seen.add(iid)
            if cr:
                round_cr_counts[cr] = round_cr_counts.get(cr, 0) + 1
                all_cr_ids[cr] = all_cr_ids.get(cr, 0) + 1

    per_round.append({
        "round": n,
        "verdict": vd_fm.get("verdict", "unknown"),
        "counts": counts,
        "cr_counts": round_cr_counts,
    })

# Final-round snapshot for reference (NOT counted in totals — it survives)
final_idx = parse_frontmatter(os.path.join(final_round_dir, "index.md"))
final_counts = {k: to_int(final_idx.get(k)) for k in INT_FIELDS}

generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
compacted_round_nums = [n for n, _ in intermediate]

# ─── Build the compacted-history.md content ────────────────────────────────

cr_sorted = sorted(all_cr_ids.items(), key=lambda kv: (-kv[1], kv[0]))

header = []
header.append("---")
header.append(f"delivery_id: {current_delivery}")
header.append(f"final_round: {final_round_num}")
header.append("compacted_rounds:")
for n in compacted_round_nums:
    header.append(f"  - {n}")
header.append(f"compacted_round_count: {len(compacted_round_nums)}")
header.append(f"total_issues_seen: {len(issue_ids_seen)}")
header.append(f"generated_at: {generated_at}")
header.append("aggregate_state_counts:")
for k in ("new_count", "fixed_count", "false_positive_count",
         "deferred_count", "superseded_count"):
    header.append(f"  {k}: {totals[k]}")
header.append("aggregate_severity_counts:")
for k in ("critical_count", "error_count", "warning_count", "info_count"):
    header.append(f"  {k}: {totals[k]}")
header.append(f"aggregate_recurrence_count: {totals['recurrence_count']}")
header.append("---")
header.append("")

body = []
body.append(f"# Delivery {current_delivery} — Compacted Review History")
body.append("")
body.append(
    f"This file replaces the intermediate round directories "
    f"{', '.join('round-' + str(n) for n in compacted_round_nums)} "
    f"of delivery {current_delivery}. The final round (round-{final_round_num}, "
    f"verdict: converged) is preserved alongside this summary."
)
body.append("")
body.append(
    f"**Aggregate across {len(compacted_round_nums)} compacted round(s):** "
    f"{len(issue_ids_seen)} unique issues seen, "
    f"{totals['fixed_count']} fixed, "
    f"{totals['false_positive_count']} false-positive, "
    f"{totals['deferred_count']} deferred, "
    f"{totals['superseded_count']} superseded, "
    f"{totals['recurrence_count']} recurrences."
)
body.append("")
body.append("## Per-round summary")
body.append("")
body.append("| Round | Verdict | Total | New | Fixed | FP | Deferred | Crit | Err |")
body.append("|------:|---------|------:|----:|------:|---:|---------:|-----:|----:|")
for r in per_round:
    c = r["counts"]
    body.append(
        f"| {r['round']} | {r['verdict']} | {c['total_issues']} | "
        f"{c['new_count']} | {c['fixed_count']} | {c['false_positive_count']} | "
        f"{c['deferred_count']} | {c['critical_count']} | {c['error_count']} |"
    )
body.append("")
body.append("## Final round (preserved)")
body.append("")
body.append(
    f"- **round-{final_round_num}** — verdict: `converged` — "
    f"final issues: {final_counts['total_issues']} "
    f"(deferred: {final_counts['deferred_count']}, "
    f"false-positive: {final_counts['false_positive_count']})"
)
body.append("")
if cr_sorted:
    body.append("## Criteria touched (compacted rounds, by frequency)")
    body.append("")
    for cr, n in cr_sorted:
        body.append(f"- `{cr}` — {n} issue(s)")
    body.append("")

content = "\n".join(header) + "\n".join(body) + "\n"

# ─── Plan the destructive ops ──────────────────────────────────────────────

target_file = os.path.join(final_round_dir, "compacted-history.md")
to_remove_round_dirs = [path for _, path in intermediate]

# Compute the set of round numbers whose round-N/ directory will SURVIVE
# the destructive step. Any traces/round-N/ whose N is not in this set is
# an orphan (its source round dir is gone — either deleted in this run or
# compacted in a prior --compact run for an older delivery) and is safe
# to remove.
remove_round_nums = {n for n, _ in intermediate}
surviving_round_nums = {n for n, _ in rounds} - remove_round_nums

to_remove_trace_dirs = []
if os.path.isdir(traces_dir):
    for name in sorted(os.listdir(traces_dir)):
        m = ROUND_RE.match(name)
        if not m:
            continue
        td = os.path.join(traces_dir, name)
        if not os.path.isdir(td):
            continue
        n = int(m.group(1))
        if n not in surviving_round_nums:
            to_remove_trace_dirs.append(td)

if dry_run:
    print(f"DRY-RUN delivery {current_delivery} (final round-{final_round_num}, "
          f"converged): would compact {len(intermediate)} intermediate round(s)")
    print(f"  WRITE   {os.path.relpath(target_file, prd_root)} "
          f"({len(content)} bytes)")
    for d in to_remove_round_dirs:
        print(f"  REMOVE  {os.path.relpath(d, prd_root)}/")
    for d in to_remove_trace_dirs:
        print(f"  REMOVE  {os.path.relpath(d, prd_root)}/")
    print("Re-run without --dry-run to apply.")
    sys.exit(0)

# Apply
with open(target_file, "w", encoding="utf-8") as f:
    f.write(content)

removed = 0
for d in to_remove_round_dirs:
    try:
        shutil.rmtree(d)
        removed += 1
    except OSError as e:
        sys.stderr.write(f"WARNING: could not remove {d}: {e}\n")

traces_removed = 0
for d in to_remove_trace_dirs:
    try:
        shutil.rmtree(d)
        traces_removed += 1
    except OSError as e:
        sys.stderr.write(f"WARNING: could not remove {d}: {e}\n")

print(
    f"OK compacted delivery {current_delivery}: "
    f"{removed} intermediate round dir(s) removed, "
    f"{traces_removed} trace dir(s) removed; "
    f"summary at {os.path.relpath(target_file, prd_root)}"
)
sys.exit(0)
PYEOF
