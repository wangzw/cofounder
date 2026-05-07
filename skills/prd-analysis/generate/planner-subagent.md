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
| `writer` | 1 write (FULL_PASS) \| 2 writes (PARTIAL) | 1) `<artifact-path>` (pure artifact body — no IPC envelopes); 2) `.review/round-<N>/self-reviews/<trace_id>.md` — only when `self_review_status: PARTIAL` (see `generate/writer-subagent.md` Output Contract Write 2). |
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
- `add` list contains the PRD bundle: a `README.md` index, one `J-NNN-{slug}.md` per persona
  journey under `journeys/`, one `F-NNN-{slug}.md` per feature derived from the journeys'
  touchpoints under `features/`, and an architecture index + topic files. A typical first
  delivery has 1–3 journeys, 5–9 features, and 4–8 architecture topic files.
- Canonical FromScratch `add` shape (paths are PRD-relative, not skill-relative):
  - `README.md`                                — product overview + journey/feature index + roadmap
  - `journeys/J-001-{slug}.md`                 — one per persona (typically 1–3 in MVP)
  - `features/F-001-{slug}.md`                 — one per feature (typically 5–9 in MVP); derive
                                                  features from the touchpoints in journeys
  - `architecture.md`                          — INDEX (~50 lines, links to topic files)
  - `architecture/tech-stack.md`               — frontend / backend / data / hosting choices
  - `architecture/design-tokens.md`            — color / spacing / typography / motion tokens
  - `architecture/data-model.md`               — primary entities + relationships
  - `architecture/coding-conventions.md`       — naming, layering, module boundaries
  - `architecture/security.md`                 — authn / authz / secrets / privacy posture
  - (additional topics like accessibility, i18n, observability, deployment as the PRD scope warrants)
- Templates available under `common/templates/`:
  - `prd-template.md`         — for `README.md`
  - `journey-template.md`     — for `journeys/J-NNN-*.md`
  - `feature-template.md`     — for `features/F-NNN-*.md`
  - `architecture-template.md` — for `architecture.md` AND each `architecture/*.md` topic file

**NewVersion mode** (`mode: new-version` in plan.md):

- Input: most recent `<target>/.review/round-0/clarification/<ISO-timestamp>.yml` (same
  selection rule as above) or `<target>/.review/round-0/input.md` if no clarification file,
  PLUS:
  - `<target>/README.md`
  - `<target>/CHANGELOG.md`
  - `<target>/.review/versions/<N-1>.md` (last converged version summary)
- All four lists are used: `delete`, `modify`, `add`, `keep`
- `keep` = files in the prior delivery that the planner certifies are unaffected by this change. The review pipeline (`review/index.md`) will re-confirm via formal review and substantive cross-reviewer.

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
    - path: "features/F-001-checkout.md"
      template: "common/templates/feature-template.md"
      description: "Cart checkout feature — covers payment + receipt screens"
      frontend_draft:                           # OMIT for non-user-facing features
        must_run_phase_5: true
        target_path: "frontend/src/pages/checkout/"
    - path: "journeys/J-001-onboarding.md"
      template: "common/templates/journey-template.md"
      description: "First-time-user onboarding from signup through first transaction"
    # ... one entry per leaf file in the PRD bundle
  keep: []             # new-version only; planner-certified unchanged files
rationale: |
  <1–3 sentences explaining the plan shape and any non-obvious choices>
```

Each entry in `add` and `modify` MUST include:
- `path`: PRD-relative path of the file to create or update (relative to `<target>` artifact root)
- `template`: path to the template the writer should use (relative to this skill root); use `null` if no template applies
- `description`: one sentence describing the file's purpose in the PRD bundle
- `frontend_draft` (REQUIRED for any feature row whose Interaction Design will be populated; OMIT entirely for backend-only features, journey rows, README, and architecture topics):
  - `must_run_phase_5: true` — signals the orchestrator to run Phase 5 (Frontend Draft) for this feature in `generate/new-version.md` Step 8c (or the equivalent step in from-scratch generation), AFTER the writer fan-out and BEFORE entering the review loop.
  - `target_path`: repo-relative path under `architecture/tech-stack.md` → "Frontend Implementation Path" where the runnable draft will live (e.g. `frontend/src/pages/<feature-area>/`). The orchestrator passes this to the `frontend-design` skill (or the chosen TUI framework) and later writes it back into the feature file's `#### Frontend Draft Reference` `Draft path:` line.
  - When the user opts to defer Phase 5 for this feature during plan approval, the orchestrator MAY downgrade `must_run_phase_5` to `false` and record the deferral in the rationale; the convergence-time gate (CR-PP-FD01) will then accept the feature's Frontend Draft Reference written as `Confirmed (experience): null` plus a sibling `Drift:` line.

### Reasoning Guidelines

- For FromScratch: derive the file list from `clarification.yml` R-001 through R-007. The
  artifact type (R-002) determines the canonical PRD bundle layout — `README.md` + `journeys/J-NNN-*.md` +
  `features/F-NNN-*.md` + `architecture.md` + topic files under `architecture/`. Pick a feature
  count consistent with the user's MVP scope (typically 5–9 features for a first delivery).
- For NewVersion: compare `input.md` change description against `versions/<N-1>.md` to determine
  which existing files are affected. Files not mentioned in the change scope go to `keep`.
- For novel files outside the canonical bundle (e.g. a glossary, a migration plan), add them to
  `add` with `template: null` and explain in `rationale` why the standard PRD shape is insufficient.
- For every feature row in `add` or `modify`, decide whether the feature is user-facing. A feature
  is user-facing iff its template will be filled with an `## Interaction Design` section (i.e. it
  involves screens, components, or interactions visible to a human user). For each such row, emit
  the `frontend_draft` block with `must_run_phase_5: true` and a concrete `target_path` under the
  Frontend Implementation Path. For backend-only features (workers, ETL, API-only services), OMIT
  the block entirely. The orchestrator uses this signal in Step 8c to decide which features need
  Phase 5; the convergence-time gate (**CR-PP-FD01**) then verifies that every feature carrying
  Interaction Design also carries a populated Frontend Draft Reference.
- **Setting `must_run_phase_5` on `modify` rows** (NewVersion only): the planner cannot read
  feature content (orchestrator constraint), so the decision is a heuristic from the change
  description in `input.md` and the prior delivery's `versions/<N-1>.md`. Set
  `must_run_phase_5: true` when the change description references screen/layout/component/
  state-machine concerns (e.g. "rewrite the per-provider toggle UI", "add a new tab to the
  admin page", "change the loading spinner to a skeleton"). Set `must_run_phase_5: false` (or
  omit the block) when the change is non-UI (e.g. "tighten the AC for unauthorized access",
  "add a new analytics event", "rename a backend field"). The user can downgrade or upgrade at
  the HITL plan-approval gate; the rationale should call out any UI-touching modify row whose
  flag is `false` (e.g. "F-021 modifies AC text only — no Phase 5 needed").

### ACK Format

```
OK trace_id=<trace_id> role=planner linked_issues=
```

- `linked_issues` is empty for the planner (issues are raised by reviewers, not planners).
- Return this ACK as the **single and final line** of the Task return. Nothing after it.
