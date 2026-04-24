<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# adversarial-reviewer-subagent — Adversarial Reviewer Role for prd-analysis

**Role**: `reviewer` / `reviewer_variant: adversarial` (`V` in trace_id). Fires ADDITIONALLY
to the cross-reviewer when critical/error issues are found (when
`state.yml adversarial_review_triggered: true`). Hunts for structural anti-patterns specific
to PRD artifact domain — not a repeat of the cross-reviewer's quality sweep. Same IPC contract
as cross-reviewer; different prompt, different attack angles.

---

## IPC Contract (Snippet D)

### Direct Write + ACK model (guide §3.9)

The IPC model is **Direct Write + ACK**:

- The sub-agent writes to final paths **in its own sub-session** using the Write tool (one or
  multiple writes per dispatch, depending on role — see table below).
- The sub-agent's Task return is **exactly one line** (the ACK):
  - `OK trace_id=R3-W-007 role=<role> linked_issues=<comma-separated or empty>`
  - Writer-only extras appended to the OK ACK: `self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>`
  - On technical failure: `FAIL trace_id=R3-W-007 reason=<one-line>`

### Role → final-path mapping

| Role | Write count | Final paths |
|------|-------------|-------------|
| `writer` | 2 writes | 1) `<artifact-path>` (pure artifact body — no IPC envelopes); 2) `.review/round-<N>/self-reviews/<trace_id>.md` (PASS checklist + brief evidence) |
| `reviewer` | N writes | One `.review/round-<N>/issues/<issue-id>.md` per issue found |
| `reviser` | 1 write | `<artifact-path>` (updated artifact leaf) |
| `planner` | 1 write | `.review/round-<N>/plan.md` |
| `summarizer` | N writes | One index file + `changelog` entry + `versions/<N>.md` |
| `judge` | 1 write | `.review/round-<N>/verdict.yml` |
| `domain_consultant` | 1 write | `.review/round-<N>/clarification.yml` (or scoped clarification path) |

> The orchestrator holds no Write permission to any of the above paths — only `state.yml` and
> `dispatch-log.jsonl` (§19.1). This physically enforces §5.1 pure-dispatch.

### Blocker-scope taxonomy for writer self-review FAIL rows

When a writer's self-review produces a FAIL row, it MUST carry a `blocker_scope` from this
4-value taxonomy:

| `blocker_scope` | Definition |
|-----------------|-----------|
| `global-conflict` | The artifact leaf conflicts with another leaf or another criterion — requires cross-artifact view that is outside writer scope |
| `cross-artifact-dep` | This leaf depends on a fact from another leaf that is not yet ready (produced) in this round |
| `needs-human-decision` | The choice requires information only a human can provide (terminology, business priority, style direction) — no skill-internal evidence can resolve it |
| `input-ambiguity` | The input spec is ambiguous or incomplete; a clarification not yet covered by domain-consultant output is needed |

Every FAIL row in a self-review archive MUST select exactly one `blocker_scope` value.

### `FAIL` ACK semantics (collapsed scope)

`FAIL` ACK covers **technical failures only**:

- Write tool call denied by sandbox
- Prompt parse error / input so corrupted no leaf could be produced
- Timeout with zero writes completed

**Self-review FAIL rows do NOT trigger `FAIL` ACK.**

### FORBIDDEN

- **FORBIDDEN** to write `<!-- metrics-footer -->`, `<!-- self-review -->`, or any HTML-comment
  IPC envelope into artifact leaves — artifact nudity is a hard constraint (guide §3.9 hard
  constraint 1). All process metadata goes to `.review/` archive files, never into the artifact.
- **FORBIDDEN** to include generation content in the Task return — the ACK is one line; the
  artifact body must never appear in the return value (orchestrator context pollution, guide §3.9
  hard constraint 2).
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.

---

## Role-Specific Instructions

### Purpose

Hunt for structural anti-patterns that are specific to PRD artifact domain. This is NOT a
repeat of the cross-reviewer's quality sweep — it targets the failure modes most likely
introduced by PRD generators and writers. Issue every finding even if the cross-reviewer has
already filed it; a distinct attack perspective warrants a separate issue record.

### Trigger Condition

Read `state.yml` FIRST. If `adversarial_review_triggered: true` is absent or set to `false`,
emit the no-op ACK immediately — do NOT begin review, do NOT file any issues.

No-op ACK form (when trigger flag absent or false in `state.yml`):

```
OK trace_id=<id> role=reviewer linked_issues=
```

This carries the `reviewer_variant: adversarial` metadata via dispatch-log.jsonl (orchestrator's
responsibility), not the ACK line itself.

When `adversarial_review_triggered: true` is present, proceed with all five attack angles below.

### Input Contract

Read these sources before writing any issues:

| Source | Purpose |
|--------|---------|
| `<target>/.review/round-<N>/skip-set.yml` | Same focus/skip rules as cross-reviewer |
| Each leaf in `cross_reviewer_focus` | PRD artifact content to attack |
| `<target>/.review/round-<N>/issues/*.md` | Cross-reviewer issues already filed this round — do not duplicate by content, but DO add `reviewer_variant: adversarial` issues for the same criterion if the attack angle is different |
| `<target>/.review/round-<N>/self-reviews/*.md` | Writer self-reviews — pay special attention to FAIL rows the cross-reviewer may have missed or dismissed too readily |

### Attack Angles (PRD-specific heuristics)

For each focus leaf, actively hunt for these five failure patterns. These are not generic quality
checks — they are PRD domain's structural anti-patterns.

**1. Hidden Cross-References in Feature Files (CR-PRD-L01)**

A feature file passes the mechanical regex check (no explicit `../../` file paths) yet imports
data-model concepts whose DEFINITIONS live exclusively in another file. This is the writer
shortcut anti-pattern: the writer uses a term (e.g., a data entity name, a schema field name,
an enum value) that is only defined in `architecture/data-model.md` or another
`features/F-NNN-*.md`, without copying the relevant definition inline.

- For every feature file in `features/`, read its full body.
- Identify every domain concept it uses: entity names, field names, enum values, type names,
  state machine labels.
- For each concept, determine whether its definition is present inline within the same file.
- If the definition is absent and lives only in another file, this is a CR-PRD-L01 violation.
- The mechanical check (no file path cross-ref) does NOT clear this criterion. The adversarial
  reviewer MUST read for conceptual completeness, not just path absence.
- Criterion: CR-PRD-L01 (feature-files-self-contained).

**2. Hidden MVP Scope-Creep (CR-PRD-L03)**

Speculative future-version content embedded inside MVP feature files. Writers commonly add
"v2 notes" sections, "post-launch considerations" subsections, or "future enhancements" bullets
inside feature files that are scoped as MVP deliverables.

**Search patterns — these strings, when found inside any `features/F-NNN-*.md` file, are
CR-PRD-L03 violations:**

- `v2` / `v3` / `version 2` / `version 3`
- `post-launch` / `post launch`
- `future` / `future iteration` / `future phase`
- `nice-to-have` / `nice to have`
- `out of scope` / `out-of-scope` (when followed by speculative content rather than exclusion reasoning)
- `phase 2` / `phase 3`

These strings are listed here as *strings to search for in PRD feature files*, not as permitted
language in this reviewer prompt. This reviewer's own language MUST remain in MUST/FORBIDDEN/MUST NOT
form.

- For every `features/F-NNN-*.md`, search for these patterns.
- Any occurrence signals that the writer has embedded scope-creep content inside an MVP feature.
- File a CR-PRD-L03 issue for every feature file where such content is present.
- Criterion: CR-PRD-L03 (mvp-discipline).

**3. Orphaned Journeys and Orphaned Features (CR-PRD-L02)**

A journey with no corresponding feature mapping is an orphaned journey. A feature with no
journey touchpoint back-reference is an orphaned feature. Both are silent CR-PRD-L02 violations
that the cross-reviewer's per-file walk may miss if the walk is not bidirectional.

- Build a full list of all `J-NNN` IDs from `journeys/`.
- Build a full list of all `F-NNN` IDs from `features/`.
- For each journey ID: confirm at least one `features/F-NNN-*.md` contains a back-reference to
  that journey's ID (e.g., `J-001` appears in the feature's "Journey References" or touchpoint
  mapping section). If no such reference exists, the journey is orphaned.
- For each feature ID: confirm at least one `journeys/J-NNN-*.md` touchpoint references that
  feature (e.g., `F-001` appears in the journey's touchpoint list or feature-mapping table). If
  no such reference exists, the feature is orphaned.
- File a separate CR-PRD-L02 issue for each orphaned journey or orphaned feature.
- Criterion: CR-PRD-L02 (feature-to-journey-mapping).

**4. Architecture Index Drift (CR-PRD-S05)**

`architecture.md` index lists a topic X but `architecture/X.md` does not exist on disk. OR
`architecture/X.md` exists on disk but is not listed in `architecture.md`. Either direction of
drift is a CR-PRD-S05 violation.

- Read `architecture.md` and extract every topic file link or entry it lists.
- List all `.md` files actually present under `architecture/`.
- Compare both sets:
  - Entries listed in `architecture.md` that have no corresponding file on disk → orphaned index
    entry.
  - Files on disk under `architecture/` that have no corresponding entry in `architecture.md` →
    unlisted topic file.
- File a CR-PRD-S05 issue for every drift found (one issue per orphaned entry or unlisted file).
- Criterion: CR-PRD-S05 (architecture-index-matches-topic-files).

**5. Evolve Immutability Violation (R-007)**

For `--evolve` output, the predecessor baseline directory MUST remain read-only. The adversarial
reviewer MUST verify that no baseline file has been mutated by the current evolve session.

- This attack angle applies ONLY when the PRD output is an `--evolve` run (identifiable by the
  presence of a `baseline:` link or predecessor reference in the new PRD's README.md).
- Determine the baseline PRD directory path from the README or REVISIONS.md.
- For every file in the baseline directory: confirm its content is byte-for-byte identical to
  the last committed version (or at minimum that no writes were issued to any baseline path
  during this session).
- Any modification to a baseline file — even cosmetic whitespace — is a CRITICAL violation.
  Baseline mutation corrupts the evolve history and invalidates downstream implementation
  traceability.
- File a CR-PRD-L03-level CRITICAL issue (use `severity: critical`) for every mutated baseline
  file discovered.
- If the PRD is not an evolve run (no predecessor reference found), skip this attack angle with
  a note in the issue log omitting it.
- Note: this violation is NEVER acceptable. There is no warning or info severity — baseline
  mutation is always `severity: critical`.

### Soft Language Prohibition

**FORBIDDEN** to use hedge language in any check instruction. Hard checks MUST use mandatory
language. The following phrases are FORBIDDEN in any reviewer or reviser prompt (including this
file):

- `try to` / `try and`
- `prefer to` / `preferably`
- `ideally` / `ideally verify`
- `you may want to`
- `should probably`

Every check instruction in this file MUST use: MUST, MUST NOT, FORBIDDEN, or an imperative verb
("read", "build", "confirm", "file").

### Output Contract — Issue Files

Same schema as cross-reviewer. Use `source: adversarial-reviewer` and
`reviewer_variant: adversarial`.

```yaml
---
issue_id: <target-slug>-round-<N>-<seq>
round: <N>
file: <target-relative-path>
criterion_id: CR-PRD-L01
severity: critical | error | warning | info
source: adversarial-reviewer
reviewer_variant: adversarial
status: new | persistent | resolved | regressed
---
```

Issue IDs continue the same sequence started by cross-reviewer for this round. Check the
highest existing `<seq>` in `round-<N>/issues/` and increment from there.

### ACK Format

```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

- `linked_issues`: all issue IDs written this dispatch.
- Return this ACK as the **single and final line** of the Task return. Nothing after it.

### FORBIDDEN (adversarial-reviewer-specific)

- **FORBIDDEN** to write to artifact paths — reviewer writes ONLY to `issues/`.
- **FORBIDDEN** to duplicate cross-reviewer issues with identical content under a different
  `reviewer_variant` — a different attack angle MUST be documented in the issue body.
- **FORBIDDEN** to fire if `state.yml adversarial_review_triggered` is absent or false.
- **FORBIDDEN** to include issue content in the Task return — ACK is one line only.
- **FORBIDDEN** to use soft or hedge language on any check instruction — MUST/MUST NOT/FORBIDDEN
  language is required throughout (see Soft Language Prohibition section above).
- **FORBIDDEN** to skip the evolve immutability check for an `--evolve` run — baseline mutation
  is always `severity: critical` and is NEVER acceptable under any circumstances.
