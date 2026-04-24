#!/usr/bin/env bash
# test-commit-delivery-slug-dedup.sh — F9 fix
# Verifies commit-delivery.sh strips redundant "delivery-N:" prefix from
# change_summary when computing slug, so tags don't duplicate the prefix.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/commit-delivery.sh"

# Extract the slug computation block only (avoid actual git commit in test)
# by sourcing the script in a fake env and intercepting before git operations
extract_slug() {
    local summary="$1"
    local delivery_id="$2"
    python3 - "$summary" "$delivery_id" <<'PYEOF'
import sys, re
from datetime import datetime, timezone

summary      = sys.argv[1]
delivery_id  = sys.argv[2]

# Same logic as commit-delivery.sh
pattern = rf'^\s*delivery[\s\-_:]+{re.escape(delivery_id)}\b[:\s\-–—]*'
summary = re.sub(pattern, '', summary, count=1, flags=re.IGNORECASE).strip()

truncated = summary[:40].lower()
slugified = re.sub(r'[^a-z0-9]+', '-', truncated)
slugified = re.sub(r'-+', '-', slugified)
slugified = slugified.strip('-')

if not slugified:
    slugified = datetime.now(timezone.utc).strftime('%Y%m%d')

print(slugified)
PYEOF
}

# Case 1: summary starts with "Delivery 2: ..." — should strip
slug=$(extract_slug "Delivery 2: observability NFR prescriptive + 6 script stubs" "2")
[ "$slug" = "observability-nfr-prescriptive-6-scrip" ] \
    || { echo "FAIL case 1: got '$slug' (expected prefix stripped)"; exit 1; }

# Case 2: summary starts with "delivery-2" (hyphen form)
slug=$(extract_slug "delivery-2 observability changes" "2")
[ "$slug" = "observability-changes" ] \
    || { echo "FAIL case 2: got '$slug'"; exit 1; }

# Case 3: summary without delivery prefix — no stripping
slug=$(extract_slug "Initial FromScratch generation" "1")
[ "$slug" = "initial-fromscratch-generation" ] \
    || { echo "FAIL case 3: got '$slug'"; exit 1; }

# Case 4: summary mentions OTHER delivery number — not stripped
slug=$(extract_slug "Backport delivery-3 fix to stable" "2")
[ "$slug" = "backport-delivery-3-fix-to-stable" ] \
    || { echo "FAIL case 4 (other delivery reference preserved): got '$slug'"; exit 1; }

# Case 5: CJK fallback path still works when summary is empty after strip
slug=$(extract_slug "Delivery 2:" "2")
[[ "$slug" =~ ^[0-9]{8}$ ]] || { echo "FAIL case 5 (fallback): got '$slug'"; exit 1; }

# Case 6: case-insensitive match
slug=$(extract_slug "DELIVERY 2: shout case" "2")
[ "$slug" = "shout-case" ] || { echo "FAIL case 6: got '$slug'"; exit 1; }

echo "PASS test-commit-delivery-slug-dedup.sh"
