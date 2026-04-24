#!/usr/bin/env bash
# check-breaking-changes.sh — variant:schema stub — emits [] for v1
# ====================================================================
# WRITER TODO (during round 1):
# Compare current schema files (OpenAPI / JSON Schema / protobuf) against
# previous delivery's schema. Detect breaking changes:
#   - removed fields / types
#   - narrowed types (string → enum)
#   - new required fields on existing types
#   - changed field positions (protobuf)
# Emit CR-SCHEMA-BREAK issues per guide §12.4. Severity: error by default.
# ====================================================================
set -euo pipefail
TARGET="${1:?usage: check-breaking-changes.sh <target-skill-dir>}"
[ -d "$TARGET" ] || { echo "FATAL: $TARGET not a directory" >&2; exit 2; }
echo "[]"
exit 0
