#!/usr/bin/env bash
# check-single-source-of-truth.sh — §9-conformant wrapper around legacy cross-bundle script.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/sd_legacy_wrapper.sh"
sd_legacy_wrapper "(check-single-source-of-truth)" "$SCRIPT_DIR/_legacy/check-single-source-of-truth.sh" "$@"
