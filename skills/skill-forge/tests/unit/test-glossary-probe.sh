#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PREPARE="$HERE/../../scripts/prepare-input.sh"
PROBE="$HERE/../../scripts/glossary-probe.sh"
GLOSSARY="$HERE/../../common/domain-glossary.md"

[ -x "$PROBE" ] || { echo "FAIL: probe not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Test 1: sparse input with no glossary hits (all short words, no terms)
"$PREPARE" "short" "$TMP/.review1" >/dev/null 2>&1
"$PROBE" "$TMP/.review1" "$GLOSSARY" >/dev/null 2>&1
[ -f "$TMP/.review1/round-0/trigger-flags.yml" ] || { echo "FAIL: trigger-flags.yml not written"; exit 1; }
grep -q 'sparse_input: true' "$TMP/.review1/round-0/trigger-flags.yml" \
  || { echo "FAIL: short prompt not flagged sparse"; exit 1; }

# Test 2: glossary hit — prompt includes the word "delivery"
"$PREPARE" "I want to generate a major version delivery release of my app with new features and tests" "$TMP/.review2" >/dev/null 2>&1
"$PROBE" "$TMP/.review2" "$GLOSSARY" >/dev/null 2>&1
grep -q 'glossary_hit: true' "$TMP/.review2/round-0/trigger-flags.yml" \
  || { echo "FAIL: 'delivery' not matched as glossary hit"; exit 1; }

# Test 3: dense prompt with no hits
"$PREPARE" "A fully self-contained specification document describing the customer-facing workflow of an internal productivity tool designed for cross-functional teams that need to coordinate asynchronously across multiple time zones during rolling-hour operations involving several distinct organizational units reporting through a central dashboard system that consolidates status updates automatically on a recurring schedule." "$TMP/.review3" >/dev/null 2>&1
"$PROBE" "$TMP/.review3" "$GLOSSARY" >/dev/null 2>&1
grep -q 'sparse_input: false' "$TMP/.review3/round-0/trigger-flags.yml" \
  || { echo "FAIL: long prompt still flagged sparse"; exit 1; }

# Test 4: yaml_str escapes quotes/backslashes (regression for 0638f6d).
# Earlier glossary-probe emitted raw term/alias strings into the output YAML.
# A glossary term containing `"` or `\` produced invalid YAML that downstream
# yaml-parsing scripts choked on.
GLOSSARY_TRICKY="$TMP/tricky-glossary.md"
cat > "$GLOSSARY_TRICKY" <<'EOF'
# Tricky Glossary

## quoted terms

```yaml
- term: 'say "hi"'
  aliases: ['back\\slash term', "single'quote"]
  disambiguation_required: true
  definition: "Test entry with embedded quotes and backslashes."
```
EOF
"$PREPARE" "I want to say \"hi\" please" "$TMP/.review-tricky" >/dev/null 2>&1
"$PROBE" "$TMP/.review-tricky" "$GLOSSARY_TRICKY" >/dev/null 2>&1
TRICKY_OUT="$TMP/.review-tricky/round-0/trigger-flags.yml"
[ -f "$TRICKY_OUT" ] || { echo "FAIL: trigger-flags.yml not written for tricky glossary"; exit 1; }
# The output must be valid YAML. Round-trip through python yaml… well, we don't
# have pyyaml, so instead use the same mini-parser the consultant would use
# (python json + str interpolation isn't safe; the simplest check is that the
# file parses through python's pyyaml-free YAML using a manual round-trip).
# We rely on python to import the file's lines and verify quoting integrity.
python3 - "$TRICKY_OUT" <<'PY'
import sys, re
content = open(sys.argv[1], encoding="utf-8").read()
# Every value in `term: "..."` form must have its embedded `"` escaped to `\"`
# and its `\` escaped to `\\`. Search for raw unescaped quotes inside a
# double-quoted string body.
lines = content.split("\n")
errs = []
for ln in lines:
    m = re.match(r'^(?:\s*-?\s*)?(?:term|alias|alias_matched|sparse_reason):\s*"(.*)"\s*$', ln)
    if not m:
        continue
    body = m.group(1)
    # Walk the body and ensure every `"` and `\` is preceded by a `\`.
    i = 0
    while i < len(body):
        ch = body[i]
        if ch == "\\":
            i += 2  # skip the escape sequence
            continue
        if ch == '"':
            errs.append(f"unescaped \" in: {ln!r}")
            break
        i += 1
if errs:
    print("\n".join(errs))
    sys.exit(1)
PY
[ "$?" -eq 0 ] || { echo "FAIL: yaml_str did not escape quotes/backslashes (0638f6d regression)"; exit 1; }
echo "PASS: yaml_str escapes quotes + backslashes (0638f6d)"

# Test 5: alias_matched dedup preserves same-line primary + alias hits
# (regression for 0638f6d). Earlier dedup key was (term, line), so a line
# that hits BOTH the primary term AND an alias of it on the same line would
# only retain one row — the disambiguation signal was lost.
GLOSSARY_ALIAS="$TMP/alias-glossary.md"
cat > "$GLOSSARY_ALIAS" <<'EOF'
# Alias Glossary

## generative skill

```yaml
- term: "generative skill"
  aliases: ["generative workflow"]
  disambiguation_required: true
  definition: "Test."
```
EOF
# Single-line input that mentions BOTH the primary term and one of its aliases.
"$PREPARE" "I want a generative skill that is also a generative workflow" "$TMP/.review-alias" >/dev/null 2>&1
"$PROBE" "$TMP/.review-alias" "$GLOSSARY_ALIAS" >/dev/null 2>&1
ALIAS_OUT="$TMP/.review-alias/round-0/trigger-flags.yml"
# Count distinct hit rows for term "generative skill" — there should be ≥2:
# one for the primary match (no alias_matched), one for the alias match.
HIT_COUNT=$(grep -c '^  - term: "generative skill"' "$ALIAS_OUT")
[ "$HIT_COUNT" -ge 2 ] \
  || { echo "FAIL: same-line primary+alias dedup collapsed both rows (0638f6d regression). hit_count=$HIT_COUNT"; cat "$ALIAS_OUT"; exit 1; }
# And one of the rows must carry the alias_matched field.
grep -q 'alias_matched: "generative workflow"' "$ALIAS_OUT" \
  || { echo "FAIL: alias_matched: 'generative workflow' not preserved (0638f6d regression)"; cat "$ALIAS_OUT"; exit 1; }
echo "PASS: same-line primary + alias hits both survive dedup (0638f6d)"

echo "PASS test-glossary-probe.sh"
