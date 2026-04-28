---
id: R9-001-resolved
round: 10
file: review/index.md
criterion_id: CR-L11
severity: error
source: cross-reviewer
reviewer_variant: cross
status: resolved
resolves: R9-001
---

# R9-001 resolved: review/index.md no longer carries stale CR-count ranges

## Verification

Round-9 reviser rewrote the three lines R9-001 flagged. Current `review/index.md`
content at the three locations:

1. **Line 20** — Phase B description now reads:

   ```
   - **Phase B**: runs all script-type checkers (every entry with `checker_type: script` in `common/review-criteria.md`) against the target tree;
   ```

   The stale `12 script-type checkers (CR-S01..CR-S12)` phrasing is gone. The
   replacement uses the namespace-based phrasing R9-001 suggested verbatim
   (`every entry with checker_type: script in common/review-criteria.md`),
   which floats automatically with the criteria namespace and survives further
   additions (CR-S13..CR-S17 already present, future CR-S18+ would also remain
   in scope without re-editing).

2. **Lines 67-70** — Step 3 cross-reviewer dispatch sub-agent inputs now read:

   ```
   - **Sub-agent inputs**: leaves listed in `skip-set.yml cross_reviewer_focus`, previous-round issue
     frontmatter from `round-<N-1>/issues/`, writer self-review files at
     `<target>/.review/round-<N>/self-reviews/`, and `common/review-criteria.md`
     (every entry with `checker_type: llm`).
   ```

   The stale `CR-L01..CR-L10` parenthetical is gone. The replacement
   `(every entry with checker_type: llm)` is namespace-based, exactly as R9-001
   suggested. CR-L11 (the criterion under which R9-001 itself was filed) and
   any future CR-L12+ are now correctly in documented scope.

3. **Line 128** — "Files in This Directory" entry now reads:

   ```
   - [cross-reviewer-subagent.md](cross-reviewer-subagent.md) — Cross-reviewer sub-agent prompt (all LLM-type criteria — `checker_type: llm` in `common/review-criteria.md`)
   ```

   The stale `LLM-type criteria CR-L01..CR-L10` phrasing is gone. The
   replacement is namespace-based and consistent with the line-69 dispatch
   description, eliminating the within-file inconsistency R9-001 also flagged.

(Note: the original R9-001 issue body cited "Line 127" for the third location;
after the round-9 reviser rewrite the corresponding text now sits at line 128
because the file's blank-line structure shifted by one. The semantic location —
the cross-reviewer-subagent.md entry under "Files in This Directory" — is
unchanged, and the stale range is gone there.)

## Class-based scan (CR-L11)

`grep -n -E "CR-(L|S)[0-9]+|CR-(L|S)0[0-9]\.\.|[0-9]+ (LLM|script)|11 LLM|10 LLM|12 script|17 script|CR-PP[0-9]+" review/index.md`
returns **zero hits**. The file no longer contains any frozen CR-ID range,
numeric checker count, or count-tied criterion family reference. Every
criteria reference uses the floating namespace form (`checker_type: script`
or `checker_type: llm`).

I also scanned for stale file-path references (`scripts/run-checkers.sh`,
`scripts/check-drift.sh`, `scripts/commit-delivery.sh`, `revise/index.md`,
`common/review-criteria.md`, `common/snippets.md`, `review/cross-reviewer-subagent.md`,
`review/adversarial-reviewer-subagent.md`, `shared/summarizer-subagent.md`,
`shared/judge-subagent.md`) — all 10 cited paths exist in the target tree.
No path drift.

Guide section references (`§8.5`, `§8.6`, `§16`) are consistent with
peer leaves (`SKILL.md`, `common/snippets.md`, `shared/summarizer-subagent.md`,
`shared/judge-subagent.md`, `review/cross-reviewer-subagent.md`) — same
section-numbering convention across the bundle.

`config.yml` reference at line 118 (`config.yml adversarial_review.triggered_by`)
uses the bare-form convention also used in `revise/index.md` line 59 and
`SKILL.md` line 283 — peer-consistent, not drift. (The qualified form
`common/config.yml` appears elsewhere in `SKILL.md` lines 241/248/256/302,
but the mixed usage is a stable bundle-wide convention pre-dating round-9
and not in scope for CR-L11 this round.)

## Status

`resolved` — R9-001's three stale CR-count ranges are all gone, replaced
with the exact namespace-based phrasings the issue's "Suggested fix"
section recommended. No same-class regression detected in the round-10
class scan. No new CR-L11 defects in `review/index.md` for this round.
