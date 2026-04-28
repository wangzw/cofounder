---
issue_id: R1-V-007-ADV
round: 1
file: generate/from-scratch.md
criterion_id: CR-L11
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Parallel writer fan-out has filename / issue-ID race conditions; dispatch-log is the only collision guard

## Attack angle

Concurrency / determinism gap (attack vector 3). Writers fan out N-wide in Step 8; the IPC contract assigns each writer a unique `trace_id`, but the SELF-REVIEW filename, the issue-ID sequence, and the `state.yml` mutation are shared mutable state across writers. None of the prompts mention atomicity or locking.

## Evidence

1. **Self-review filenames**: `writer-subagent.md` line 392 — `<design-dir>/.review/round-<N>/self-reviews/<trace_id>.md`. Trace IDs are per-round per-role sequential: `R1-W-001`, `R1-W-002`, …. Assigned by orchestrator before dispatch. SAFE for self-review filename, ASSUMING the orchestrator assigns sequence atomically. SKILL.md does not specify atomicity. If two parallel dispatches read the counter from `state.yml` and both write back `count+1`, the second writer's self-review overwrites the first's (same `trace_id`).

2. **Cross-reviewer issue IDs**: cross-reviewer-subagent.md line 197-199 — "Start `<seq>` at max existing in `round-<N>/issues/` + 1 so cross-reviewer IDs never collide with script-tier IDs." This describes a glob-and-increment pattern. With cross-reviewer + adversarial-reviewer in PARALLEL (from-scratch.md Step 10: "Both reviewers are dispatched simultaneously"), both readers compute the same max + 1 at the same time. They both write `R1-008.md` and one overwrites the other, OR they both produce the same `id:` frontmatter and the judge double-counts.

   Adversarial prompt (line 273-274) repeats the same pattern: "Issue IDs continue the same sequence started by cross-reviewer for this round (check the highest existing `<seq>` in `round-<N>/issues/` and increment from there)." Sequential narrative, parallel dispatch — race.

3. **`state.yml` writes**: SKILL.md says the orchestrator's only writes are `state.yml` and `dispatch-log.jsonl`. Multiple parallel sub-agent ACKs returning at the same time → orchestrator updates `state.yml.dispatched_at`/`returned_at` for each. No `flock` is mentioned. If orchestrator's Edit-tool calls are not serialized by Claude Code's tool harness, two ACK handlers can produce a corrupted YAML.

4. **Round counter monotonicity** is documented but not enforced: SKILL.md line 99-100 "Round numbers are cross-delivery monotonic. Delivery-1 round-1..k, delivery-2 starts at round-k+1." If a delivery is rolled back (`git tag -d` or revert), `state.yml.current_round` is not rolled back atomically; subsequent runs will reuse round numbers that already exist in the git tree, causing dispatch-log JOIN by `trace_id` to merge rounds.

## Severity reasoning

`important`: the orchestrator likely runs in a single Claude session where Task-tool calls are serialized at some level, so most parallel races may be mitigated by the harness. But the prompts make explicit promises ("never collide", "always increment from max") that the harness does not guarantee. Tier-2 metrics aggregation will silently report wrong counts when collisions occur.

## Fix

1. Mandate that the **orchestrator** assigns issue ID sequences (not the sub-agents). Pre-allocate a per-round sequence range to each reviewer dispatch in the user-prompt header:

   ```
   trace_id: R1-V-001
   id_seq_start: 1
   id_seq_end: 50    (cross-reviewer reserves 1-50, adversarial 51-100)
   ```

   Both `cross-reviewer-subagent.md` (line 197) and `adversarial-reviewer-subagent.md` (line 273) replace "check the highest existing seq" with "use the assigned id_seq_start; never glob the directory."

2. Add to SKILL.md "Orchestrator Dispatch Contract" a step "Atomic state.yml mutation": orchestrator MUST hold an in-memory lock around `Edit state.yml` calls; dispatch-log appends are append-only newline-delimited so safe.

3. Document round-counter rollback semantics: on revert, orchestrator must read the highest `R<N>-` prefix in `.review/round-*/` and `.review/traces/round-*/dispatch-log.jsonl` files and resume from `max + 1`.

4. Self-review filename includes the role suffix already (`<trace_id>.md` where `trace_id` includes role letter), so the role boundary is fine. But if a writer is RE-dispatched (retry policy in §16), it may keep the same trace_id and overwrite the prior self-review. State the retry semantic: "On `FAIL` ACK retry, orchestrator MUST move the prior self-review file to `<trace_id>.failed-1.md` before re-dispatching."
