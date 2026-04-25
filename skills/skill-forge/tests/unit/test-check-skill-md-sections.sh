#!/usr/bin/env bash
# test-check-skill-md-sections.sh — CR-S15 enforcement guard
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/check-skill-md-sections.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# ── Fixture 1: no SKILL.md → exit 1 with structured issue ──
T1="$TMP/empty-target"
mkdir -p "$T1"
set +e
out=$("$SCRIPT" "$T1" 2>/dev/null); ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: missing SKILL.md expected exit 1, got $ec"; exit 1; }
echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d and d[0]['criterion_id']=='CR-S15'" \
  || { echo "FAIL: missing-SKILL.md issue shape wrong"; exit 1; }
echo "PASS: missing SKILL.md → CR-S15 issue (exit 1)"

# ── Fixture 2: SKILL.md missing all 4 sections → ≥3 issues ──
T2="$TMP/legacy-target"
mkdir -p "$T2"
cat > "$T2/SKILL.md" <<'EOF'
---
name: legacy-skill
version: 1.0.0
description: "Use when ..."
---
# legacy-skill — no cost-control sections
EOF
set +e
out=$("$SCRIPT" "$T2" 2>/dev/null); ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: legacy SKILL.md expected exit 1, got $ec"; exit 1; }
n=$(echo "$out" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
[ "$n" -ge "3" ] || { echo "FAIL: legacy expected ≥3 issues, got $n"; exit 1; }
echo "PASS: legacy SKILL.md → $n CR-S15 issues (exit 1)"

# ── Fixture 3: SKILL.md with all sections + table + flags → exit 0 ──
T3="$TMP/good-target"
mkdir -p "$T3"
cat > "$T3/SKILL.md" <<'EOF'
---
name: good-skill
version: 1.0.0
description: "Use when ..."
---

# good-skill — has all cost-control sections

## Model Tiers

Abstract: heavy / balanced / light. Mapping in common/config.yml.

### Per-dispatch model override (MANDATORY for cost control)

Sub-agents inherit parent unless overridden.

| Role | Default tier | Agent-tool `model` value |
|---|---|---|
| domain-consultant | heavy | "opus" |
| planner | heavy | "opus" |
| writer | balanced | "sonnet" |
| reviewer | heavy | "opus" |
| reviser | balanced | "sonnet" |
| summarizer | light | "haiku" |
| judge | light | "haiku" |

## CLI Flags

| Flag | Applies to | Semantics |
|---|---|---|
| `--full` | --review | force-full |
| `--no-consultant` | Generate | skip consultant |
| `--tier <role>=<tier>` | All | override tier |
| `--max-iterations N` | All | override convergence cap |
EOF
set +e
out=$("$SCRIPT" "$T3" 2>/dev/null); ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: good SKILL.md expected exit 0, got $ec; output: $out"; exit 1; }
echo "$out" | grep -q '\[\]' || { echo "FAIL: good SKILL.md expected '[]', got: $out"; exit 1; }
echo "PASS: good SKILL.md → no issues (exit 0)"

# ── Fixture 4: model-override section present but role table missing ──
T4="$TMP/missing-table"
mkdir -p "$T4"
cat > "$T4/SKILL.md" <<'EOF'
---
name: x
version: 1.0.0
description: "Use when ..."
---

## Model Tiers

### Per-dispatch model override

Sub-agents must override.

(table missing)

## CLI Flags

| Flag | Applies to | Semantics |
|---|---|---|
| `--full` | --review | x |
| `--no-consultant` | Generate | x |
| `--tier <role>=<tier>` | All | x |
| `--max-iterations N` | All | x |
EOF
set +e
out=$("$SCRIPT" "$T4" 2>/dev/null); ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: missing-table expected exit 1, got $ec"; exit 1; }
echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(x.get('subcheck')=='model-override-role-table' for x in d)" \
  || { echo "FAIL: missing role-table subcheck not fired"; exit 1; }
echo "PASS: missing role table → role-table subcheck fires"

# ── Fixture 5: CLI section present but missing --no-consultant row ──
T5="$TMP/missing-flag"
mkdir -p "$T5"
cat > "$T5/SKILL.md" <<'EOF'
---
name: x
version: 1.0.0
description: "Use when ..."
---

## Model Tiers
### Per-dispatch model override

| Role | Default tier | Agent-tool `model` value |
|---|---|---|
| writer | balanced | sonnet |

## CLI Flags

| Flag | Applies to | Semantics |
|---|---|---|
| `--full` | --review | x |
| `--tier <role>=<tier>` | All | x |
| `--max-iterations N` | All | x |
EOF
set +e
out=$("$SCRIPT" "$T5" 2>/dev/null); ec=$?
set -e
[ "$ec" = "1" ] || { echo "FAIL: missing --no-consultant expected exit 1, got $ec"; exit 1; }
echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert any(x.get('subcheck')=='cli-flags-required-rows' for x in d)" \
  || { echo "FAIL: cli-flags-required-rows subcheck not fired"; exit 1; }
echo "PASS: missing --no-consultant row → cli-flags-required-rows subcheck fires"

# ── Fixture 6: missing target dir → exit 2 ──
set +e
"$SCRIPT" /nonexistent-$$ >/dev/null 2>&1; ec=$?
set -e
[ "$ec" = "2" ] || { echo "FAIL: missing target expected exit 2, got $ec"; exit 1; }
echo "PASS: missing target → exit 2"

echo "=== PASS test-check-skill-md-sections.sh (6 sub-tests) ==="
