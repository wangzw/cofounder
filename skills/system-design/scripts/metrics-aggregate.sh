#!/usr/bin/env bash
# metrics-aggregate.sh — reference implementation of the --diagnose subcommand
# defined in `生成式 Skill 设计指南.md` §3.6–3.9.
#
# Responsibility: JOIN harness JSONL usage events with orchestrator dispatch-log
# records and emit `.review/metrics/round-<N>.metrics.yml` /
# `delivery-<N>.metrics.yml` / `since-<iso>.metrics.yml`.
# (README.md trend rendering is summarizer's job — not this script.)
#
# This is a pure script — no LLM, no subagent dispatch, no external dependencies
# beyond bash + python3 (stdlib only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_CORE="$SCRIPT_DIR/lib/aggregate.py"

usage() {
  cat <<'EOF'
Usage:
  metrics-aggregate.sh --diagnose [scope] [options]

Scope (mutually exclusive; default: auto-detect latest round):
  --round N              Aggregate one round (writes round-N.metrics.yml)
  --delivery N           Aggregate all rounds of one delivery (writes delivery-N.metrics.yml)
  --since <iso>          Aggregate all dispatches since ISO timestamp
                         (writes since-<iso>.metrics.yml; git-sha not supported —
                          use `git show -s --format=%cI <sha>` to get the ISO)

Options:
  --review-dir <path>    Path to .review/ directory (default: ./.review)
  --harness-dir <path>   Path to harness JSONL session dir
                         (default: $CLAUDE_HARNESS_DIR or ~/.claude/projects/)
  --config <path>        Path to skill config.yml (default: common/config.yml)
  --criterion-extractor <path>
                         Optional script: given a trace_id, prints newline-
                         separated criterion IDs that trace contributed to.
                         When provided, `cost.by_criterion` is populated.
  --dry-run              Print YAML to stdout, do not write files
  -h | --help            Show this help

Exit codes:
  0  success
  1  usage error
  2  input/parse error
  3  JOIN failure threshold exceeded (>50% traces unmatched)
EOF
}

# --- arg parsing ---
MODE=""
SCOPE_KEY=""
SCOPE_VAL=""
REVIEW_DIR="./.review"
HARNESS_DIR="${CLAUDE_HARNESS_DIR:-$HOME/.claude/projects}"
CONFIG_PATH="common/config.yml"
CRITERION_EXTRACTOR=""
DRY_RUN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diagnose) MODE="diagnose"; shift ;;
    --round) SCOPE_KEY="round"; SCOPE_VAL="${2:-}"; shift 2 ;;
    --delivery) SCOPE_KEY="delivery"; SCOPE_VAL="${2:-}"; shift 2 ;;
    --since) SCOPE_KEY="since"; SCOPE_VAL="${2:-}"; shift 2 ;;
    --review-dir) REVIEW_DIR="${2:-}"; shift 2 ;;
    --harness-dir) HARNESS_DIR="${2:-}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    --criterion-extractor) CRITERION_EXTRACTOR="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$MODE" != "diagnose" ]]; then
  echo "error: --diagnose is required (this reference impl only supports diagnose mode)" >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$REVIEW_DIR" ]]; then
  echo "error: review dir not found: $REVIEW_DIR" >&2
  exit 2
fi
if [[ ! -d "$HARNESS_DIR" ]]; then
  echo "error: harness dir not found: $HARNESS_DIR (set --harness-dir or CLAUDE_HARNESS_DIR)" >&2
  exit 2
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "warn: config not found: $CONFIG_PATH (using zero-pricing defaults)" >&2
  CONFIG_PATH=""
fi
if [[ -n "$CRITERION_EXTRACTOR" && ! -x "$CRITERION_EXTRACTOR" ]]; then
  echo "error: criterion-extractor not executable: $CRITERION_EXTRACTOR" >&2
  exit 1
fi

# Default scope: latest round
if [[ -z "$SCOPE_KEY" ]]; then
  latest=$(ls -1 "$REVIEW_DIR/traces" 2>/dev/null \
            | grep -E '^round-[0-9]+$' \
            | sort -t- -k2 -n \
            | tail -1 \
            | sed 's/^round-//')
  if [[ -z "$latest" ]]; then
    echo "error: no rounds found under $REVIEW_DIR/traces/" >&2
    exit 2
  fi
  SCOPE_KEY="round"
  SCOPE_VAL="$latest"
fi

# Invoke python core
exec python3 "$PY_CORE" \
  --scope "$SCOPE_KEY=$SCOPE_VAL" \
  --review-dir "$REVIEW_DIR" \
  --harness-dir "$HARNESS_DIR" \
  --config "$CONFIG_PATH" \
  --criterion-extractor "$CRITERION_EXTRACTOR" \
  ${DRY_RUN:+--dry-run}
