# common/snippets.md — Pinned Snippet C and Snippet D

Single source of truth for the orchestrator dispatch contract (Snippet C) and the sub-agent IPC
contract (Snippet D). Downstream check scripts (`check-dispatch-log-snippet.sh`,
`check-ipc-footer.sh`) grep for the fingerprint lines defined here. Do not rename or reformat
those lines.

---

## Snippet C — Orchestrator dispatch contract

<!-- snippet-c-fingerprint: dispatch-log-v1 -->

### Per every dispatch (mandatory)

For **every** sub-agent dispatch the orchestrator MUST:

1. **Assign a `trace_id`** in the format `R{round}-{role-letter}-{nnn}` where:
   - `round` is the integer round number
   - `role-letter` is the single-letter code from the table below (**no two-letter forms**)
   - `nnn` is a zero-padded 3-digit sequence counter, per-round per-role (`001`, `002`, …)

   | Role | Letter | Notes |
   |------|--------|-------|
   | domain-Consultant | `C` | |
   | Planner | `P` | |
   | Writer | `W` | |
   | reViewer (cross + adversarial) | `V` | Single letter for both reviewer variants; distinguish via `reviewer_variant` in dispatch-log |
   | Reviser | `R` | |
   | Summarizer | `S` | |
   | Judge | `J` | |

   > Example: `R3-W-007` = Round 3, writer, 7th call. `R5-V-003` = Round 5, reviewer, 3rd call
   > (cross vs. adversarial is determined by `reviewer_variant` in the dispatch-log, not the letter).
   > Note: in `R3-R-001` the leading `R` means "Round 3"; the second `R` is the reviser role code —
   > parse by splitting on `-` into three segments, never by letter shape.

2. **Before dispatch — append a `launched` event** to
   `.review/traces/round-<N>/dispatch-log.jsonl` (one JSONL line, see schema below).

3. **After dispatch — append a `completed` event** to the same file once the ACK is received
   (see schema below).

4. **Inject `trace_id`** as the **literal first line** of the sub-agent's first user message:
   ```
   trace_id: R3-W-007
   ```

### `launched` event schema

One JSONL line appended before dispatch:

```jsonl
{"event": "launched", "trace_id": "R3-W-007", "role": "writer", "reviewer_variant": null, "tier": "balanced", "model": "claude-sonnet-4-5", "delivery_id": 3, "dispatched_at": "2026-04-20T10:15:30Z", "prompt_hash": "sha256:...", "linked_issues": ["R3-012"], "session_file": "/Users/me/.claude/projects/my-project/abc-def.jsonl"}
```

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `event` | `"launched"` | Literal string |
| `trace_id` | string | JOIN key; must match user-prompt first line and sub-agent ACK |
| `role` | string | One of: `writer`, `reviewer`, `reviser`, `planner`, `summarizer`, `judge`, `domain_consultant` |
| `reviewer_variant` | `"cross"` \| `"adversarial"` \| `null` | Required when `role == "reviewer"`; `null` for all other roles |
| `tier` | string | Model tier classification |
| `model` | string | Model identifier; used for pricing lookup and fallback JOIN |
| `delivery_id` | integer | `--delivery` scope filter for `metrics-aggregate.sh` |
| `dispatched_at` | ISO-8601 | Time-window start for fallback JOIN + latency calculation |
| `prompt_hash` | string | `sha256:...` of full prompt text; required if skill supports resume (§17) |
| `linked_issues` | array of strings | Issue IDs relevant to this dispatch; may be empty array `[]` |
| `session_file` | string \| omit | Absolute path to harness JSONL for this dispatch; omit if unavailable — falls back to rglob scan |

### `completed` event schema

One JSONL line appended after ACK is received:

```jsonl
{"event": "completed", "trace_id": "R3-W-007", "role": "writer", "ack_status": "OK", "linked_issues": ["R3-012"], "self_review_status": "PARTIAL", "fail_count": 1, "returned_at": "2026-04-20T10:16:10Z"}
```

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `event` | `"completed"` | Literal string |
| `trace_id` | string | Must match the paired `launched` event |
| `role` | string | Same as `launched` |
| `ack_status` | `"OK"` \| `"FAIL"` | See §3.9 ACK semantics |
| `linked_issues` | array of strings | Backfilled from ACK; may be empty |
| `returned_at` | ISO-8601 | Time-window end for fallback JOIN + latency calculation |
| `self_review_status` | `"FULL_PASS"` \| `"PARTIAL"` | **Writer only** (required); omit for all other roles |
| `fail_count` | integer | **Writer only** (required); number of FAIL rows in self-review archive; `0` when `FULL_PASS`; omit for all other roles |

### FORBIDDEN

The orchestrator MUST NOT:

- **Read artifact leaves** — no reading of `<artifact-path>` content; those paths belong to sub-agents
- **Summarize or compute verdicts** from artifact content
- **Rewrite or generate artifacts** (production content belongs to sub-agents only)
- **Write to `.review/` business archive files** (self-reviews, issues, plan, verdict) — those are sub-agent write targets

The orchestrator's ONLY write targets are `state.yml` and `dispatch-log.jsonl` (§5.1 pure-dispatch principle).

---

## Snippet D — Sub-agent IPC contract

<!-- snippet-d-fingerprint: ipc-ack-v1 -->

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

These map to §16 `retry_policy` (re-dispatch may be effective: new sub-session, repaired input).

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
- **FORBIDDEN** (writer) to "硬修" (force-fix in-place) a `global-conflict` self-review FAIL —
  use the blocker-scope taxonomy, record the FAIL row with `blocker_scope`, and return
  `OK ... self_review_status=PARTIAL`. The cross-reviewer and reviser handle global conflicts
  in the review/revise loop (§11.2).

### Task Return Hygiene (MUST enforce before returning)

Before emitting your Task return, **re-read the message you are about to send**. The ENTIRE
Task return MUST be EXACTLY ONE LINE of the form:

```
OK trace_id=<id> role=<role> linked_issues=<comma-separated or empty>[ self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>]
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

**Self-check**: before you send your final message, ask yourself "if I stripped every line
except the ACK, would the orchestrator have everything it needs?" If yes → send only the ACK
line. If you feel you need to explain something to the user, STOP — write it to a file in
`.review/round-N/notes/<trace_id>.md` instead, and mention the note in the ACK's rationale is
not allowed either — just write the note file and move on.
