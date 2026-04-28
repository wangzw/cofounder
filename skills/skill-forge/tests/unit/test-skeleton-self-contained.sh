#!/usr/bin/env bash
# test-skeleton-self-contained.sh — the document skeleton must be self-contained.
# Generated skills must not reference skill-forge paths or user-local absolute paths.
# Scope: skeleton/document/ tree, excluding .review/ (not present in skeleton).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
FAIL=0

# Forbidden patterns in any .md, .yml, .yaml, .sh under skeleton/document/
# - "<skill-forge>/..."   path placeholder pointing at the meta tool
# - "skill_forge_dir"     obsolete state.yml field
# - "skills/skill-forge/" literal source path
# - "~/Documents/"        user-local absolute path (except the CLAUDE_HARNESS_DIR default in metrics-aggregate, which uses ~/.claude/)
# We check each pattern independently and report any hit.

dir="$ROOT/common/skeleton/document"
violations=$(grep -rnE "<skill-forge>/|skill_forge_dir|skills/skill-forge/|Documents/mind|upstream: ~/" "$dir" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.sh" 2>/dev/null || true)
if [ -n "$violations" ]; then
  echo "FAIL: skeleton/document/ contains external refs:"
  echo "$violations" | head -20
  FAIL=1
fi

if [ "$FAIL" = "0" ]; then
  echo "PASS test-skeleton-self-contained.sh (document skeleton self-contained)"
fi
exit "$FAIL"
