# Output Discipline — system-design

Applies to the **main agent** (orchestrator) in ALL system-design modes. Subagents follow
their dispatch prompt's own output rules (see `common/parallel-dispatch.md`).

These rules govern the orchestrator's user-facing text and tool-call cadence — they are
**main-agent-only** and do not constrain what subagents write to artifact leaves or
`.review/` archives. Domain rules (paths, ID schemes, README structure, module conventions)
live in `SKILL.md` Core Principles and in the templates under `common/templates/`, not here.

---

## Rule 1 — No Echo-Then-Write (MANDATORY)

When generating large artifacts (REVISIONS.md entries, plan content packaged for HITL
approval, dispatch prompts pre-materialized for fan-out), write them directly via the Write
tool. Do NOT include the full artifact body in assistant text before the tool call.

- **Permitted:** a one-line summary such as `"Writing modules/M-007-billing.md (state machine
  + 12 sections)."`
- **Forbidden:** pasting the full artifact body inline, then calling Write — this doubles
  output token cost.

**Why:** observed duplicate generation of a 35k-token REVIEW report (once as inline text,
once via Write) cost $5.98 in a single session.

---

## Rule 2 — No Inter-Dispatch Commentary (MANDATORY)

After a subagent returns a task notification, do NOT emit an assistant response that contains
only an acknowledgment or summary of the return.

- If the next action is another tool call (TaskUpdate at a milestone, next dispatch, Write to
  `state.yml` / `dispatch-log.jsonl`, next phase-gate script), proceed to that tool call in
  the SAME response that processes the return.
- If the next action is human review (HITL gate, plan approval, post-converge summary), emit
  the full user-facing summary in that response, not an intermediate ack.

**Why:** observed 87 tool-less "thinking responses" worth $71.6 in a single session, most
triggered by subagent returns.

---

## Rule 3 — Task Board Parsimony

`TaskUpdate` fires ONLY at cluster-level milestones:

- All subagents in a cluster dispatched
- All subagents in a cluster returned (batch the status change)
- All clusters complete

Do NOT `TaskUpdate` after each individual subagent return. **Targets:** ≤3 TaskUpdate calls
per `--review` pass, ≤5 per `--revise` pass.

---

## Rule 4 — Bash Consolidation

When multiple independent read-only Bash commands are needed — e.g., `git status`, `git diff`,
`ls`, `scripts/run-checkers.sh`, `scripts/check-review-readiness.sh`,
`scripts/check-revise-completeness.sh` — combine them in a single response via parallel
tool_use blocks, OR chain with `&&` in one command when output ordering is deterministic.

Never emit separate Bash tool calls across multiple responses for a batch of
git / ls / phase-gate-script operations.
