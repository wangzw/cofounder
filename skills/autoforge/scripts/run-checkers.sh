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
#   run-checkers.sh <plan-dir> [--source-root <dir>] [--gate=delivery-tag]
#
# <plan-dir> is the autoforge plan directory, e.g.
# `docs/raw/plans/2026-04-27-product-abc-x9k1/`.
#
# --source-root <dir> is the project root the discipline scan walks for
# soft-pass / silent-debt patterns. Defaults to the cwd.
#
# --gate=delivery-tag enables the strict pre-tag gate. In gate mode:
#   - reports/acceptance.md MUST exist (not just optionally)
#   - reports/traceability.json MUST exist
#   - the acceptance-tester-subagent sentinel MUST be present
#   - check-e2e-coverage.sh MUST pass (not just be informational)
#   - any error or critical finding fails the gate
#   The autoforge skill (Step E6) requires this gate to pass before
#   `git tag -a autoforge-delivery-N-*`. Without --gate, the same checks
#   still run but are advisory.
#
# Returncode:
#   0  every sub-check passed (or in gate mode: gate passed)
#   1  one or more sub-checks reported issues — JSON document on stdout
#   2  script-level error in one of the sub-checks

set -euo pipefail

usage() {
  echo "Usage: run-checkers.sh <plan-dir> [--source-root <dir>] [--gate=delivery-tag]" >&2
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
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    --gate=delivery-tag) GATE_MODE="delivery-tag"; shift ;;
    --gate=*) echo "ERROR: unknown gate: $1 (valid: --gate=delivery-tag)" >&2; exit 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_SCRIPT_DIR="$SCRIPT_DIR"
export AF_GATE_MODE="$GATE_MODE"

python3 - <<'PYEOF'
import json, os, subprocess, sys, glob

plan_dir = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]
script_dir = os.environ["AF_SCRIPT_DIR"]
gate_mode = os.environ.get("AF_GATE_MODE") or ""


def run(cmd: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


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

# Acceptance report
acc = os.path.join(plan_dir, "reports", "acceptance.md")
if os.path.isfile(acc):
    dispatches.append((
        "acceptance-report",
        [os.path.join(script_dir, "check-acceptance-report.sh"), acc],
    ))

# Traceability JSON
trc = os.path.join(plan_dir, "reports", "traceability.json")
if os.path.isfile(trc):
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

# E2E coverage. Runs only when acceptance.md exists OR when gate mode
# is on. Reasoning:
#   - During phase execution, acceptance.md does not exist yet; emitting
#     a CR-AF23 critical here would be noise on every module-level
#     discipline-scan invocation.
#   - In gate mode, the CR-AF27 preflight above already emits a critical
#     for missing acceptance.md, so the e2e checker piling on with the
#     same signal would be redundant.
#   - When acceptance.md exists, the e2e checker is the gate that
#     verifies the report records a real e2e command + has matching
#     spec files. This is the key signal blocking d1 / d2 soft-pass.
if os.path.isfile(acc) or gate_mode == "delivery-tag":
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
