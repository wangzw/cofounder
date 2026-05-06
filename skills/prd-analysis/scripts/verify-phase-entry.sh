#!/usr/bin/env bash
# verify-phase-entry.sh — script-enforced phase boundary gate.
#
# Per SKILL.md "Phase Contract", every phase has an entry precondition.
# This script consolidates those preconditions into a single mandatory
# call that orchestration files MUST invoke as their first action. If
# this script exits non-zero, the orchestrator MUST NOT proceed with
# the phase — control returns to whoever invoked it (typically the
# previous phase's loop, or HITL).
#
# Why a unified gate: documenting the contract in prose is not
# enforcement; LLM agents can skip steps. Threading the gate through a
# single script ensures (a) the exit code halts orchestration if the
# LLM tries to proceed past a violation, (b) all entry preconditions
# for a phase live in one auditable place, and (c) the next phase's
# entry catches any cleanup the prior phase's exit gate skipped.
#
# Usage:
#   verify-phase-entry.sh <phase> <prd-dir> [round]
#
# Phases:
#   read              entering review (cross-reviewer dispatch). Verifies:
#                     (a) check-review-readiness PASS — no state:new from
#                         prior rounds (i.e. prior revise wrote completely)
#                     (b) run-checkers PASS — bundle is formally clean
#                         (i.e. prior write phase produced a valid bundle)
#   revise            entering revise (per-issue reviser dispatch). Verifies:
#                     (a) round-N/issues/ exists with at least one state:new
#                         issue (otherwise revise has nothing to do)
#   generate-fresh    entering FromScratch generate. Verifies:
#                     (a) the PRD bundle is absent or has no PRD content
#                         leaves (avoids overwriting an existing PRD)
#   generate-evolve   entering NewVersion generate. Verifies:
#                     (a) the prior delivery's versions/<N-1>.md exists
#                         (otherwise --evolve has no baseline to extend)
#   compact           entering --compact. Verifies:
#                     (a) the current (highest-delivery_id) delivery's
#                         final round has verdict.yml with verdict=converged
#                     (b) at least one intermediate round exists in that
#                         delivery (otherwise compact would be a no-op)
#
# Exit codes:
#   0  entry preconditions all PASS — phase may proceed
#   1  one or more preconditions FAIL — phase MUST NOT proceed
#   2  script-level error / bad input

set -uo pipefail

PHASE="${1:-}"
PRD_ROOT="${2:-}"

if [ -z "$PHASE" ] || [ -z "$PRD_ROOT" ]; then
  echo "ERROR: two arguments required: <phase> <prd-dir>" >&2
  echo "Usage: verify-phase-entry.sh <read|revise|generate-fresh|generate-evolve|compact> <prd-dir> [round]" >&2
  exit 2
fi

if [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: prd-dir not found: $PRD_ROOT" >&2
  exit 2
fi

PRD_ROOT="${PRD_ROOT%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Helper: run a sub-script, capture its summary; on FAIL forward output ───
run_subcheck() {
  local label="$1"; shift
  local out
  out="$("$@" 2>&1)"
  local rc=$?
  if [ "$rc" = 2 ]; then
    echo "ERROR ($label): script-level error" >&2
    echo "$out" >&2
    return 2
  fi
  if [ "$rc" != 0 ]; then
    echo "FAIL ($label):" >&2
    echo "$out" | sed 's/^/  /' >&2
    return 1
  fi
  return 0
}

case "$PHASE" in
  read)
    # Two sub-checks; both must PASS to enter the read (review) phase.
    fail=0
    run_subcheck "no state:new from prior rounds" \
        "$SCRIPT_DIR/check-review-readiness.sh" "$PRD_ROOT" \
        || fail=$?
    if [ "$fail" = 2 ]; then exit 2; fi
    run_subcheck "bundle is formally clean" \
        "$SCRIPT_DIR/run-checkers.sh" "$PRD_ROOT" \
        || fail=$?
    if [ "$fail" = 2 ]; then exit 2; fi
    if [ "$fail" != 0 ]; then
      echo "REFUSE entering read phase: at least one entry precondition failed (see above)"
      exit 1
    fi
    echo "OK read-phase entry verified — readiness PASS + formal PASS"
    exit 0
    ;;

  revise)
    ROUND="${3:-}"
    if [ -z "$ROUND" ] || ! echo "$ROUND" | grep -qE '^[0-9]+$'; then
      echo "ERROR: revise phase requires <round> as 3rd argument (positive integer)" >&2
      exit 2
    fi
    ROUND_DIR="$PRD_ROOT/.review/round-${ROUND}"
    ISSUES_DIR="$ROUND_DIR/issues"
    if [ ! -d "$ROUND_DIR" ]; then
      echo "REFUSE entering revise phase: round-${ROUND} directory does not exist"
      exit 1
    fi
    # Count state:new issues — at least one required
    new_count=0
    if [ -d "$ISSUES_DIR" ]; then
      new_count=$(grep -l "^state: new$" "$ISSUES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ "$new_count" -eq 0 ]; then
      echo "REFUSE entering revise phase: no state:new issues in round-${ROUND} (nothing to do)"
      exit 1
    fi
    echo "OK revise-phase entry verified — ${new_count} state:new issue(s) in round-${ROUND}"
    exit 0
    ;;

  generate-fresh)
    # PRD content leaves should NOT exist — avoid overwriting an existing PRD.
    found=""
    if [ -f "$PRD_ROOT/README.md" ]; then found="README.md"; fi
    if [ -d "$PRD_ROOT/features" ] && [ -n "$(ls -A "$PRD_ROOT/features" 2>/dev/null)" ]; then
      found="${found:+$found, }features/"
    fi
    if [ -d "$PRD_ROOT/journeys" ] && [ -n "$(ls -A "$PRD_ROOT/journeys" 2>/dev/null)" ]; then
      found="${found:+$found, }journeys/"
    fi
    if [ -n "$found" ]; then
      echo "REFUSE entering generate-fresh phase: existing PRD content found ($found)"
      echo "  use --evolve to update an existing PRD instead"
      exit 1
    fi
    echo "OK generate-fresh entry verified — no existing PRD content"
    exit 0
    ;;

  generate-evolve)
    VERSIONS_DIR="$PRD_ROOT/.review/versions"
    if [ ! -d "$VERSIONS_DIR" ]; then
      echo "REFUSE entering generate-evolve phase: no prior delivery (no .review/versions/ directory)"
      exit 1
    fi
    found_version=$(ls "$VERSIONS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$found_version" -eq 0 ]; then
      echo "REFUSE entering generate-evolve phase: .review/versions/ exists but has no version files"
      exit 1
    fi
    echo "OK generate-evolve entry verified — ${found_version} prior delivery summary file(s) present"
    exit 0
    ;;

  compact)
    REVIEW_DIR="$PRD_ROOT/.review"
    if [ ! -d "$REVIEW_DIR" ]; then
      echo "REFUSE entering compact phase: no .review/ directory under $PRD_ROOT"
      exit 1
    fi
    # Identify current delivery's final round + verify converged verdict.
    # Reuses the same parsing logic as compact-delivery.sh.
    python3 - "$PRD_ROOT" <<'PYEOF' || exit $?
import os, re, sys
prd_root = sys.argv[1]
review = os.path.join(prd_root, ".review")
ROUND_RE = re.compile(r"^round-(\d+)$")
LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$")

def fm(path):
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    body = text
    if text.startswith("---"):
        e = text.find("\n---", 3)
        if e >= 0:
            body = text[4:e]
    out = {}
    for line in body.splitlines():
        if line.startswith((" ", "\t")) or not line.strip() or line.startswith("#"):
            continue
        m = LINE.match(line)
        if m:
            v = m.group(2).strip().strip('"')
            out[m.group(1)] = v
    return out

rounds = []
for n in os.listdir(review):
    m = ROUND_RE.match(n)
    if m:
        p = os.path.join(review, n)
        if os.path.isdir(p):
            rounds.append((int(m.group(1)), p))
if not rounds:
    print("REFUSE entering compact phase: no round-N/ directories")
    sys.exit(1)
rounds.sort()
by_d = {}
for n, p in rounds:
    d = None
    for fn in ("verdict.yml", "index.md"):
        v = fm(os.path.join(p, fn)).get("delivery_id", "")
        if v.isdigit():
            d = int(v); break
    by_d.setdefault(d, []).append((n, p))
known = {d: rs for d, rs in by_d.items() if d is not None}
if not known:
    print("REFUSE entering compact phase: no round has a usable delivery_id "
          "in verdict.yml or index.md frontmatter")
    sys.exit(1)
cur = max(known.keys())
delivery = sorted(known[cur])
last_n, last_p = delivery[-1]
v = fm(os.path.join(last_p, "verdict.yml")).get("verdict", "")
if v != "converged":
    print(f"REFUSE entering compact phase: delivery {cur} final round-{last_n} "
          f"has verdict={v!r} (need 'converged')")
    sys.exit(1)
if len(delivery) <= 1:
    print(f"REFUSE entering compact phase: delivery {cur} has only one round "
          f"(round-{last_n}) — nothing to compact")
    sys.exit(1)
print(f"OK compact-phase entry verified — delivery {cur}, "
      f"final round-{last_n} converged, "
      f"{len(delivery)-1} intermediate round(s) eligible")
sys.exit(0)
PYEOF
    ;;

  *)
    echo "ERROR: unknown phase: $PHASE" >&2
    echo "Valid phases: read, revise, generate-fresh, generate-evolve, compact" >&2
    exit 2
    ;;
esac
