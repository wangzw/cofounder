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
# Usage: run-checkers.sh <plan-dir> [--source-root <dir>]
#
# <plan-dir> is the autoforge plan directory, e.g.
# `docs/raw/plans/2026-04-27-product-abc-x9k1/`.
#
# --source-root <dir> is the project root the discipline scan walks for
# soft-pass / silent-debt patterns. Defaults to the cwd.
#
# Returncode:
#   0  every sub-check passed
#   1  one or more sub-checks reported issues — JSON document on stdout
#   2  script-level error in one of the sub-checks

set -euo pipefail

usage() {
  echo "Usage: run-checkers.sh <plan-dir> [--source-root <dir>]" >&2
}

PLAN_DIR="${1:-}"
if [ -z "$PLAN_DIR" ] || [ ! -d "$PLAN_DIR" ]; then
  echo "ERROR: plan-dir not found: ${PLAN_DIR:-<empty>}" >&2
  usage
  exit 2
fi
shift

SOURCE_ROOT="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --source-root) SOURCE_ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AF_PLAN_DIR="$PLAN_DIR"
export AF_SOURCE_ROOT="$SOURCE_ROOT"
export AF_SCRIPT_DIR="$SCRIPT_DIR"

python3 - <<'PYEOF'
import json, os, subprocess, sys, glob

plan_dir = os.environ["AF_PLAN_DIR"]
source_root = os.environ["AF_SOURCE_ROOT"]
script_dir = os.environ["AF_SCRIPT_DIR"]


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
        [os.path.join(script_dir, "check-traceability.sh"), trc],
    ))

# Discipline scan (project source root, not plan dir)
dispatches.append((
    "discipline-scan",
    [os.path.join(script_dir, "check-discipline-scan.sh"), source_root],
))

aggregated: list[dict] = []
script_error_seen = False
SEV_ORDER = {"info": 0, "warning": 1, "error": 2, "critical": 3}
worst = "info"

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

if not aggregated:
    print("PASS 0 issues found across autoforge checkers")
    sys.exit(0)

print(f"FOUND {len(aggregated)} issue(s) across autoforge checkers (worst severity: {worst}):")
print(json.dumps({"issues": aggregated}, indent=2, ensure_ascii=False))
sys.exit(1)
PYEOF
