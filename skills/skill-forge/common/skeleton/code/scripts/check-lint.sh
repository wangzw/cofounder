#!/usr/bin/env bash
# check-lint.sh — variant:code stub — emits [] for v1
# ====================================================================
# WRITER TODO (during round 1):
# Dispatch per detected language:
#   - *.py → ruff check / ruff format --check
#   - *.ts / *.tsx → tsc --noEmit
#   - *.go → golangci-lint run
#   - *.rs → cargo clippy
# Emit issues per guide §12.4 contract: JSON array to stdout, exit 0/1/2.
# ====================================================================
set -euo pipefail
TARGET="${1:?usage: check-lint.sh <target-skill-dir>}"
[ -d "$TARGET" ] || { echo "FATAL: $TARGET not a directory" >&2; exit 2; }
echo "[]"
exit 0
