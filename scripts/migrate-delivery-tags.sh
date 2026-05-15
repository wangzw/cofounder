#!/usr/bin/env bash
# migrate-delivery-tags.sh — one-shot rename of legacy `delivery-<N>-<slug>` tags
#
# Background. Before 2026-05-08 the `prd-analysis` and `system-design` skills
# both wrote annotated git tags of the form `delivery-<N>-<slug>` on
# converged-delivery commits. The two skills shared the same tag namespace,
# which produced cosmetic confusion in `git tag -l` listings and a functional
# hazard for `autoforge --evolve`, which resolves the design baseline via
# `git tag --list 'delivery-*' --merged HEAD --sort=creatordate` and would
# default to whichever delivery tag (prd or design) sorted earliest.
#
# Each skill now owns its own namespaced tag form:
#   - prd-analysis  → prd-analysis-delivery-<N>-<slug>
#   - system-design → system-design-delivery-<N>-<slug>
#   - autoforge     → autoforge-delivery-<N>-<slug>   (already namespaced; untouched)
#
# This script renames pre-existing `delivery-<N>-<slug>` tags to the new
# namespaced form by inspecting each tag's commit tree. It is idempotent
# (already-renamed tags are skipped) and refuses to overwrite an existing
# target tag.
#
# Usage:
#   scripts/migrate-delivery-tags.sh [--dry-run] [--repo <git-repo>]
#
# Flags:
#   --dry-run        Print what would happen; touch nothing.
#   --repo <path>    Operate on this repo (defaults to current directory).
#
# Exit:
#   0  success (or dry run)
#   1  no candidate tags found, or every candidate ambiguous (see warnings)
#   2  usage / setup error
#
# Detection rule (per tag):
#   The tagged commit's tree changes are inspected with
#   `git show --name-only --pretty=format: <tag>`. If the dominant prefix of
#   the changed paths is `docs/raw/prd/`, the tag is mapped to prd-analysis.
#   If `docs/raw/design/`, system-design. Otherwise the tag is skipped and a
#   warning is printed — the user must either rename it manually (if they know
#   which skill produced it) or delete it.

set -euo pipefail

DRY_RUN=0
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --repo)     REPO="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

REPO="${REPO:-$(pwd)}"
REPO="${REPO%/}"

if [ ! -d "$REPO/.git" ] && ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: '$REPO' is not a git repository" >&2
  exit 2
fi

# Collect candidate tags: legacy form `delivery-<N>-<slug>` only.
# Already-namespaced forms (prd-analysis-delivery-*, system-design-delivery-*,
# autoforge-delivery-*) are explicitly excluded by the leading-token test.
mapfile -t CANDIDATES < <(
  git -C "$REPO" for-each-ref --format='%(refname:short)' refs/tags |
    awk '/^delivery-[0-9]+-/ { print }'
)

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "no legacy 'delivery-<N>-<slug>' tags found in $REPO — nothing to do"
  exit 0
fi

echo "found ${#CANDIDATES[@]} legacy tag(s) in $REPO"
[ "$DRY_RUN" = 1 ] && echo "(dry-run mode — no changes will be made)"
echo ""

renamed=0
skipped_ambiguous=0
skipped_target_exists=0

for old in "${CANDIDATES[@]}"; do
  # Inspect changed paths in the tagged commit.
  paths=$(git -C "$REPO" show --name-only --pretty=format: "$old" 2>/dev/null \
            | sed '/^$/d' || true)

  if [ -z "$paths" ]; then
    printf '  SKIP  %s (cannot read commit tree — orphaned tag?)\n' "$old"
    skipped_ambiguous=$((skipped_ambiguous + 1))
    continue
  fi

  prd_hits=$(printf '%s\n' "$paths" | grep -cE '^docs/raw/prd/' || true)
  des_hits=$(printf '%s\n' "$paths" | grep -cE '^docs/raw/design/' || true)

  skill=""
  if [ "$prd_hits" -gt 0 ] && [ "$des_hits" -eq 0 ]; then
    skill="prd-analysis"
  elif [ "$des_hits" -gt 0 ] && [ "$prd_hits" -eq 0 ]; then
    skill="system-design"
  elif [ "$prd_hits" -gt 0 ] && [ "$des_hits" -gt 0 ]; then
    # Mixed: prefer the larger share, but require >=2x dominance to call it.
    if [ "$prd_hits" -ge $((des_hits * 2)) ]; then
      skill="prd-analysis"
    elif [ "$des_hits" -ge $((prd_hits * 2)) ]; then
      skill="system-design"
    fi
  fi

  if [ -z "$skill" ]; then
    printf '  SKIP  %s (cannot disambiguate: %d prd path(s), %d design path(s))\n' \
      "$old" "$prd_hits" "$des_hits"
    skipped_ambiguous=$((skipped_ambiguous + 1))
    continue
  fi

  new="${skill}-${old}"  # delivery-<N>-<slug>  →  <skill>-delivery-<N>-<slug>

  if git -C "$REPO" rev-parse "$new" >/dev/null 2>&1; then
    printf '  SKIP  %s → %s (target already exists)\n' "$old" "$new"
    skipped_target_exists=$((skipped_target_exists + 1))
    continue
  fi

  printf '  RENAME  %s → %s\n' "$old" "$new"

  if [ "$DRY_RUN" = 1 ]; then
    continue
  fi

  # Preserve annotation. for-each-ref %(contents) returns the tag message
  # body for annotated tags, empty for lightweight ones. Re-create as
  # annotated to keep the audit trail; the underlying commit object is
  # unchanged. Tagger date / committer identity are NOT preserved (would
  # require GIT_COMMITTER_DATE + a fresh tagger entry); this is acceptable
  # because the tag's pointed-at commit retains its original authorship
  # and date.
  msg=$(git -C "$REPO" for-each-ref --format='%(contents)' "refs/tags/$old")
  commit=$(git -C "$REPO" rev-list -n 1 "$old")

  if [ -z "$msg" ]; then
    git -C "$REPO" tag "$new" "$commit"
  else
    git -C "$REPO" tag -a "$new" "$commit" -m "$msg"
  fi
  git -C "$REPO" tag -d "$old" >/dev/null

  renamed=$((renamed + 1))
done

echo ""
echo "summary:"
echo "  renamed:          $renamed"
echo "  skipped (target exists): $skipped_target_exists"
echo "  skipped (ambiguous):     $skipped_ambiguous"

if [ "$DRY_RUN" = 1 ]; then
  echo ""
  echo "this was a dry run — re-run without --dry-run to apply"
fi

if [ "$skipped_ambiguous" -gt 0 ]; then
  echo ""
  echo "warn: $skipped_ambiguous tag(s) could not be auto-classified."
  echo "      Inspect with 'git show <tag>' and rename manually:"
  echo "        git tag -a <skill>-<old-tag> <old-tag>^{commit} -m \"\$(git for-each-ref --format='%(contents)' refs/tags/<old-tag>)\""
  echo "        git tag -d <old-tag>"
fi
