# Structural Lint — Mechanical Gate Before Semantic Review

This file defines **deterministic, grep-runnable checks** that fire before any semantic review. Its sole purpose is to catch the recurring mechanical gaps that otherwise dominate review findings (placeholder `...` in JSON, missing per-endpoint blocks, unfilled Boundary Enforcement columns, endpoint literals referencing nonexistent API contracts, PRD convention files silently dropped).

## Why this exists

Reviewers consistently waste cycles rediscovering the same mechanical gaps. In one observed design, three sequential `--review → --revise` cycles each produced 49 → 40 → 115 Important findings, the majority of which were repeats of identical patterns (missing `Authentication & Permissions` block, missing populated JSON, missing `CI Job` column). Each cycle burned subagent tokens re-finding issues that a `grep` could have caught in seconds.

**Rule:** mechanical gaps are not semantic findings. They must be fixed in place before review begins, not reported as review output. If a reviewer re-discovers a gap that any check below would have caught, the structural-lint pass was skipped — re-run it and extend this file if a new pattern slipped through.

## When to run

| Mode | Entry point | Failure action |
|------|-------------|----------------|
| Generate | `generate-mode.md` Step 9a (after files written, before Step 10 semantic self-review) | Fix in place via MultiEdit, re-run until clean, then proceed to Step 10 |
| Revise | `revise-mode.md` Step 7.0 — mandatory gate **before** the Step 7 semantic cross-file sweep | Fix via Fix subagent batch, re-run, then proceed with semantic sweep |
| Review | `review-mode.md` Step 1.5 (after inventory, before Step 2 subagent dispatch) | Report failures in the review preamble so `--revise` fixes them via lint, not via per-file re-edits. LINT file stays in `.reviews/` unrenamed (review is read-only); next run's timestamp supersedes it. `.applied.md` rename only happens when the consumer is a lint-fix mode (generate / revise). |

## Execution model

The main agent may run lint checks directly via `Bash` / `Grep` / `Glob`, or delegate to a `general-purpose` subagent (model: `sonnet`) for a single sweep. Subagent delegation is preferred when the design has >20 modules — lint output stays out of main context.

Each check produces rows in this shape:

```
[check-id] <severity> <relative path>:<line-or-anchor> — <one-line reason>
  Fix: <concrete edit>
```

`severity` is always `blocker` or `mechanical`. There is no "suggestion" tier in lint — if a check produces ambiguous output, it belongs in the semantic checklist, not here.

Aggregated output is written to `{design-dir}/.reviews/LINT-{timestamp}.md` (same `.reviews/` scratch directory as reviews; create the directory if absent). Rename behavior is mode-specific — see the When-to-run table above. Never commit `.reviews/`.

## Per-file checks

### L1 — API per-endpoint seven subsections

Every `**METHOD /path**` heading in `api/API-*.md` (for REST APIs) must be followed by these seven subsections **in order**, before the next endpoint heading or next `###` section. This matches the enforcement in `api-template.md` Rules ("Per-endpoint completeness"):

1. `**Description:**`
2. `**Authentication & Permissions:**`
3. `**Request:**` (table — location column may be `header`, covering dual-surface/beta headers)
4. `**Request example:**` (fenced JSON or HTTP block)
5. `**Response:**` (table)
6. `**Response example:**` (fenced JSON block)
7. `**Constraints:**` (bullet list)

Grep sketch:

```bash
# For each API-*.md, extract sections between ^\*\*(GET|POST|PUT|PATCH|DELETE) headers.
# Assert each section contains all seven subheadings exactly once.
```

Severity: **blocker** for a missing Auth or Constraints subsection on any endpoint (matches `design-review-checklist.md` Critical-adjacent class); **mechanical** for missing Description, Request, Request example, Response, or Response example.

### L2 — Forbidden placeholders in examples

**Authoritative forbidden-pattern list lives in `api-template.md` Rules section.** When the template gains a new forbidden pattern, mirror it here. If the two files drift, the template wins — `api-template.md` is the source of truth for what belongs in a contract; this lint rule is the enforcement surface.

These patterns never appear inside a fenced code block that belongs to `**Request example:**` or `**Response example:**`:

| Pattern | Why forbidden |
|---------|---------------|
| `"..."` | lazy filler — use a populated value |
| `/* ... */` | JSON comments are invalid AND the `...` is filler |
| `// ...` | same |
| A body that is literally `{}` | populated example required |
| `"<placeholder>"`, `"TBD"`, `"TODO"` | explicit placeholder text |
| `"snapshot of above"` | cross-reference instead of content |
| `...` as the sole content of an object/array value (e.g. `"items": [...]`) | filler |

Every field in the matching `**Response:**` table's Body column must appear as a key in the `**Response example:**` body. A check that iterates Body entries and greps for each key in the example block catches schema/example drift.

Severity: **mechanical**. Fix by writing a realistic populated example derived from the Request/Response tables and field constraints.

### L3 — Boundary Enforcement four-column fill

In every `modules/M-*.md`, the `## Boundary Enforcement` table (when present) must have four columns: `Constraint | Tool / Lint / Test | File Path | CI Job`. Every non-header row must have:

- `Tool / Lint / Test`: a named rule identifier, e.g. `golangci-lint:errcheck`, `eslint:no-restricted-paths:repo-no-service`, `go test ./internal/{slug}/...`. Descriptive English like `custom lint`, `structural check`, or `code review rule` fails.
- `File Path`: a path that resolves to an actual file in the repo root (config file or test file).
- `CI Job`: a job name that appears in the Development Infrastructure module's CI pipeline definition.

Grep sketch: count `|` per row under `## Boundary Enforcement`; any row with <5 separators or a `Tool` cell matching `(custom|structural|code[- ]review)\s*$` fails.

Severity: **mechanical**. Fix by either (a) filling with concrete tool + file + job, or (b) moving the row to `## Implementation Constraints` as advisory.

### L4 — API Surface seven-column fill

Every `## API Surface` row in a `modules/M-*.md` file must fill all seven columns: `Method + Path | Auth & Role | Success | Error Codes | Request Example | Response Example | Constraints`.

- `Request Example` / `Response Example` must be an anchor link of the form `[API-NNN](../api/API-NNN-slug.md#anchor)` — a literal `{}` or `see API-...` string without anchor fails.
- `Error Codes` must list at least one status code with an error-type string (e.g. `400 invalid_request_error`).
- `Constraints` cell is not empty (`—` is acceptable only for pure internal endpoints).

Severity: **mechanical**. Fix by looking up the endpoint in `api/API-*.md` and pasting anchor links.

### L5 — Module interface type references resolve

Every type, function, or field referenced in a module's `## Interface Definition` block must be defined somewhere in the design — either:

- In the same file's `## Data Model` or earlier in the file, or
- In another `modules/M-*.md` file's `## Interface Definition` (or `## Data Model`), or
- In the imported-from-PRD types explicitly copied in the module.

**Scope:** this check is best-effort. Identifier extraction from a fenced code block depends on the module's language (Go: capitalized exports; TypeScript: `export` keyword; Python: convention). Run L5 with per-language regex when the project has a single primary language (detectable via the tech stack in README's Key Technical Decisions). For polyglot designs, mark L5 advisory — the reviewer checks the same class under the semantic checklist's Implementability dimension.

Heuristic grep (single-language projects): extract exported identifiers from each module's Interface Definition code block; for each identifier, grep across the whole design directory for its definition. Any identifier with zero definition hits is a dangling reference.

Severity: **blocker** when L5 runs in its strict form (matches Critical example in semantic checklist: "Module's Interface Definition references a type … that is not defined anywhere in the design"). Advisory when L5 is in best-effort mode — report as mechanical.

## Cross-file checks

### X1 — Module Deps ↔ README Module Interaction Protocols

For every `modules/M-*.md`, extract the module's `Deps (direct)` cell. For each `(caller, callee)` implied pair, assert `README.md`'s `## Module Interaction Protocols` table has one row with `Caller → Callee = {caller} → {callee}` (or the pair is annotated with a cross-cutting note linked from `## Dependency Layering`).

Likewise, every protocol row must map to a declared Deps pair. Orphan rows on either side fail.

Severity: **blocker** (matches "Interaction completeness" dimension; observed as a recurring Important finding that should be mechanically preventable).

### X2 — Endpoint literal ↔ API file alignment

Hook-name inference (`useListSkills` → `GET /skills`) is fragile — naming conventions differ per project and are not enforced by the module template. This check operates on **literal method+path strings** to stay deterministic.

For every `modules/M-*.md`:

- Grep for HTTP method+path literals (e.g. `POST /v1/tasks`, `GET /api/v1/skills/:id`) under `## State Management`, `## Key Interactions`, and `## API Surface`.
- For each literal, assert the same method+path appears as an endpoint heading in some `api/API-*.md` file.

For every endpoint defined in `api/API-*.md`:

- Assert at least one module's `## API Surface` lists the same method+path (no orphan endpoints).

Hook-name-only references without a method+path literal are out of scope for lint — flag them as a Self-containment finding in the semantic checklist instead (the module spec should carry the literal so a coding agent can implement without inferring).

Severity: **blocker**. The canonical "frontend references nonexistent endpoint" class (Critical example in semantic checklist) must never reach a reviewer.

### X3 — PRD architecture.md ↔ README Implementation Conventions

List every file under `{PRD path}/architecture/*.md`. For each topic file, `README.md`'s `## Implementation Conventions` must contain either:

- A row whose Category name or PRD Policy column cell references the topic, or
- A one-line `N/A — {reason}` note under Implementation Conventions that names the topic.

Silent omission fails. Extra rows are fine.

Severity: **mechanical**. Fix by inserting the missing row or N/A note.

### X4 — PRD Analytics events ↔ README Analytics Coverage

`grep -A 30 '^## Analytics' {PRD path}/features/*.md` produces a per-feature event list (each event appears as a row in a `| Event | Trigger | ... |` table, or as a bullet). For each event, assert one row in `README.md` `## Analytics Coverage` matches on `(Feature, Event)`, **or** a named sweep rule covers it (e.g. `F-004..F-042 (operational backend) → audit.Emit → Log Viewer`).

Unnamed blanket rules ("all backend features emit audit events") fail — the sweep rule must list feature IDs and the channel.

Severity: **mechanical**. Fix by adding rows or refining the sweep rule.

### X5 — PRD Feature ↔ Module traceability

List every `F-*` feature from `{PRD path}/features/*.md`. For each feature:

- `README.md` `## Feature-Module Mapping` must have the feature as a row with at least one `✦` or `△` marker on a module column.
- Every module with `✦` on that row must have the feature in its `> **Source Features:** F-...` header line.

List every `M-*` module. For each module, the `## Source Features` section must contain at least one feature reference that resolves (grep-able path) to a PRD feature file.

Severity: **blocker** for orphaned features (matches Critical example "PRD feature with zero module allocation"); **mechanical** for orphan module lacking feature trace.

### X6 — Dependency Layering forward-only

Build a graph from every module's `Deps (direct)`. Using `README.md`'s `## Dependency Layering` table, assign each module to a layer. Any edge `A → B` where layer(B) > layer(A) **and** the pair has no documented cross-cutting exemption (consumer-side interface note linked from Dependency Layering) is a reverse-layer import.

Severity: **blocker** (matches Critical example "Module's Deps imports a module in a higher layer … with no documented cross-cutting exemption").

### X7 — Single-source-of-truth invariants

For every ID-prefix convention named in any module's Responsibility or Data Model (e.g. `task_`, `agv_`, `skl_`), assert the prefix is declared in the authoritative source-of-truth module named in the Architecture Overview (typically the Types or IDs module). A prefix locally declared in a module that is not itself the source of truth violates the "single truth" invariant.

Severity: **blocker**. This class caused an observed Critical finding (`agv_` prefix declared in M-012 while M-003 was supposed to own all prefixes). The fix is either extending the source module or weakening the source-of-truth invariant and documenting the exception.

**Semantic escalation path:** X7 is lint-only — there is no dedicated `design-review-checklist.md` dimension for invariant ownership. When a reviewer encounters a related semantic case lint cannot evaluate (e.g. the "owner" module itself is weakly defined, or two modules both legitimately claim prefix ownership with unclear arbitration), report the finding under the **Consistency** dimension tagged `[X7-semantic]` so the relationship to this lint rule is traceable.

### X8 — README references resolve

`README.md` `## References` section links must resolve:

- `REVISIONS.md` link appears iff the file exists
- Each `[{PRD name}]({path})` link resolves relative to the README
- `Revision History` bullet appears iff `REVISIONS.md` exists

Severity: **mechanical**.

## Reporting format

Aggregate into `{design-dir}/.reviews/LINT-{timestamp}.md`:

```markdown
# Structural Lint — {ISO timestamp}

Reviewed: {absolute path of design directory}
Checks run: L1, L2, L3, L4, L5, X1, X2, X3, X4, X5, X6, X7, X8
Blocker: N
Mechanical: N

## Failures

### {relative path}
- [L2] mechanical: Response example uses `"..."` filler at line 87
  Fix: replace with populated JSON derived from Response table's Body column

### modules/M-012-agents.md
- [X7] blocker: `agv_` prefix declared locally; source of truth is M-003 per Architecture Overview
  Fix: move `PrefixAgentVersion` declaration to M-003, or weaken M-003 invariant and document the exception inline

## Cross-file

- [X1] blocker: M-016 → M-022 dependency pair has no row in Module Interaction Protocols
  Fix: add row `M-016 → M-022` with method/data/error strategy, or document cross-cutting exemption under Dependency Layering
```

## Extending this file

When a new recurring mechanical gap shows up in a review:

1. Check whether an existing rule would have caught it — if yes, the rule's grep pattern needs refining; update it here.
2. If it's a genuinely new class, add a new check with an ID (`L{N}` for per-file, `X{N}` for cross-file), severity, grep sketch, and fix guidance.
3. Cross-reference the new check from the corresponding semantic-checklist dimension in `design-review-checklist.md` (note: "caught upstream by structural-lint {id}").

Do not add checks that require semantic judgment — those belong in `design-review-checklist.md`. The test is: can a deterministic script flag the failure without understanding intent? If yes, it belongs here.
