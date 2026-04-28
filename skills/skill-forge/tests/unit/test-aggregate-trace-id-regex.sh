#!/usr/bin/env bash
# test-aggregate-trace-id-regex.sh — regression guard for R6-V003-004.
#
# Bug: aggregate.py's TRACE_ID_RE used permissive `[A-Za-z]-\d+` while the
# canonical CR-S10 trace_id format (and check-trace-id-format.sh enforcer) is
# `R<N>-[CPWVRSJ]-<nnn>` (exactly 3 zero-padded digits, role-letter from the
# fixed 7-letter alphabet). The mismatch meant aggregate.py would silently
# attribute usage events to malformed trace markers like `R3-X-007` (invalid
# role letter) or `R3-W-7` (missing zero-padding) — the very malformations the
# format check is supposed to surface.
#
# Fix: tighten the regex to canonical alphabet + 3-digit padding.
# Skeleton-protected: also requires updating the sha256 pin in
# common/shared-scripts-manifest.yml.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."

# Test 1: main aggregate.py uses the canonical alphabet [CPWVRSJ] (not [A-Za-z])
PYFILE="$ROOT/scripts/lib/aggregate.py"
[ -f "$PYFILE" ] || { echo "FAIL: $PYFILE not found"; exit 1; }
if grep -q 'TRACE_ID_RE.*\[A-Za-z\]' "$PYFILE"; then
  echo "FAIL: aggregate.py TRACE_ID_RE still uses permissive [A-Za-z] (R6-V003-004)"
  grep -n 'TRACE_ID_RE' "$PYFILE"
  exit 1
fi
grep -qE 'TRACE_ID_RE.*\[CPWVRSJ\].*\\d\{3\}' "$PYFILE" \
  || { echo "FAIL: aggregate.py TRACE_ID_RE missing canonical [CPWVRSJ] + \\d{3}"; grep -n 'TRACE_ID_RE' "$PYFILE"; exit 1; }
echo "PASS: main aggregate.py uses canonical TRACE_ID_RE"

# Test 2: same constraint in the document skeleton
SK_PY="$ROOT/common/skeleton/document/scripts/lib/aggregate.py"
[ -f "$SK_PY" ] || { echo "FAIL: skeleton aggregate.py missing"; exit 1; }
if grep -q 'TRACE_ID_RE.*\[A-Za-z\]' "$SK_PY"; then
  echo "FAIL: skeleton aggregate.py TRACE_ID_RE still uses [A-Za-z]"
  exit 1
fi
grep -qE 'TRACE_ID_RE.*\[CPWVRSJ\].*\\d\{3\}' "$SK_PY" \
  || { echo "FAIL: skeleton aggregate.py TRACE_ID_RE missing canonical pattern"; exit 1; }
echo "PASS: document skeleton aggregate.py uses canonical TRACE_ID_RE"

# Test 3: behavioural — regex matches valid canonical IDs and rejects malformed ones.
# We extract the TRACE_ID_RE pattern via grep instead of importing the module,
# because aggregate.py uses @dataclass at module level and importlib's
# spec_from_file_location does not register the module in sys.modules, which
# the dataclass machinery requires for type resolution.
python3 - "$PYFILE" <<'PYEOF'
import re, sys
src = open(sys.argv[1]).read()
m = re.search(r'TRACE_ID_RE\s*=\s*re\.compile\(\s*r"([^"]+)"\s*\)', src)
assert m, "could not extract TRACE_ID_RE pattern from aggregate.py"
TRACE_ID_RE = re.compile(m.group(1))

def assert_match(text, expected_id):
    m = TRACE_ID_RE.search(text)
    assert m and m.group(1) == expected_id, f"expected match {expected_id} in {text!r}, got {m}"

def assert_no_match(text):
    m = TRACE_ID_RE.search(text)
    assert m is None, f"expected NO match in {text!r}, got {m.group(1)}"

# Valid: all 7 canonical role letters, 3-digit padding
for letter in "CPWVRSJ":
    assert_match(f"trace_id: R3-{letter}-007", f"R3-{letter}-007")
assert_match("trace_id: R12-W-042", "R12-W-042")

# Invalid: wrong role letter (would be silently accepted by old regex)
assert_no_match("trace_id: R3-X-007")
assert_no_match("trace_id: R3-Q-007")
assert_no_match("trace_id: R3-A-007")
assert_no_match("trace_id: R3-z-007")  # lowercase

# Invalid: missing zero-padding (would be silently accepted by old regex)
assert_no_match("trace_id: R3-W-7")
assert_no_match("trace_id: R3-W-12")
assert_no_match("trace_id: R3-W-1234")

# Invalid: missing R prefix
assert_no_match("trace_id: 3-W-007")

print("PASS: TRACE_ID_RE behaviour matches canonical CR-S10 contract")
PYEOF

# Test 4: shared-scripts-manifest.yml sha256 matches the actual file
EXPECTED_SHA=$(grep -A 2 '^  scripts/lib/aggregate.py:' "$ROOT/common/shared-scripts-manifest.yml" \
                 | grep '^    sha256:' | head -1 | awk '{print $2}')
ACTUAL_SHA=$(shasum -a 256 "$PYFILE" | awk '{print $1}')
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] \
  || { echo "FAIL: shared-scripts-manifest.yml sha256 ($EXPECTED_SHA) != actual file sha ($ACTUAL_SHA)"; exit 1; }
echo "PASS: shared-scripts-manifest.yml sha256 matches updated aggregate.py"

echo "=== PASS test-aggregate-trace-id-regex.sh (4 sub-tests) ==="
