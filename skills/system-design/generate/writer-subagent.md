<!-- snippet-d-fingerprint: ipc-ack-v1 -->

# writer-subagent — Writer Role for system-design

**Role**: Writer (`W` in trace_id). Pure-write, no user interaction. The writer is the ONLY role
that produces artifact content AND a self-review archive in a single dispatch. Self-review discipline
is mandatory — do not skip it.

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

### FORBIDDEN

- **FORBIDDEN** to write `<!-- metrics-footer -->`, `<!-- self-review -->`, or any HTML-comment
  IPC envelope into artifact leaves — artifact nudity is a hard constraint (guide §3.9 hard
  constraint 1). All process metadata goes to `.review/` archive files, never into the artifact.
- **FORBIDDEN** to include generation content in the Task return — the ACK is one line; the
  artifact body must never appear in the return value (orchestrator context pollution, guide §3.9
  hard constraint 2).
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.
- **FORBIDDEN** to force-fix in-place a `global-conflict` self-review FAIL — use the
  blocker-scope taxonomy, record the FAIL row with `blocker_scope: global-conflict`, and return
  `OK ... self_review_status=PARTIAL`. The cross-reviewer and reviser handle global conflicts
  in the review/revise loop (§11.2).

---

## Role-Specific Instructions

### Purpose

Author ONE target artifact file (the domain content) and ONE self-review archive. Both writes
happen in the same dispatch; neither write is optional.

### Input Contract

Read these files before writing:

| File | When available |
|------|---------------|
| `<design-dir>/.review/round-0/clarification/<ts>.yml` | Always (most recent timestamp) |
| `<design-dir>/.review/round-<N>/plan.md` | Always |
| `common/templates/<template-name>` | Per `plan.add[].template` or `plan.modify[].template`; use as structural scaffold |
| `<design-dir>/<file>` (existing content) | NewVersion `modify` files only |
| PRD feature files listed in row's `source_features` | Module spec and README writers |
| Dep module files listed in row's `deps` | Module spec writers |

The `trace_id` (injected as the first line of this sub-session by the orchestrator) identifies
which file in `plan.add` or `plan.modify` this writer instance is responsible for.

### Mandatory cross-skill carryovers (writer-of-meta-files only)

Two artifacts in the standard FromScratch `add:` set carry MANDATORY content that
must propagate across every generated skill regardless of artifact domain. Writers
of these specific paths MUST include the carryover content verbatim from the
template:

- **`SKILL.md`** — MUST include `## Model Tiers` + `### Per-dispatch model override`
  (with the role→tier→Agent-tool-`model` mapping table) + `## CLI Flags` (with rows
  for `--full`, `--no-consultant`, `--tier <role>=<tier>`, `--max-iterations N`).
  Enforced by **CR-S15 skill-md-cost-control-sections**.
- **`common/review-criteria.md`** — MUST register the meta-CR
  `skill-md-cost-control-sections` (you may number it CR-S<N> in your local
  scheme; the `name:` field MUST be `skill-md-cost-control-sections` and
  `script_path:` MUST be `scripts/check-skill-md-sections.sh`). Without this,
  the generated skill's own self-review will not enforce its SKILL.md
  cost-control invariants when it self-hosts a `--review` cycle.

Skipping these carryovers silently regresses Tier 1.1 (per-dispatch model override)
and Tier 3.7 (--no-consultant flag) every time skill-forge generates a new skill.

---

## Domain-Specific Generation Guidance

### Artifact-Leaf Types

Each writer dispatch is assigned exactly ONE leaf type. Determine your leaf type from
`plan.add[].type` (or the artifact path prefix):

---

#### Leaf Type 1 — Module Spec (`<design-dir>/modules/M-NNN-{slug}.md`)

**Source reads (MUST read before writing):**
1. Every PRD feature file listed in `source_features` (`{prd-dir}/features/F-NNN-*.md`)
2. `common/templates/module-template.md` — structural scaffold
3. Every dep module file listed in `deps` (`<design-dir>/modules/M-NNN-*.md`) — for
   interface signatures and data model alignment

**Required sections (from module-template.md):**

| Section | Requirement |
|---------|-------------|
| Header block | Status, Assignee, Source Features, Complexity filled |
| Responsibility | 2–3 sentences; explicit Out-of-scope list |
| Architecture Position | Mermaid graph showing callers, this module, deps; edges labelled with call type |
| API Surface | 7 columns filled for every HTTP-facing endpoint: Method+Path, Auth & Role, Success, Error Codes, Request+Response example links, Constraints. Leave table absent (not empty) for non-HTTP modules |
| Boundary Enforcement | 4 columns filled: Rule, Enforcement Mechanism, Violation Signal, Scope — required if project has linting/CI infra; omit only for S-complexity modules with no external deps |
| Data Models | Field-level detail: name, type, constraints, description. MUST be inline (no cross-references) |
| Interface | Public function/method signatures with param types, return types, error types — MUST be inline |
| Relevant Conventions | Copy applicable convention rows from architecture.md inline — not a path reference |
| Testing | Unit + integration stubs, isolation strategy, test doubles needed; omit only for trivial S-complexity modules with zero dependencies |
| Backend i18n Implementation | Full section if PRD flags backend i18n triggers; explicit N/A otherwise |
| UI Architecture | Required for frontend modules: component tree, routing, state management, key interactions, performance, a11y implementation, i18n implementation, Prototype Reuse Guide |

**Self-contained rule:** a coding agent MUST be able to implement this module reading only this
file. Inline every data model, interface signature, and convention row — NEVER write a path
like "see architecture.md for conventions" or "data model defined in M-002".

**GOOD — self-contained interface block:**

```markdown
## Interface

### `CreateTask(ctx context.Context, cmd CreateTaskCommand) (Task, error)`

| Param | Type | Description |
|-------|------|-------------|
| `ctx` | `context.Context` | Request context; carries trace ID and deadline |
| `cmd.Title` | `string` | Task title, 1–200 chars, required |
| `cmd.AssigneeID` | `uuid.UUID` | Must reference an existing User row |

**Returns:** `(Task, error)` — Task on success; `ErrTaskNotFound`, `ErrPermissionDenied`,
or `ErrValidation` on failure. Never returns a nil Task with a nil error simultaneously.

**Inline data model:**

```go
type Task struct {
    ID          uuid.UUID
    Title       string
    AssigneeID  uuid.UUID
    CreatedAt   time.Time
    UpdatedAt   time.Time
}
```
```

**BAD — cross-reference instead of inline:**

```markdown
## Interface

See M-002-auth for the Task data model. Refer to architecture.md for error handling conventions.
# WRONG: consuming agent must open two more files; self-contained rule violated (CR-L02 fires)
```

---

#### Leaf Type 2 — API Contract (`<design-dir>/api/API-NNN-{slug}.md`)

**Source reads (MUST read before writing):**
1. PRD endpoint specs from the relevant feature file(s) in `source_features`
2. `common/templates/api-template.md` — structural scaffold
3. Owning module's API Surface table from `<design-dir>/modules/M-NNN-*.md`

**Per-endpoint required subsections (7 total — ALL MUST be present):**

| # | Subsection | Requirement |
|---|-----------|-------------|
| 1 | Request | HTTP method, URL, headers table, path/query param table |
| 2 | Request body | JSON schema table + populated ```json example (no `...`, `TODO`, `FIXME`, `<...>`) |
| 3 | Response body | JSON schema table + populated ```json example |
| 4 | Status codes | Table of every HTTP status code the endpoint can return with condition |
| 5 | Error model | Structured error shape with `code`, `message`, `details` fields |
| 6 | Auth | Auth mechanism, required roles/scopes, unauthenticated behavior |
| 7 | Rate limits | Limit (requests/window), per-user vs. global, 429 retry-after behavior |

**L2 lint (FORBIDDEN inside ```json blocks):** `...`, `TODO`, `FIXME`, `<field>`, `<...>`.
Use realistic example values — not placeholders.

**GOOD — fully populated endpoint:**

```markdown
### POST /tasks

**Owned by:** M-003-task-service

#### Request

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <JWT>` |
| `Content-Type` | `application/json` |

#### Request Body

| Field | Type | Required | Constraint |
|-------|------|----------|-----------|
| `title` | string | yes | 1–200 chars |
| `assignee_id` | string (UUID) | no | Must exist in users table |

```json
{
  "title": "Implement payment webhook handler",
  "assignee_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

#### Response Body (201 Created)

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "title": "Implement payment webhook handler",
  "assignee_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "created_at": "2026-04-28T09:00:00Z"
}
```

#### Status Codes

| Code | Condition |
|------|-----------|
| 201 | Task created successfully |
| 400 | Validation error (title too long, malformed UUID) |
| 401 | Missing or invalid JWT |
| 403 | Caller lacks `tasks:write` scope |
| 422 | `assignee_id` references non-existent user |

#### Error Model

```json
{ "code": "VALIDATION_ERROR", "message": "title must be 1–200 chars", "details": {} }
```

#### Auth

Bearer JWT required. Caller MUST have `tasks:write` scope. Unauthenticated requests
receive 401 with `WWW-Authenticate: Bearer` header.

#### Rate Limits

100 requests per minute per user. Excess requests receive 429 with
`Retry-After: 60` header.
```

**BAD — placeholder JSON (L2 lint fires):**

```markdown
```json
{
  "id": "<uuid>",
  "title": "...",
  "assignee_id": "TODO"
}
```
# WRONG: placeholder values inside JSON block — L2 fires on review
```

---

#### Leaf Type 3 — Design README (`<design-dir>/README.md`)

**Source reads (MUST read before writing):**
1. Every file under `{prd-dir}/architecture/*.md` — source for Implementation Conventions table (X3 lint)
2. Every module file `<design-dir>/modules/M-NNN-*.md`:
   - Source Features → Feature-Module matrix (X5 lint)
   - Module Deps → Module Interaction Protocols (X1 lint) and Dependency Layering
3. Every PRD feature file's `## Analytics` block → Analytics Coverage table (X4 lint)
4. `common/templates/design-readme-template.md` — structural scaffold

**Required sections and their lint checks:**

| Section | Lint | Requirement |
|---------|------|-------------|
| Module Index | — | One row per module: ID, Name, Type (backend/frontend/shared), Responsibility, Complexity, Deps, Source Features, Impl |
| Dependency Layering | — | Forward-only layer order table; no reverse-layer imports |
| Module Interaction Protocols | X1 | One row per `(caller, callee)` pair from all module Deps; extras need cross-cutting justification |
| Feature-Module Mapping | X5 | Matrix: PRD F-NNN columns × module rows; `✦` = modifies data, `△` = read-only support; no orphan features |
| Analytics Coverage | X4 | One row per PRD analytics event; no PRD event silently omitted |
| Implementation Conventions | X3 | One row per `architecture/*.md` file topic; explicit `N/A — {reason}` if skipped |
| NFR Allocation | — | Each PRD NFR decomposed to module-level budget; bottleneck module identified |
| Key Technical Decisions | — | Table of architecture decisions with rationale and alternatives dismissed |
| Test Strategy | — | Pyramid allocation, isolation approach, external dep strategy, test data management |
| View / Screen Index | — | Present if project has frontend; each PRD journey touchpoint Screen/View listed with owning module |
| Prototype-to-Production Mapping | — | Present if PRD contains `prototypes/`; Reuse/Refactor/Rewrite per prototype component |

**X1 lint (Module Interaction Protocols sync):** every `(caller, callee)` dep pair from Module
Index MUST have a corresponding row. Extra rows (no backing dep) MUST carry a cross-cutting note.

**X3 lint (Implementation Conventions):** `ls {prd-dir}/architecture/*.md` — every file MUST
appear as at least one row (or explicit `N/A — {reason}`). Silent omission is a blocker.

**X4 lint (Analytics Coverage):** count every `## Analytics` event across all PRD feature files.
README row count MUST equal event count. Any delta is a blocker.

**X5 lint (Feature-Module matrix):** every PRD `F-NNN` in any module's Source Features MUST
appear as a column. No orphan features (F-NNN in a PRD file but absent from every module).

**GOOD — Feature-Module matrix excerpt:**

```markdown
## Feature-Module Mapping

| Module | F-001 Auth | F-002 Tasks | F-003 Notifications |
|--------|-----------|------------|-------------------|
| M-001-auth | ✦ | | |
| M-002-task-service | | ✦ | |
| M-003-notification | | △ | ✦ |
```

**BAD — orphan feature (X5 fires):**

```markdown
## Feature-Module Mapping

| Module | F-001 Auth | F-002 Tasks |
|--------|-----------|------------|
| M-001-auth | ✦ | |
| M-002-task-service | | ✦ |
# WRONG: F-003 exists in PRD but has no column — X5 lint fires
```

---

### Output Contract — Write 1: Artifact File

Path: `<design-dir>/<artifact-relative-path>` (from `plan.add[].path` or `plan.modify[].path`)

Content rules:
- Follow `common/templates/<template-name>` structure exactly.
- Fill all placeholders from clarification.yml and source reads.
- **Pure artifact body** — no HTML comment IPC envelopes, no `<!-- metrics-footer -->`,
  no `<!-- self-review -->` blocks.
- **Self-contained**: inline every data model, interface signature, and convention row.
  A coding agent MUST be able to act on this file without opening any other file.

### Output Contract — Write 2: Self-Review Archive

Path: `<design-dir>/.review/round-<N>/self-reviews/<trace_id>.md`

Content structure:

```markdown
# Self-Review — <trace_id>

**File reviewed**: `<design-dir>/<relative-path>`
**Round**: <N>
**Timestamp**: <ISO-8601>

## Checklist

See `generate/in-generate-review.md` for CR applicability table.

- CR-S08 ipc-footer-present: PASS | FAIL — blocker_scope: <value> — note: <reason>
- CR-L02 self-contained-file: PASS | FAIL — ...
# (include only CRs applicable to this file type — see in-generate-review.md table)
# For module specs: also check L2 lint (no placeholder JSON) and Boundary Enforcement fill
# For API contracts: check all 7 per-endpoint subsections present, L2 lint
# For README: check X1/X3/X4/X5 lint coverage

## Summary

**FULL_PASS**: yes | no
**fail_count**: <N>
**Scope notes**: <brief explanation of any PARTIAL status>
```

Each applicable CR gets exactly one line: `- <CR-ID> <name>: PASS` or
`- <CR-ID> <name>: FAIL — blocker_scope: <value> — note: <reason>`.

### Self-Review Discipline

1. After writing the artifact, perform an honest CR-by-CR check against `common/review-criteria.md`.
2. Apply only the CRs relevant to this file type (see `generate/in-generate-review.md` table).
3. For PASS: brief evidence is sufficient ("all 7 endpoint subsections present").
4. For FAIL: MUST specify exactly one `blocker_scope` from the taxonomy above.
5. **PARTIAL ACK trigger: if ANY FAIL row exists in the self-review file, set
   `self_review_status: PARTIAL` and `fail_count: <N>` in the ACK.** The 4 `blocker_scope`
   values are:
   - `global-conflict` — conflict with another leaf or cross-cutting concern
   - `cross-artifact-dep` — depends on a file outside writer's scope
   - `needs-human-decision` — requires a policy/preference call beyond writer's scope
   - `input-ambiguity` — clarification.yml is silent or contradictory on this point

   All four equally count toward `fail_count`. The distinction determines downstream action
   (which path in the review/revise loop consumes the blocker), not whether the ACK is PARTIAL.
   Do NOT attempt to fix any FAIL row in-place — write it and move on.
6. If ALL rows are PASS → set `self_review_status: FULL_PASS`, `fail_count: 0`.
7. FORBIDDEN: marking a row PASS when you have genuine uncertainty. If uncertain, mark FAIL with
   `blocker_scope: input-ambiguity` and let the cross-reviewer adjudicate.

### ACK Format

```
OK trace_id=R3-W-007 role=writer linked_issues=<comma-separated issue IDs or empty> self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>
```

- `linked_issues`: comma-separated IDs of any issues this writer believes exist (for pre-filing);
  leave empty if no issues identified (self-review FAIL rows are NOT pre-filed as issues — that
  is the cross-reviewer's job).
- Return this ACK as the **single and final line** of the Task return. Nothing after it.

### Task Return Hygiene (MUST enforce before returning)

Before emitting your Task return, **re-read the message you are about to send**. The ENTIRE
Task return MUST be EXACTLY ONE LINE of the form:

```
OK trace_id=R3-W-007 role=<role> linked_issues=<comma-separated or empty>[ self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>]
```

or

```
FAIL trace_id=R3-W-007 reason=<one-line-reason>
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
