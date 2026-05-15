#!/usr/bin/env bash
# Self-test for migrate-delivery-tags.sh.
# Builds a temp repo with synthetic prd / design / ambiguous delivery tags
# and verifies the rename behavior.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE="$SCRIPT_DIR/migrate-delivery-tags.sh"

FIXTURE=$(mktemp -d -t migrate-tag-test.XXXXXX)
trap 'rm -rf "$FIXTURE"' EXIT

cd "$FIXTURE"
git init -q
git config user.email t@t
git config user.name t
git commit --allow-empty -q -m "init"

# 1) prd-analysis-style delivery: changes under docs/raw/prd/
mkdir -p docs/raw/prd/2026-05-01-foo
echo "prd-content-1" > docs/raw/prd/2026-05-01-foo/README.md
git add docs/raw/prd/2026-05-01-foo/README.md
git commit -q -m "feat(2026-05-01-foo): delivery-1: initial PRD"
git tag -a delivery-1-initial-prd -m "delivery 1: initial PRD"

# 2) system-design-style delivery: changes under docs/raw/design/
mkdir -p docs/raw/design/2026-05-02-foo
echo "design-content-1" > docs/raw/design/2026-05-02-foo/README.md
git add docs/raw/design/2026-05-02-foo/README.md
git commit -q -m "feat(2026-05-02-foo): delivery-1: initial design"
git tag -a delivery-1-initial-design -m "delivery 1: initial design"

# 3) ambiguous delivery: changes neither under prd nor design
mkdir -p other
echo "other-content" > other/file.txt
git add other/file.txt
git commit -q -m "chore: unrelated"
git tag -a delivery-1-ambiguous -m "ambiguous"

# 4) target-exists case: pre-create the would-be new tag
mkdir -p docs/raw/prd/2026-05-03-bar
echo "prd-content-2" > docs/raw/prd/2026-05-03-bar/README.md
git add docs/raw/prd/2026-05-03-bar/README.md
git commit -q -m "feat(2026-05-03-bar): delivery-2"
git tag -a delivery-2-bar -m "delivery 2 bar"
# pre-create the would-be target
git tag prd-analysis-delivery-2-bar HEAD

# 5) already-namespaced tag: must be ignored
echo "noise" >> docs/raw/prd/2026-05-03-bar/README.md
git add docs/raw/prd/2026-05-03-bar/README.md
git commit -q -m "feat(2026-05-03-bar): delivery-3"
git tag -a prd-analysis-delivery-3-already-renamed -m "already renamed"

# Run the migration
output=$("$MIGRATE" --repo "$FIXTURE" 2>&1)
rc=$?
printf '%s\n' "$output"

ok=1
[ "$rc" = 0 ] || { echo "FAIL: exit was $rc"; ok=0; }

# Asserts
git -C "$FIXTURE" rev-parse "prd-analysis-delivery-1-initial-prd" >/dev/null 2>&1 \
  && echo "PASS: prd tag renamed" \
  || { echo "FAIL: prd tag not renamed"; ok=0; }

git -C "$FIXTURE" rev-parse "system-design-delivery-1-initial-design" >/dev/null 2>&1 \
  && echo "PASS: design tag renamed" \
  || { echo "FAIL: design tag not renamed"; ok=0; }

git -C "$FIXTURE" rev-parse "delivery-1-ambiguous" >/dev/null 2>&1 \
  && echo "PASS: ambiguous tag preserved" \
  || { echo "FAIL: ambiguous tag was deleted"; ok=0; }

# Original prd / design tags must be gone
git -C "$FIXTURE" rev-parse "delivery-1-initial-prd" >/dev/null 2>&1 \
  && { echo "FAIL: old prd tag still exists"; ok=0; } \
  || echo "PASS: old prd tag deleted"

git -C "$FIXTURE" rev-parse "delivery-1-initial-design" >/dev/null 2>&1 \
  && { echo "FAIL: old design tag still exists"; ok=0; } \
  || echo "PASS: old design tag deleted"

# target-exists case: old delivery-2-bar must STILL exist (skipped)
git -C "$FIXTURE" rev-parse "delivery-2-bar" >/dev/null 2>&1 \
  && echo "PASS: target-exists skip preserved old tag" \
  || { echo "FAIL: old tag removed despite target-exists"; ok=0; }

# already-namespaced: untouched
git -C "$FIXTURE" rev-parse "prd-analysis-delivery-3-already-renamed" >/dev/null 2>&1 \
  && echo "PASS: already-renamed tag untouched" \
  || { echo "FAIL: already-renamed tag missing"; ok=0; }

# Idempotence: second run should be a no-op (zero candidates)
output2=$("$MIGRATE" --repo "$FIXTURE" 2>&1)
echo "$output2" | grep -q "no legacy 'delivery-<N>-<slug>' tags found" \
  && echo "PASS: idempotent re-run reports nothing to do" \
  || {
    # delivery-1-ambiguous and delivery-2-bar are still legacy form,
    # so the script will see candidates again — but ambiguous + target-exists
    # are skipped, so no rename. We accept either of two outputs:
    if echo "$output2" | grep -q "renamed:          0"; then
      echo "PASS: idempotent re-run made no changes"
    else
      echo "FAIL: idempotence broken (unexpected re-run output)"
      printf '%s\n' "$output2"
      ok=0
    fi
  }

[ "$ok" = 1 ] && { echo ""; echo "ALL PASS"; exit 0; } || { echo ""; echo "FAILURES"; exit 1; }
