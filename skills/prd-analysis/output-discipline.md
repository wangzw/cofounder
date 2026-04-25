# Output Discipline — prd-analysis

Applies to the main agent in ALL prd-analysis modes. Subagents follow their dispatch prompt's own
output rules (see `parallel-dispatch.md`).

---

## Rule 1 — Artifact Path Convention

All generated PRD artifacts MUST use the canonical root path:

```
docs/raw/prd/<YYYY-MM-DD>-<product-slug>/
```

- `YYYY-MM-DD` is the generation date (ISO-8601, local session date).
- `product-slug` is a lowercase, hyphen-separated identifier derived from the product name.
- This path MUST be stable across `--revise` and `--evolve` passes: do NOT re-date on revision.
  Only a fresh `--evolve` cycle produces a new dated directory.

Directory structure under this root:

```
README.md                    ← pyramid index (summaries only — see Rule 3)
journeys/
  J-001.md
  J-002.md
  ...
features/
  F-001-<slug>.md
  F-002-<slug>.md
  ...
architecture/
  data-model.md
  conventions.md
  design-tokens.md
  ...                        ← additional topic files as needed
REVISIONS.md                 ← present only when --revise has run at least once
```

---

## Rule 2 — Self-Contained Leaf Files (Inline-Copy Rule)

Every leaf file (`journeys/J-NNN.md`, `features/F-NNN-slug.md`, `architecture/*.md`) MUST be
independently readable and actionable without opening any other file.

**Mandatory inline-copy targets:**

| Content type | Where it originates | What to inline |
|---|---|---|
| Data models | `architecture/data-model.md` | Applicable entity definitions verbatim |
| Coding conventions | `architecture/conventions.md` | Applicable policy excerpts verbatim |
| Journey context | `journeys/J-NNN.md` | Relevant touchpoint rows verbatim in each feature that references that journey |
| Design tokens | `architecture/design-tokens.md` | Token name + value for every token used in the file |

**Forbidden:** path references like "see `architecture/data-model.md`" or "as defined in
`journeys/J-001.md`" inside a leaf file body. Cross-references are allowed only in the README
index (Rule 3).

**Rationale:** a coding agent implementing `F-007` opens only `features/F-007-*.md`. If that file
contains path references instead of inline content, the agent silently operates on incomplete
context.

---

## Rule 3 — README Is Index-Only

The `README.md` at the PRD root is a navigation index. It MUST NOT duplicate full content from
leaf files.

Permitted README content:
- Vision statement (≤5 sentences)
- Target personas (name + one-line description)
- Journey index: ID, title, persona, one-line summary
- Feature index: ID, title, priority, phase, one-line summary
- Cross-journey patterns section (pattern name + brief description; details live in features)
- Design token overview (token categories listed; full definitions live in `architecture/design-tokens.md`)
- Constraints, glossary, competitive context (short-form — these do NOT duplicate feature body text)

**Forbidden in README:** full Acceptance Criteria blocks, full State Machines, full Interaction
Design sections, verbatim journey touchpoint tables. If a reviewer or coding agent needs the full
content, they open the leaf file.

---

## Rule 4 — ID Stability and Zero-Padding

All IDs MUST be:
- **Zero-padded to 3 digits**: `F-001`, `F-002`, ..., `F-099`, `F-100`.
- **Sequential with no gaps**: assigning `F-003` after `F-001` is only allowed if `F-002` was
  tombstoned (evolve-mode) — even then, `F-002` tombstone file MUST exist.
- **Stable across revisions**: `--revise` MUST NOT renumber existing IDs. New features appended
  during revision take the next available sequential ID.
- **Stable across evolve iterations**: when a new evolve directory is generated, existing IDs from
  the baseline are preserved. Deprecated items become tombstones (files present, status:deprecated).
  New items take IDs continuing the baseline sequence.

ID schemas:
- Features: `F-NNN` (e.g., `F-001`)
- Journeys: `J-NNN` (e.g., `J-001`)
- Architecture topic files do not carry IDs — they use descriptive slugs.

---

## Rule 5 — No Echo-Then-Write (MANDATORY)

When generating large artifacts (feature files, journey files, architecture topic files,
REVISIONS.md entries), write them directly via the Write tool. Do NOT include the full artifact
body in assistant text before the tool call.

- **Permitted:** a one-line summary such as `"Writing F-007-payment-flow.md (state machine + 12 ACs)."`
- **Forbidden:** pasting the full artifact body inline, then calling Write — this doubles output
  token cost.

**Why:** observed duplicate generation of a 35k-token REVIEW report (once as inline text, once via
Write) cost $5.98 in a single session.

---

## Rule 6 — No Inter-Dispatch Commentary (MANDATORY)

After a subagent returns a task notification, do NOT emit an assistant response that contains only
an acknowledgment or summary of the return.

- If the next action is another tool call (TaskUpdate at a milestone, next dispatch, Write), proceed
  to that tool call in the SAME response that processes the return.
- If the next action is human review, emit the full user-facing summary in that response, not an
  intermediate ack.

**Why:** observed 87 tool-less "thinking responses" worth $71.6 in a single session, most triggered
by subagent returns.

---

## Rule 7 — Task Board Parsimony

`TaskUpdate` fires ONLY at cluster-level milestones:

- All subagents in a cluster dispatched
- All subagents in a cluster returned (batch the status change)
- All clusters complete

Do NOT `TaskUpdate` after each individual subagent return. **Targets:** ≤3 TaskUpdate calls per
`--review` pass, ≤5 per `--revise` pass.

---

## Rule 8 — Bash Consolidation

When multiple independent read-only Bash commands are needed (e.g., `git status`, `git diff`, `ls`,
file inspection), combine them in a single response via parallel tool_use blocks, OR chain with
`&&` in one command when output ordering is deterministic.

Never emit separate Bash tool calls across multiple responses for a batch of git/ls/file-inspection
operations.
