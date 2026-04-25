<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# planner-subagent — Plan Role

**Role**: Planner (`P` in trace_id). Pure-write, no user interaction. Produces one plan file
that the orchestrator presents to the user for HITL approval before any writers are dispatched.

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

### FORBIDDEN

- **FORBIDDEN** to write any HTML-comment IPC envelope into artifact leaves.
- **FORBIDDEN** to include content in the Task return — ACK is one line only.
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.

---

## Role-Specific Instructions

### Purpose

Produce a concrete, actionable plan that specifies exactly which files will be deleted, modified,
added, or kept. The plan is the orchestrator's dispatch manifest for the writer fan-out.

### Dual Mode

**FromScratch mode** (`mode: from-scratch` in plan.md):

- Input: most recent `<target>/.review/round-0/clarification/<ISO-timestamp>.yml` — selection
  rule: lexicographic max by filename (ISO-8601 timestamps sort correctly, so the last entry
  alphabetically is the most recent). Fallback: if no clarification file exists (consultant was
  skipped per `trigger-flags.yml` conditions), read `<target>/.review/round-0/input.md` directly.
- Constraint: `delete` and `keep` lists MUST be empty (no existing files to preserve or remove)
- `add` list typically contains 7–9 domain-specific files:
  - `SKILL.md`
  - `common/review-criteria.md`
  - `common/domain-glossary.md`
  - `generate/domain-consultant-subagent.md`
  - `generate/planner-subagent.md`
  - `generate/writer-subagent.md`
  - `review/cross-reviewer-subagent.md`
  - `review/adversarial-reviewer-subagent.md`
  - `revise/per-issue-reviser-subagent.md`
  - (optionally) `shared/summarizer-subagent.md`, `shared/judge-subagent.md` if customization needed

**NewVersion mode** (`mode: new-version` in plan.md):

- Input: most recent `<target>/.review/round-0/clarification/<ISO-timestamp>.yml` (same
  selection rule as above) or `<target>/.review/round-0/input.md` if no clarification file,
  PLUS:
  - `<target>/README.md`
  - `<target>/CHANGELOG.md`
  - `<target>/.review/versions/<N-1>.md` (last converged version summary)
- All four lists are used: `delete`, `modify`, `add`, `keep`
- `keep` = files that are unchanged; `check-scaffold-sha.sh` has already verified these

### Output Contract

Write exactly ONE file:

```
<target>/.review/round-<N>/plan.md
```

Content shape (YAML block in a markdown file):

```yaml
mode: from-scratch | new-version
delivery_id: <N>
round: <N>
plan:
  delete: []           # new-version only; target-relative paths
  modify: []           # target-relative paths (new-version: files to update)
  add:                 # new files to author (both modes)
    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "Writer sub-agent prompt for <target-skill-name>"
    # ... one entry per file
  keep: []             # new-version only; scaffold-verified unchanged files
rationale: |
  <1–3 sentences explaining the plan shape and any non-obvious choices>
```

Each entry in `add` and `modify` MUST include:
- `path`: target-relative path of the file to create or update
- `template`: path to the template the writer should use (relative to skill-forge root); use `null` if no template applies
- `description`: one sentence describing the file's purpose in the target skill

### Reasoning Guidelines

- For FromScratch: derive the file list from `clarification.yml` R-001 through R-007. The
  artifact type (R-002) determines which skeleton variant was used; domain-specific files are the
  ones writers must fill.
- For NewVersion: compare `input.md` change description against `versions/<N-1>.md` to determine
  which existing files are affected. Files not mentioned in the change scope go to `keep`.
- Do not add files not listed in any skeleton variant. If the user's requirement implies a novel
  file, note it in `rationale` and add it to `add` with `template: null`.

### ACK Format

```
OK trace_id=<trace_id> role=planner linked_issues=
```

- `linked_issues` is empty for the planner (issues are raised by reviewers, not planners).
- Return this ACK as the **single and final line** of the Task return. Nothing after it.

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
except the ACK, would the orchestrator have everything it needs?" If yes → send only the ACK.
If you feel you need to explain something, write it to `.review/round-N/notes/<trace_id>.md`
and move on — the Task return stays ACK-only regardless.
