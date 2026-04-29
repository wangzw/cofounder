# Revise Mode — Orchestration

Loaded by the orchestrator when `--revise` is invoked, or when review-mode
Step 2 short-circuits with formal failures. Defines the revise loop. Per
[~/Documents/mind/raw/guide/生成式skill的审查设计.md](../../../../Documents/mind/raw/guide/生成式skill的审查设计.md):

- §7.2 — issue state machine: `new` → {fixed | false-positive | deferred | superseded}
- §7.3 — `check-revise-completeness.sh` is the exit gate
- §7.4 — revise can run repeatedly within the same round until the gate
  passes
- §7.5 — recurrence handling per state
- §7.7 — quality-at-delivery ratio signals

This file is **orchestration**, not a sub-agent prompt.

---

## Revise Loop — Step by Step

### Step 1 — Build Issue-Group Manifest (script)

The orchestrator reads `<prd-dir>/.review/round-<N>/issues/*.md` and groups
them by `file:` field. Issues whose `state` is already in
{fixed, false-positive, deferred, superseded} are skipped — only `state: new`
needs work.

The grouping logic is mechanical (frontmatter-only inspection); the
orchestrator does it inline rather than via a separate script. Output is
held in `state.yml` as:

```yaml
revise_groups:
  - leaf: features/F-001-checkout.md
    issues: [I-007, I-012]
  - leaf: features/F-002-cart.md
    issues: [I-008]
  - leaf: ""    # repo-wide issues
    issues: [I-014]
```

If no `state: new` issues remain, jump directly to Step 5.

### Step 2 — Fan-out Per-Issue-Reviser (parallel)

For each entry in `revise_groups`, dispatch one
`revise/per-issue-reviser-subagent.md` with:

- The leaf path
- The full text of every issue in that group (from
  `<prd-dir>/.review/round-<N>/issues/<id>.md`)
- The current content of the leaf
- `<prd-dir>/.review/issues/summary.yml` — for any `recurrence_of`
  reference, the reviser reads `fix_history` to see how the prior
  attempt(s) failed (guide §7.5.1)

**Reviser is allowed to** edit the leaf, then transition each issue's
`state:` field. Permitted state transitions (guide §7.2):

| from | to | required metadata |
|------|----|-------------------|
| new | fixed | (verify formal pass; see Step 3) |
| new | false-positive | `dismissed_reason` non-empty |
| new | deferred | `defer_until` + `defer_reason` non-empty |
| new | superseded | `superseded_by` referencing another issue id |

The reviser MUST NOT silently leave an issue at `state: new` while
claiming to have addressed it. Any such issue is caught by the gate in
Step 4.

**Reviser is forbidden to** edit `history` or `fix_history`; those are
maintained by `update-summary.sh` (Step 5).

### Step 3 — Self-Verify Formal Pass (writer self-loop, no issues created)

After each reviser finishes, the orchestrator re-runs

```bash
scripts/run-checkers.sh <prd-dir>
```

Per guide §4 + §4.1, formal failures discovered here are NOT filed as new
issues — the reviser is dispatched again on the affected leaf with the
formal-checker's JSON output and is expected to fix the structural problem
in place. This loop continues until either:

- formal pass (exit 0) — proceed to Step 4
- 3 consecutive formal failures on the same leaf — escalate to HITL with
  the leaf path and the failing CR-IDs (per guide §4.1 last paragraph,
  this is the only time a self-audit failure becomes a real issue)

### Step 4 — Phase Gate: revise completeness

```bash
scripts/check-revise-completeness.sh <prd-dir> <round-number>
```

Exit 0 → all issues this round have left `state: new`; proceed.
Exit 1 → at least one issue still in `state: new`; loop back to Step 2 for
the affected groups (guide §7.4 allows revise to repeat until the gate
passes). After 3 such iterations, escalate to HITL.
Exit 2 → script error; HITL.

### Step 5 — Update Summary

```bash
scripts/update-summary.sh <prd-dir>
```

Refreshes `summary.yml` with the new issue states. Cross-reviewer in the
next review round will read this for fingerprint matching.

### Step 6 — Summarizer (update-state phase)

Dispatch `shared/summarizer-subagent.md` to write the updated round-N
index with state transitions and ratio signals (guide §7.7):

- `false_positive_ratio` = (false-positive count) / (total this round)
- `deferred_ratio` = (deferred count) / (total this round)
- `regression_count` = issues whose state went `fixed` → `new` between
  rounds (caught via `recurrence_count`)

Default thresholds (overridable in `config.yml`):

| Signal | Threshold | Action |
|--------|-----------|--------|
| `false_positive_ratio` | > 0.5 | warn — reviewer prompt or criteria likely off |
| `deferred_ratio` | > 0.7 | warn — writer is deferring instead of fixing |
| critical/error issue with `defer_until: never` | any | error — must be in `versions/<N>.md.justified_regressions` |

These are quality-at-delivery signals. The judge consumes them in Step 7.

### Step 7 — Judge Dispatch

Dispatch `shared/judge-subagent.md`. Verdict considers:

- The Step 5 summary (issue counts, severities, state distribution)
- Ratio signals from Step 6
- Recurrence counts for any `recurrence_of` matches

Verdict routing is identical to review/index.md Step 8.

---

## Notes

- The orchestrator does NOT read leaf content — it routes on ACKs and
  scripts only (orchestrator dispatch contract).
- Round numbers are monotonic. If Step 4 passes, the round closes; the
  next review pass increments N.
- Skeleton-protected files: removed concept. With `skill-forge` deleted,
  the artifact is the PRD bundle which has no skeleton. Every leaf is
  authored.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) —
  per-leaf reviser sub-agent prompt
- [revise-mode.md](revise-mode.md) — separate concern: interactive PRD
  change-management mode (e.g. add a feature to a delivered PRD); not
  loaded by `--revise` review-revise loop.
