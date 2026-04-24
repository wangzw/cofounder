#!/usr/bin/env bash
# test-skeleton-identity.sh — assert verbatim files identical across 4 skeleton variants
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."

# Files that MUST be byte-identical across all 4 variants (verbatim generic).
# When these diverge, a variant tree has drifted and downstream scaffolded
# skills will have inconsistent behavior.
VERBATIM_FILES=(
  "scripts/git-precheck.sh"
  "scripts/prepare-input.sh"
  "scripts/glossary-probe.sh"
  "scripts/extract-criteria.sh"
  "scripts/build-depgraph.sh"
  "scripts/commit-delivery.sh"
  "scripts/prune-traces.sh"
  "scripts/metrics-aggregate.sh"
  "scripts/lib/aggregate.py"
  "scripts/check-frontmatter.sh"
  "scripts/check-mode-routing.sh"
  "scripts/check-skill-structure.sh"
  "scripts/check-scripts-inventory.sh"
  "scripts/check-config-schema.sh"
  "scripts/check-criteria-yaml.sh"
  "scripts/check-ipc-footer.sh"
  "scripts/check-dispatch-log-snippet.sh"
  "scripts/check-trace-id-format.sh"
  "scripts/check-scaffold-sha.sh"
  "scripts/check-artifact-pyramid.sh"
  "scripts/check-dependencies.sh"
  "scripts/check-criteria-consistency.sh"
  "scripts/check-index-consistency.sh"
  "scripts/check-changelog-consistency.sh"
  "common/snippets.md"
  "generate/from-scratch.md"
  "generate/new-version.md"
  "generate/planner-subagent.md"
  "review/index.md"
  "revise/index.md"
  "shared/summarizer-subagent.md"
  "shared/judge-subagent.md"
)

VARIANTS=(document code schema hybrid)
FAIL=0
for f in "${VERBATIM_FILES[@]}"; do
  doc_sha=$(sha256sum "$ROOT/common/skeleton/document/$f" 2>/dev/null | awk '{print $1}')
  [ -z "$doc_sha" ] && { echo "FAIL: missing $f in document variant"; FAIL=1; continue; }
  for v in code schema hybrid; do
    v_sha=$(sha256sum "$ROOT/common/skeleton/$v/$f" 2>/dev/null | awk '{print $1}')
    [ -z "$v_sha" ] && { echo "FAIL: missing $f in $v variant"; FAIL=1; continue; }
    [ "$doc_sha" = "$v_sha" ] || { echo "FAIL: $f differs in $v (expected $doc_sha, got $v_sha)"; FAIL=1; }
  done
done

# Files that MUST differ across variants (variant-specific)
VARIANT_SPECIFIC=(
  "SKILL.md"
  "scripts/run-checkers.sh"
)
for f in "${VARIANT_SPECIFIC[@]}"; do
  shas=$(for v in "${VARIANTS[@]}"; do sha256sum "$ROOT/common/skeleton/$v/$f" 2>/dev/null | awk '{print $1}'; done | sort -u | wc -l | tr -d ' ')
  [ "$shas" = "4" ] || { echo "FAIL: $f does not differ across all 4 variants (got $shas distinct shas)"; FAIL=1; }
done

[ "$FAIL" = "0" ] && echo "PASS test-skeleton-identity.sh"
exit "$FAIL"
