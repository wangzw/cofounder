#!/usr/bin/env bash
# check-feature-ids.sh — stub for CR-PRD-S* (delivery-2 amendment; full implementation deferred to delivery-3)
# §12.4 contract: stdout = JSON array of issues; exit 0 = pass, 1 = issues, 2 = error
set -euo pipefail
TARGET="${1:?usage: check-feature-ids.sh <target-dir>}"
[ -d "$TARGET" ] || { echo "FATAL: target not found: $TARGET" >&2; exit 2; }
# TODO(delivery-3): implement actual check logic
echo "[]"
exit 0
