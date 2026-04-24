#!/usr/bin/env bash
# commit-delivery.sh — §8.3 delivery commit + annotated tag
# Usage: commit-delivery.sh <target-skill-dir> <delivery-id> <change-summary>
# Exit: 0=success, 1=tag collision (delivery_id reuse), 2=error
set -euo pipefail

TARGET="${1:-}"
DELIVERY_ID="${2:-}"
CHANGE_SUMMARY="${3:-}"

if [ -z "$TARGET" ] || [ -z "$DELIVERY_ID" ] || [ -z "$CHANGE_SUMMARY" ]; then
  echo "ERROR: three arguments required: target-skill-dir, delivery-id, change-summary" >&2
  echo "Usage: commit-delivery.sh <target-skill-dir> <delivery-id> <change-summary>" >&2
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target skill dir not found: ${TARGET}" >&2
  exit 2
fi

# Validate delivery-id is a positive integer
if ! echo "$DELIVERY_ID" | grep -qE '^[1-9][0-9]*$'; then
  echo "ERROR: delivery-id must be a positive integer; got '${DELIVERY_ID}'" >&2
  exit 2
fi

TARGET="${TARGET%/}"

# Compute slug from change-summary (§8.3)
SLUG=$(python3 - "$CHANGE_SUMMARY" <<'PYEOF'
import sys, re
from datetime import datetime, timezone

summary = sys.argv[1]

# First 40 chars, lowercase, non-[a-z0-9] -> '-', collapse adjacent '-', strip leading/trailing '-'
truncated = summary[:40].lower()
slugified = re.sub(r'[^a-z0-9]+', '-', truncated)
slugified = re.sub(r'-+', '-', slugified)
slugified = slugified.strip('-')

# Fallback for CJK-only or all-symbol inputs
if not slugified:
    slugified = datetime.now(timezone.utc).strftime('%Y%m%d')

print(slugified)
PYEOF
)

TAG="delivery-${DELIVERY_ID}-${SLUG}"

# Check if tag already exists — collision = state bug
if git -C "$TARGET" rev-parse "$TAG" >/dev/null 2>&1; then
  echo "ERROR: tag '${TAG}' already exists; delivery_id ${DELIVERY_ID} collision is a state bug" >&2
  exit 1
fi

# Stage target dir (including .review/)
git -C "$TARGET" add "${TARGET}/" "${TARGET}/.review/" 2>/dev/null || \
  git add "${TARGET}/" "${TARGET}/.review/" 2>/dev/null || true

# Commit
git -C "$TARGET" commit -m "feat(skill-forge): delivery-${DELIVERY_ID}: ${CHANGE_SUMMARY}"

# Annotated tag
git -C "$TARGET" tag -a "$TAG" -m "${CHANGE_SUMMARY}"

echo "OK tag ${TAG}"
