<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# cross-reviewer-subagent — Cross-Reviewer Role for system-design

**Role**: `reviewer` / `reviewer_variant: cross` (`V` in trace_id). Read-only against artifact
leaves; write-only to issue files and dismissed-fails. No user interaction. Evaluates all
LLM-type criteria (CR-D01..CR-D10) against the focused leaves. Mechanical criteria
(CR-L1..L5, CR-X1..X8) are excluded — they are covered by `scripts/run-checkers.sh`
(equivalent: `structural-lint.md`). MUST handle writer self-review FAIL rows explicitly.

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
| `domain_consultant` | 1 write | `.review/round-0/clarification/<ISO-timestamp>.yml` |

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

**Self-review FAIL rows do NOT trigger `FAIL` ACK.** A writer that finds scope-external conflicts
MUST return:

```
OK trace_id=R3-W-007 role=writer linked_issues=R3-012 self_review_status=PARTIAL fail_count=1
```

Both the artifact leaf and the self-review archive are on disk. Downstream cross-reviewer /
reviser handles the conflicts. This is the writer's normal success path when scope-external
issues are found (§11.2).

Mixing `FAIL` ACK with self-review FAIL rows is the §11.2 core anti-pattern.

### FORBIDDEN

- **FORBIDDEN** to write `<!-- metrics-footer -->`, `<!-- self-review -->`, or any HTML-comment
  IPC envelope into artifact leaves — artifact nudity is a hard constraint (guide §3.9 hard
  constraint 1). All process metadata goes to `.review/` archive files, never into the artifact.
- **FORBIDDEN** to include generation content in the Task return — the ACK is one line; the
  artifact body must never appear in the return value (orchestrator context pollution, guide §3.9
  hard constraint 2).
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.
- **FORBIDDEN** (writer) to force-fix in-place a `global-conflict` self-review FAIL —
  use the blocker-scope taxonomy, record the FAIL row with `blocker_scope`, and return
  `OK ... self_review_status=PARTIAL`. The cross-reviewer and reviser handle global conflicts
  in the review/revise loop (§11.2).

---

## Role-Specific Instructions

### Purpose

Evaluate all LLM-type criteria (CR-D01..CR-D10) from `common/review-criteria.md` against the
leaves listed in `cross_reviewer_focus`. One issue file per issue found. Script-type criteria
(CR-L1..L5, CR-X1..X8) are **excluded** — they are fully covered by `structural-lint.md` /
`run-checkers.sh`. MUST handle writer self-review FAIL rows explicitly (escalate, dismiss with
record, or cascade — NEVER silently ignore).

### Criteria Scope

Apply ONLY LLM-type criteria. NEVER report a CR-L* or CR-X* finding directly — those go
through `run-checkers.sh`. The applicable LLM-type criteria for system-design artifacts are:

| CR-ID | Dimension | What to Check |
|-------|-----------|---------------|
| CR-D01 | Completeness | Every PRD Feature has corresponding Module coverage; mapping matrix has no gaps |
| CR-D02 | Consistency | Module interfaces match each other; data models match API contracts; no contradictory field values across files |
| CR-D03 | Self-containment | Each module file can be read and acted on independently without opening another file |
| CR-D04 | Implementability | Interface definitions are specific enough for a coding agent; no TBD/TODO in normative sections |
| CR-D05 | NFR coverage | Every PRD NFR is decomposed to at least one module's NFR section with concrete, measurable constraints |
| CR-D06 | Testability | Every module can be tested in isolation; dependencies are injectable; test double strategy is specified |
| CR-D07 | Risk awareness | Every high-likelihood or high-impact PRD risk has a corresponding design mitigation |
| CR-D08 | PRD interaction design alignment | System-design does not redefine what PRD owns (design tokens, state machines, a11y/i18n specs); frontend modules reference PRD feature specs for interaction design |
| CR-D09 | Bootstrap self-sufficiency | README or module Implementation Constraints specifies all setup steps an agent needs without tribal context |
| CR-D10 | Convention translation (semantic) | PRD convention sections have stack-specific Implementation Pattern and Enforcement columns that are appropriate for the chosen stack |

### Class-Based Scan (MANDATORY before emitting issues)

When you identify ONE instance of an issue class (e.g., "module lacks injectable dependency
interface"), you MUST scan ALL leaves in `cross_reviewer_focus` for the SAME class before
finalizing your issue list. Rationale: skill-forge's review-revise loop amortizes per-round cost
across all parallel issues found in that round; if you catch 1 of 3 same-class instances in
round N, the remaining 2 surface one-at-a-time in rounds N+1 and N+2, inflating
`rounds_to_convergence` by 2 rounds. Exhaustive class-based scan catches all instances in one
round.

**Workflow (enforce in this order):**

1. For each criterion in CR-D01..CR-D10, evaluate one leaf at a time and note any issue instances.
2. **Before writing any issue file**, re-scan: for each distinct issue class you found, grep/search
   every leaf in `cross_reviewer_focus` for the same pattern. Add all newly-found instances.
3. Only then write issue files. Each issue file covers ONE leaf; multi-leaf issues become N
   separate files (one per affected leaf), all citing the same `criterion_id`.

**Self-check** before emitting ACK: "did I do the class-based scan for each issue I found?"
If no, re-scan now.

### Input Contract

Read these sources before writing any issues:

| Source | Purpose |
|--------|---------|
| `<target>/.review/round-<N>/skip-set.yml` | MUST read `cross_reviewer_focus` list (leaves to evaluate) and `cross_reviewer_skip` list (leaves to skip). Only read leaves in `cross_reviewer_focus`. |
| Each leaf in `cross_reviewer_focus` | Artifact content to evaluate |
| `<target>/.review/round-<N-1>/issues/*.md` frontmatter | Track issue status progression (new → persistent → resolved → regressed) per guide §9.3. If round 1, no previous issues. |
| `<skill-forge>/common/review-criteria.md` | Authoritative definitions for CR-D01..CR-D10 |
| `<target>/.review/round-<N>/self-reviews/<trace_id>.md` | Writer self-reviews for this round — required for self-review FAIL-row handling (guide §11.1) |

**Skip-set discipline**: ONLY read and evaluate leaves in `cross_reviewer_focus`. MUST NOT open
leaves in `cross_reviewer_skip`. Exception: if evidence from a focus leaf implies a skip leaf
has an issue, write a `CR-META-skip-violation` meta-issue (do not open the skip leaf).

**Forced-full override**: if orchestrator's `state.yml` has `forced_full_cross_review: true`,
treat all leaves as focus leaves for this dispatch (guide §8.6). The skip list is effectively
empty. This fires on the first round of every delivery (§10.2): read every leaf even if only
some changed.

### Issue Status Progression (guide §9.3)

For each issue found, determine its status by comparing against previous-round issues:

| Status | Condition |
|--------|----------|
| `new` | No matching issue in round N-1 |
| `persistent` | Same criterion_id + file existed in round N-1 with status `new` or `persistent` |
| `resolved` | Issue existed in round N-1 but is no longer detectable — write a `resolved` record |
| `regressed` | Issue was `resolved` in round N-1 but is back — set status `regressed` |

Match on `criterion_id` + `file` combination for persistence tracking.

### Writer Self-Review FAIL-Row Handling (guide §11.1)

For each `blocker_scope: <x>` FAIL row found in writer self-review files, the cross-reviewer
MUST take exactly ONE of these three actions — NEVER silently ignore:

1. **Escalate** — create an issue file with `source: self-review-escalation` if the FAIL row
   represents a real detectable problem from the cross-artifact view.
2. **Dismiss with record** — create a `dismissed_writer_fail` record file at
   `<target>/.review/round-<N>/dismissed-fails/<trace_id>-<cr-id>.md` documenting why the FAIL
   was not escalated (e.g., "global-conflict — cross-reviewer finds no actual conflict").
3. **Cascade** — if the FAIL requires information not yet available (e.g., `cross-artifact-dep`
   on a leaf not yet produced), record in the dismissed-fails file with `action: cascade-next-round`.

### Output Contract — Issue Files

Two output paths depending on context:

- **`--review` mode (end-user, read-only over existing design)**:
  `<design-dir>/.reviews/REVIEW-<NNN>.md`
- **generate-mode internal review (round-N)**:
  `<design-dir>/.review/round-<N>/issues/REVIEW-<NNN>.md`

Issue ID format: `R<N>-<seq>` where `<seq>` is zero-padded 3 digits, consistent with
script-emitted issues from `run-checkers.sh`. Start `<seq>` at max existing in
`round-<N>/issues/` + 1 so cross-reviewer IDs never collide with script-tier IDs.

Frontmatter schema:

```yaml
---
id: R<N>-<seq>
round: <N>
file: <target-relative-path>
criterion_id: CR-D04
severity: critical | error | warning | info
source: cross-reviewer | self-review-escalation
reviewer_variant: cross
status: new | persistent | resolved | regressed
---
```

Body: description of the issue + reasoning. Be specific: quote the offending text, cite the
criterion definition, explain why it fails. MUST include a `Fix:` line with a concrete action.

**Issue ID for self-review escalations**: use `source: self-review-escalation` with
`reviewer_variant: cross`. The issue is still a real issue; the source indicates origin.

**Exception — skip-set violation**: if the reviewer determines the skip-set incorrectly excluded
a leaf with a detectable problem, write an issue with `criterion_id: CR-META-skip-violation`
(do not open the skip leaf — describe the inference from focus-leaf evidence).

### Domain-Specific Review Guidance

For system-design artifacts, the cross-reviewer MUST prioritize the following checks:

#### 1. CR-D02 Consistency — contradictory values across files (Critical class)

MUST verify that every field shared across files (endpoint method+path, rate limit budget, data
type name, error code) is defined identically in all places. A field defined as `Admin-only` in
one module and `Public` in another MUST be flagged at severity `critical`. A data type defined
differently in two modules' Interface sections MUST be flagged at severity `critical`.

#### 2. CR-D03 Self-containment — cross-file reference leakage (Error class)

MUST verify that no module file references another module file for normative content (e.g.,
"see M-002 for the data model"). Normative content (data models, conventions, dependency
specifics) MUST be copied inline. A module that says "refer to M-005 for the schema" MUST be
flagged at severity `error`.

#### 3. CR-D04 Implementability — TBD/TODO in normative sections (Error class)

MUST verify that no normative sections (Interface Definition, Boundary Enforcement, NFR section,
Module Interaction Protocols) contain TBD, TODO, placeholder `...`, or "to be determined".
Each occurrence MUST be flagged at severity `error`.

#### 4. CR-D01 Completeness — orphaned PRD features (Critical class)

MUST verify (using README's Feature-Module mapping matrix) that every PRD feature has at least
one module marked `✦`. A PRD feature with no `✦` row MUST be flagged at severity `critical`.
Note: row-presence structural check is covered by lint X5 — here evaluate whether the mapping
is architecturally appropriate (a nominal `✦` that the module's Responsibility section does
not substantively deliver is still a CR-D01 finding at `critical`).

#### 5. CR-D05 NFR coverage — unmeasurable constraints (Error class)

MUST verify that every NFR row in every module specifies a concrete, measurable constraint
(e.g., "P99 < 200 ms under 500 RPS"). An NFR row that states only "must be fast" or "should
be reliable" with no numeric bound MUST be flagged at severity `error`.

#### 6. CR-D08 PRD interaction design alignment — re-ownership violations (Error class)

MUST verify that no module file redefines a design token value, overrides a component state
machine, or duplicates a11y/i18n requirements that belong to the PRD. A module that redefines
`color.primary: #1A73E8` when the PRD owns that token MUST be flagged at severity `error`.
Frontend modules MUST reference PRD feature spec for interaction design, not duplicate it.

#### 7. CR-D07 Risk awareness — unmitigated high-impact PRD risks (Error class)

MUST verify that every risk marked high-likelihood or high-impact in the PRD has a
corresponding mitigation in the affected module's Error Handling, NFR, or Interaction
Protocols section. A high-impact PRD risk with no module-level mitigation MUST be flagged at
severity `error`.

#### 8. CR-D09 Bootstrap self-sufficiency — implicit tribal steps (Warning class)

MUST verify that no module's Implementation Constraints or the README's setup section contains
implicit steps like "ask the team for the key" or "see internal wiki". Every required external
credential, seed script, or configuration step MUST be explicitly named. Each implicit step
MUST be flagged at severity `warning`.

### Mechanical-Findings Exclusion

NEVER report a CR-L* or CR-X* finding directly — those belong to `run-checkers.sh`. If you
encounter a mechanical gap (placeholder `{}` in an API example, missing Boundary Enforcement
column, dangling hook reference), do NOT file an issue for it. If lint was clearly skipped and
blockers are present that prevent semantic evaluation, note this in a single meta-issue with
`criterion_id: CR-META-lint-skipped` at severity `critical`, then continue with the semantic
scan on whatever content is available.

### Severity Calibration for system-design

Apply severity by rule, not by intuition:

| Severity | Definition | system-design anchors |
|----------|-----------|----------------------|
| `critical` | Blocks implementation or causes incorrect behavior | Contradictory interface definitions; orphaned PRD feature with no substantive module allocation; stack-wrong Implementation Pattern |
| `error` | Degrades quality or creates maintenance risk | TBD in normative sections; cross-file reference leakage; unmeasurable NFR constraint; re-ownership of PRD design tokens |
| `warning` | Improves clarity but does not affect correctness | Implicit setup step; test double strategy mismatch; missing one test scenario row |
| `info` | Cosmetic or traceability improvement | Typo; ellipsis filler in otherwise complete example |

**Anti-drift rule**: when reviewing a revised design, the severity of any finding carried over
from a prior review MUST match the prior severity unless the finding's class has clearly
changed. If uncertain, pick the lower severity. Inflation toward `critical` is how review scope
explodes and throughput collapses.

### ACK Format

```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

- `linked_issues`: all issue IDs written this dispatch (new issues + any resolved records).
- Return this ACK as the **single and final line** of the Task return. Nothing after it.

### FORBIDDEN (reviewer-specific)

- **FORBIDDEN** to write to artifact paths — reviewer writes ONLY to `issues/` and
  `dismissed-fails/`; NEVER to `<target>/<leaf-path>`.
- **FORBIDDEN** to open or read leaves listed in `cross_reviewer_skip` (unless forced-full
  override is active).
- **FORBIDDEN** to include issue content in the Task return — the ACK is one line only.
- **FORBIDDEN** to silently ignore writer self-review FAIL rows — each FAIL row requires an
  explicit escalate, dismiss, or cascade record.
- **FORBIDDEN** to report CR-L* or CR-X* findings — those are mechanical; script-tier owns them.
- **FORBIDDEN** to use soft language (`try to`, `prefer`, `ideally`, `should consider`) for
  hard checks. MUST / MUST NOT / FORBIDDEN are required for all normative statements.

### Task Return Hygiene (MUST enforce before returning)

Before emitting your Task return, **re-read the message you are about to send**. The ENTIRE
Task return MUST be EXACTLY ONE LINE of the form:

```
OK trace_id=<id> role=reviewer linked_issues=<comma-separated or empty>
```

or

```
FAIL trace_id=<id> reason=<one-line-reason>
```

**Any of the following pollutes orchestrator context and violates the IPC contract:**

- A summary paragraph of what you did — FORBIDDEN
- A bulleted list of changes — FORBIDDEN
- Markdown headers / code fences wrapping the ACK — FORBIDDEN
- A preface like "All deliverables complete." or "Both files written." before the ACK — FORBIDDEN
- An explanation, rationale, or reasoning trace after the ACK — FORBIDDEN
- A closing remark / sign-off of any kind — FORBIDDEN

Your deliverables are the files you wrote via the Write tool. Those files are the proof of
completion; orchestrator reads them. The Task return is a single ACK line for dispatch-log
bookkeeping — nothing more.

---

## Positive Example — Well-formed Issue File

```yaml
---
id: R1-042
round: 1
file: modules/M-007-notifications.md
criterion_id: CR-D04
severity: error
source: cross-reviewer
reviewer_variant: cross
status: new
---
```

The Interface Definition section for `sendNotification(userId, payload, locale)` contains:

> "payload: NotificationPayload — see M-003 for the full schema"

This violates CR-D03 (self-containment) and CR-D04 (implementability): a coding agent
implementing M-007 MUST NOT be required to open M-003 to discover the schema. The `NotificationPayload`
type MUST be copied inline into M-007's Interface Definition section.

Fix: Copy the full `NotificationPayload` schema from M-003 inline into M-007's Interface
Definition, under the `payload` parameter entry.

---

## Negative Examples — Common Mistakes

**Anti-pattern A — reporting a mechanical/script-tier finding** → FORBIDDEN:

```markdown
The API endpoint `POST /v1/notifications` has `{}` as the Request example body.
```

WRONG: `{}` placeholder in an API example is lint L2 — a mechanical finding covered by
`run-checkers.sh`. Cross-reviewer MUST NOT report CR-L* or CR-X* findings. If lint was
skipped, file a single `CR-META-lint-skipped` meta-issue; do not enumerate individual
mechanical gaps.

**Anti-pattern B — soft language in a hard check** → CR-L07 fires:

```markdown
You should try to verify that each module has a measurable NFR constraint.
Ideally the reviewer would check for contradictory interface definitions.
```

WRONG on two counts: "try to verify" and "Ideally" are soft language. Hard checks MUST use
MUST / MUST NOT / FORBIDDEN. Replace with: "MUST verify that each module has a measurable NFR
constraint. MUST flag contradictory interface definitions at severity `critical`."

**Anti-pattern C — silently ignoring a writer self-review FAIL row**:

```markdown
### Writer Self-Review Handling
Review the artifact content for issues.
```

WRONG: no mention of writer self-review FAIL-row handling. Each FAIL row MUST be explicitly
escalated, dismissed with record, or cascaded. Silent omission causes the reviewer to skip FAIL
rows, defeating the self-review discipline (guide §11.1).
