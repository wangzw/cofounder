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

# Use `pwd -P` (physical path with all symlinks resolved) for BOTH the repo
# root and the target, so the prefix-strip below works on systems where the
# logical and physical paths differ — e.g. macOS resolves /tmp and /var to
# /private/tmp and /private/var, and a target reached via /var would otherwise
# fail to share the /private/var prefix that `git rev-parse --show-toplevel`
# emits.
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
TARGET_ABS="$(cd "$TARGET" && pwd -P)"
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
# differs between the latest delivery tag and the WORKING TREE. Comparing to HEAD
# alone misses uncommitted edits and would falsely report no-drift on a target
# that has been modified locally but not yet committed (review/revise cycles
# routinely operate on uncommitted changes).
#
# `git diff <tag> -- <path>` (no second ref) diffs the tag against the working
# tree, which catches both committed and unstaged changes.
#
# Build the .review/ exclusion prefix. When the target IS the repo root
# (REL_TARGET="."), git emits paths like `.review/foo.md` with no leading
# `./`, so the exclude pattern must NOT have one either. When the target is
# a subdir (REL_TARGET="skills/foo"), git emits `skills/foo/.review/...`.
if [ "$REL_TARGET" = "." ]; then
  REVIEW_PREFIX_RE='^\.review/'
else
  REVIEW_PREFIX_RE="^${REL_TARGET}/\\.review/"
fi
DRIFT="$(git -C "$REPO_ROOT" diff --name-only "$LATEST_TAG" -- "$REL_TARGET" \
          2>/dev/null | grep -v "$REVIEW_PREFIX_RE" || true)"
# Also include untracked files under the target (excluding .review/), since
# `diff` does not see them.
UNTRACKED="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$REL_TARGET" \
          2>/dev/null | grep -v "$REVIEW_PREFIX_RE" || true)"
if [ -n "$UNTRACKED" ]; then
  DRIFT="$(printf '%s\n%s' "$DRIFT" "$UNTRACKED" | grep -v '^$' || true)"
fi

# Reviewer drift: target-tree byte-equality is necessary but not sufficient for
# short-circuit. If skill-forge itself (the reviewer logic — review-criteria.md,
# scripts/check-*.sh, sub-agent prompts, config.yml) has changed since the
# baseline tag, a re-review on an unchanged target may surface NEW issues that
# the prior reviewer would not have caught. Skipping the LLM review in that
# case silently regresses correctness.
#
# We read `skill_forge_dir` from <target>/.review/state.yml (written by
# Bootstrap Precheck) and diff that path against the SAME baseline tag.
REVIEWER_DRIFT=""
STATE_YML="$TARGET_ABS/.review/state.yml"
if [ -f "$STATE_YML" ]; then
  SKILL_FORGE_DIR="$(grep -E '^[[:space:]]*skill_forge_dir:' "$STATE_YML" \
                       | head -1 \
                       | sed -E 's/^[[:space:]]*skill_forge_dir:[[:space:]]*//' \
                       | sed -E 's/^["'"'"']//; s/["'"'"']$//' \
                       || true)"
else
  SKILL_FORGE_DIR=""
fi

if [ -n "$SKILL_FORGE_DIR" ] && [ -d "$SKILL_FORGE_DIR" ]; then
  SKILL_FORGE_ABS="$(cd "$SKILL_FORGE_DIR" && pwd -P)"
  SKILL_FORGE_REPO="$(git -C "$SKILL_FORGE_ABS" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$SKILL_FORGE_REPO" ]; then
    SKILL_FORGE_REPO="$(cd "$SKILL_FORGE_REPO" && pwd -P)"
    if [ "$SKILL_FORGE_REPO" = "$REPO_ROOT" ]; then
      # Same repo as target — diff skill-forge tree against the same tag.
      REL_FORGE="${SKILL_FORGE_ABS#"$REPO_ROOT"/}"
      [ "$REL_FORGE" = "$SKILL_FORGE_ABS" ] && REL_FORGE="."
      # Skip skill-forge's own .review/ if it exists (mirrors target rule).
      if [ "$REL_FORGE" = "." ]; then
        FORGE_REVIEW_RE='^\.review/'
      else
        FORGE_REVIEW_RE="^${REL_FORGE}/\\.review/"
      fi
      REVIEWER_DRIFT="$(git -C "$REPO_ROOT" diff --name-only "$LATEST_TAG" -- "$REL_FORGE" \
                          2>/dev/null | grep -v "$FORGE_REVIEW_RE" || true)"
      FORGE_UNTRACKED="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$REL_FORGE" \
                          2>/dev/null | grep -v "$FORGE_REVIEW_RE" || true)"
      if [ -n "$FORGE_UNTRACKED" ]; then
        REVIEWER_DRIFT="$(printf '%s\n%s' "$REVIEWER_DRIFT" "$FORGE_UNTRACKED" | grep -v '^$' || true)"
      fi
    else
      # skill-forge lives in a different git repo. We cannot diff against the
      # target's baseline tag (the tag refs a commit in the target's repo, not
      # the skill-forge repo). Surface a warning so the user understands the
      # no-drift gate is target-only in this configuration.
      echo "warning: skill-forge in different repo ($SKILL_FORGE_REPO != $REPO_ROOT); cannot verify reviewer drift" >&2
    fi
  else
    echo "warning: skill_forge_dir is not in a git repo ($SKILL_FORGE_DIR); cannot verify reviewer drift" >&2
  fi
fi

if [ -z "$DRIFT" ] && [ -z "$REVIEWER_DRIFT" ]; then
  echo "no-drift since $LATEST_TAG — skipping LLM review"
  exit 0
fi

if [ -n "$DRIFT" ]; then
  echo "drift detected against $LATEST_TAG (target: ${DRIFT})" >&2
fi
if [ -n "$REVIEWER_DRIFT" ]; then
  echo "drift detected against $LATEST_TAG (reviewer/skill-forge: ${REVIEWER_DRIFT})" >&2
fi
exit 1
