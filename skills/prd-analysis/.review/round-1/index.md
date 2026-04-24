---
round: 1
delivery_id: 1
open_issues: 11
resolved_this_round: 0
regressed_count: 0
critical_count: 0
error_count: 11
warning_count: 0
coverage_percent: 100
skip_set_utilization: 100%
writer_fail_count_sum: 0
---

# Round 1 Review Summary

Round 1 is the first review round of delivery 1 (first delivery; no prior baseline).
The round-checker swept all 46 target leaves (single-file-focus count == cross-reviewer-focus
count == 46; both unions complete, zero skips), giving full 100% coverage with 100%
skip-set utilization. Forced-full mode was off; the depgraph-driven focus selection
happened to converge on the full leaf set because every leaf was touched or produced
this round.

Ten writer dispatches all returned `OK ... self_review_status=FULL_PASS fail_count=0`,
so `writer_fail_count_sum = 0`. No scope-external conflicts were surfaced from the
writer tier.

The cross-reviewer and script tier together filed 11 issues, all with
`status: new` (no prior round to carry state from), all at `severity: error`
(no critical, no warning). Every issue is bound to `common/review-criteria.md`
via the meta-criterion `CR-META-missing-checker`: the criteria file lists
inline-`script` checks that reference checker scripts not present under `scripts/`.
The missing scripts referenced are: `check-leaf-size.sh` (x2), `check-id-format.sh`
(x2), `check-module-refs.sh`, `check-slug-naming.sh`, `check-template-sections.sh`,
`check-cross-refs.sh`, `check-artifact-nudity.sh`, `check-revisions-log.sh`,
`check-wikilinks.sh`. Resolution requires either implementing the missing
checker scripts or rewriting the affected criteria to use a different
evaluation mechanism — a decision the judge and (if needed) the reviser loop
will route in the next phase.

Because this is the first round of the first delivery, `resolved_this_round`
and `regressed_count` are both 0 by definition. Status trend baseline is
established with this round; subsequent rounds will measure resolution and
regression deltas against these 11 open issues.
