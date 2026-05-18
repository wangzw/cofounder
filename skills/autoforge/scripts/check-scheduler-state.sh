#!/usr/bin/env bash
# check-scheduler-state.sh — CR-AF33 scheduler-state-inconsistent
#
# Cross-validates run-state.json against on-disk truth:
#   - modules marked exec_status=merged must have their branch as an
#     ancestor of the feature branch (or have a matching feat({mid})
#     commit in feature-branch history if the module branch was deleted
#     post-merge)
#   - modules in inflight.modules must have an associated worktree
#
# (A future check for "modules marked running whose module-state-M-*.json
# claims approved/later state — indicating a lost completion notification"
# is planned but requires a stable Module Agent state schema first; see
# follow-ups in the DAG scheduling design spec.)
#
# Usage: check-scheduler-state.sh <plan-dir> [--source-root <dir>]
#
# Exit codes:
#   0  PASS (consistent or no state file)
#   1  finding emitted
#   2  script-level error

set -euo pipefail

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  exit 2
fi
shift
SOURCE_ROOT="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AF_PLAN_DIR="$PLAN_DIR"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_SCRIPT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import json, os, sys, subprocess
plan_dir = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]
script_dir = os.environ["AF_SCRIPT_DIR"]
sys.path.insert(0, os.path.join(script_dir, "lib"))
from run_state import load_state

state_path = os.path.join(plan_dir, "run-state.json")
if not os.path.isfile(state_path):
    print("PASS no run-state.json (checker is a no-op pre-init)")
    sys.exit(0)

state = load_state(state_path)
issues: list[dict] = []


def git(*args: str) -> tuple[int, str]:
    res = subprocess.run(
        ["git", "-C", source_root, *args],
        capture_output=True, text=True
    )
    return res.returncode, (res.stdout or "") + (res.stderr or "")


# Resolve the feature branch by convention: autoforge/<run-id>. If multiple
# match, use the most recent (committerdate). If none, skip ancestry checks.
rc, out = git("for-each-ref", "--format=%(refname:short)",
              "--sort=-committerdate", "refs/heads/autoforge/")
feature_branch = ""
if rc == 0:
    for line in out.strip().splitlines():
        # The feature branch has the run id but no slash after it; module
        # branches are `autoforge/<run>/p<n>/M-...` — more slashes.
        if line.count("/") == 1:
            feature_branch = line; break

for mid, m in state["modules"].items():
    if m["exec_status"] == "merged":
        # Find the module's branch. Convention: contains the module id.
        rc, out = git("for-each-ref", "--format=%(refname:short)",
                      f"refs/heads/**/{mid}-**")
        branches = [b for b in out.strip().splitlines() if b]
        if not branches:
            # The branch may have been deleted post-merge — that's OK if
            # the merge commit is in the feature branch's history.
            if feature_branch:
                rc2, commit_log = git("log", "--format=%H", "--grep",
                             f"feat({mid})", feature_branch)
                if rc2 != 0 or not commit_log.strip():
                    issues.append({
                        "criterion_id": "CR-AF33",
                        "file": os.path.relpath(state_path, plan_dir),
                        "severity": "critical",
                        "description": (
                            f"Module {mid} marked exec_status=merged but no "
                            f"corresponding branch exists and feature branch "
                            f"{feature_branch} has no commit matching "
                            f"feat({mid})."
                        ),
                        "suggested_fix": (
                            f"Investigate: was {mid} actually merged? If not, "
                            f"revert exec_status to 'approved' and re-run "
                            f"merge from its worktree."
                        ),
                    })
            else:
                # No feature branch and no module branch — definitely stale
                issues.append({
                    "criterion_id": "CR-AF33",
                    "file": os.path.relpath(state_path, plan_dir),
                    "severity": "critical",
                    "description": (
                        f"Module {mid} marked exec_status=merged but no "
                        f"corresponding branch exists and no autoforge "
                        f"feature branch could be found to verify ancestry."
                    ),
                    "suggested_fix": (
                        f"Investigate: was {mid} actually merged? If not, "
                        f"revert exec_status to 'approved' and re-run "
                        f"merge from its worktree."
                    ),
                })
            continue
        # Ancestry: at least one matching branch must be an ancestor of
        # the feature branch (or be the feature branch itself).
        if feature_branch:
            ancestor = False
            for b in branches:
                rc2, _ = git("merge-base", "--is-ancestor", b, feature_branch)
                if rc2 == 0:
                    ancestor = True; break
            if not ancestor:
                issues.append({
                    "criterion_id": "CR-AF33",
                    "file": os.path.relpath(state_path, plan_dir),
                    "severity": "critical",
                    "description": (
                        f"Module {mid} marked exec_status=merged but its "
                        f"branch(es) {branches} are NOT ancestors of feature "
                        f"branch {feature_branch}."
                    ),
                    "suggested_fix": (
                        f"Either complete the merge of one of {branches} into "
                        f"{feature_branch} (use ff-merge per Git Strategy) or "
                        f"revert {mid} exec_status to 'approved' if the merge "
                        f"was abandoned."
                    ),
                })

# Inflight modules without worktrees
rc, out = git("worktree", "list", "--porcelain")
worktree_paths: list[str] = []
if rc == 0:
    for line in out.splitlines():
        if line.startswith("worktree "):
            worktree_paths.append(line.removeprefix("worktree "))
for mid in state["inflight"]["modules"]:
    if not any(mid in p for p in worktree_paths):
        issues.append({
            "criterion_id": "CR-AF33",
            "file": os.path.relpath(state_path, plan_dir),
            "severity": "error",
            "description": (
                f"Module {mid} is in inflight.modules but no worktree "
                f"matches it (checked: {worktree_paths})."
            ),
            "suggested_fix": (
                f"Either restart {mid}'s Module Agent (recreate the worktree) "
                f"or remove {mid} from inflight via "
                f"`run-state-update.sh ... inflight-remove modules {mid}`."
            ),
        })

if not issues:
    print(f"PASS scheduler state consistent ({len(state['modules'])} modules)")
    sys.exit(0)

print(
    f"FOUND CR-AF33 ({len(issues)} inconsistency/inconsistencies)",
    file=sys.stderr,
)
print(json.dumps({"issues": issues}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
