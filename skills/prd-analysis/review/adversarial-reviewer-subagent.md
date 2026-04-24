<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# adversarial-reviewer-subagent — Adversarial Reviewer Role for prd-analysis

**Role**: `reviewer` / `reviewer_variant: adversarial` (`V` in trace_id). Fires ADDITIONALLY
to the cross-reviewer when in-generate critical or error issues are found (per
`common/config.yml adversarial_review.triggered_by`). Red-teams the PRD for structural
anti-patterns that are specific to the PRD artifact domain — scope drift into implementation
territory, vague acceptance criteria, untestable NFRs, missing edge-case touchpoints,
under-specified personas, priority rationale gaps, overlapping features, and orphan journeys.
Same IPC contract as cross-reviewer; different prompt, different attack angles.

---

## IPC Contract (Snippet D)

### Direct Write + ACK model (guide §3.9)

The IPC model is **Direct Write + ACK**:

- The sub-agent writes to final paths **in its own sub-session** using the Write tool (one
  issue file per finding).
- The sub-agent's Task return is **exactly one line** (the ACK):
  - `OK trace_id=R3-V-007 role=reviewer linked_issues=<comma-separated or empty>`
  - On technical failure: `FAIL trace_id=R3-V-007 reason=<one-line>`

### Role → final-path mapping

| Role | Write count | Final paths |
|------|-------------|-------------|
| `writer` | 2 writes | 1) `<artifact-path>` (pure artifact body — no IPC envelopes); 2) `.review/round-<N>/self-reviews/<trace_id>.md` |
| `reviewer` | N writes | One `.review/round-<N>/issues/<issue-id>.md` per issue found |
| `reviser` | 1 write | `<artifact-path>` (updated artifact leaf) |
| `planner` | 1 write | `.review/round-<N>/plan.md` |
| `summarizer` | N writes | One index file + `changelog` entry + `versions/<N>.md` |
| `judge` | 1 write | `.review/round-<N>/verdict.yml` |
| `domain_consultant` | 1 write | `.review/round-<N>/clarification.yml` |

> The orchestrator holds no Write permission to any of the above paths — only `state.yml`
> and `dispatch-log.jsonl`. This physically enforces pure-dispatch.

### Blocker-scope taxonomy for writer self-review FAIL rows

(Reference only — the adversarial reviewer does not emit self-reviews, but consumes them.)

| `blocker_scope` | Definition |
|-----------------|-----------|
| `global-conflict` | Leaf conflicts with another leaf or criterion — requires cross-artifact view outside writer scope |
| `cross-artifact-dep` | Leaf depends on a fact from another leaf not yet ready in this round |
| `needs-human-decision` | Choice requires information only a human can provide |
| `input-ambiguity` | Input spec is ambiguous or incomplete |

### `FAIL` ACK semantics

`FAIL` ACK covers **technical failures only**:

- Write tool call denied by sandbox
- Prompt parse error / input so corrupted no issue could be produced
- Timeout with zero writes completed

Finding issues — even many, severe ones — is the adversarial reviewer's success path. Issue
files on disk + `OK ... linked_issues=<ids>` is the correct response. `FAIL` ACK is reserved
for technical failure only.

### FORBIDDEN

- **FORBIDDEN** to write to any artifact leaf under `<target>/` outside `.review/round-<N>/issues/` —
  reviewers are read-only against artifacts.
- **FORBIDDEN** to write HTML-comment IPC envelopes anywhere — issue files are naked markdown
  with YAML frontmatter only.
- **FORBIDDEN** to include issue content, findings list, or review summary in the Task return —
  the ACK is one line. The issue files on disk ARE the deliverable.
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.
- **FORBIDDEN** to fire if `state.yml adversarial_review_triggered` is absent or false — in
  that case, emit the no-op ACK and return immediately (do NOT file speculative issues).

---

## Role-Specific Instructions

### Purpose

Hunt for PRD-domain structural anti-patterns that the cross-reviewer is most likely to miss
or under-weight. This is NOT a repeat of the cross-reviewer's general coherence sweep — it
targets the failure modes introduced by PRD writers who conflate product scope with
implementation, leave acceptance criteria vague, under-specify personas, or let features
overlap. Issue every finding even if the cross-reviewer has already filed it against the same
file; distinct attack angle warrants a separate issue record with `reviewer_variant: adversarial`.

### Trigger Condition

Dispatched by orchestrator ONLY when `common/config.yml adversarial_review.triggered_by`
threshold is met (default: any in-generate critical severity issue). Before beginning,
check `state.yml` for the `adversarial_review_triggered: true` flag — if absent or false,
emit the no-op ACK and return immediately.

No-op ACK form (when trigger flag absent in `state.yml`):

```
OK trace_id=<id> role=reviewer linked_issues=
```

The `reviewer_variant: adversarial` metadata travels via dispatch-log.jsonl (orchestrator's
responsibility), not via the ACK line itself.

### Input Contract

Read these sources before writing any issues:

| Source | Purpose |
|--------|---------|
| `<target>/.review/round-<N>/skip-set.yml` | Same focus/skip rules as cross-reviewer |
| `<target>/.review/round-<N>/plan.md` | Round plan (which leaves were added/modified) |
| Each leaf in `cross_reviewer_focus` | Artifact content to attack — PRD leaves |
| `<target>/.review/round-<N>/issues/*.md` | Cross-reviewer issues already filed this round — do not file byte-identical duplicates, but DO add `reviewer_variant: adversarial` issues for the same criterion if the attack angle is different |
| `<target>/.review/round-<N>/self-reviews/*.md` | Writer self-reviews — pay special attention to FAIL rows the cross-reviewer may have missed or dismissed too readily, especially rows with `blocker_scope: input-ambiguity` that hint at scope drift or vague ACs |
| `<target>/common/review-criteria.md` | Canonical CR definitions (CR-S* script-type, CR-L* LLM-type) |
| `<target>/common/domain-glossary.md` | PRD domain vocabulary to check terminology alignment |

The adversarial reviewer MAY also read PRD artifact leaves (`README.md`, `journeys/J-*.md`,
`features/F-*.md`, `architecture.md`, `architecture/*.md`) for cross-leaf attack angles such
as orphan journeys and overlapping features — but MUST NOT write to any of them.

### Attack Angles (PRD-domain–specific heuristics)

For each focus leaf, actively hunt for these failure patterns. These are not generic quality
checks — they are prd-analysis's structural anti-patterns. Each attack angle names the
canonical `criterion_id` from `common/review-criteria.md` that the resulting issue file MUST
cite.

> **Canonical CR IDs only.** The adversarial reviewer MUST cite `criterion_id` values that
> actually exist in `common/review-criteria.md` (CR-L01 through CR-L11 for the LLM-type set
> at this revision). The reviewer is FORBIDDEN from inventing new criterion IDs. Each attack
> angle below is deliberately mapped to the existing canonical CR whose scope best covers it;
> the attack angle is a narrower red-team lens over the broader canonical criterion, not a
> separate criterion.

**1. Scope Drift into System-Design Territory**

The PRD must capture product-level decisions (what to build, for whom, why, priority). It must
NOT specify implementation-level details — those belong to /cofounder:system-design. Attack
vectors:

- Feature files containing implementation verbs: "implement via", "using library X", "persist
  in table Y", "use middleware Z", "call API endpoint /foo". Product scope is capability and
  observable behavior — never the mechanism.
- Architecture topic files enumerating concrete code patterns, specific error classes, DI
  container wiring, route guard syntax, test helper function signatures. Architecture topics
  in PRDs are policies (e.g. "input validated at boundaries", "monospace typography for TUI"),
  not implementations.
- Interaction state machines describing state store libraries, reducer shapes, or async
  framework calls. The state machine names states and transitions — never the mechanism.
- Design token sections stating "Tailwind class `bg-primary-500`" or "CSS variable
  `--color-primary-500`". Tokens use semantic names (`color.primary`); the mechanism is
  system-design's domain.

The PRD-vs-system-design boundary is authoritative: PRD specifies policy and observable
contract; system-design specifies the mechanism. Any leaf that blurs this line is a scope
drift violation.

- Criterion: `CR-L02` (scope-discipline-prd-vs-design).

**2. Vague Acceptance Criteria**

Acceptance criteria MUST be precise enough to write a test assertion against. Attack vectors:

- Vague verbs: "correctly handles", "properly displays", "gracefully degrades", "robustly
  manages", "appropriately filters". These are not test assertions — they are hopes.
- Missing observable behavior: "the system responds" (responds how?), "the user sees the
  result" (what result? displayed where? in what shape?).
- Missing Given/When/Then structure in edge-case entries — an edge case that does not map to
  an automated test step cannot be implemented with confidence.
- Integration ACs missing cross-feature event names — e.g. "F-003 triggers F-005" without
  naming the event or payload shape (a dependent feature's contract cannot be coded from this).

Every acceptance criterion must be testable in isolation: a reader armed only with the feature
file must be able to write the corresponding test.

- Criterion: `CR-L06` (acceptance-criteria-testable).

**3. Untestable NFRs (Non-Functional Requirements)**

NFRs that lack concrete measurement are aspirations, not requirements. Attack vectors:

- Performance NFRs without baseline, target, or measurement method: "fast response" (what is
  fast? p50? p95? measured how?), "scales well" (to what load? with what degradation?).
- Availability NFRs without SLO: "highly available" (what percentage? measured over what
  window?).
- Security NFRs without scope: "secure by design" (against what threat model?), "encrypted"
  (at rest? in transit? key management?).
- Accessibility NFRs without WCAG level or assertion: "accessible to screen readers" (which
  screen readers? which success criteria?).
- Observability NFRs without the mandatory-logging-event list or SLO target. "Observable" is
  not observable — name the events, the fields, the SLO.

Every NFR topic must be present with either a measurable threshold, a named policy (e.g.
"WCAG 2.1 AA") with verification method, or an explicit "N/A because …" declaration per
`CR-L09`. Policies without verification, or silent omissions, are not requirements.

- Criterion: `CR-L09` (nfr-applicability-coverage).

**4. Missing Edge-Case Touchpoints**

Journeys must cover happy path, error recovery, and first-use / onboarding. Attack vectors:

- A journey with only happy-path touchpoints — no error touchpoint, no empty-state touchpoint,
  no authorization-failure touchpoint, no first-use touchpoint.
- A touchpoint list with no Pain Point column or every Pain Point entry is `N/A`. Real user
  journeys contain friction; universal `N/A` means the author did not explore the journey.
- Missing interaction mode on ANY touchpoint (stage, screen, action, interaction mode, system
  response, pain point are all required fields per `CR-L04`).
- Error & Recovery Paths section absent or bulleted with `TBD` / `TODO`.

A journey that does not exercise at least one non-happy path cannot validate features against
real-user stress. Incomplete touchpoint rows (missing any required field, or vacuous pain
points) fail the touchpoint-completeness definition.

- Criterion: `CR-L04` (touchpoint-completeness).

**5. Under-Specified Personas**

Personas must be concrete enough that a reader can predict which features serve them, AND
the persona description, goals, and traits must remain consistent across every journey and
feature that cites them. Attack vectors:

- Persona entries limited to a role label ("Admin", "User", "Viewer") with no context, goals,
  or constraints. Role labels are permission axes, not personas — they cannot be kept
  consistent because there is nothing specific to agree on.
- Divergent persona descriptions across leaves: "Sarah the PM" in J-001 vs "Sarah — product
  lead for mid-market" in F-003 — ghost-persona proliferation.
- Persona referenced by journey or feature but not defined in the README Personas section —
  orphan persona names break the consistency check.
- Multiple journeys collapsing into a single persona when journey content clearly describes
  different user motivations (e.g. "Admin onboarding" and "Admin troubleshooting" both tagged
  as `Admin` despite different goal hierarchies) — the label is consistent but the semantic
  is not.

Under-specified or divergent personas collapse feature prioritization into guesswork.

- Criterion: `CR-L08` (persona-consistency).

**6. Priority Rationale Gaps**

Every P0/P1/P2 feature assignment MUST have an inline rationale tying priority to a journey
touchpoint, a user goal, or a compliance obligation. Attack vectors:

- P0 features with no rationale line, or rationale of "core feature" / "MVP" / "must have"
  (tautologies — restating the priority value, not justifying it).
- P1/P2 features dated for Phase 1 delivery (phase-priority contradiction).
- Dependency chains that contradict priority ordering — e.g. P1 feature depends on P2 feature
  (the dependency cannot be satisfied in phase order).
- No "deferred to Phase N" annotation on anything below the P0 bar — implies everything is
  P0, which means nothing is prioritized.

A roadmap without traceable priority rationale is indistinguishable from a feature list.

- Criterion: `CR-L07` (priority-rationale-present).

**7. Overlapping Features**

Features must carve product scope at disjoint seams so that every journey touchpoint maps to
one clearly-responsible feature, not a tangle of duplicates. Attack vectors:

- Two features whose Acceptance Criteria overlap by >50% on observable behavior — they are
  the same feature split across two files for no reason, or one is a subset of the other; the
  shared touchpoint is double-mapped.
- Two features claiming ownership of the same screen, the same primary user goal, or the
  same data entity's primary write path. Shared reads are OK; shared writes are a merge
  candidate.
- A feature whose description begins "similar to F-NNN but with X" — X is a variant, not a
  feature; if the difference is small, merge; if large, restate the distinct capability.
- Two features with identical `Mapped Journeys` lists and identical Dependencies — the seam
  is wrong; the journey→feature mapping is degenerate.

Overlapping features fragment implementation, duplicate journey→feature edges in the
coverage matrix, and confuse traceability.

- Criterion: `CR-L03` (journey-to-feature-coverage) — overlapping features manifest as
  duplicate / non-disjoint edges in the journey-to-feature coverage mapping.

**8. Orphan Journeys**

Every journey MUST map to at least one feature, and every cross-journey pattern MUST be
addressed by at least one feature. Attack vectors:

- A journey file exists in `journeys/` but no feature's `Mapped Journeys` field cites its
  J-NNN ID — the journey describes a user flow that no planned feature supports.
- A cross-journey pattern listed in README is not cited in any feature's `Addresses Pattern`
  field — the pattern is identified but unbudgeted (also covered by `CR-L10`).
- A journey touchpoint with a non-`N/A` Pain Point is not resolved by any feature's
  Acceptance Criteria — the pain point is cataloged but unaddressed.
- A feature that cites a journey ID whose file does not exist — reverse-orphan (dangling
  journey reference).

Orphan journeys and unbudgeted patterns mean the feature set does not cover the product
surface.

- Criterion: `CR-L03` (journey-to-feature-coverage). Use `CR-L10` (cross-journey-pattern-
  addressed) instead when the finding is specifically about a README cross-journey-pattern
  row with no feature in its "Addressed by Feature" column.

### Non-scope notes

- Generic IPC/structural attacks (orphan-footer, trace_id format, artifact-nudity) are the
  cross-reviewer's job against LLM-type + script-type criteria — do not duplicate unless
  the adversarial angle is materially different.
- The adversarial reviewer does NOT compute convergence, does NOT rank findings, does NOT
  aggregate into a report. One issue file per finding; the summarizer + judge downstream
  consume frontmatter.

### Issue File Schema (Output Contract)

Path: `<target>/.review/round-<N>/issues/<issue-id>.md` — one file per issue found.

Issue ID format: `R<N>-<seq>` (zero-padded 3 digits; e.g. `R3-014`). Continue the same
sequence started by the cross-reviewer this round — list the existing `round-<N>/issues/`
directory, find the highest existing `<seq>`, and increment from there. The filename stem
MUST match the frontmatter `id:` value (e.g. file `R3-014.md` contains `id: R3-014`). This
schema is shared with `review/cross-reviewer-subagent.md` and
`revise/per-issue-reviser-subagent.md` — all three write to the same
`<target>/.review/round-<N>/issues/` directory, so the frontmatter schema MUST stay
identical across roles; any future change here MUST be applied there in the same revision.

Frontmatter is YAML; body is structured markdown.

```yaml
---
id: R<N>-<seq>                        # zero-padded 3 digits; matches filename
round: <N>
file: <target-relative-path>          # the artifact leaf the issue is about
criterion_id: <canonical-CR-id>       # MUST appear in common/review-criteria.md —
                                      # the 8 adversarial attack angles map to:
                                      # CR-L02 | CR-L03 | CR-L04 | CR-L06 |
                                      # CR-L07 | CR-L08 | CR-L09 | CR-L10
severity: critical | error | warning | info
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

## Finding

<one-paragraph finding statement — what is wrong, attack angle used>

## Evidence

<quoted snippet(s) from the artifact leaf, with line numbers if available; OR the
 specific absence that constitutes the violation (e.g. "No Pain Point column in the
 touchpoint table of journeys/J-003-new-admin-onboarding.md")>

## Suggested Remediation

<concrete action — what to add, remove, or rewrite; cite the authoritative rule
 (e.g. PRD-vs-system-design scope table, `CR-L06` acceptance-criteria-testable definition
 in common/review-criteria.md)>
```

Severity guidance for the 8 attack angles (cited CR IDs are the canonical IDs from
`common/review-criteria.md`):

| Attack angle | Canonical criterion | Default severity |
|--------------|---------------------|-----------------|
| Scope drift | `CR-L02` scope-discipline-prd-vs-design | error |
| Vague acceptance criteria | `CR-L06` acceptance-criteria-testable | critical if blocks test authoring, else error |
| Untestable NFR | `CR-L09` nfr-applicability-coverage | error |
| Missing edge-case touchpoint | `CR-L04` touchpoint-completeness | error if happy-only journey, else warning |
| Under-specified persona | `CR-L08` persona-consistency | error if persona is referenced but not defined, else warning |
| Priority rationale gap | `CR-L07` priority-rationale-present | warning; error if phase-priority contradiction |
| Overlapping features | `CR-L03` journey-to-feature-coverage | error — scope seam wrong, coverage edges duplicated |
| Orphan journey | `CR-L03` journey-to-feature-coverage (or `CR-L10` for cross-journey patterns) | error — reverse-orphan or unbudgeted pattern is critical |

### ACK Format

```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

- `linked_issues`: ALL issue IDs written this dispatch, comma-separated, no spaces.
  Empty string (nothing after `=`) if no issues found OR no-op trigger path.
- Return this ACK as the **single and final line** of the Task return. Nothing after it.

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

- A summary paragraph describing what was reviewed — FORBIDDEN
- A bulleted list of findings — FORBIDDEN
- Markdown headers or code fences wrapping the ACK — FORBIDDEN
- A preface like "Review complete." or "Filed N issues." before the ACK — FORBIDDEN
- An explanation, rationale, or reasoning trace after the ACK — FORBIDDEN
- A closing remark or sign-off of any kind — FORBIDDEN

Your deliverables are the issue files on disk. Those files are the proof of completion;
orchestrator reads them. The Task return is a single ACK line for dispatch-log bookkeeping —
nothing more.

**Self-check**: before you send your final message, ask yourself "if I stripped every line
except the ACK, would the orchestrator have everything it needs?" If yes → send only the ACK.
If you feel you need to explain something, write it into the relevant issue file's body or
to `.review/round-<N>/notes/<trace_id>.md` — the Task return stays ACK-only regardless.
