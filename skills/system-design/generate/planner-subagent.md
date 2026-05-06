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
| `reviewer` | 1 write | `.review/round-<N>/reviewer-output/<trace_id>.json` |
| `reviser` | 1+ writes | `<artifact-path>` + state-transitioned `.review/round-<N>/issues/<id>.md` files |
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
  When `input.md` names a source PRD bundle path (e.g. `docs/raw/prd/<date>-<slug>/`), ALSO
  Read that PRD's `README.md`, `features/F-NNN-*.md`, `journeys/J-NNN-*.md`, and
  `architecture/*.md` directly — the design's modules are derived from PRD features and
  architecture topics. The orchestrator does NOT pre-expand PRD paths into `input.md`; you
  resolve them yourself via the Read tool.
- Constraint: `delete` and `keep` lists MUST be empty (no existing files to preserve or remove)
- `add` list contains the system-design bundle:
  - exactly one `README.md` index (with the Feature-Module mapping matrix that bridges PRD
    features to design modules)
  - one `modules/M-NNN-{slug}.md` per module (typically 5–12 modules in a first delivery; one
    module per cohesive responsibility derived from PRD feature clusters and architecture
    topics)
  - one `api/API-NNN-{slug}.md` per externally exposed API surface (REST/gRPC/CLI). A module
    that exposes no external surface does NOT need an API file; an API surface that spans
    multiple modules gets one API file owned by the primary module.
- Canonical FromScratch `add` shape (paths are design-bundle-relative, NOT skill-relative):
  - `README.md`                                 — design overview, Architecture Overview,
                                                   Module Index, Feature-Module mapping matrix,
                                                   Interaction Protocols, Implementation
                                                   Conventions, Analytics Coverage, Boundary
                                                   Enforcement, References
  - `modules/M-001-{slug}.md`                   — one per module (Responsibility, Public
                                                   Interface, Internal Structure, Module Deps,
                                                   Failure Modes, Observability, Security
                                                   Considerations, API Surface)
  - `modules/M-002-{slug}.md`                   — ...
  - `api/API-001-{slug}.md`                     — one per external API surface (Endpoints with
                                                   the seven mandatory per-endpoint subsections)
  - `api/API-002-{slug}.md`                     — ...
- Templates available under `common/templates/`:
  - `design-readme-template.md`     — for `README.md`
  - `module-template.md`            — for `modules/M-NNN-{slug}.md`
  - `api-template.md`               — for `api/API-NNN-{slug}.md`

**FORBIDDEN** for the planner: emitting `add` paths that point at skill-internal files
(e.g. `generate/writer-subagent.md`, `common/templates/*.md`, `scripts/*.sh`). The `add` list
is the **design-bundle manifest**, not a list of skill files. Templates are a separate
field per entry, never themselves entries.

**NewVersion mode** (`mode: new-version` in plan.md):

- Input: most recent `<target>/.review/round-0/clarification/<ISO-timestamp>.yml` (same
  selection rule) or `<target>/.review/round-0/input.md` if no clarification, PLUS:
  - `<target>/README.md`
  - `<target>/CHANGELOG.md`
  - `<target>/.review/versions/<N-1>.md` (last converged version summary)
  - the (possibly updated) source PRD bundle, when `input.md` names a PRD path — Read it
    directly via the Read tool
- All four lists are used: `delete`, `modify`, `add`, `keep`
- `keep` = files in the prior delivery that the planner certifies are unaffected by this
  change. The review pipeline (`review/index.md`) will re-confirm via formal review and
  substantive cross-reviewer.
- Module IDs are stable across versions: a module that is renamed keeps its `M-NNN`; a
  module that is removed becomes a tombstone in `modules/M-NNN-{slug}.md` (`status: deprecated`).
  IDs are NEVER renumbered.

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
    - path: "README.md"
      template: "common/templates/design-readme-template.md"
      description: "Design overview + module index + Feature-Module mapping matrix"
    - path: "modules/M-001-auth.md"
      template: "common/templates/module-template.md"
      description: "Authentication module — credential validation, session issuance, password reset"
    - path: "api/API-001-public.md"
      template: "common/templates/api-template.md"
      description: "Public REST API exposed by M-001 (auth) and M-003 (profile)"
    # ... one entry per leaf file in the design bundle
  keep: []             # new-version only; planner-certified unchanged files
rationale: |
  <1–3 sentences explaining the plan shape and any non-obvious choices>
```

Each entry in `add` and `modify` MUST include:
- `path`: design-bundle-relative path of the file to create or update (relative to `<target>` artifact root)
- `template`: skill-relative path to the template the writer should use; use `null` if no template applies
- `description`: one sentence describing the file's purpose in the design bundle

### Reasoning Guidelines

- For FromScratch: derive the module list from `clarification.yml` R-001 through R-007 and
  the source PRD bundle. One module per cohesive responsibility; module count is typically
  5–12 for a first delivery. Group features by data-model + interaction-mode locality;
  modules with high coupling (frequent inter-module calls) should be merged or have their
  dependency direction documented in `README.md` Module Deps.
- For each module that exposes a network/CLI/IPC surface to clients outside this design,
  emit one `api/API-NNN-{slug}.md` entry. Internal-only modules (called only by other
  modules in this design) do NOT need an API file.
- For NewVersion: compare `input.md` change description against `versions/<N-1>.md` to
  determine which existing modules + APIs are affected. Files not mentioned in the change
  scope go to `keep`.
- For novel files outside the canonical bundle (e.g. a glossary, a migration plan), add them
  to `add` with `template: null` and explain in `rationale` why the standard design shape is
  insufficient.

### ACK Format

```
OK trace_id=<trace_id> role=planner linked_issues=
```

- `linked_issues` is empty for the planner (issues are raised by reviewers, not planners).
- Return this ACK as the **single and final line** of the Task return. Nothing after it.
