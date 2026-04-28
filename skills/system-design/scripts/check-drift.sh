#!/usr/bin/env bash
# check-drift.sh — fast short-circuit for `--review` mode on converged skills.
# Compares the target tree to the last converged delivery tag; if zero files
# under <target>/ (excluding .review/) have drifted, emit a "no-drift-converged"
# verdict to stdout and exit 0 WITHOUT dispatching any LLM.
#
# Usage: check-drift.sh <target-skill-dir>
# Exit:  0 = no drift (caller should skip the review cycle)
#        1 = drift detected OR no prior delivery tag OR script error
#             (caller should proceed with the normal --review flow)
#        2 = argument / state error
#
# Stdout: one line on no-drift:  `no-drift since delivery-<N>-<slug> — skipping LLM review`
#         otherwise empty.
# Stderr: always empty on success; diagnostic message on exit 1.
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: target dir required: $TARGET" >&2
  exit 2
fi
TARGET="${TARGET%/}"

# Work from the target's enclosing repo root (may be the skill root itself if it
# was `git init`'d in place, or a parent repo if the skill lives inside a monorepo).
REPO_ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "not a git repo; cannot compute drift" >&2
  exit 1
fi

TARGET_ABS="$(cd "$TARGET" && pwd)"
REL_TARGET="${TARGET_ABS#"$REPO_ROOT"/}"
[ "$REL_TARGET" = "$TARGET_ABS" ] && REL_TARGET="."

# Find the most recent delivery tag that (a) points at a commit reachable from
# HEAD AND (b) actually tags the CURRENT target (not a same-N tag from some
# other skill in a monorepo). The match-by-path check walks the tag-commit's
# tree and asserts `<REL_TARGET>/SKILL.md` exists at that commit — any
# legitimate delivery of this skill would have touched its own SKILL.md.
# Within the matching set, pick the tag with the latest creator timestamp.
LATEST_TAG=""
LATEST_TS=0
while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  # Parse N from `delivery-<N>-...` (just to confirm shape — we don't rank by N
  # because `delivery-2` may tag either this skill OR another skill's delivery-2
  # in the same monorepo, and timestamps disambiguate correctly either way).
  echo "$tag" | grep -qE '^delivery-[0-9]+-' || continue
  # Reachable from HEAD?
  git -C "$REPO_ROOT" merge-base --is-ancestor "$tag" HEAD 2>/dev/null || continue
  # Tag points at a commit that touched THIS target (SKILL.md exists in its tree)?
  git -C "$REPO_ROOT" cat-file -e "$tag:$REL_TARGET/SKILL.md" 2>/dev/null || continue
  ts=$(git -C "$REPO_ROOT" log -1 --format=%ct "$tag" 2>/dev/null || echo 0)
  if [ "$ts" -gt "$LATEST_TS" ]; then
    LATEST_TS="$ts"
    LATEST_TAG="$tag"
  fi
done <<< "$(git -C "$REPO_ROOT" tag -l 'delivery-*')"

if [ -z "$LATEST_TAG" ]; then
  echo "no HEAD-reachable delivery-* tag; first review" >&2
  exit 1
fi

# Compute drift — any path under <target>/ (excluding .review/ meta-archive) that
# differs between the latest delivery tag and HEAD.
DRIFT="$(git -C "$REPO_ROOT" diff --name-only "$LATEST_TAG" HEAD -- "$REL_TARGET" \
          2>/dev/null | grep -v '^'"$REL_TARGET"'/\.review/' || true)"

if [ -z "$DRIFT" ]; then
  echo "no-drift since $LATEST_TAG — skipping LLM review"
  exit 0
fi

echo "drift detected against $LATEST_TAG (${DRIFT})" >&2
exit 1
