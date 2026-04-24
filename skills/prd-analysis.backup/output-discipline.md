# Output Discipline for Main Agent

Applies to the main agent in ALL prd-analysis modes. Subagents follow their dispatch prompt's own output rules (see `parallel-dispatch.md`).

## Rule 1 — No Echo-Then-Write (MANDATORY)

When generating large artifacts (REVIEW files, feature files, journey files, architecture topic files, REVISIONS.md entries), write them directly via the `Write` tool. Do NOT include the full body of the artifact in assistant text before the tool call.

- **Permitted:** a one-line summary like `"Writing REVIEW-20260417-*.md with 18 Critical / 47 Important / 142 Suggestion findings."`
- **Forbidden:** pasting the full 30k-token report body inline, then calling `Write` — this doubles output token cost.

**Why:** observed duplicate generation of a 35k-token REVIEW report (once as inline text, once via `Write`) cost $5.98 in a single session.

## Rule 2 — No Inter-Dispatch Commentary (MANDATORY)

After a subagent returns a `<task-notification>`, do NOT emit an assistant response that contains only acknowledgment or summary of the return.

- If the next action is another tool call (TaskUpdate at a milestone, next dispatch, Write), proceed to that tool call in the SAME response that processes the return.
- If the next action is human review, emit the full user-facing summary in that response, not an intermediate ack.

**Why:** observed 87 tool-less "thinking responses" worth $71.6 in a single session, most triggered by subagent returns.

## Rule 3 — Task Board Parsimony

`TaskUpdate` fires ONLY at cluster-level milestones:

- All subagents in a cluster dispatched
- All subagents in a cluster returned (batch the status change)
- All clusters complete

Do NOT `TaskUpdate` after each individual subagent return. **Targets:** ≤3 TaskUpdate calls per `--review` pass, ≤5 per `--revise` pass.

## Rule 4 — Bash Consolidation

When multiple independent read-only Bash commands are needed (e.g., `git status`, `git diff`, `ls`, file inspection), combine them in a single response via parallel tool_use blocks, OR chain with `&&` in one command when output ordering is deterministic.

Never emit separate Bash tool calls across multiple responses for a batch of git/ls/file-inspection operations.
