#!/usr/bin/env bash
# synthesize-clarification.sh — write a minimal deferred-only clarification.yml
# when the orchestrator is invoked with --no-consultant.
#
# Per generate/from-scratch.md Step 4 (`--no-consultant` override), the
# domain-consultant subagent is bypassed and the orchestrator must produce
# a clarification.yml that downstream subagents (planner, writer) will read.
# This script encapsulates that write so SKILL.md's "orchestrator only
# writes state.yml + dispatch-log.jsonl" contract isn't violated.
#
# Usage:
#   synthesize-clarification.sh <prd-dir> <skill-name> <skill-version>
#                               <skill-description> <artifact-root>
#
# Writes <prd-dir>/.review/round-0/clarification/<ISO-timestamp>.yml with
# R-001..R-007 marked status: deferred and the four flat keys populated.
#
# Exit codes:
#   0  success
#   1  bad input
#   2  IO error

set -euo pipefail

PRD_ROOT="${1:-}"
SKILL_NAME="${2:-}"
SKILL_VERSION="${3:-}"
SKILL_DESCRIPTION="${4:-}"
ARTIFACT_ROOT="${5:-}"

if [ -z "$PRD_ROOT" ] || [ -z "$SKILL_NAME" ] || [ -z "$SKILL_VERSION" ] \
   || [ -z "$SKILL_DESCRIPTION" ] || [ -z "$ARTIFACT_ROOT" ]; then
  echo "ERROR: five arguments required" >&2
  echo "Usage: synthesize-clarification.sh <prd-dir> <skill-name> <skill-version> <skill-description> <artifact-root>" >&2
  exit 1
fi

if [ ! -d "$PRD_ROOT" ]; then
  echo "ERROR: prd-dir not found: $PRD_ROOT" >&2
  exit 2
fi

PRD_ROOT="${PRD_ROOT%/}"
TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
OUT_DIR="$PRD_ROOT/.review/round-0/clarification"
OUT_FILE="$OUT_DIR/$TS.yml"

mkdir -p "$OUT_DIR" || { echo "ERROR: cannot create $OUT_DIR" >&2; exit 2; }

# Escape any double-quotes in user-supplied strings to keep YAML valid
escape_yaml() {
  printf '%s' "$1" | sed 's/"/\\"/g'
}

cat > "$OUT_FILE" <<EOF
SKILL_NAME: "$(escape_yaml "$SKILL_NAME")"
SKILL_VERSION: "$(escape_yaml "$SKILL_VERSION")"
SKILL_DESCRIPTION: "$(escape_yaml "$SKILL_DESCRIPTION")"
ARTIFACT_ROOT: "$(escape_yaml "$ARTIFACT_ROOT")"

clarification_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
synthesized_via: "no-consultant override (orchestrator delegated to scripts/synthesize-clarification.sh)"
normalized_requirements:
  R-001:
    status: deferred
    note: "no-consultant: product name/scope deferred; planner uses input.md as-is"
  R-002:
    status: deferred
    note: "no-consultant: output scope deferred; default canonical PRD bundle shape"
  R-003:
    status: deferred
    note: "no-consultant: artifact structure depth deferred"
  R-004:
    status: deferred
    note: "no-consultant: success criteria deferred"
  R-005:
    status: deferred
    note: "no-consultant: stakeholders / personas deferred"
  R-006:
    status: deferred
    note: "no-consultant: constraints deferred"
  R-007:
    status: deferred
    note: "no-consultant: prior art / version-N status deferred"
domain_terms_aligned: []
EOF

echo "OK wrote $OUT_FILE"
