#!/usr/bin/env bash
# phase-audit.sh — autoforge phase-boundary worktree-health audit.
#
# Runs at two distinct moments:
#
#   1. Before the Orchestrator merges per-module branches at the end of a
#      phase ("After All Modules in Phase Complete" → merge gate). Any
#      Module Agent that returned APPROVE but left a dirty worktree, or
#      crashed mid-edit (the M-019 failure mode observed in the
#      2026-04-11-castworks d3 run, where the agent did not return a
#      tool_result and left 5 files uncommitted) is caught here instead
#      of leaking into the merged feature branch.
#
#   2. When a fresh Orchestrator session resumes a previously interrupted
#      run (SKILL.md Resume Protocol). Surfacing dirty worktrees +
#      orphan module branches lets the resumed Orchestrator decide:
#      adopt the existing commits, restart the agent, or escalate.
#
# Two criteria — both severity `error` (block merge, do not block
# resume — see SKILL.md Resume Protocol for how the Orchestrator routes
# each finding):
#
#   CR-AF30  worktree-cleanliness — any worktree whose branch starts
#            with `autoforge/` has a non-empty `git status --porcelain`.
#            Emitted once per dirty file. Distinct from CR-AF29
#            (plan-dir-isolation on *non*-autoforge worktrees): CR-AF29
#            asserts "the default-branch checkout is clean", CR-AF30
#            asserts "every autoforge worktree is clean *after* the
#            phase agents claim to be done".
#
#   CR-AF31  stale-module-branch — a per-module branch matching
#            `autoforge/<run>/p<N>/M-<id>-<slug>` exists locally with
#            no worktree, AND is not an ancestor of the run's feature
#            branch (`autoforge/<run>/main` or `autoforge/<run>`).
#            Indicates either (a) the cleanup step ran but the branch
#            survived because the merge silently failed, or (b) the
#            phase was abandoned mid-way and the branch is orphan. The
#            user / Orchestrator must decide whether to merge or delete
#            (the script never deletes branches — that decision is
#            out-of-scope for an audit).
#
# Usage:
#   phase-audit.sh <plan-dir> [--source-root <dir>]
#
# `<plan-dir>` is informational (used only in the scope label of the
# JSON output, matching the contract of the other check-*.sh scripts).
# The audit itself operates on the git repository discovered from
# `--source-root` (any worktree of the run is fine — `git worktree list`
# enumerates all siblings).
#
# Returncode follows the shared 3-state contract via autoforge_lint.emit:
#   0  no findings
#   1  one or more findings — JSON document on stdout
#   2  script-level error

set -uo pipefail

PLAN_DIR_ARG="${1:-}"
if [ -z "$PLAN_DIR_ARG" ]; then
  echo "ERROR: plan-dir argument missing" >&2
  echo "Usage: phase-audit.sh <plan-dir> [--source-root <dir>]" >&2
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR_ARG"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_LIB_DIR="$SCRIPT_DIR/lib"

python3 - <<'PYEOF'
import json, os, re, sys

sys.path.insert(0, os.environ["AF_LIB_DIR"])
from autoforge_lint import (
    Finding,
    branch_short,
    emit,
    fail_with_script_error,
    parse_porcelain_line,
    parse_worktree_list,
    run_cmd,
)

source_root = os.environ["AF_SOURCE_ROOT"]


rc, top, err = run_cmd(["git", "rev-parse", "--show-toplevel"], cwd=source_root)
if rc != 0:
    # No git repo at source-root — nothing to audit. Emit PASS (matches
    # check-plan-pollution.sh behaviour for the same condition).
    emit([], scope_label="(phase audit; no git repo at source-root)")
    sys.exit(0)

src_top = os.path.realpath(top)

# --- Enumerate worktrees ---------------------------------------------------
rc, wt_out, err = run_cmd(["git", "worktree", "list", "--porcelain"], cwd=src_top)
if rc != 0:
    fail_with_script_error(f"git worktree list failed: {err}")
worktrees = parse_worktree_list(wt_out)

findings: list[Finding] = []

# --- CR-AF30: dirty autoforge/* worktrees ---------------------------------
# Track branch-attached worktrees by branch name; track DETACHED worktrees
# by HEAD SHA. The detached-SHA set lets CR-AF31 below recognise a module
# branch whose tip is held by a detached worktree (Module Agent that
# `git checkout <sha>`'d inside its worktree — the worktree is still live,
# the branch is NOT orphan). Only detached HEADs go into this set —
# branch-attached worktrees that incidentally share a SHA with another
# branch must not mask that other branch's orphan status.
worktree_branches: set[str] = set()
detached_worktree_heads: set[str] = set()
for wt in worktrees:
    if wt.get("bare"):
        continue
    if wt.get("detached"):
        head = wt.get("head", "")
        if head:
            detached_worktree_heads.add(head)
        continue
    br = branch_short(wt)
    if br:
        worktree_branches.add(br)
    if not br.startswith("autoforge/"):
        continue
    wt_path = wt.get("path")
    if not wt_path or not os.path.isdir(wt_path):
        continue

    rc, st_out, st_err = run_cmd(["git", "status", "--porcelain"], cwd=wt_path)
    if rc != 0:
        findings.append(Finding(
            criterion_id="CR-AF30",
            file=os.path.relpath(wt_path, src_top) or "(source-root)",
            severity="warning",
            description=(
                f"could not query git status in autoforge worktree "
                f"'{wt_path}' (branch '{br}'): {st_err.strip()}"
            ),
            suggested_fix=(
                "verify the worktree is healthy via "
                f"`git -C {wt_path} status`; informational only"
            ),
        ))
        continue
    if not st_out.strip():
        continue

    # One finding per dirty file — same granularity as CR-AF29.
    for ln in st_out.splitlines():
        parsed = parse_porcelain_line(ln)
        if parsed is None:
            continue
        status_code, dirty_file = parsed

        wt_display = os.path.relpath(wt_path, src_top) or wt_path
        findings.append(Finding(
            criterion_id="CR-AF30",
            file=f"{wt_display}/{dirty_file}",
            severity="error",
            description=(
                f"autoforge worktree '{wt_path}' (branch '{br}') has "
                f"uncommitted change '{status_code.strip()}' to "
                f"'{dirty_file}'. A sub-agent (Module Agent / Integration "
                f"Tester / Acceptance Tester / Developer) either crashed "
                f"mid-edit without committing, or returned a verdict "
                f"without honouring the Pre-Return Verification block "
                f"(SKILL.md). Merging the feature branch in this state "
                f"would lose the change."
            ),
            suggested_fix=(
                f"In worktree '{wt_path}':\n"
                f"  1. Inspect: `git status` + `git diff -- '{dirty_file}'`\n"
                f"  2. If the change belongs to the just-completed work: "
                f"commit it with the appropriate conventional message and "
                f"re-run this audit.\n"
                f"  3. If the change is in-flight from a crashed agent: "
                f"`git stash push -u -m 'rescued from <agent> {br}'` to "
                f"preserve it, then either resume that agent or escalate.\n"
                f"  4. Never `git checkout -- '{dirty_file}'` blindly — the "
                f"change may be the only record of work the agent did "
                f"before crashing."
            ),
        ))

# --- CR-AF31: orphan per-module branches ----------------------------------
# Single for-each-ref call returns name + tip SHA (full + short) + commit
# subject for every local autoforge branch. We use:
#   - tip SHA to exclude branches whose tip is held by a detached worktree
#     (Module Agent that `git checkout <sha>`'d inside its worktree —
#     the worktree is live, the branch is NOT orphan)
#   - short SHA + subject to build the finding's `detail` text without
#     spawning a per-branch `git log -1`.
# Scope is constrained to refs/heads/autoforge/ — non-autoforge branches
# can never match module_branch_re, so excluding them in the query keeps
# the parse loop tight on repos with many user/feature branches.
rc, br_out, br_err = run_cmd(
    ["git", "for-each-ref",
     "--format=%(refname:short)\t%(objectname)\t%(objectname:short)\t%(subject)",
     "refs/heads/autoforge/"],
    cwd=src_top,
)
if rc != 0:
    fail_with_script_error(f"git for-each-ref failed: {br_err}")

module_branch_re = re.compile(r"^(autoforge/.+)/p\d+/M-[A-Za-z0-9-]+$")

# Parse once; index branch name -> (tip_sha, short_sha, subject).
branch_info: dict[str, tuple[str, str, str]] = {}
for raw in br_out.splitlines():
    parts = raw.split("\t", 3)
    if len(parts) != 4:
        continue
    name, tip, short, subject = parts
    branch_info[name] = (tip, short, subject)

# Candidate module branches grouped by run_prefix so each prefix's
# feature-branch lookup and merged-set query runs exactly once.
candidates_by_prefix: dict[str, list[str]] = {}
for br, (tip, _, _) in branch_info.items():
    m = module_branch_re.match(br)
    if not m:
        continue
    if br in worktree_branches:
        continue  # branch is checked out — CR-AF30 covers dirtiness
    if tip in detached_worktree_heads:
        continue  # tip is held by a detached worktree — branch is in use
    candidates_by_prefix.setdefault(m.group(1), []).append(br)

# Per-prefix cache: (feature_branch_or_None, merged_branch_set).
prefix_cache: dict[str, tuple[str | None, set[str]]] = {}
for run_prefix in candidates_by_prefix:
    feature_branch: str | None = None
    for candidate in (f"{run_prefix}/main", run_prefix):
        rc, _, _ = run_cmd(
            ["git", "rev-parse", "--verify", "--quiet", candidate],
            cwd=src_top,
        )
        if rc == 0:
            feature_branch = candidate
            break
    merged: set[str] = set()
    if feature_branch:
        # One subprocess returns every branch already merged into the
        # feature branch — replaces N `merge-base --is-ancestor` forks.
        rc, mg_out, mg_err = run_cmd(
            ["git", "for-each-ref",
             f"--merged={feature_branch}",
             "--format=%(refname:short)",
             "refs/heads/autoforge/"],
            cwd=src_top,
        )
        if rc == 0:
            merged = {ln.strip() for ln in mg_out.splitlines() if ln.strip()}
        else:
            # Non-zero usually means the feature-branch ref points to a
            # GC'd object (`git gc --prune=now` corner case). Without a
            # log, every candidate becomes a false-positive CR-AF31.
            print(
                f"WARN: for-each-ref --merged={feature_branch} failed: "
                f"{mg_err.strip()}", file=sys.stderr,
            )
    prefix_cache[run_prefix] = (feature_branch, merged)

for run_prefix, branches in candidates_by_prefix.items():
    feature_branch, merged = prefix_cache[run_prefix]
    for br in branches:
        if br in merged:
            continue  # branch is merged — orphan but harmless; skip

        _, short, subject = branch_info[br]
        detail = (
            f"branch HEAD {short} {subject}".rstrip()
            if short
            else "branch HEAD unavailable"
        )
        if feature_branch:
            feature_note = (
                f"not an ancestor of feature branch '{feature_branch}'"
            )
        else:
            feature_note = (
                f"no feature branch found at '{run_prefix}/main' or "
                f"'{run_prefix}'"
            )

        findings.append(Finding(
            criterion_id="CR-AF31",
            file=br,
            severity="error",
            description=(
                f"stale module branch '{br}' has no worktree and "
                f"{feature_note}; {detail}. Either the cleanup step after "
                f"a previous phase merge silently failed, or the phase was "
                f"abandoned before the module's commits could be merged. "
                f"Leaving it in place causes the next Resume Protocol pass "
                f"to keep flagging it and pollutes the branch namespace."
            ),
            suggested_fix=(
                f"Decide via inspection:\n"
                f"  1. `git log {br} --not "
                f"{feature_branch or run_prefix + '/main'} --oneline`  — "
                f"see what work is on this branch that is not yet merged.\n"
                f"  2. If the work should be kept: re-create a worktree "
                f"(`git worktree add <wt-path> {br}`) and resume the Module "
                f"Agent, then merge through the normal phase flow.\n"
                f"  3. If the work is obsolete (e.g. superseded by a later "
                f"replan): `git branch -d {br}` (plain `-d`; git refuses "
                f"if unmerged, surfacing any work loss before it happens).\n"
                f"  4. The audit script never deletes branches — that is "
                f"a human/Orchestrator decision."
            ),
        ))

emit(findings, scope_label="(phase audit)")
PYEOF
