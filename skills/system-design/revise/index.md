# Revise Mode — Orchestration

Loaded by the orchestrator when `--revise` is invoked, or when review-mode
Step 1 (verify-phase-entry) short-circuits with formal failures. Defines
the revise loop. Per
[~/Documents/mind/raw/guide/生成式skill的审查设计.md](../../../../Documents/mind/raw/guide/生成式skill的审查设计.md):

- §7.2 — issue state machine: `new` → {fixed | false-positive | deferred | superseded}
- §7.3 — `check-revise-completeness.sh` is the exit gate
- §7.4 — revise can run repeatedly within the same round until the gate
  passes
- §7.5 — recurrence handling per state
- §7.7 — quality-at-delivery ratio signals

Revise mode is a **write phase** of the alternating write/read cycle
defined in `SKILL.md` "Phase Contract". This file enforces the
write-phase exit gate's two clauses:

1. **State-machine PASS** (Step 5) — no issue is left in `state: new`
   in the current round; every issue has been dispositioned.
2. **Formal PASS** (Step 4 self-loop, plus the next read phase's
   Step 1 verify-phase-entry) — the bundle passes `run-checkers.sh`.

If either clause fails, the revise phase loops; it MUST NOT ACK as
done with violations outstanding. Only when both clauses PASS does
control pass back to the read phase (review mode) for the next round.

This file is **orchestration**, not a sub-agent prompt.

---

## Revise Loop — Step by Step

### Step 1 — MANDATORY: Phase Entry Verification (script-enforced)

**This MUST be the first action of the revise (write) phase. The
orchestrator MUST NOT proceed past this script on a non-zero exit.**

```bash
scripts/verify-phase-entry.sh revise <design-dir> <round>
```

Verifies the revise-phase entry precondition: round-N's issues
directory exists AND contains at least one `state: new` issue.

| Exit | Meaning | Next action |
|------|---------|-------------|
| 0    | At least one `state: new` issue in round-N — revise has work to do | continue to Step 2 (build issue-group manifest) |
| 1    | Round dir missing OR no `state: new` issues | revise phase has nothing to do; return control to caller (typically a no-op handoff back to read phase). The orchestrator MUST NOT fan out per-issue revisers. |
| 2    | Script-level error | HITL — do not modify the artifact |

Why this is the first step: prevents the revise phase from being
invoked on an empty or mis-numbered round. The script makes the
precondition unskippable — control cannot reach reviser dispatch
without `verify-phase-entry` having exited 0.

### Step 2 — Build Criterion-Cluster Manifest

The orchestrator reads `<design-dir>/.review/round-<N>/issues/*.md` and
groups them **by `criterion_id:` field** (NOT by `file:` — that was the
prior model). Issues whose `state` is already in
{fixed, false-positive, deferred, superseded} are skipped — only
`state: new` needs work.

The grouping logic is mechanical (frontmatter-only inspection); the
orchestrator does it inline rather than via a separate script. Each
cluster covers ONE `criterion_id` and AT MOST
`common/config.yml revise.edit_cap` issues (default 8). When a criterion
has more than `edit_cap` issues, the orchestrator splits it into multiple
clusters; each cluster gets a distinct `cluster_id` (`R<round>-CC-<nnn>`).
Output is held in `state.yml` as `revise_clusters:`:

```yaml
revise_clusters:
  - cluster_id: R3-CC-001
    criterion_id: CR-SD-DESIGN01
    category: module-boundary
    issues: [I-007, I-019, I-024]
    affected_leaves: [modules/M-001-auth.md, modules/M-004-billing.md, modules/M-007-notifications.md]
  - cluster_id: R3-CC-002
    criterion_id: CR-SD-DESIGN06
    category: failure-modes
    issues: [I-012, I-031]
    affected_leaves: [modules/M-001-auth.md, modules/M-005-orders.md]
```

It is **expected** that the same leaf appears in multiple clusters —
different revisers will Edit different sections of that leaf, with `Edit`'s
unique-match semantics providing the safety lock.

(Step 1's `verify-phase-entry revise` already guarantees at least one
`state: new` issue exists in the round, so the manifest is always
non-empty when we reach Step 2.)

### Step 3 — Fan-out Per-Criterion-Cluster Reviser (parallel)

For each entry in `revise_clusters`, dispatch one
`revise/per-issue-reviser-subagent.md` in a single assistant response
(`common/parallel-dispatch.md` Rule 1) with:

- `trace_id: R<round>-R-<NNN>`
- The cluster's `criterion_id` and `category`
- The full text of every issue in this cluster (from
  `<design-dir>/.review/round-<N>/issues/<id>.md`)
- The `affected_leaves` list (absolute paths from artifact root) — the
  reviser reads each leaf at processing time, not in advance
- `<design-dir>/.review/issues/summary.yml` — for any `recurrence_of`
  reference, the reviser reads `fix_history` to see how the prior
  attempt(s) failed (guide §7.5.1)
- The relevant section of `common/criterion-categories.md` for this
  category (typical fix pattern + anti-patterns)

The reviser **MUST use `Edit` only** (no `Write`) on artifact leaves.
Concurrency safety follows from `Edit`'s requirement that `old_string` be
unique; collisions surface as self-loop iterations in Step 4 rather than
silent overwrites.

**Reviser is allowed to** Edit any leaf listed in `affected_leaves`, then
transition each issue's `state:` field. Permitted state transitions
(guide §7.2, unchanged):

| from | to | required metadata |
|------|----|-------------------|
| new | fixed | (verify formal pass; see Step 4) |
| new | false-positive | `dismissed_reason` non-empty |
| new | deferred | `defer_until` + `defer_reason` non-empty |
| new | superseded | `superseded_by` referencing another issue id |

The reviser MUST NOT silently leave an issue at `state: new` while
claiming to have addressed it. Any such issue is caught by the gate in
Step 5.

**Reviser MUST append** to `history` (one row per state transition) and
**MAY append** to `fix_history` (one row per non-trivial fix per guide
§7.5.1). Reviser MUST NOT rewrite or delete prior history entries —
append-only. `update-summary.sh` (Step 6) reads but does not modify
these blocks; it propagates them verbatim into `summary.yml`.

### Step 4 — Self-Verify Formal Pass (writer self-loop, no issues created)

After all revisers in this iteration ACK, the orchestrator re-runs

```bash
scripts/run-checkers.sh <design-dir>
```

Per guide §4 + §4.1, formal failures discovered here are NOT filed as new
issues. **Re-dispatch is by failing leaf, not by criterion** — formal
problems often span multiple types, so leaf is the better re-dispatch unit
for self-loop. Each re-dispatched reviser sees:

- The failing leaf path
- The formal-checker's JSON output (failure rows scoped to this leaf)
- All (criterion, issue) pairs touching this leaf that have not yet reached
  a terminal state

The re-dispatched reviser **still uses `Edit`-only** (never `Write`). If a
formal failure can only be repaired by integrated rewriting (rare), the
reviser ACKs `FAIL trace_id=... reason=requires-write-not-edit` and the
orchestrator escalates to HITL. This loop continues until either:

- formal pass (exit 0) — proceed to Step 5
- 3 consecutive formal failures on the same leaf — escalate to HITL with
  the leaf path and the failing CR-IDs (per guide §4.1 last paragraph).
  Under `--auto`, the orchestrator instead appends an `auto_decision`
  block to `state.yml` with `verdict: formal_self_loop_exhausted`,
  `leaf`, and `failing_cr_ids` (schema in `review/index.md` Step 8),
  and exits non-zero (`1`).

### Step 5 — Phase Gate: revise completeness

```bash
scripts/check-revise-completeness.sh <design-dir> <round-number>
```

Exit 0 → all issues this round have left `state: new`; proceed.
Exit 1 → at least one issue still in `state: new`; loop back to Step 3 for
the affected groups (guide §7.4 allows revise to repeat until the gate
passes). After 3 such iterations, escalate to HITL. Under `--auto`,
the orchestrator instead appends an `auto_decision` block to
`state.yml` with `verdict: revise_completeness_exhausted` and
`stuck_issue_ids` (schema in `review/index.md` Step 8), and exits
non-zero (`1`).
Exit 2 → script error; HITL.

### Step 6 — Update Summary

```bash
scripts/update-summary.sh <design-dir>
```

Refreshes `summary.yml` with the new issue states. Cross-reviewer in the
next review round will read this for fingerprint matching.

### Step 7 — Summarizer (update-state phase)

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

These are quality-at-delivery signals. The judge consumes them in Step 8.

### Step 8 — Judge Dispatch

Dispatch `shared/judge-subagent.md`. Verdict considers:

- The Step 7 per-round index (issue counts, severities, state distribution); `summary.yml` from Step 6 is also read for cross-round oscillation history
- Ratio signals from Step 7
- Recurrence counts for any `recurrence_of` matches

Verdict routing is identical to review/index.md Step 8 (including
`--auto` semantics: HITL prompts are replaced by an `auto_decision`
block appended to `state.yml`, and the orchestrator exits non-zero on
non-converged terminal verdicts).

---

## Notes

- The orchestrator does NOT read leaf content — it routes on ACKs and
  scripts only (orchestrator dispatch contract).
- Round numbers are monotonic. If Step 5 passes, the round closes; the
  next review pass increments N.
- Skeleton-protected files: removed concept. With `skill-forge` deleted,
  the artifact is the system-design bundle which has no skeleton. Every
  leaf (`README.md`, `modules/*`, `api/*`) is authored.

---

## Files in This Directory

- [per-issue-reviser-subagent.md](per-issue-reviser-subagent.md) —
  per-leaf reviser sub-agent prompt
