#!/usr/bin/env bash
# compute-review-scope.sh — decide whether the next reviewer dispatch
# applies all LLM criteria to all leaves (mode: full) or only changed
# leaves (mode: incremental), and emit a machine-readable scope file
# for the reviewer sub-agent to consume.
#
# Usage:
#   scripts/compute-review-scope.sh <prd-dir> <round> [--full]
#
# Output:
#   <prd-dir>/.review/round-<N>/review-scope.yml
#
# Decision tree:
#   - --full flag passed                              → mode: full,
#                                                       reason: --full-flag
#   - No prior manifest in current delivery exists    → mode: full,
#                                                       reason: first-round-of-delivery
#   - Prior manifest unreadable / malformed           → mode: full,
#                                                       reason: missing-prior-manifest
#   - Otherwise diff (current vs prior) and emit
#     mode: incremental, reason: diff
#     changed_leaves = added ∪ modified ∪ deleted
#
# The "current delivery" is identified via the delivery_id key in the
# current round's manifest, with state.yml as a fallback. A prior
# round's manifest counts as in-current-delivery if its delivery_id
# matches; rounds with a different delivery_id are skipped (i.e. we do
# not diff across delivery boundaries).
#
# Compaction interaction: if intermediate round-<N>/ dirs were deleted
# by compact-delivery.sh, the script walks back through surviving
# round dirs to find the most recent surviving manifest.
#
# Exit codes (guide §9.1):
#   0  scope file written (single PASS line on stdout)
#   2  script error (current manifest missing, IO error, etc.)

set -euo pipefail

FULL_FLAG=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --full) FULL_FLAG=1 ;;
    --help|-h)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *) ARGS+=("$arg") ;;
  esac
done

if [[ ${#ARGS[@]} -ne 2 ]]; then
  echo "Usage: $0 <prd-dir> <round> [--full]" >&2
  exit 2
fi

PRD_DIR="${ARGS[0]}"
ROUND="${ARGS[1]}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$PRD_DIR" ]]; then
  echo "ERROR: prd-dir does not exist: $PRD_DIR" >&2
  exit 2
fi

if ! [[ "$ROUND" =~ ^[0-9]+$ ]]; then
  echo "ERROR: round must be a non-negative integer (got $ROUND)" >&2
  exit 2
fi

export PRD_DIR ROUND SCRIPT_DIR FULL_FLAG

python3 - <<'PYEOF'
import os
import re
import sys
from datetime import datetime, timezone

PRD_DIR = os.environ["PRD_DIR"]
ROUND = int(os.environ["ROUND"])
SCRIPT_DIR = os.environ["SCRIPT_DIR"]
FULL_FLAG = os.environ["FULL_FLAG"] == "1"

sys.path.insert(0, os.path.join(SCRIPT_DIR, "lib"))
from prd_lint import ROUND_RE, fail_with_script_error  # type: ignore

ROUND_DIR = os.path.join(PRD_DIR, ".review", f"round-{ROUND}")
SCOPE_PATH = os.path.join(ROUND_DIR, "review-scope.yml")
CURRENT_MANIFEST = os.path.join(ROUND_DIR, "leaves-manifest.yml")


def parse_manifest(path: str):
    """Return (delivery_id_str_or_None, dict[path -> sha256]) or
    (None, None) on parse failure."""
    if not os.path.isfile(path):
        return None, None
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None, None
    leaves: dict[str, str] = {}
    delivery_id: str | None = None
    in_leaves = False
    pending_path: str | None = None
    for raw in text.splitlines():
        if raw.startswith("delivery_id:"):
            delivery_id = raw.split(":", 1)[1].strip()
            continue
        if raw.startswith("leaves:"):
            in_leaves = True
            continue
        if not in_leaves:
            continue
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line == "[]":
            continue
        if line.startswith("- path:"):
            pending_path = line.split(":", 1)[1].strip()
            continue
        if line.startswith("path:"):
            pending_path = line.split(":", 1)[1].strip()
            continue
        if line.startswith("sha256:"):
            digest = line.split(":", 1)[1].strip()
            if pending_path is not None and digest:
                leaves[pending_path] = digest
                pending_path = None
            continue
    return delivery_id, leaves


if not os.path.isfile(CURRENT_MANIFEST):
    fail_with_script_error(
        f"current round manifest missing: {CURRENT_MANIFEST} "
        f"(run snapshot-leaves.sh {PRD_DIR} {ROUND} first)"
    )

current_delivery_id, current_leaves = parse_manifest(CURRENT_MANIFEST)
if current_leaves is None:
    fail_with_script_error(f"cannot parse current manifest: {CURRENT_MANIFEST}")


def find_prior_manifest():
    """Walk earlier round-<N>/ dirs in current delivery; return
    (round_number, manifest_path) for the most recent surviving
    manifest with a matching delivery_id, or (None, None)."""
    review_dir = os.path.join(PRD_DIR, ".review")
    if not os.path.isdir(review_dir):
        return None, None
    candidates: list[int] = []
    for entry in os.listdir(review_dir):
        m = ROUND_RE.match(entry)
        if not m:
            continue
        n = int(m.group(1))
        if n >= ROUND:
            continue
        candidates.append(n)
    candidates.sort(reverse=True)
    for n in candidates:
        manifest_path = os.path.join(review_dir, f"round-{n}", "leaves-manifest.yml")
        if not os.path.isfile(manifest_path):
            continue
        prior_delivery_id, _ = parse_manifest(manifest_path)
        # Only treat as in-delivery baseline if delivery_id matches OR
        # one side is missing (best-effort tolerance for older rounds
        # written before this script existed).
        if (
            current_delivery_id is None
            or prior_delivery_id is None
            or prior_delivery_id == current_delivery_id
        ):
            return n, manifest_path
    return None, None


prior_round, prior_manifest_path = find_prior_manifest()

mode = "incremental"
reason = "diff"
prior_round_field: int | None = prior_round
changed: list[str] = []
unchanged: list[str] = []

if FULL_FLAG:
    mode = "full"
    reason = "--full-flag"
elif prior_round is None:
    mode = "full"
    reason = "first-round-of-delivery"
else:
    _, prior_leaves = parse_manifest(prior_manifest_path)
    if prior_leaves is None:
        mode = "full"
        reason = "missing-prior-manifest"
    else:
        all_paths = set(current_leaves) | set(prior_leaves)
        for p in sorted(all_paths):
            if (
                p not in prior_leaves
                or p not in current_leaves
                or current_leaves[p] != prior_leaves[p]
            ):
                changed.append(p)
            else:
                unchanged.append(p)

if mode == "full":
    changed = sorted(current_leaves.keys())
    unchanged = []

generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

lines: list[str] = []
lines.append("# Generated by compute-review-scope.sh — do not edit by hand.")
lines.append(f"round: {ROUND}")
if current_delivery_id is not None:
    lines.append(f"delivery_id: {current_delivery_id}")
lines.append(f"generated_at: {generated_at}")
lines.append(f"mode: {mode}")
lines.append(f"reason: {reason}")
if prior_round_field is not None and mode != "full":
    lines.append(f"prior_round: {prior_round_field}")
elif prior_round_field is not None:
    # In full mode we still record where the manifest came from for audit.
    lines.append(f"prior_round: {prior_round_field}")
lines.append("full_scan_criteria_apply_to: ALL_LEAVES")
lines.append("per_file_criteria_apply_to: changed_leaves")
lines.append("changed_leaves:")
if not changed:
    lines.append("  []")
else:
    for p in changed:
        lines.append(f"  - {p}")
lines.append("unchanged_leaves:")
if not unchanged:
    lines.append("  []")
else:
    for p in unchanged:
        lines.append(f"  - {p}")

# category_clusters: derived from common/review-criteria.md (LLM-type CRs only).
# One cluster per category with CR-IDs and the in-scope leaves. Used by
# review/index.md Step 2 to fan out one cross-reviewer per category.
criteria_path = os.path.join(SCRIPT_DIR, "..", "common", "review-criteria.md")
cat_to_crs: dict[str, list[str]] = {}
if os.path.isfile(criteria_path):
    crit_text = open(criteria_path, encoding="utf-8").read()
    for m in re.finditer(r"^- id:\s*(CR-[A-Za-z0-9-]+)$", crit_text, re.M):
        crid = m.group(1)
        rest = crit_text[m.end():m.end()+2000]
        body_lines: list[str] = []
        for line in rest.split("\n"):
            if line.startswith("  ") or (line == "" and not body_lines):
                body_lines.append(line)
            else:
                break
        body = "\n".join(body_lines)
        if "checker_type: llm" not in body:
            continue
        cat_m = re.search(r"^\s+category:\s*([a-z0-9-]+)\s*$", body, re.M)
        if not cat_m:
            continue
        cat_to_crs.setdefault(cat_m.group(1), []).append(crid)

# Leaves in scope this round: changed + unchanged for full_scan criteria;
# per-cluster fan-out treats this as the universe of leaves the reviewer
# may inspect. (Per-criterion incremental_skip handling lives in the
# reviewer prompt, not here.)
all_leaves = sorted(set(changed) | set(unchanged))

lines.append("category_clusters:")
if not cat_to_crs:
    lines.append("  []")
else:
    for cat in sorted(cat_to_crs.keys()):
        crs = sorted(cat_to_crs[cat])
        lines.append(f"  - category: {cat}")
        lines.append(f"    criteria: [{', '.join(crs)}]")
        if not all_leaves:
            lines.append("    leaves: []")
        else:
            lines.append("    leaves:")
            for p in all_leaves:
                lines.append(f"      - {p}")

try:
    with open(SCOPE_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
except OSError as exc:
    fail_with_script_error(f"cannot write scope {SCOPE_PATH}: {exc}")

n_changed = len(changed)
n_unchanged = len(unchanged)
print(
    f"PASS scope mode={mode} reason={reason} "
    f"changed={n_changed} unchanged={n_unchanged} "
    f"(round-{ROUND})"
)
PYEOF
