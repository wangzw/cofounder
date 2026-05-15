#!/usr/bin/env bash
# run-checkers.sh — autoforge formal-review aggregator.
#
# Walks the per-artifact check-*.sh scripts and invokes each against the
# matching artifact path under <plan-dir>. Concatenates JSON output into
# one document on stdout, matching the prd-analysis run-checkers contract.
#
# Adding a new check-X.sh under scripts/ that follows the 3-state contract
# will automatically participate in the next run, IF its dispatch is added
# to the dispatch table below.
#
# Usage:
#   run-checkers.sh <plan-dir> [--source-root <dir>] [--phase=<phase>] [--gate=delivery-tag]
#
# <plan-dir> is the autoforge plan directory, e.g.
# `docs/raw/plans/2026-04-27-product-abc-x9k1/`.
#
# --source-root <dir> is the project root the discipline scan walks for
# soft-pass / silent-debt patterns. Defaults to the cwd.
#
# --phase=<phase> declares which autoforge step is invoking the checker.
# Each phase enables a different subset of checkers:
#
#   --phase=plan      — Step 1 / Step E4 plan review. Plan-time only:
#                       runs check-plan-readme, check-module-plan,
#                       check-discipline-scan, check-plan-pollution.
#                       SKIPS check-acceptance-report, check-traceability,
#                       and check-e2e-coverage even if reports/acceptance.md
#                       and reports/traceability.json are present (e.g.
#                       leftover from delivery N-1 in --evolve mode — they
#                       are stale until the new acceptance run at E6).
#   --phase=execute   — Step 2 / Step E5 phase execution. Same suppression
#                       set as plan: acceptance artifacts are still stale
#                       (Step 2 runs per-module Reviewer + integration test
#                       loops; acceptance happens at Step 3 / E6).
#   --phase=accept    — Step 3 / Step E6 acceptance fix cycle. Enables the
#                       full default check set: any reports/acceptance.md
#                       and reports/traceability.json present are this
#                       delivery's own and SHOULD be gated.
#   --phase=delivery-tag — Step E6 pre-tag gate. Equivalent to --gate=delivery-tag.
#                       Enables every check + the strict preflight + the
#                       PASS/FAIL banner. error/critical findings block
#                       tag creation.
#
# If --phase is omitted AND --gate=delivery-tag is not set, the script
# auto-detects evolve plan-phase: when <plan-dir>/.evolve-*/impact.md
# exists (the marker `--evolve` Step E1 writes), the script behaves as
# --phase=plan and prints a one-line notice. This protects callers that
# pre-date the --phase flag from accidentally gating against stale N-1
# acceptance reports during E1..E5.
#
# --gate=delivery-tag is an alias for --phase=delivery-tag (kept for
# back-compat). In delivery-tag phase:
#   - reports/acceptance.md MUST exist (not just optionally)
#   - reports/traceability.json MUST exist
#   - the acceptance-tester-subagent sentinel MUST be present
#   - check-e2e-coverage.sh MUST pass (not just be informational)
#   - any error or critical finding fails the gate
#   The autoforge skill (Step E6) requires this gate to pass before
#   `git tag -a autoforge-delivery-N-*`.
#
# Returncode:
#   0  every sub-check passed (or in gate mode: gate passed)
#   1  one or more sub-checks reported issues — JSON document on stdout
#   2  script-level error in one of the sub-checks

set -euo pipefail

usage() {
  echo "Usage: run-checkers.sh <plan-dir> [--source-root <dir>] [--phase=<phase>] [--gate=delivery-tag]" >&2
  echo "  --phase=<plan|execute|accept|delivery-tag>" >&2
}

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  usage
  exit 2
fi
shift

SOURCE_ROOT="$(pwd)"
GATE_MODE=""
PHASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    --gate=delivery-tag)
      GATE_MODE="delivery-tag"
      if [ -n "$PHASE" ] && [ "$PHASE" != "delivery-tag" ]; then
        echo "ERROR: --gate=delivery-tag conflicts with --phase=$PHASE" >&2
        exit 2
      fi
      PHASE="delivery-tag"
      shift
      ;;
    --gate=*) echo "ERROR: unknown gate: $1 (valid: --gate=delivery-tag)" >&2; exit 2 ;;
    --phase=plan|--phase=execute|--phase=accept|--phase=delivery-tag)
      new_phase="${1#--phase=}"
      if [ -n "$PHASE" ] && [ "$PHASE" != "$new_phase" ]; then
        echo "ERROR: --phase=$new_phase conflicts with prior --phase=$PHASE / --gate" >&2
        exit 2
      fi
      PHASE="$new_phase"
      if [ "$PHASE" = "delivery-tag" ]; then GATE_MODE="delivery-tag"; fi
      shift
      ;;
    --phase=*)
      echo "ERROR: unknown phase: $1 (valid: --phase=plan|execute|accept|delivery-tag)" >&2
      exit 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_SCRIPT_DIR="$SCRIPT_DIR"
export AF_GATE_MODE="$GATE_MODE"
export AF_PHASE="$PHASE"

python3 - <<'PYEOF'
import json, os, subprocess, sys, glob

plan_dir = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]
script_dir = os.environ["AF_SCRIPT_DIR"]
gate_mode = os.environ.get("AF_GATE_MODE") or ""
phase = os.environ.get("AF_PHASE") or ""


def run(cmd: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


# Auto-detect plan-phase when the caller didn't specify --phase and we're
# inside an --evolve run that hasn't reached E6 yet.
#
# Signal: each `.evolve-N/impact.md` is paired with a `versions/N.md` that
# E6 sub-step 2 writes immediately before the pre-tag gate. If ANY
# `.evolve-N/impact.md` exists whose matching `versions/N.md` is missing,
# evolution N is in progress and the plan-dir still carries the previous
# delivery's `reports/acceptance.md` + `reports/traceability.json`. Gating
# E1-E5 against those stale artifacts is the "checker mode mismatch"
# this auto-detect is designed to prevent.
#
# Why not just check "any .evolve-*/impact.md exists": Step E1's
# .evolve-N/ directory is committed for traceability and persists across
# subsequent deliveries (see SKILL.md plan-dir layout). A past completed
# evolution leaves the marker but is not in progress. Pairing with
# `versions/N.md` (which E6 always writes) cleanly distinguishes
# in-progress from archived.
#
# Auto-detection only kicks in when no explicit phase was passed AND no
# delivery-tag gate is set. Explicit --phase always wins.
import re as _re
EVOLVE_DIR_RE = _re.compile(r"\.evolve-(\d+)$")
if not phase and not gate_mode:
    in_progress_n = None
    for marker in sorted(glob.glob(os.path.join(plan_dir, ".evolve-*", "impact.md"))):
        evolve_dir = os.path.dirname(marker)
        m = EVOLVE_DIR_RE.search(os.path.basename(evolve_dir))
        if not m:
            continue
        n = m.group(1)
        version_path = os.path.join(plan_dir, "versions", f"{n}.md")
        if not os.path.isfile(version_path):
            in_progress_n = n
            break
    if in_progress_n is not None:
        phase = "plan"
        # Compute the previous delivery from the actual versions/ directory
        # rather than assuming sequential numbering. With sparse deliveries
        # (`.evolve-2` done + `.evolve-10` in progress) "delivery-N-1" is
        # misleading; the stale reports actually came from the most recent
        # completed delivery, whatever its number.
        completed_ns = []
        for vp in glob.glob(os.path.join(plan_dir, "versions", "*.md")):
            base = os.path.basename(vp)
            stem = base[:-3] if base.endswith(".md") else base
            if stem.isdigit():
                completed_ns.append(int(stem))
        prior_n = max(completed_ns) if completed_ns else None
        prior_phrase = (
            f"delivery-{prior_n}" if prior_n is not None
            else "the previous delivery"
        )
        print(
            f"NOTE: auto-detected --phase=plan — delivery-{in_progress_n} "
            f"evolution is in progress (.evolve-{in_progress_n}/impact.md "
            f"exists, versions/{in_progress_n}.md does not). Acceptance / "
            f"traceability / e2e checks suppressed; their reports are still "
            f"from {prior_phrase} until E6 archives them. Pass "
            f"--phase=accept or --phase=delivery-tag at acceptance / "
            f"tag-creation time to re-enable them.",
            file=sys.stderr,
        )

# Plan and execute phases SHARE one suppression rule: stale acceptance
# artifacts from a prior delivery (in --evolve mode) or absent acceptance
# artifacts (in initial run) must not trigger E6-time gates. Accept and
# delivery-tag phases run the full set.
suppress_acceptance_checks = phase in ("plan", "execute")

# Dispatch table: (label, cmd_args). Each cmd is invoked once per artifact
# matching its scope; missing artifacts are silently skipped (they will be
# flagged by the "required artifact present" gate, not here).
dispatches: list[tuple[str, list[str]]] = []

# Plan-dir README
readme = os.path.join(plan_dir, "README.md")
if os.path.isfile(readme):
    dispatches.append((
        "plan-readme",
        [os.path.join(script_dir, "check-plan-readme.sh"), plan_dir],
    ))

# Per-module plans
for path in sorted(glob.glob(os.path.join(plan_dir, "plans", "plan-M-*.md"))):
    dispatches.append((
        f"module-plan({os.path.basename(path)})",
        [os.path.join(script_dir, "check-module-plan.sh"), path],
    ))

# Acceptance report — gated by phase. At plan/execute phase the file may
# exist (--evolve carries forward N-1's acceptance.md until E6 archives
# it), but checking it would gate against stale content.
acc = os.path.join(plan_dir, "reports", "acceptance.md")
if os.path.isfile(acc) and not suppress_acceptance_checks:
    dispatches.append((
        "acceptance-report",
        [os.path.join(script_dir, "check-acceptance-report.sh"), acc],
    ))

# Traceability JSON — same phase-gating logic as acceptance.md.
trc = os.path.join(plan_dir, "reports", "traceability.json")
if os.path.isfile(trc) and not suppress_acceptance_checks:
    dispatches.append((
        "traceability",
        [os.path.join(script_dir, "check-traceability.sh"), trc,
         "--source-root", source_root],
    ))

# Discipline scan (project source root, not plan dir)
dispatches.append((
    "discipline-scan",
    [os.path.join(script_dir, "check-discipline-scan.sh"), source_root],
))

# Plan-dir isolation: detect plan files modified on any non-autoforge worktree
# (the main project repo + any other branch's worktree). This is the gate that
# would have caught the 2026-05-15 castworks delivery-3 incident where a
# Planner sub-agent ran with cwd = project root on `main` and wrote
# plan-M-013-environment.md to the main branch's working tree instead of the
# autoforge feature-branch worktree. The check is cheap (a `git worktree list`
# + one `git status --porcelain` per non-autoforge worktree) and always
# applicable, so it runs on every invocation regardless of gate mode.
dispatches.append((
    "plan-pollution",
    [os.path.join(script_dir, "check-plan-pollution.sh"), plan_dir,
     "--source-root", source_root],
))

# E2E coverage. Runs only when acceptance.md exists OR when delivery-tag
# phase is on, AND we're not in plan/execute (where N-1's acceptance.md
# would otherwise drag a stale e2e record into the gate). Reasoning:
#   - During phase execution, acceptance.md may exist from a prior
#     delivery (--evolve in-place reuse) but its E2E Test Run section
#     references commands and spec files that pre-date the current
#     delivery's design. Suppressing here at plan/execute matches the
#     acceptance/traceability suppression above.
#   - In delivery-tag gate mode, the CR-AF27 preflight above already
#     emits a critical for missing acceptance.md, so the e2e checker
#     piling on with the same signal would be redundant.
#   - When acceptance.md exists at accept phase, the e2e checker is the
#     gate that verifies the report records a real e2e command + has
#     matching spec files. This is the key signal blocking d1 / d2
#     soft-pass.
if (os.path.isfile(acc) or gate_mode == "delivery-tag") and not suppress_acceptance_checks:
    dispatches.append((
        "e2e-coverage",
        [os.path.join(script_dir, "check-e2e-coverage.sh"), plan_dir,
         "--source-root", source_root],
    ))

aggregated: list[dict] = []
script_error_seen = False
SEV_ORDER = {"info": 0, "warning": 1, "error": 2, "critical": 3}
worst = "info"


def synth(scope: str, criterion_id: str, severity: str, file: str,
          description: str, suggested_fix: str) -> dict:
    return {
        "criterion_id": criterion_id,
        "file": file,
        "severity": severity,
        "description": description,
        "suggested_fix": suggested_fix,
        "scope": scope,
    }


# Gate-mode preflight. The skill's Step E6 routes here BEFORE creating
# the `autoforge-delivery-N-<slug>` annotated tag. The d1/d2 retros
# showed the delivery tag was created based on the Orchestrator's
# self-attestation; this preflight makes that bypass mechanically
# detectable.
if gate_mode == "delivery-tag":
    acc_path = os.path.join(plan_dir, "reports", "acceptance.md")
    trc_path = os.path.join(plan_dir, "reports", "traceability.json")
    if not os.path.isfile(acc_path):
        aggregated.append(synth(
            "gate-preflight",
            "CR-AF27",
            "critical",
            os.path.relpath(acc_path, plan_dir),
            "delivery-tag gate: reports/acceptance.md is missing",
            "spawn the Acceptance Tester subagent (autoforge SKILL.md "
            "Step 3 / E6) to produce reports/acceptance.md; the "
            "delivery tag MUST NOT be created without it",
        ))
        worst = "critical"
    if not os.path.isfile(trc_path):
        aggregated.append(synth(
            "gate-preflight",
            "CR-AF28",
            "critical",
            os.path.relpath(trc_path, plan_dir),
            "delivery-tag gate: reports/traceability.json is missing",
            "the Acceptance Tester subagent must emit traceability.json "
            "alongside acceptance.md per acceptance/tester-prompt.md "
            "Step 4; without it, no AC-coverage closure can be checked",
        ))
        worst = "critical"

for label, cmd in dispatches:
    rc, out, err = run(cmd)
    if rc == 2:
        script_error_seen = True
        sys.stderr.write(f"[{label}] script error\n{err}")
        continue
    if rc == 0:
        # PASS — first stdout line is the PASS banner; drop it.
        continue
    if rc == 1:
        # Stdout: one banner line + JSON document. Skip the banner.
        try:
            json_start = out.index("{")
        except ValueError:
            sys.stderr.write(f"[{label}] missing JSON in stdout\n")
            script_error_seen = True
            continue
        try:
            doc = json.loads(out[json_start:])
        except json.JSONDecodeError as e:
            sys.stderr.write(f"[{label}] invalid JSON: {e}\n")
            script_error_seen = True
            continue
        for issue in doc.get("issues", []):
            issue["scope"] = label
            sev = issue.get("severity", "info")
            if SEV_ORDER.get(sev, 0) > SEV_ORDER[worst]:
                worst = sev
            aggregated.append(issue)
    else:
        script_error_seen = True
        sys.stderr.write(f"[{label}] unexpected exit {rc}\n{err}")

if script_error_seen:
    sys.exit(2)

# In gate mode, only error/critical findings actually fail the gate.
# Warnings are visible in the JSON but do not block the delivery tag —
# they're advisory. Information findings never block.
if gate_mode == "delivery-tag":
    blockers = [
        i for i in aggregated
        if SEV_ORDER.get(i.get("severity", "info"), 0) >= SEV_ORDER["error"]
    ]
    if not blockers:
        if not aggregated:
            print("DELIVERY-TAG GATE PASSED — 0 issues found across autoforge checkers")
        else:
            print(
                f"DELIVERY-TAG GATE PASSED — {len(aggregated)} advisory "
                f"warning(s) (no error/critical findings)"
            )
            print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
        sys.exit(0)
    print(
        f"DELIVERY-TAG GATE FAILED — {len(blockers)} blocking finding(s) "
        f"(worst severity: {worst}); refusing to authorize tag creation:"
    )
    print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
    sys.exit(1)

if not aggregated:
    print("PASS 0 issues found across autoforge checkers")
    sys.exit(0)

print(f"FOUND {len(aggregated)} issue(s) across autoforge checkers (worst severity: {worst}):")
print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
