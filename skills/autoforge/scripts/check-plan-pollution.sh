#!/usr/bin/env bash
# check-plan-pollution.sh — detect plan-dir pollution in non-autoforge worktrees.
#
# Per guide §1.1 + §9: emits one issue per finding in JSON; 3-state returncode;
# idempotent. Implements:
#
#   CR-AF29  plan-dir-isolation — the autoforge feature-branch worktree is the
#            ONLY worktree allowed to carry uncommitted modifications under the
#            plan directory `<plan-dir>`. Any *other* worktree of the same
#            repository (notably the main project working tree on `main` /
#            `master` / `develop`) MUST have a clean git-status for the
#            plan-dir path. Otherwise a Planner / Bootstrap / Integration /
#            Acceptance sub-agent was dispatched with cwd outside the primary
#            worktree and silently wrote plan / report files to the project's
#            default branch (the failure mode that motivated SKILL.md Step 0
#            sub-step 7a and the per-sub-agent `cd {worktree_path}` Setup
#            guards). Detecting it here lets the Orchestrator abort *before*
#            committing the plan batch.
#
# Walks every worktree returned by `git worktree list --porcelain` from the
# source-root's repository:
#   - Skip the worktree whose branch starts with `autoforge/` (the
#     legitimate work location).
#   - For every other worktree, run `git status --porcelain -- <plan-dir-rel>`
#     and report any non-empty result.
#
# Usage:
#   check-plan-pollution.sh <plan-dir> [--source-root <dir>]
#
# `<plan-dir>` is the autoforge plan directory (absolute or relative to cwd),
# e.g. `docs/raw/plans/2026-04-27-product-abc-x9k1/`.
#
# `--source-root <dir>` is the worktree to start probing from (any worktree of
# the autoforge repo is fine; the script discovers all sibling worktrees via
# `git worktree list`). Defaults to the cwd.

set -uo pipefail

PLAN_DIR_ARG="${1:-}"
if [ -z "$PLAN_DIR_ARG" ]; then
  echo "ERROR: plan-dir argument missing" >&2
  echo "Usage: check-plan-pollution.sh <plan-dir> [--source-root <dir>]" >&2
  exit 2
fi
shift

SOURCE_ROOT="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d "$SOURCE_ROOT" ]; then
  echo "ERROR: --source-root not a directory: $SOURCE_ROOT" >&2
  exit 2
fi
SOURCE_ROOT="$(cd "$SOURCE_ROOT" && pwd)"

if [ ! -d "$PLAN_DIR_ARG" ] && [ ! -d "$SOURCE_ROOT/$PLAN_DIR_ARG" ]; then
  echo "ERROR: plan-dir not found: $PLAN_DIR_ARG" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR_ARG"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_LIB_DIR="$SCRIPT_DIR/lib"

python3 - <<'PYEOF'
import json, os, subprocess, sys

sys.path.insert(0, os.environ["AF_LIB_DIR"])
from autoforge_lint import Finding, emit, fail_with_script_error

plan_dir_arg = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]

# Anchor plan_dir to an absolute path. Try as-is, then resolve under source_root.
if os.path.isabs(plan_dir_arg) and os.path.isdir(plan_dir_arg):
    plan_dir_abs = plan_dir_arg
elif os.path.isdir(plan_dir_arg):
    plan_dir_abs = os.path.abspath(plan_dir_arg)
else:
    plan_dir_abs = os.path.abspath(os.path.join(source_root, plan_dir_arg))
    if not os.path.isdir(plan_dir_abs):
        fail_with_script_error(f"plan-dir resolves to a non-directory: {plan_dir_abs}")

# Find the source-root's git toplevel — used to compute plan-dir relative
# to each worktree (worktrees share the same tracked-path layout).
def run(cmd: list[str], cwd: str | None = None) -> tuple[int, str, str]:
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return p.returncode, p.stdout.rstrip("\n"), p.stderr.rstrip("\n")

rc, top, err = run(["git", "rev-parse", "--show-toplevel"], cwd=source_root)
if rc != 0:
    # source-root is not a git working tree (commonly: test fixtures that
    # mock a plan-dir without initialising a repo). The pollution check has
    # nothing to compare against here — emit PASS and let other checkers
    # decide whether the absence of git is itself a problem. `emit` exits;
    # the explicit sys.exit(0) below is belt-and-braces in case emit changes.
    emit([], scope_label="(plan-dir pollution; no git repo at source-root)")
    sys.exit(0)

src_top = os.path.realpath(top)
plan_dir_real = os.path.realpath(plan_dir_abs)

# Compute plan-dir relative to the source-root toplevel. If plan_dir is not
# under src_top, fall back to the basename — most worktrees mirror the tracked
# tree, so the relative path is the same across worktrees.
try:
    plan_dir_rel = os.path.relpath(plan_dir_real, src_top)
    if plan_dir_rel.startswith(".."):
        # plan_dir is outside the source-root worktree; use the path the user
        # passed (relative to source_root) instead.
        plan_dir_rel = plan_dir_arg.rstrip("/")
except ValueError:
    plan_dir_rel = plan_dir_arg.rstrip("/")
plan_dir_rel = plan_dir_rel.rstrip("/")

# Enumerate every worktree of this repository.
rc, wt_out, err = run(["git", "worktree", "list", "--porcelain"], cwd=src_top)
if rc != 0:
    fail_with_script_error(f"git worktree list failed: {err}")

worktrees: list[dict] = []
current: dict = {}
for line in wt_out.splitlines():
    if not line.strip():
        if current:
            worktrees.append(current)
            current = {}
        continue
    parts = line.split(" ", 1)
    key = parts[0]
    val = parts[1] if len(parts) == 2 else ""
    if key == "worktree":
        current["path"] = val
    elif key == "HEAD":
        current["head"] = val
    elif key == "branch":
        current["branch"] = val  # e.g. refs/heads/main
    elif key == "detached":
        current["detached"] = True
    elif key == "bare":
        current["bare"] = True
if current:
    worktrees.append(current)

findings: list[Finding] = []

for wt in worktrees:
    if wt.get("bare"):
        continue
    wt_path = wt.get("path")
    if not wt_path or not os.path.isdir(wt_path):
        continue
    branch_ref = wt.get("branch", "")
    branch_name = (
        branch_ref[len("refs/heads/"):]
        if branch_ref.startswith("refs/heads/")
        else branch_ref
    )
    # An autoforge feature-branch worktree is the legitimate location for
    # plan modifications; skip it. Detached heads are also skipped (rare,
    # but cannot map to a default branch by name).
    if branch_name.startswith("autoforge/") or wt.get("detached"):
        continue

    # Probe the plan-dir under this worktree.
    target = os.path.join(wt_path, plan_dir_rel)
    # `git status --porcelain -- <path>` works even when the path doesn't
    # currently exist (returns empty). No need to pre-check existence.
    rc, st_out, st_err = run(
        ["git", "status", "--porcelain", "--", plan_dir_rel],
        cwd=wt_path,
    )
    if rc != 0:
        # Not all worktrees are usable git checkouts; surface as an info-level
        # warning rather than failing the gate.
        findings.append(Finding(
            criterion_id="CR-AF29",
            file=os.path.relpath(wt_path, src_top) or "(source-root)",
            severity="warning",
            description=(
                f"could not query git status in worktree '{wt_path}' "
                f"(branch '{branch_name or '<none>'}'): {st_err.strip()}"
            ),
            suggested_fix=(
                "verify the worktree is healthy via `git -C <wt-path> status`; "
                "this is informational only"
            ),
        ))
        continue
    if not st_out.strip():
        continue

    # Non-empty status under the plan-dir on a non-autoforge worktree =
    # pollution. Emit one critical finding per dirty file.
    lines = [ln for ln in st_out.splitlines() if ln.strip()]
    for ln in lines:
        # Porcelain format: "XY path" (X = staged status, Y = unstaged).
        # Path may be quoted; split on the first whitespace after columns 2.
        if len(ln) < 4:
            continue
        status_code = ln[:2]
        rest = ln[3:]
        # Rename / copy entries have form "R  old -> new" — keep the right side.
        if " -> " in rest:
            rest = rest.split(" -> ", 1)[1]
        # Strip surrounding double-quotes that git uses for special chars.
        if rest.startswith('"') and rest.endswith('"'):
            rest = rest[1:-1]
        polluted_file = rest.strip()

        wt_display = os.path.relpath(wt_path, src_top) or wt_path
        findings.append(Finding(
            criterion_id="CR-AF29",
            file=f"{wt_display}/{polluted_file}",
            severity="critical",
            description=(
                f"plan-dir pollution: worktree '{wt_path}' (branch "
                f"'{branch_name or '<detached>'}') carries uncommitted "
                f"change '{status_code.strip()}' to '{polluted_file}', which "
                f"lives under the autoforge plan directory '{plan_dir_rel}'. "
                f"A Planner / Bootstrap / Integration / Acceptance sub-agent "
                f"was dispatched with cwd outside the autoforge feature-branch "
                f"worktree and wrote plan / report files to the project's "
                f"default branch working tree — the same failure mode that "
                f"motivated SKILL.md Step 0 sub-step 7a + the sub-agent "
                f"Setup `cd {{worktree_path}}` guards."
            ),
            suggested_fix=(
                f"Move the polluted file into the autoforge feature-branch "
                f"worktree, then revert it here:\n"
                f"  1. cp '{wt_path}/{polluted_file}' "
                f"'{{worktree_root}}/main/{polluted_file}'\n"
                f"  2. cd '{wt_path}' && "
                f"git restore -- '{polluted_file}'\n"
                f"  3. cd '{{worktree_root}}/main' && git status   # confirm "
                f"the modification is now on the feature branch\n"
                f"After the cleanup, verify the Orchestrator's cwd via `pwd` "
                f"(MUST equal `{{worktree_root}}/main`) before re-dispatching."
            ),
        ))

emit(findings, scope_label="(plan-dir pollution)")
PYEOF
