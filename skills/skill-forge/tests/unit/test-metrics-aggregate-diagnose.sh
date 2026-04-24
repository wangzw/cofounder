#!/usr/bin/env bash
# test-metrics-aggregate-diagnose.sh
# Exercises --diagnose on a canned .review/ fixture and asserts:
#   - idempotency (content stable across repeat runs, except `generated_at`)
#   - absolute `pricing_source`
#   - no `unattributed_harness_events` field (intentionally removed — that count
#     grows with the orchestrator's own session activity and breaks idempotency)
#   - no yaml parser warnings on stderr (hitl.require_approval list is now parsed)
#   - error exits on invalid scope / missing review-dir
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/metrics-aggregate.sh"
CONFIG="$HERE/../../common/config.yml"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
[ -f "$CONFIG" ] || { echo "FAIL: config missing: $CONFIG"; exit 1; }

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# --- Build a minimal review fixture ---
REVIEW="$TMP/.review"
mkdir -p "$REVIEW/traces/round-1" "$REVIEW/metrics"
cat >> "$REVIEW/traces/round-1/dispatch-log.jsonl" <<'JSONL'
{"event":"launched","trace_id":"R1-W-001","role":"writer","reviewer_variant":null,"tier":"balanced","model":"claude-sonnet-4-5","delivery_id":1,"dispatched_at":"2026-04-24T10:00:00Z","prompt_hash":"sha256:abc","linked_issues":[]}
{"event":"completed","trace_id":"R1-W-001","role":"writer","ack_status":"OK","linked_issues":[],"returned_at":"2026-04-24T10:01:00Z","self_review_status":"FULL_PASS","fail_count":0}
JSONL

DIAG() {
  # Empty harness dir → JOIN coverage is 0 → script exits 3 (documented — see
  # SKILL.md §--diagnose exit-code table). Output YAML is still written. Tests
  # below care about YAML shape + idempotency; swallow exit 3 here so callers
  # can continue. Real errors (1/2) are surfaced by the explicit exit-code
  # tests below.
  local ec=0
  bash "$SCRIPT" --diagnose "$@" --review-dir "$REVIEW" --config "$CONFIG" \
    --harness-dir "$TMP/empty-harness" || ec=$?
  [ "$ec" = "0" ] || [ "$ec" = "3" ] || return "$ec"
  return 0
}
mkdir -p "$TMP/empty-harness"  # empty → no events to join (expected for fixture)

# --- Test 1: --round 1 succeeds and writes round-1.metrics.yml ---
DIAG --round 1 >/dev/null 2>&1
[ -f "$REVIEW/metrics/round-1.metrics.yml" ] || { echo "FAIL: round-1.metrics.yml not written"; exit 1; }
echo "PASS: --round 1 writes round-1.metrics.yml"

# --- Test 2: repeat run produces byte-identical content modulo generated_at ---
h1=$(grep -v "^generated_at:" "$REVIEW/metrics/round-1.metrics.yml" | sha256sum | awk '{print $1}')
DIAG --round 1 >/dev/null 2>&1
h2=$(grep -v "^generated_at:" "$REVIEW/metrics/round-1.metrics.yml" | sha256sum | awk '{print $1}')
[ "$h1" = "$h2" ] || { echo "FAIL: round-1 not idempotent (h1=$h1 h2=$h2)"; exit 1; }
echo "PASS: --round 1 idempotent across repeat runs"

# --- Test 3: --delivery 1 idempotent ---
DIAG --delivery 1 >/dev/null 2>&1
h1=$(grep -v "^generated_at:" "$REVIEW/metrics/delivery-1.metrics.yml" | sha256sum | awk '{print $1}')
DIAG --delivery 1 >/dev/null 2>&1
h2=$(grep -v "^generated_at:" "$REVIEW/metrics/delivery-1.metrics.yml" | sha256sum | awk '{print $1}')
[ "$h1" = "$h2" ] || { echo "FAIL: --delivery 1 not idempotent"; exit 1; }
echo "PASS: --delivery 1 idempotent"

# --- Test 4: pricing_source is absolute path ---
src=$(grep "^pricing_source:" "$REVIEW/metrics/delivery-1.metrics.yml" | awk '{print $2}')
case "$src" in
  /*) echo "PASS: pricing_source is absolute ($src)" ;;
  *)  echo "FAIL: pricing_source not absolute: $src"; exit 1 ;;
esac

# --- Test 5: unattributed_harness_events field removed (non-deterministic) ---
if grep -q "unattributed_harness_events" "$REVIEW/metrics/delivery-1.metrics.yml"; then
  echo "FAIL: unattributed_harness_events still present (should be removed)"
  exit 1
fi
echo "PASS: unattributed_harness_events removed"

# --- Test 6: required join_stats fields present ---
for key in dispatched_traces unmatched_dispatches unmatched_ratio; do
  grep -q "^  ${key}:" "$REVIEW/metrics/delivery-1.metrics.yml" \
    || { echo "FAIL: missing join_stats.${key}"; exit 1; }
done
echo "PASS: join_stats schema intact"

# --- Test 7: no yaml parser warnings on stderr (hitl list now parses) ---
err=$(DIAG --delivery 1 2>&1 >/dev/null)
if echo "$err" | grep -q "yaml_load: dropped"; then
  echo "FAIL: yaml_load warnings on stderr:"
  echo "$err" | grep "yaml_load:"
  exit 1
fi
echo "PASS: no yaml_load warnings"

# --- Test 8: invalid --round exits 2 ---
set +e
DIAG --round 99 >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "2" ] || { echo "FAIL: invalid --round expected exit 2, got $ec"; exit 1; }
echo "PASS: invalid --round exits 2"

# --- Test 9: missing review-dir exits 2 ---
set +e
bash "$SCRIPT" --diagnose --review-dir /tmp/no-such-diag-$$ --delivery 1 --config "$CONFIG" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "2" ] || { echo "FAIL: missing review-dir expected exit 2, got $ec"; exit 1; }
echo "PASS: missing review-dir exits 2"

# --- Test 10: --dry-run doesn't modify the metrics file ---
before=$(stat -f %m "$REVIEW/metrics/delivery-1.metrics.yml" 2>/dev/null || stat -c %Y "$REVIEW/metrics/delivery-1.metrics.yml")
DIAG --delivery 1 --dry-run >/dev/null 2>&1
after=$(stat -f %m "$REVIEW/metrics/delivery-1.metrics.yml" 2>/dev/null || stat -c %Y "$REVIEW/metrics/delivery-1.metrics.yml")
[ "$before" = "$after" ] || { echo "FAIL: --dry-run modified the file"; exit 1; }
echo "PASS: --dry-run leaves file untouched"

# --- Test 11: trace_id hint survives tool_result `user` turns ---
# Regression guard for Bug #14 — Claude Code sub-agent transcripts log
# tool_result returns as `type: "user"` per the Anthropic API protocol.
# Invalidating the hint on such turns caused primary JOIN to drop ~95% of
# assistant events in real sub-agent sessions and under-reported total cost
# to near-zero.
HARNESS2="$TMP/harness-tool-result"
mkdir -p "$HARNESS2"
cat > "$HARNESS2/sub-agent.jsonl" <<'JSONL'
{"type":"user","message":{"content":[{"type":"text","text":"trace_id: R1-W-001\n\nYou are the writer…"}]}}
{"type":"assistant","timestamp":"2026-04-24T10:00:10Z","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":10,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":20000}}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"file contents"}]}}
{"type":"assistant","timestamp":"2026-04-24T10:00:20Z","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":5,"output_tokens":30,"cache_read_input_tokens":20000,"cache_creation_input_tokens":500}}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","content":"more contents"}]}}
{"type":"assistant","timestamp":"2026-04-24T10:00:30Z","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":3,"output_tokens":20,"cache_read_input_tokens":20500,"cache_creation_input_tokens":100}}}
JSONL

REVIEW2="$TMP/.review-tool-result"
mkdir -p "$REVIEW2/traces/round-1" "$REVIEW2/metrics"
cat > "$REVIEW2/traces/round-1/dispatch-log.jsonl" <<'JSONL'
{"event":"launched","trace_id":"R1-W-001","role":"writer","reviewer_variant":null,"tier":"balanced","model":"claude-sonnet-4-5","delivery_id":1,"dispatched_at":"2026-04-24T10:00:00Z","prompt_hash":"sha256:abc","linked_issues":[]}
{"event":"completed","trace_id":"R1-W-001","role":"writer","ack_status":"OK","linked_issues":[],"returned_at":"2026-04-24T10:01:00Z","self_review_status":"FULL_PASS","fail_count":0}
JSONL

set +e
bash "$SCRIPT" --diagnose --round 1 \
  --review-dir "$REVIEW2" --config "$CONFIG" \
  --harness-dir "$HARNESS2" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" = "0" ] || { echo "FAIL: tool_result fixture expected exit 0, got $ec"; exit 1; }

# All 3 assistant events attributed via primary JOIN (not fallback) → total_usd
# reflects all 3 turns' tokens, not just the first.
usd=$(grep '^  total_usd:' "$REVIEW2/metrics/round-1.metrics.yml" | awk '{print $2}')
unmatched=$(grep 'unmatched_dispatches:' "$REVIEW2/metrics/round-1.metrics.yml" | awk '{print $2}')
[ "$unmatched" = "0" ] || { echo "FAIL: expected unmatched_dispatches=0, got $unmatched"; exit 1; }
# Sum of tokens: input=18, output=100, cache_read=40500, cache_creation=20600
# At sonnet-4 pricing: 18*3e-6 + 100*15e-6 + 40500*0.3e-6 + 20600*3.75e-6 = $0.0905
# Verify total_usd > $0.08 (would be ~$0.025 if only first turn attributed)
python3 -c "import sys; sys.exit(0 if float('$usd') > 0.08 else 1)" \
  || { echo "FAIL: total_usd=$usd looks like only 1/3 turns attributed (Bug #14 regression?)"; exit 1; }
echo "PASS: trace_id hint persists across tool_result user turns (Bug #14)"

echo "=== PASS test-metrics-aggregate-diagnose.sh (11 sub-tests) ==="
