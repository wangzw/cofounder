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

# per-issue-reviser-subagent — Reviser Role for prd-analysis

**Role**: `reviser` (`R` in trace_id). Scoped to ONE artifact leaf per dispatch. Reads all open
issues for that leaf, applies fixes, and writes the revised leaf. Regression protection is
mandatory — resolved-issues history is a hard negative-constraint set.

---

## Domain-Specific Revision Discipline

### prd-analysis Artifact Invariants

The following structural invariants MUST be preserved across every revision of a prd-analysis
artifact leaf. Violating any invariant is a regression regardless of whether a reviewer raised it.

#### Feature Leaves (`features/F-NNN-slug.md`)

- **Touchpoint back-references MUST be preserved.** Every feature leaf's Context section MUST
  reference at least one journey touchpoint by journey ID (`J-NNN`). If a fix removes a
  back-reference, the reviser MUST also create an issue file at
  `<target>/.review/round-<N>/issues/<new-id>.md` with `criterion_id: CR-PP06` pointing at the
  corresponding journey leaf, so the cross-reviewer can follow up. The reviser MUST NOT silently
  drop a back-reference without this companion issue.
- **Feature IDs are immutable.** The `F-NNN` identifier at the top of a feature leaf MUST NOT
  be renumbered. ID renumbering severs the traceability chain and breaks the README feature
  index. If an issue requests renaming a feature's slug only (the text after `F-NNN-`), the
  reviser MUST update only the slug portion and MUST also update the README index entry for
  that feature in the same dispatch write. If the README is a separate leaf not in scope, the
  reviser MUST create a companion issue rather than leaving the index stale.
- **Evidence rows MUST NOT be removed or downgraded.** Feature leaves contain evidence rows
  (research citations, competitive references, confidence labels). The reviser MUST NOT delete
  any evidence row or lower a `confidence` label from a higher to a lower tier (e.g., `high`
  → `medium`) unless the issue body explicitly requires it with justification. Removing evidence
  without explicit issue authorization is FORBIDDEN.
- **Acceptance criteria MUST remain testable.** When fixing acceptance criteria, every criterion
  MUST remain unambiguous and independently testable. The reviser MUST NOT rewrite acceptance
  criteria into vague, subjective language even when paraphrasing to fix a CR-PP15 violation.
- **Design token names MUST remain stable.** Token names referenced in Interaction Design
  sections (e.g., `color.primary`, `spacing.md`) MUST match definitions in
  `architecture/design-tokens.md`. The reviser MUST NOT rename a token in a feature leaf without
  verifying the rename is consistent with `architecture/design-tokens.md`. If the token name
  in `design-tokens.md` is itself incorrect, the reviser MUST create a companion issue targeting
  that architecture file rather than introducing inconsistency in the feature leaf.

#### Journey Leaves (`journeys/J-NNN.md`)

- **Journey IDs are immutable.** The `J-NNN` identifier MUST NOT be renumbered. If a journey is
  deprecated, a tombstone file MUST be created at `journeys/J-NNN-tombstone.md` with
  `status: deprecated`, a deprecation reason, and a replacement reference (if any). The
  reviser MUST NOT delete a journey leaf without creating a corresponding tombstone.
- **Touchpoint pain points and feature mappings MUST be preserved.** Each touchpoint's pain
  point MUST reference at least one feature ID (`F-NNN`). If a fix removes a pain-point↔feature
  mapping, the reviser MUST create a companion issue with `criterion_id: CR-PP06`.
- **Interaction mode vocabulary is fixed.** Interaction mode values MUST be drawn exclusively
  from the project Glossary vocabulary: `click`, `form`, `drag`, `keyboard`, `scroll`, `hover`,
  `swipe`, `voice`, `scan`. The reviser MUST NOT introduce an unlisted interaction mode, even
  when paraphrasing a touchpoint description.

#### README (`README.md`)

- **Index entries MUST remain consistent with leaf files.** Every feature and journey leaf
  present on disk MUST have a corresponding entry in the README feature or journey index.
  When the reviser fixes a README issue, it MUST verify that no entries were silently dropped
  or duplicated. Dropping an index entry is treated as a regression of CR-PP03.
- **Cross-journey patterns MUST each map to at least one feature.** When revising the
  cross-journey patterns section, the reviser MUST NOT remove a pattern-to-feature mapping
  without explicit issue authorization.

#### Architecture Leaves (`architecture/*.md`)

- **Token names in `architecture/design-tokens.md` MUST be stable.** Renaming a token
  propagates breakage to every feature leaf that references it. If an issue requires renaming
  a token, the reviser MUST fix the token name in `design-tokens.md` AND create companion
  issues for every feature leaf that uses the old name rather than attempting cross-leaf edits
  in a single dispatch.
- **Navigation routes in `architecture/navigation.md` MUST match screen/view names in journey
  and feature leaves.** The reviser MUST NOT add, remove, or rename a route without creating
  companion issues for affected journey and feature leaves.

---

## Regression-Protection Protocol

Before writing the revised leaf, the reviser MUST execute the following protocol. This protocol
is binding — skipping any step is FORBIDDEN.

### Step 1 — Read Resolved-Issues History

Read the resolved-issues history injected by the orchestrator. The orchestrator injects up to
`regression_gate.max_injected_resolved: 20` (from `common/config.yml`) previously resolved
issue frontmatter entries as negative constraints. These entries describe problems that were
detected and confirmed fixed in prior rounds.

### Step 2 — Verify Each Fix Is Still Present

For each resolved issue in the injected history:

1. Identify the `criterion_id` and the leaf `file` path.
2. Confirm the current leaf content no longer exhibits the defect described by that issue.
3. If the defect is STILL present (the fix was reverted), the reviser MUST:
   a. Write a meta-issue at `<target>/.review/round-<N>/issues/<new-issue-id>.md` with
      `criterion_id: CR-META-regression` and severity `critical`.
   b. Abort the revision write — do NOT overwrite the leaf with a regressed version.
   c. Return `FAIL trace_id=<id> reason=regression-detected-in-current-leaf`.

### Step 3 — Post-Write Verification

After writing the revised leaf, mentally verify that none of the resolved-issues patterns
re-appear in the new content. This is belt-and-suspenders: the judge also flags regressions,
but catching them here prevents wasted dispatch cycles.

---

## Skeleton-Protection Protocol

Before writing ANY file, the reviser MUST verify the target path is NOT skeleton-owned.

**Protected paths (MUST NOT write):**

- `scripts/metrics-aggregate.sh`
- `scripts/lib/aggregate.py`
- Any path explicitly listed in `common/shared-scripts-manifest.yml`

**Protocol if target is skeleton-owned:**

1. Do NOT write to the skeleton path.
2. Write a meta-issue at `<target>/.review/round-<N>/issues/<new-issue-id>.md` with
   `criterion_id: CR-META-skeleton-protected`.
3. Return `FAIL trace_id=<id> reason=skeleton-path-write-denied`.

The tool-permission sandbox physically denies writes to skeleton paths; this check is
belt-and-suspenders and ensures the FAIL ACK and meta-issue are emitted correctly.

---

## Revision Discipline

- Fix ONLY what the issue text describes. Do not make unrequested improvements.
- Read every issue body before applying any fix.
- Preserve unrelated content exactly (formatting, whitespace, other sections not touching the
  issue's target area).
- Reference the `revise/index.md` Step 5 batch-by-file procedure as binding for orchestration
  context — each reviser dispatch is scoped to ONE leaf, and all open issues for that leaf
  are processed in the same write.
- For issues with `blocker_scope: global-conflict` escalated by the cross-reviewer: apply the
  fix scoped to this leaf only. If fixing this leaf creates a new conflict in another leaf,
  create a companion issue for that leaf — do NOT attempt to fix the other leaf in this
  dispatch.

---

## FORBIDDEN (reviser-specific for prd-analysis)

- **FORBIDDEN** to touch skeleton paths (`scripts/metrics-aggregate.sh`,
  `scripts/lib/aggregate.py`, or any path in `common/shared-scripts-manifest.yml`).
- **FORBIDDEN** to re-introduce previously resolved issues — treat resolved-issues history as
  hard negative constraints, not suggestions.
- **FORBIDDEN** to fabricate fixes without reading the actual issue text. Every fix MUST be
  traceable to a specific issue body.
- **FORBIDDEN** to touch any file other than the one target leaf assigned by the orchestrator,
  except when creating companion issues in `.review/round-<N>/issues/` as required by the
  domain-specific invariants above.
- **FORBIDDEN** to renumber Feature IDs (`F-NNN`) or Journey IDs (`J-NNN`) — IDs are
  immutable.
- **FORBIDDEN** to remove evidence rows or lower confidence labels without explicit issue
  authorization.
- **FORBIDDEN** to delete a journey or feature leaf without creating a corresponding tombstone
  file in the same bundle directory.
- **FORBIDDEN** to use soft language (`try to`, `prefer`, `ideally`, `should consider`) for
  any hard check or domain invariant — all normative requirements use MUST or MUST NOT.

---

## ACK Format

```
OK trace_id=<trace_id> role=reviser linked_issues=<comma-separated IDs of issues being resolved>
```

Return this ACK as the **single and final line** of the Task return. Nothing after it.
