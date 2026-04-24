#!/usr/bin/env bash
# test-run-checkers-meta-issues.sh
# Verifies run-checkers.sh emits structured CR-META-* issues (not silent warnings)
# when a declared script_path doesn't exist or a checker misbehaves.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_CHECKERS="$HERE/../../scripts/run-checkers.sh"

# Build a minimal target fixture with a criteria file declaring a script_path
# that doesn't exist. run-checkers should emit CR-META-missing-checker.
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$TMP/common" "$TMP/generate" "$TMP/review" "$TMP/revise" "$TMP/shared" "$TMP/scripts"

# Minimal criteria file with one script-type CR pointing at a non-existent script
cat > "$TMP/common/review-criteria.md" <<'EOF'
# Review Criteria

## CR-TEST-01 missing-script-test

```yaml
- id: CR-TEST-01
  name: "missing-script-test"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-does-not-exist.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
EOF

# run-checkers should emit a CR-META-missing-checker issue
"$RUN_CHECKERS" "$TMP" round-1 >/dev/null 2>&1 || true

OUT="$TMP/.review/round-1/issues/round-checker-output.json"
[ -f "$OUT" ] || { echo "FAIL: $OUT not produced"; exit 1; }

python3 - "$OUT" <<'PYEOF'
import json, sys
arr = json.load(open(sys.argv[1]))
meta = [i for i in arr if i.get("criterion_id") == "CR-META-missing-checker"]
if not meta:
    print(f"FAIL: expected CR-META-missing-checker in {arr}")
    sys.exit(1)
# Verify issue has all required §12.4 fields
required = {"criterion_id", "file", "severity", "description", "suggested_fix"}
missing = required - set(meta[0].keys())
if missing:
    print(f"FAIL: meta-issue missing fields: {missing}")
    sys.exit(1)
if meta[0]["severity"] != "error":
    print(f"FAIL: expected severity=error, got {meta[0]['severity']!r}")
    sys.exit(1)
if "check-does-not-exist.sh" not in meta[0]["description"]:
    print(f"FAIL: description does not name the missing script")
    sys.exit(1)
PYEOF

echo "PASS test-run-checkers-meta-issues.sh"
