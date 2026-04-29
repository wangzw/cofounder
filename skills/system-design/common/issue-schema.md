# Issue Schema — system-design

This file defines the on-disk schema for review issues. It is the single
source of truth consumed by:

- LLM reviewers — emit raw judgment JSON conforming to the **input schema** below;
  they NEVER write issue files directly (see `scripts/create-issues.sh`).
- `scripts/create-issues.sh` — converts LLM raw output into per-issue files at
  `.review/round-N/issues/I-NNN.md`.
- `scripts/check-issue.sh` — validates that on-disk issue files conform
  to the **on-disk schema** (formal review of audit artifacts; guide §10).
- `scripts/update-summary.sh` — aggregates open / deferred issues into
  `.review/issues/summary.yml` for cross-round fingerprint matching (guide §7.6).

---

## On-disk schema

Each issue lives at `<artifact-root>/.review/round-<N>/issues/<id>.md`.

```markdown
---
id: I-NNN                      # Required. Stable per artifact root, monotonic. Format: I-<3+ digits>.
criterion_id: CR-XXX           # Required. Must match an entry in common/review-criteria.md.
file: relative/path.md         # Required. Path from artifact root. May be "" for repo-wide issues.
severity: error                # Required. One of: critical | error | warning | info.
state: new                     # Required. One of: new | fixed | false-positive | deferred | superseded.
created_in_round: 3            # Required. Integer >= 1.

# State-dependent fields (presence rules below):
fixed_in_round: 4              # Required when state=fixed.
defer_until: round-5           # Required when state=deferred. Values: round-N+M | delivery-N+M | never | input-arrived.
defer_reason: scope-overflow   # Required when state=deferred.
dismissed_reason: out-of-scope # Required when state=false-positive.
superseded_by: I-007           # Required when state=superseded. Must reference an existing issue id.

# Recurrence (set by create-issues.sh from LLM-emitted recurrence_of):
recurrence_of: I-012           # Optional. References an earlier issue id from summary.yml.
recurrence_count: 2            # Optional. Times this signature has surfaced (incl. current).

# Audit trail (auto-maintained):
history:
  - {round: 3, action: created}
  - {round: 4, action: state-change, from: new, to: deferred}
fix_history: []                # Diff/notes for past fixes; consulted on recurrence (guide §7.5.1).
---

## Description
<one or two sentences locating the issue in the artifact: file, line/section, what's wrong>

## Suggested fix
<one concrete action — not "rewrite this", but a specific change>
```

### Required-field rules

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Always | Format `I-\d{3,}`. Monotonic per artifact root. |
| `criterion_id` | Always | Must match a CR id in `review-criteria.md`. |
| `file` | Always | Empty string allowed for repo-wide issues. |
| `severity` | Always | `critical` / `error` / `warning` / `info`. |
| `state` | Always | See state machine below. |
| `created_in_round` | Always | Integer. |
| `fixed_in_round` | When `state=fixed` | Must be `>= created_in_round`. |
| `defer_until` | When `state=deferred` | Must be one of: `round-<N+M>` (numeric N+M), `delivery-<N+M>`, `never`, `input-arrived`. |
| `defer_reason` | When `state=deferred` | Free text; non-empty. |
| `dismissed_reason` | When `state=false-positive` | Free text; non-empty. |
| `superseded_by` | When `state=superseded` | Must reference an existing issue id. |
| `recurrence_of` | Optional | If present, must reference an id in `summary.yml`. |

`history` and `fix_history` are auto-maintained — writers MUST not
hand-edit them; `create-issues.sh` and `update-summary.sh` are the only
permitted authors.

### Body sections

Both `## Description` and `## Suggested fix` are required and must be
non-empty (at least 5 characters of meaningful prose). The body is human-
and-agent-readable context; frontmatter is the machine-truth source.

---

## State machine (guide §7.2)

```
   ┌─── created via create-issues.sh
   ▼
 [new] ─── revise + verify ───▶ [fixed]
   │
   ├── reason=out-of-scope ───▶ [false-positive]
   ├── reason=scope-overflow ─▶ [deferred] (defer_until set)
   └── covered-by ──────────▶ [superseded] (superseded_by set)

[deferred] ── defer_until expires ───▶ [new] (auto-reactivation)
[fixed]    ── recurrence detected ──▶ [new] (severity auto-bumps; see §7.5.1)
[false-positive] ── recurrence ─────▶ auto-dismissed via summary.yml (no new issue)
```

### Reason metadata replaces independent states (guide §7.2.1)

| Common scenario | Encoding |
|---|---|
| wont-fix (design trade-off) | `state: deferred`, `defer_until: never` |
| out-of-scope | `state: false-positive`, `dismissed_reason: out-of-scope` |
| needs-input (external blocker) | `state: deferred`, `defer_until: input-arrived` |

---

## LLM raw-output schema (input to `create-issues.sh`)

Reviewers (cross / adversarial) emit a JSON document — **not** issue files —
on stdout. `create-issues.sh` reads this and writes the issue files to disk.

```json
{
  "round": 3,
  "reviewer_variant": "cross",
  "trace_id": "R3-V-001",
  "issues": [
    {
      "criterion_id": "CR-PP01",
      "file": "features/F-001-checkout.md",
      "severity": "error",
      "description": "missing '## Acceptance Criteria' section",
      "suggested_fix": "add '## Acceptance Criteria' with at least one BDD entry",
      "recurrence_of": "I-012"
    }
  ]
}
```

Required per-issue fields: `criterion_id`, `file`, `severity`, `description`,
`suggested_fix`. Optional: `recurrence_of` (when reviewer's fingerprint match
against `summary.yml` succeeds).

`create-issues.sh` validates this schema, allocates issue ids, dedupes against
the round's already-filed issues, and writes one file per accepted issue.
LLM-side schema violations cause `create-issues.sh` to exit 1 with a
formal-review error — no issues are written.

---

## summary.yml schema (`.review/issues/summary.yml`)

Lives at the artifact root, not inside a round directory — it spans all
rounds. Maintained by `scripts/update-summary.sh` after each round's revise
step.

```yaml
generated_at: 2026-04-29T08:00:00Z
issues:
  - id: I-042
    state: deferred
    defer_until: delivery-2
    criterion_id: CR-PP01
    file: features/F-001-checkout.md
    summary: "missing acceptance criteria section"
    history:
      - {round: 3, action: created}
      - {round: 4, action: deferred, reason: scope-overflow}
  - id: I-073
    state: fixed
    fixed_in_round: 5
    criterion_id: CR-PP15
    file: features/F-002-cart.md
    summary: "BDD format violation in AC #2"
    fix_summary: "rewrote AC#2 as Given/When/Then"
    history: [...]
```

Pruning policy: `update-summary.sh` keeps all `deferred` (any age) plus
`fixed` / `false-positive` issues from the most recent N deliveries
(default `summary_retention_deliveries: 2` in `config.yml`). Older ones
move to `.review/issues/archive.yml` and are NOT shown to the reviewer
(guide §7.6 cost control).
