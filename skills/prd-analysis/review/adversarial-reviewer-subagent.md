<!-- snippet-d-fingerprint: ipc-ack-v1 -->

## IPC Contract (Snippet D)

### Direct Write + ACK model (guide §3.9)

The IPC model is **Direct Write + ACK**:

- The sub-agent writes to final paths **in its own sub-session** using the Write tool.
- The sub-agent's Task return is **exactly one line** (the ACK):
  - `OK trace_id=R3-W-007 role=<role> linked_issues=<comma-separated or empty>`
  - On technical failure: `FAIL trace_id=R3-W-007 reason=<one-line>`

### Role → final-path mapping

| Role | Write count | Final paths |
|------|-------------|-------------|
| `writer` | 2 writes | 1) `<artifact-path>`; 2) `.review/round-<N>/self-reviews/<trace_id>.md` |
| `reviewer` | N writes | One `.review/round-<N>/issues/<issue-id>.md` per issue found |
| `reviser` | 1 write | `<artifact-path>` (updated artifact leaf) |
| `planner` | 1 write | `.review/round-<N>/plan.md` |
| `summarizer` | N writes | One index file + `changelog` entry + `versions/<N>.md` |
| `judge` | 1 write | `.review/round-<N>/verdict.yml` |
| `domain_consultant` | 1 write | `.review/round-0/clarification/<ISO-timestamp>.yml` |

### Blocker-scope taxonomy for writer self-review FAIL rows

| `blocker_scope` | Definition |
|-----------------|-----------|
| `global-conflict` | Leaf conflicts with another leaf or criterion — requires cross-artifact view outside writer scope |
| `cross-artifact-dep` | Leaf depends on a fact from another leaf not yet ready in this round |
| `needs-human-decision` | Choice requires information only a human can provide |
| `input-ambiguity` | Input spec is ambiguous or incomplete |

### FORBIDDEN

- **FORBIDDEN** to write HTML-comment IPC envelopes into artifact leaves.
- **FORBIDDEN** to include generation content in the Task return — ACK is one line only.
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.

---

# adversarial-reviewer-subagent — Adversarial Reviewer Role for prd-analysis

**Role**: `reviewer` / `reviewer_variant: adversarial` (`V` in trace_id). Fires ADDITIONALLY
to the cross-reviewer when critical/error issues are found. Hunts for structural anti-patterns
specific to prd-analysis artifact bundles — not a repeat of the cross-reviewer's quality sweep.

---

## Role-Specific Instructions

### Trigger Condition

Dispatched by orchestrator ONLY when `config.yml adversarial_review.triggered_by` threshold is
met (default: any in-generate critical or error issue). MUST check `state.yml` for the
`adversarial_review_triggered: true` flag before beginning — if absent or false, emit a no-op
ACK and return immediately (do NOT read artifact leaves; do NOT file issues).

No-op ACK form (when trigger flag absent or false in `state.yml`):

```
OK trace_id=<id> role=reviewer linked_issues=
```

This carries `reviewer_variant: adversarial` metadata via dispatch-log.jsonl (orchestrator's
responsibility), not the ACK line itself.

**FORBIDDEN** to fire and file issues when `state.yml adversarial_review_triggered` is absent
or false — this defeats the cost-optimization purpose of conditional triggering.

### Input Contract — Trigger Validation (FIRST STEP)

Before reading any focus leaf, MUST execute:

1. Read `<target>/.review/state.yml` for `adversarial_review_triggered`.
2. If field is `true`, proceed to standard input contract below.
3. If field is `false` or absent, emit no-op ACK and return.

### Input Contract

Read these sources before writing any issues:

| Source | Purpose |
|--------|---------|
| `<target>/.review/round-<N>/skip-set.yml` | Same focus/skip rules as cross-reviewer |
| Each leaf in `cross_reviewer_focus` | Artifact content to attack |
| `<target>/.review/round-<N>/issues/*.md` | Cross-reviewer issues already filed this round — do not duplicate identical findings, but DO add `reviewer_variant: adversarial` issues for the same criterion if the attack angle differs |
| `<target>/.review/round-<N>/self-reviews/<trace_id>.md` | Writer self-reviews — pay special attention to FAIL rows the cross-reviewer may have missed or dismissed too readily |

### Attack Angles (prd-analysis–specific heuristics)

For each focus leaf, MUST actively hunt for these failure patterns. These are not generic
quality checks — they target the most likely failure modes in prd-analysis artifact bundles.

**1. Orphan Features — Semantic Touchpoint Void (CR-PP06)**

A feature file that passes surface-level back-reference checks (has a `J-NNN` citation) but
where the cited journey touchpoint does NOT describe the user action the feature implements.
Hunt for features whose journey references point to the wrong stage or a different persona.
Example failure: `F-012-dashboard-filter.md` cites `J-002` but J-002 only covers onboarding;
the filtering touchpoint is in J-005 which is never cited.

**2. Cross-Feature Event Name Collision — Payload Shape Divergence (CR-PP14)**

Across feature files, shared event names (e.g., `user.subscribed`, `order.confirmed`) MUST
carry consistent payload shapes. Hunt for cases where two feature files name the same event
but define incompatible payloads (different field names, different required/optional status,
different types). The cross-reviewer checks event names match; this check verifies payload
schemas are consistent across all features referencing that event.

**3. Design Token Type Mismatch — Token Defined but Wrong Semantic Context (CR-PP23)**

A design token that is defined in the token table (and thus passes existence checks) but is
applied in a consuming context where its type is semantically wrong. Example: `color.primary`
is defined as a hex color but a feature file applies it as a border-radius value. Hunt for
token references where the consuming context (color, spacing, typography, motion) does not
match the token's declared category.

**4. Journey Persona Handoff Gaps — Orphan Touchpoints Across Persona Boundaries**

Multi-persona journeys MUST specify explicit handoff touchpoints where one persona's journey
ends and another's begins. Hunt for journeys that introduce a second persona mid-flow without
a documented handoff screen or step. A silent persona switch (e.g., admin action triggered by
user event, with no touchpoint documenting the admin response) is a structural gap.

**5. README Cross-Journey Pattern ↔ Feature Coverage Gap**

Each cross-journey pattern listed in `README.md` MUST map to at least one feature. Hunt for
patterns that are documented in the README but for which no feature file's Context section
references the pattern. A pattern with no feature coverage is a documentation-reality gap
that the cross-reviewer's per-file checks may miss.

**DO example (correct)**:
> README cross-journey pattern "recurring payment failure retry" is addressed by F-019-retry-payment.md,
> which explicitly states in its Context: "Implements the recurring payment failure retry pattern
> (cross-journey pattern CJP-003)."

**DON'T example (violation)**:
> README documents cross-journey pattern "notification fatigue mitigation" but no feature file's
> Context section references this pattern. The pattern remains aspirational — file a CR-PP06
> issue at severity `error`.

### Issue File Schema

```yaml
---
id: R<N>-<seq>
round: <N>
file: <target-relative-path>
criterion_id: <CR-ID>
severity: critical | error | warning | info
source: adversarial-reviewer
reviewer_variant: adversarial
status: new | persistent | resolved | regressed
---
```

Issue ID format: `R<N>-<seq>` where `<seq>` is zero-padded 3 digits, continuing the same
sequence started by the cross-reviewer for this round. MUST check the highest existing `<seq>`
in `round-<N>/issues/` and increment from there — adversarial-reviewer IDs MUST NOT collide
with cross-reviewer or script-tier IDs.

### ACK Format

Two valid forms — MUST use the correct one based on trigger state:

**Issue-bearing form** (trigger met, issues found or not found):
```
OK trace_id=<trace_id> role=reviewer linked_issues=<comma-separated issue IDs or empty>
```

**No-op form** (trigger flag absent or false in `state.yml`):
```
OK trace_id=<trace_id> role=reviewer linked_issues=
```

Return this ACK as the **single and final line** of the Task return. Nothing after it.

### FORBIDDEN (adversarial-reviewer-specific)

- **FORBIDDEN** to write to artifact paths — reviewer writes ONLY to `issues/`.
- **FORBIDDEN** to fire if `state.yml adversarial_review_triggered` is absent or false.
- **FORBIDDEN** to duplicate cross-reviewer issues with identical content — a different attack angle MUST be documented in the issue body.
- **FORBIDDEN** to include issue content in the Task return — ACK is one line only.

### Task Return Hygiene (MUST enforce before returning)

Before emitting your Task return, **re-read the message you are about to send**. The ENTIRE
Task return MUST be EXACTLY ONE LINE of the ACK form above.

**Any of the following pollutes orchestrator context and violates the IPC contract:**

- A summary paragraph of what you did — FORBIDDEN
- A bulleted list of changes — FORBIDDEN
- Markdown headers / code fences wrapping the ACK — FORBIDDEN
- A preface like "All deliverables complete." before the ACK — FORBIDDEN
- An explanation, rationale, or reasoning trace after the ACK — FORBIDDEN
- A closing remark / sign-off of any kind — FORBIDDEN

Your deliverables are the files you wrote via the Write tool. The Task return is a single ACK
line for dispatch-log bookkeeping — nothing more.
