<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# summarizer-subagent — Summarizer Role

Role: `summarizer` (`S` in trace_id). LIGHT-tier. Aggregates issue
frontmatter and self-review counts; produces the round index, version
summary on convergence, and CHANGELOG entry. Read-only against
frontmatter; never reads issue bodies or artifact leaves.

Two phases, dispatched independently by the orchestrator:

| Phase | When | Output |
|-------|------|--------|
| **per-round** | After all reviewers ACK; before the judge | `<artifact-root>/.review/round-<N>/index.md` |
| **on-converge** | After judge emits `verdict: converged` | `<artifact-root>/.review/versions/<N>.md` + CHANGELOG entry |

Check `state.yml phase` to determine which phase applies.

---

## Inputs (frontmatter only)

| Source | Purpose |
|--------|---------|
| `<artifact-root>/.review/round-<N>/issues/*.md` frontmatter | Per-issue counts by `state` and `severity`, recurrence detection |
| `<artifact-root>/.review/issues/summary.yml` | Cross-round history (read-only here; `update-summary.sh` is the only writer) |
| `<artifact-root>/.review/round-<N>/self-reviews/*.md` frontmatter | Writer `fail_count` and `self_review_status` |
| `<artifact-root>/.review/round-<N>/verdict.yml` (if exists) | Verdict reference (post-judge phase) |
| `<artifact-root>/.review/versions/<N-1>.md` (if exists) | Previous delivery's quality_at_delivery for trend |
| `<artifact-root>/.review/traces/round-<N>/dispatch-log.jsonl` | Latency, tier distribution, coverage |

**Forbidden**: reading issue bodies, artifact leaves, or any narrative
prose.

---

## Phase 1 — Per-Round Summary

Output: `<artifact-root>/.review/round-<N>/index.md`

```markdown
---
round: <N>
delivery_id: <D>

# Counts by state (sum to total_issues)
total_issues: <int>
new_count: <int>
fixed_count: <int>
false_positive_count: <int>
deferred_count: <int>
superseded_count: <int>

# Counts by severity (over total_issues, including all states)
critical_count: <int>
error_count: <int>
warning_count: <int>
info_count: <int>

# Quality-at-delivery signals (guide §7.7)
false_positive_ratio: <float, 0..1>     # false_positive_count / total_issues
deferred_ratio: <float, 0..1>            # deferred_count / total_issues
recurrence_count: <int>                  # number of issues with recurrence_of set

# Justified regressions (deferred critical/error issues with valid reason)
justified_regressions_ok: <bool>         # true iff every (severity ∈ {critical,error} AND state=deferred) has defer_until=never AND non-empty defer_reason
justified_regressions: []                # list of issue ids that fit that criterion

# Writer self-review aggregation (when applicable)
writer_dispatch_count: <int>
writer_fail_count_sum: <int>
writer_full_pass_count: <int>
---

# Round <N> Review Summary

<2-4 sentence prose summary: how many issues this round, what trended
how vs prior round, top criterion ids contributing to new findings.>

## State distribution

<small markdown table — state vs count>

## Recurrences (if recurrence_count > 0)

<bullet list of issues with recurrence_of set, listing their prior id
and recurrence_count>

## Open work for revise

<bullet list of issues with state: new, grouped by file, listing
criterion_id and severity>
```

**Counting rules**:

- Always count `state: new` ONLY for issues that are still open (i.e.
  not `state: fixed/false-positive/deferred/superseded`). The
  state machine is mutually exclusive — every issue is in exactly one
  state.
- `recurrence_count` counts how many issues have `recurrence_of:` set
  to a non-empty value, NOT the maximum recurrence depth.
- Severity counts are over **all** issues regardless of state, because
  `false_positive_ratio` and `deferred_ratio` need the full denominator.

---

## Phase 2 — On-Converge Delivery Record

Triggered only after `verdict: converged`. Three writes:

### Write 1 — Version summary

`<artifact-root>/.review/versions/<N>.md`

```markdown
---
delivery_id: <D>
round: <N>
git_sha: <from state.yml, injected by orchestrator>
verdict: converged
rounds_to_convergence: <N minus first round of this delivery>
previous_delivery: <D-1 or null>
quality_at_delivery:
  total_issues: <final-round total>
  new_count: 0
  fixed_count: <int>
  false_positive_count: <int>
  deferred_count: <int>
  recurrence_count: 0
  critical_count: 0
  error_count: 0
  false_positive_ratio: <float>
  deferred_ratio: <float>
  writer_fail_count_sum: 0
justified_regressions:
  - id: I-042
    severity: error
    defer_reason: "<copied from issue frontmatter>"
    defer_until: never
---

# Delivery <D> — Version Summary

**Change summary**: <one-sentence summary of what this delivery produced>

## Affected Leaves

<bullet list of leaves modified between this delivery and the previous
one — read from `state.yml` modified_leaves field>

## Control Signals

<any non-default config.yml flags or override flags active during this
delivery; usually empty>

## Justified Regressions

<expand the justified_regressions list; one paragraph per item
explaining why it is acceptable to ship with the issue deferred>
```

### Write 2 — CHANGELOG entry

Prepend (do not overwrite) to `<artifact-root>/CHANGELOG.md`:

```markdown
## <YYYY-MM-DD> Delivery <D> — round <N>

<one-sentence change summary>

- Total issues this delivery: <total_issues>
- Justified regressions: <count> (see `.review/versions/<N>.md`)
- Rounds to convergence: <rounds_to_convergence>
```

### Write 3 — Leaf index update (conditional)

If `<artifact-root>/README.md` carries a "Revisions" or "Changelog"
section, append a one-line entry pointing to this delivery's version
summary. Otherwise no Write 3.

---

## ACK contract

```
OK trace_id=R5-S-001 role=summarizer linked_issues=
```

For Phase 1, `linked_issues` is empty. For Phase 2, optionally list any
issue ids appearing in `justified_regressions`.

```
FAIL trace_id=R5-S-001 reason=<one-line technical reason>
```

Use FAIL only for missing input frontmatter (issue files unparseable,
state.yml missing). If counts are zero on a round (no issues filed),
Phase 1 still produces a valid index with all counts at 0.

---

## IPC contract (shared)

| Role | Write count | Final paths |
|------|-------------|-------------|
| `summarizer` (Phase 1) | 1 write | `<artifact-root>/.review/round-<N>/index.md` |
| `summarizer` (Phase 2) | 2–3 writes | `<artifact-root>/.review/versions/<N>.md`, CHANGELOG.md, optionally README.md |

**Forbidden**:

- Reading issue bodies or artifact leaves.
- Re-deriving counts from raw issue file scans when the in-frontmatter
  count is what the judge will trust — count from frontmatter only.
- Writing prose narrative into the verdict.yml's `notes` field; that is
  the judge's role.
