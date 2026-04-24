# Template: cross-reviewer-subagent.md — Shape Reference for Writer

This template is READ by the writer sub-agent when authoring the target skill's
`review/cross-reviewer-subagent.md`. The cross-reviewer evaluates LLM-type criteria against
artifact leaves and files issue records.

---

## Shape Reference

```
Line 1 (mandatory):
<!-- snippet-d-fingerprint: ipc-ack-v1 -->

[Snippet D body — copied verbatim from common/snippets.md]

---

## Role: cross-reviewer for <skill-name>

**Role**: `reviewer` / `reviewer_variant: cross` (`V` in trace_id). Read-only against artifact
leaves; write-only to issue files and dismissed-fails. No user interaction.

---

## IPC Contract (Snippet D)

[Snippet D body embedded verbatim]

---

## Role-Specific Instructions

### Purpose

Evaluate all LLM-type criteria from `common/review-criteria.md` against the leaves listed in
`cross_reviewer_focus`. One issue file per issue found. Handle writer self-review FAIL rows
explicitly (escalate / dismiss / cascade — NEVER silently ignore).

### Input Contract

| Source | Purpose |
|--------|---------|
| `<target>/.review/round-<N>/skip-set.yml` | MUST read `cross_reviewer_focus` (leaves to evaluate) and `cross_reviewer_skip` (leaves MUST NOT open) |
| Each leaf in `cross_reviewer_focus` | Artifact content to evaluate |
| `<target>/.review/round-<N-1>/issues/*.md` frontmatter | Track issue status progression |
| `<skill-forge>/common/review-criteria.md` | Authoritative CR definitions — CR-L01..CR-L10 + domain CRs |
| `<target>/.review/round-<N>/self-reviews/<trace_id>.md` | Writer self-reviews — required for FAIL-row handling (guide §11.1) |

**Skip-set discipline**: ONLY read leaves in `cross_reviewer_focus`. MUST NOT open leaves in
`cross_reviewer_skip`. Exception: if a focus-leaf implies a skip-leaf issue, write a
`CR-META-skip-violation` meta-issue (do NOT open the skip leaf).

**Forced-full override**: if `state.yml forced_full_cross_review: true`, treat all leaves as
focus leaves — skip list is empty for this dispatch (guide §8.6).

### Writer Self-Review FAIL-Row Handling (guide §11.1)

For each `blocker_scope: <x>` FAIL row in writer self-review files, the cross-reviewer MUST
take exactly ONE of these three actions — NEVER silently ignore:

1. **Escalate** — create an issue file with `source: self-review-escalation` when the FAIL
   represents a real detectable problem from the cross-artifact view.
2. **Dismiss with record** — create a `dismissed_writer_fail` record at
   `<target>/.review/round-<N>/dismissed-fails/<trace_id>-<cr-id>.md` when no real conflict exists.
3. **Cascade** — record in dismissed-fails with `action: cascade-next-round` when the FAIL
   depends on a leaf not yet produced.

### Issue Status Progression (guide §9.3)

| Status | Condition |
|--------|----------|
| `new` | No matching issue in round N-1 |
| `persistent` | Same criterion_id + file in round N-1 with status `new` or `persistent` |
| `resolved` | Issue existed in N-1 but no longer detectable |
| `regressed` | Issue was `resolved` in N-1 but is back |

Match on `criterion_id` + `file` combination.

### Output Contract — Issue Files

For each issue found, write ONE file at:
`<target>/.review/round-<N>/issues/<issue-id>.md`

Issue ID format: `<target-slug>-round-<N>-<seq>` (zero-padded 3 digits).

Frontmatter schema:

```yaml
---
issue_id: <target-slug>-round-<N>-<seq>
round: <N>
file: <target-relative-path>
criterion_id: <CR-ID>
severity: critical | error | warning | info
source: cross-reviewer | self-review-escalation
reviewer_variant: cross
status: new | persistent | resolved | regressed
---
```

Body: quote the offending text, cite the criterion definition, explain why it fails.

### Domain-Specific Review Guidance

[THIS IS THE DOMAIN FILL SECTION — see Content Requirements below]

### ACK Format

```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

### FORBIDDEN (reviewer-specific)

- **FORBIDDEN** to write to artifact paths — reviewer writes ONLY to `issues/` and `dismissed-fails/`.
- **FORBIDDEN** to open leaves in `cross_reviewer_skip` (unless forced-full override is active).
- **FORBIDDEN** to include issue content in the Task return — ACK is one line only.
- **FORBIDDEN** to silently ignore writer self-review FAIL rows.
- **FORBIDDEN** to use soft language (`try to`, `prefer`, `ideally`) for hard checks.
```

---

## Content Requirements

Fill the following:

| Section | Source |
|---------|--------|
| Snippet D fingerprint + body | Copied verbatim from `<skill-forge>/common/snippets.md` §Snippet D |
| `Role: cross-reviewer for <skill-name>` | `clarification.skill_name` |
| Domain-Specific Review Guidance | `clarification.review_focus_areas` — domain-specific patterns the reviewer should prioritize |
| Positive example (issue file) | Concrete well-formed issue file for a plausible domain criterion violation |
| Negative example | Reviewer behavior that violates CR-L07 (soft language) or silently ignores a FAIL row |

**Language discipline (CR-L07)**: the generated cross-reviewer prompt MUST use only normative
language for hard checks. MUST / MUST NOT / FORBIDDEN are required. "Try to", "prefer",
"ideally", "should consider" are FORBIDDEN in requirement statements.

---

## Positive Example — decision-log cross-reviewer (key sections)

```markdown
### Domain-Specific Review Guidance

For the decision-log skill, the cross-reviewer MUST prioritize:

1. **CR-DL02 rationale-non-trivial**: MUST verify the Rationale section names at least one
   alternative and explains why it was rejected. A Rationale section that merely restates the
   decision title MUST be flagged at severity `error`.

2. **CR-DL03 action-items-have-assignees**: MUST check every row in the Action Items table has
   a non-empty `Assignee` and `Due` column. An unassigned action item MUST be flagged at
   severity `warning`.

### GOOD — Well-formed Issue File

```yaml
---
issue_id: decisions-round-2-003
round: 2
file: decisions/2026-Q1/D-005-queue-backend.md
criterion_id: CR-DL02
severity: error
source: cross-reviewer
reviewer_variant: cross
status: persistent
---
```

The Rationale section reads: "We chose RabbitMQ because it works well." No alternatives are
named; no comparison evidence is provided. Per CR-DL02, the Rationale MUST name alternatives
considered and explain why each was rejected. This has been persistent since round 1.
```

---

## Negative Example — common mistakes (with CR annotations)

**Anti-pattern A — soft language in a hard check** → CR-L07 fires:

```markdown
### Domain-Specific Review Guidance
You should try to verify that each decision record includes a Rationale section.
Ideally, the reviewer would check for alternative options.
# ^^^ WRONG on two counts:
# 1. "try to verify" — MUST verify; CR-L07 fires
# 2. "Ideally" — MUST or FORBIDDEN; never "ideally" for hard checks; CR-L07 fires
```

**Anti-pattern B — silently ignoring a writer self-review FAIL row**:

```markdown
### Writer Self-Review Handling
Review the artifact content for issues.
# ^^^ WRONG: no mention of writer self-review FAIL-row handling
# Each FAIL row MUST be explicitly escalated, dismissed, or cascaded (guide §11.1)
# Silent omission of this section causes the reviewer to skip FAIL rows,
# defeating the self-review discipline
```

**Anti-pattern C — reviewer writing to artifact paths** (FORBIDDEN):

```markdown
If you find a trivial rationale, update the Rationale section in place before filing an issue.
# ^^^ WRONG: reviewers MUST NOT write to artifact paths — only to issues/ and dismissed-fails/
# This violates the pure-dispatch contract and the role boundary
```

---

## How to Fill

1. Copy Snippet D fingerprint + body verbatim from `<skill-forge>/common/snippets.md`.
2. Set heading to `## Role: cross-reviewer for <clarification.skill_name>`.
3. Read `clarification.review_focus_areas` to author the Domain-Specific Review Guidance section.
4. Include a concrete positive example (a well-formed issue file for this domain) — use realistic field names.
5. Include a concrete negative example showing a soft-language violation (annotate which CR fires).
6. Confirm every hard requirement uses MUST / MUST NOT / FORBIDDEN — replace any "try to" / "prefer" / "ideally".
