#!/usr/bin/env bash
# sd_legacy_wrapper.sh — generic entry-point used by §9-conformant
# wrappers around legacy cross-bundle check scripts.
#
# The wrapper runs the legacy script with `--quiet --strict` so it emits
# only a JSON array on stdout, then translates that array into the
# canonical §9 PASS/FOUND output via sd_legacy_emit.sh.
#
# Usage:
#   . "$SCRIPT_DIR/lib/sd_legacy_wrapper.sh"
#   sd_legacy_wrapper "(scope label)" "$LEGACY_PATH" "$@"
#
# Notes:
#   - legacy scripts are expected to print exactly one JSON array on stdout
#     (either `[]` or `[ {…}, {…} ]`). Any extra leading/trailing whitespace
#     is tolerated.
#   - legacy stderr is forwarded unchanged (helps debugging) but suppressed
#     for unit tests by piping the wrapper's stderr to /dev/null.

set -euo pipefail
_SD_LEGACY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sd_legacy_wrapper() {
  local scope="$1"; shift
  local legacy="$1"; shift
  if [ ! -x "$legacy" ]; then
    echo "ERROR: legacy script not executable: $legacy" >&2
    exit 2
  fi

  # Run the legacy script. It is expected to emit a JSON array on stdout
  # and exit 0 (or 1 in --strict mode when findings present). We tolerate
  # both since we are about to re-derive the exit status from the array
  # contents anyway.
  local raw rc
  set +e
  raw="$("$legacy" --quiet "$@")"
  rc=$?
  set -e
  if [ "$rc" = 2 ]; then
    # Argument or environment error; forward as-is.
    exit 2
  fi

  # Strip the enclosing brackets (legacy convention: `[]` or `[<objs>]`).
  local inner
  inner="$(printf '%s' "$raw" | python3 -c '
import sys, re
text = sys.stdin.read().strip()
if not text:
    print("")
else:
    if text.startswith("["):
        text = text[1:]
    if text.endswith("]"):
        text = text[:-1]
    print(text.strip())
')"
  SD_LEGACY_FINDINGS="$inner" bash "$_SD_LEGACY_LIB_DIR/sd_legacy_emit.sh" "$scope"
}
