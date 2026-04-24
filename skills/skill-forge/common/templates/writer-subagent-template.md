# Template: writer-subagent.md — Shape Reference for Writer

This template is READ by the writer sub-agent when authoring the target skill's
`generate/writer-subagent.md`. The writer sub-agent prompt is the MOST IMPORTANT file in a
generated skill — it is where domain-specific generation logic lives.

---

## Shape Reference

The target file MUST have this structure in this order:

```
Line 1 (mandatory):
<!-- snippet-d-fingerprint: ipc-ack-v1 -->

[Snippet D body — copied verbatim from common/snippets.md, §Snippet D section]

---

## Role: writer for <skill-name>

**Role**: Writer (`W` in trace_id). Pure-write, no user interaction. The writer is the ONLY role
that produces artifact content AND a self-review archive in a single dispatch. Self-review
discipline is mandatory — do not skip it.

---

## IPC Contract (Snippet D)

[Snippet D body embedded here — verbatim from common/snippets.md]

---

## Role-Specific Instructions

### Purpose

Author ONE target artifact file (the domain content) and ONE self-review archive. Both writes
happen in the same dispatch; neither write is optional.

### Input Contract

| File | When available |
|------|---------------|
| `<target>/.review/round-0/clarification/<ts>.yml` | Always (most recent timestamp) |
| `<target>/.review/round-<N>/plan.md` | Always |
| `<skill-forge>/common/templates/<template-name>` | Per `plan.add[].template` or `plan.modify[].template` |
| `<target>/<file>` (existing content) | NewVersion `modify` files only |

### Output Contract — Write 1: Artifact File

Path: `<target>/<relative-path>` (from `plan.add[].path` or `plan.modify[].path`)

Content rules:
- Follow the template structure from `common/templates/` exactly.
- Fill all domain-specific placeholders from `clarification.yml`.
- Pure artifact body — no HTML comments, no metadata headers, no IPC envelopes.
- Self-contained: all context a consuming agent needs MUST be copied inline.

### Output Contract — Write 2: Self-Review Archive

Path: `<target>/.review/round-<N>/self-reviews/<trace_id>.md`

[Self-review archive format as defined in Snippet D]

### Self-Review Discipline

[Self-review instructions + blocker_scope taxonomy — required content below]

The 4 `blocker_scope` values are:
- `global-conflict` — conflict with another leaf or cross-cutting concern
- `cross-artifact-dep` — depends on a file outside writer's scope
- `needs-human-decision` — requires a policy/preference call beyond writer's scope
- `input-ambiguity` — clarification.yml is silent or contradictory on this point

All four equally count toward `fail_count`. The distinction determines downstream action.
Do NOT attempt to fix any FAIL row in-place — write it and move on.

### Domain-Specific Generation Guidance

[THIS IS THE DOMAIN FILL SECTION — see Content Requirements below]

### ACK Format

```
OK trace_id=<trace_id> role=writer linked_issues=<comma-separated or empty> self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>
```
```

---

## Content Requirements

Fill the following:

| Section | Source |
|---------|--------|
| Snippet D fingerprint + body | Copied verbatim from `<skill-forge>/common/snippets.md` §Snippet D |
| `Role: writer for <skill-name>` heading | `clarification.skill_name` |
| Domain-specific generation guidance | `clarification.generation_guidance` + `clarification.artifact_variant` |
| Positive quality example | `clarification.positive_example` — concrete well-generated artifact excerpt |
| Negative quality example | `clarification.negative_example` — poorly-generated excerpt with annotation |

The writer sub-agent prompt MUST contain (CR-L06 hard check):
- At least 1 positive example ("DO" / "GOOD" / "Well-formed") of what the artifact looks like
- At least 1 negative example ("DON'T" / "BAD" / "Anti-pattern") with explanation of why it fails

The writer sub-agent prompt MUST contain (CR-L09 hard check):
- All 4 `blocker_scope` values listed by name in the self-review section

**FORBIDDEN in the generated writer prompt** (these failures cause CR-L07 on review):
- Soft language for hard requirements: "try to ensure", "ideally", "prefer" — use MUST/MUST NOT/FORBIDDEN
- Instructing the writer to "硬修" a `global-conflict` FAIL — FORBIDDEN per §11.2; writer records and returns PARTIAL
- Omitting the Snippet D fingerprint on line 1 (CR-S08 fires immediately)

---

## Positive Example — decision-log writer prompt (key sections)

```markdown
<!-- snippet-d-fingerprint: ipc-ack-v1 -->

[Snippet D body verbatim]

---

## Role: writer for decision-log

**Role**: Writer (`W` in trace_id). Writes one decision record leaf and one self-review archive.

### Domain-Specific Generation Guidance

**What a well-formed decision record looks like:**

A decision record MUST have five sections in order:
1. Frontmatter (YAML) with `decision_id`, `status`, `date`, `deciders`
2. `## Context` — the situation that prompted the decision (2–4 sentences)
3. `## Decision` — the chosen option, stated as an affirmative sentence
4. `## Rationale` — why this option over alternatives (each alternative named and dismissed)
5. `## Action Items` — table with `Item`, `Assignee`, `Due` columns; may be empty table

### GOOD — Well-formed Decision Record

```yaml
---
decision_id: D-003
status: accepted
date: 2026-04-15
deciders: [alice, bob, carol]
---
```

```markdown
## Context
The team needed a caching layer for session tokens. Redis was in use for job queues.
Extending Redis for sessions was evaluated alongside a dedicated Memcached cluster.

## Decision
Adopt Redis as the session-token cache by adding a `sessions` keyspace to the existing cluster.

## Rationale
Memcached would require a second infrastructure component with no operational benefit. Redis
already meets latency targets (<1ms p99) and the team has existing expertise. Memcached was
dismissed: higher ops burden, no persistence for session recovery.

## Action Items
| Item | Assignee | Due |
|------|----------|-----|
| Add Redis TTL config for sessions | alice | 2026-04-22 |
```

### BAD — Rationale is trivial (CR-DL02 fires)

```markdown
## Rationale
We chose Redis because it is better and faster than alternatives.
# WRONG: no alternatives named, no comparison evidence — CR-DL02 fires on review
```
```

---

## Negative Example — common mistakes in writer prompts (with CR annotations)

**Anti-pattern A — soft language on a hard requirement** → CR-L07 fires on the generated skill's review:

```markdown
### Generation Guidance
Try to ensure each decision record includes a Rationale section.
# ^^^ WRONG: "try to ensure" — use MUST instead; CR-L07 fires
```

**Anti-pattern B — missing blocker_scope taxonomy** → CR-L09 fires:

```markdown
### Self-Review Discipline
After writing, check each criterion. Mark FAIL with a note if anything is wrong.
# ^^^ WRONG: the 4 blocker_scope values are not listed; cross-reviewer cannot categorize blockers
# CR-L09 fires: blocker-scope-taxonomy not present
```

**Anti-pattern C — instructing writer to 硬修 a global-conflict FAIL** → §11.2 violation:

```markdown
If you detect a conflict with another leaf, fix it in place before returning OK.
# ^^^ WRONG: global-conflict FAIL MUST be recorded and returned as PARTIAL, not fixed in place
# The cross-reviewer and reviser own global-conflict resolution (§11.2)
```

---

## How to Fill

1. Copy Snippet D fingerprint + body verbatim from `<skill-forge>/common/snippets.md`.
2. Set heading to `## Role: writer for <clarification.skill_name>`.
3. Read `clarification.generation_guidance` and `clarification.artifact_structure` to author the Domain-Specific Generation Guidance section.
4. Include a concrete positive example from `clarification.positive_example` (or compose one consistent with the artifact template).
5. Include a concrete negative example from `clarification.negative_example` (or compose one that shows a common domain mistake).
6. Ensure all 4 `blocker_scope` values are listed verbatim in the self-review section.
7. Replace every "try to" / "ideally" / "prefer" with MUST / MUST NOT / FORBIDDEN in requirement statements.
