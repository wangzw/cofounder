#!/usr/bin/env bash
# check-placeholder-json.sh — §9-conformant wrapper around legacy cross-bundle script.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/sd_legacy_wrapper.sh"
sd_legacy_wrapper "(check-placeholder-json)" "$SCRIPT_DIR/_legacy/check-placeholder-json.sh" "$@"
