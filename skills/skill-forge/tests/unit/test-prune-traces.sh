#!/usr/bin/env bash
# test-prune-traces.sh — unit tests for prune-traces.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../scripts" && pwd)"
SCRIPT="${SCRIPTS_DIR}/prune-traces.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Assert executable ---
if [ -x "$SCRIPT" ]; then
  pass "prune-traces.sh exists and is executable"
else
  fail "prune-traces.sh not found or not executable"
fi

# --- Create fake target with 30 round directories ---
TMPDIR_TARGET=$(mktemp -d)
mkdir -p "${TMPDIR_TARGET}/common"

cleanup() {
  rm -rf "$TMPDIR_TARGET"
}
trap cleanup EXIT

TRACES_DIR="${TMPDIR_TARGET}/.review/traces"

for i in $(seq 1 30); do
  RDIR="${TRACES_DIR}/round-${i}"
  mkdir -p "$RDIR"
  # Create dummy yml files
  echo "data: round-${i}" > "${RDIR}/data.yml"
  echo "state: round-${i}" > "${RDIR}/state.yml"
  # Create dispatch-log.jsonl (must survive pruning)
  echo '{"event":"round_start"}' > "${RDIR}/dispatch-log.jsonl"
done

# Run with retention=20 (rounds 1-10 should be pruned, 11-30 kept)
set +e
OUTPUT=$("$SCRIPT" "$TMPDIR_TARGET" 20 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -eq 0 ]; then
  pass "prune-traces.sh exits 0 with retention=20"
else
  fail "prune-traces.sh should exit 0; got $EXIT_CODE; output: $OUTPUT"
fi

# Check rounds 1-10 yml files are deleted
PRUNED_OK=true
for i in $(seq 1 10); do
  RDIR="${TRACES_DIR}/round-${i}"
  if [ -f "${RDIR}/data.yml" ] || [ -f "${RDIR}/state.yml" ]; then
    PRUNED_OK=false
    break
  fi
done
if [ "$PRUNED_OK" = "true" ]; then
  pass "rounds 1-10 yml files deleted"
else
  fail "rounds 1-10 yml files should be deleted (cutoff=10)"
fi

# Check rounds 1-10 dispatch-log.jsonl are PRESERVED
DISPATCH_OK=true
for i in $(seq 1 10); do
  RDIR="${TRACES_DIR}/round-${i}"
  if [ ! -f "${RDIR}/dispatch-log.jsonl" ]; then
    DISPATCH_OK=false
    break
  fi
done
if [ "$DISPATCH_OK" = "true" ]; then
  pass "dispatch-log.jsonl preserved in pruned rounds 1-10"
else
  fail "dispatch-log.jsonl should be preserved in pruned rounds"
fi

# Check rounds 11-30 yml files are NOT deleted
KEPT_OK=true
for i in $(seq 11 30); do
  RDIR="${TRACES_DIR}/round-${i}"
  if [ ! -f "${RDIR}/data.yml" ]; then
    KEPT_OK=false
    break
  fi
done
if [ "$KEPT_OK" = "true" ]; then
  pass "rounds 11-30 yml files kept"
else
  fail "rounds 11-30 should be kept"
fi

# --- Idempotent: run again, same result ---
set +e
"$SCRIPT" "$TMPDIR_TARGET" 20 >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "prune-traces.sh is idempotent (second run exits 0)"
else
  fail "second run should exit 0; got $EXIT_CODE"
fi

# --- No traces dir -> exit 0 ---
TMPDIR_EMPTY=$(mktemp -d)
set +e
"$SCRIPT" "$TMPDIR_EMPTY" 20 >/dev/null 2>&1
EXIT_CODE_EMPTY=$?
set -e
rm -rf "$TMPDIR_EMPTY"
if [ "$EXIT_CODE_EMPTY" -eq 0 ]; then
  pass "no traces dir -> exit 0"
else
  fail "no traces dir should exit 0; got $EXIT_CODE_EMPTY"
fi

# --- Non-existent target -> exit 2 ---
set +e
"$SCRIPT" "/nonexistent" >/dev/null 2>&1
EXIT_CODE=$?
set -e
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "non-existent target -> exit 2"
else
  fail "non-existent target should exit 2; got $EXIT_CODE"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
