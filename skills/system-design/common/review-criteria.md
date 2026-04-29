# Review Criteria — system-design

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks — the prose is for human readers only. All
`conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via
CR-L04 (LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**.
Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

---

## Structural Criteria (Script-Type)

---

## CR-S01 skill-md-frontmatter

SKILL.md MUST have frontmatter with `name`, `version`, `description` keys. `description` MUST be ≤ 1024 characters and MUST start with the literal phrase "Use when" per guide §21.1.

```yaml
- id: CR-S01
  name: "skill-md-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-frontmatter.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S02 mode-routing-complete

The mode-routing table in SKILL.md MUST list all 4 base modes plus `--diagnose`. Every row in the routing table MUST include a "Loaded Files" column documenting which topic files are loaded for that mode.

```yaml
- id: CR-S02
  name: "mode-routing-complete"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-mode-routing.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S03 directory-skeleton

All required top-level directories — `generate/`, `review/`, `revise/`, `shared/`, `common/`, `scripts/` — MUST exist at the target skill root. Missing any directory means the skill scaffold is incomplete and downstream agents will fail on file-not-found errors.

```yaml
- id: CR-S03
  name: "directory-skeleton"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S04 subagent-file-inventory

All 8 required sub-agent prompts MUST be present: orchestrator (inline in SKILL.md) + 6 standalone files + reviewer has 2 prompts (standard + adversarial). Missing any prompt breaks the round loop.

```yaml
- id: CR-S04
  name: "subagent-file-inventory"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S05 scripts-inventory

All required shell scripts MUST exist and be executable. The full list (~13 scripts) is defined in guide §7.1. Missing or non-executable scripts cause silent failures in the review round.

```yaml
- id: CR-S05
  name: "scripts-inventory"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scripts-inventory.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-S06 config-schema

`config.yml` MUST contain all §21.2 top-level keys. A missing key causes the orchestrator to fall back to undefined defaults, producing non-deterministic behavior across environments.

```yaml
- id: CR-S06
  name: "config-schema"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-config-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S07 criteria-yaml-shape

Every criterion entry in the target skill's `review-criteria.md` MUST have the fields: `id`, `name`, `version`, `checker_type`, `severity`. `checker_type` MUST be one of `script`, `llm`, or `hybrid`. Malformed criteria are silently skipped by checker scripts.

```yaml
- id: CR-S07
  name: "criteria-yaml-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-criteria-yaml.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S08 ipc-footer-present

Every sub-agent prompt MUST contain the Snippet D fingerprint verbatim. Snippet D is the IPC footer that instructs the sub-agent to write output to the final path inside the sub-session and return exactly one ACK line. Without it, sub-agents return content inline and break the orchestrator's dispatch loop.

```yaml
- id: CR-S08
  name: "ipc-footer-present"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-ipc-footer.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S09 dispatch-log-snippet

The SKILL.md orchestrator body MUST contain the Snippet C fingerprint verbatim. Snippet C is the dispatch-log write pattern that ensures every sub-agent invocation is recorded for observability and retry recovery.

```yaml
- id: CR-S09
  name: "dispatch-log-snippet"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dispatch-log-snippet.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-S10 trace-id-format

All `trace_id` occurrences in the generated skill MUST use the format `R<N>-<role-letter>-<nnn>` where `role-letter` ∈ `{C, P, W, V, R, S, J}` per guide §3.5. Malformed trace IDs break log correlation and metrics aggregation.

```yaml
- id: CR-S10
  name: "trace-id-format"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-trace-id-format.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S11 tool-permissions-coverage

`config.yml` `tool_permissions` MUST enumerate all 8 roles. `user-interaction: true` MUST appear ONLY on `domain_consultant`. Any other role with `user-interaction: true` violates the pure-dispatch contract.

```yaml
- id: CR-S11
  name: "tool-permissions-coverage"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-config-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S12 metrics-aggregate-verbatim

`scripts/metrics-aggregate.sh` and `scripts/lib/aggregate.py` sha256 hashes MUST match the values recorded in `shared-scripts-manifest.yml`. These files are shared infrastructure; silent divergence causes cross-skill metrics incompatibility.

```yaml
- id: CR-S12
  name: "metrics-aggregate-verbatim"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scaffold-sha.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-S13 artifact-pyramid

The target skill's artifact output MUST use a multi-level index structure (README + subdirectories for modules, api, etc.). No single leaf file MAY exceed 300 lines. Flat single-file artifacts defeat the self-contained file principle.

```yaml
- id: CR-S13
  name: "artifact-pyramid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-artifact-pyramid.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-S14 git-precheck-dependencies

The target skill's `git-precheck.sh` MUST verify: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8` per guide §21.0. Missing version checks allow the skill to run in unsupported environments and produce hard-to-debug failures.

```yaml
- id: CR-S14
  name: "git-precheck-dependencies"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dependencies.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S15 skill-md-cost-control-sections

The target's `SKILL.md` MUST include the cost-control sections that the
`skill-md-template.md` template bakes in: a `## Model Tiers` heading, a
`### Per-dispatch model override` subsection with the role→tier→Agent-tool-`model`
mapping table, and a `## CLI Flags` table containing at minimum the rows
`--full`, `--no-consultant`, `--tier <role>=<tier>`, and `--max-iterations N`.

These sections are the orchestrator-facing contract for cost control. Without
them, the orchestrator inherits the parent session's model (typically `opus`)
across every sub-agent dispatch, and users have no documented way to skip the
domain-consultant or override tiers per role. The writer-subagent is told to
follow the SKILL.md template "exactly", but absent this script-tier check the
writer can quietly omit these sections (as observed in the prd-analysis
delivery-1 run that prompted this CR).

The check is structural — regex anchors against H2/H3 headings, the role table
header, and backtick-quoted flag literals. It does not validate the prose inside
each section; that would require an LLM check.

```yaml
- id: CR-S15
  name: "skill-md-cost-control-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-md-sections.sh
  severity: error
  applies_to: ["SKILL.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
  rationale: |
    Without this gate, Tier 1.1 (per-dispatch model override) and Tier 3.7
    (--no-consultant flag) silently fail to propagate from skill-forge into
    the generated skill's SKILL.md, regressing the cost optimizations on
    every new generation.
```

## CR-S16 skeleton-conformance

The target skill's root directory MUST conform to the canonical skeleton: only
`SKILL.md`, `CHANGELOG.md`, and (optionally) `README.md` may exist as loose
files at the skill root. The only permitted top-level subdirectories are
`common/`, `generate/`, `review/`, `revise/`, `shared/`, `scripts/`, and
`.review/`. All templates, mode files, sub-agent prompts, and discipline files
MUST live under their prescribed skeleton subdirectory (e.g. `*-template.md`
and `*-checklist.md` under `common/templates/`; `*-subagent.md` under the
matching role directory `generate/`/`review/`/`revise/`/`shared/`; `*-mode.md`
folded into the corresponding role directory's `index.md` or generate/ topic
file).

Without this gate, skills accumulate stray root-level `.md` files (templates,
mode docs, checklists) over their lifetime — CR-S03 only verifies that the
required directories *exist*, not that loose files *outside* them are
forbidden. The prd-analysis delivery-1 audit surfaced 11+ stray `.md` files at
the skill root that CR-S03 could not catch, breaking the assumption that
downstream agents can navigate by directory rather than ad-hoc filename.

The check emits one `CR-S16` issue per stray file or directory, with a concrete
`suggested_fix` proposing the canonical target path inferred from the filename
pattern.

```yaml
- id: CR-S16
  name: "skeleton-conformance"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-structure.sh
  severity: error
  applies_to: ["**"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
  rationale: |
    CR-S03 verifies that the canonical skeleton directories EXIST; CR-S16
    verifies that no stray files or directories live OUTSIDE the canonical
    skeleton. Without the strict whitelist, skill scaffolds drift over their
    lifetime as templates / mode files / checklists are added at the root
    rather than placed in the prescribed skeleton subdirectories.
```

## CR-S17 checker-implements-declared-cr

For every script-tier criterion in `review-criteria.md` that declares a `script_path:`, the target's script at that path MUST grep-contain the literal CR-ID string. This is the structural guard against the silent stale-checker drift: a script may be present on disk but lack the logic for a newly registered CR-ID, causing `run-checkers.sh` to return no issues even when violations exist.

The check is a textual grep, not a behavioural one. False negatives are possible (a script could contain the CR-ID string in a comment without actually implementing the check) but that is intentional — the cheaper structural signal catches the common case (deleted/renamed CR-ID logic) without trying to parse program semantics.

```yaml
- id: CR-S17
  name: "checker-implements-declared-cr"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-checker-implementations.sh
  severity: error
  applies_to: ["common/review-criteria.md", "scripts/check-*.sh"]
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
  rationale: |
    Detects stale-implementation drift: a script may be present but lack logic
    for a newly registered CR-ID, causing run-checkers.sh to return no issues
    even when violations exist.
```

---

## Domain Structural Criteria (Script-Type) — System-Design Lint

These CRs map 1:1 to the structural-lint checks in `structural-lint.md` (L1..L5 per-file,
X1..X8 cross-file). They are run by `scripts/run-checkers.sh` BEFORE LLM reviewers are
dispatched (two-phase quality gate). Mechanical gaps caught here MUST NOT be re-reported
as semantic findings.

---

## CR-L1 api-per-endpoint-blocks

Every `**METHOD /path**` heading in `api/API-*.md` MUST be followed by all seven required subsections in order before the next endpoint heading: Description, Authentication & Permissions, Request (table), Request example (fenced, populated), Response (table), Response example (fenced, populated), Constraints (bullet list). A missing Auth or Constraints subsection on any endpoint is a blocker; missing the other five subsections is mechanical.

```yaml
- id: CR-L1
  name: "api-per-endpoint-blocks"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["api/API-*.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-L2 placeholder-json

Placeholder tokens — `"..."`, `/* ... */`, `// ...`, a body that is literally `{}`, `"<placeholder>"`, `"TBD"`, `"TODO"`, `"snapshot of above"`, or `"items": [...]` as the sole content — MUST NOT appear inside any fenced code block belonging to a Request example or Response example in `api/API-*.md` or `modules/M-*.md`. Every field in the matching Response table's Body column MUST appear as a key in the Response example body.

```yaml
- id: CR-L2
  name: "placeholder-json"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["api/API-*.md", "modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L3 boundary-enforcement-cols

Every `## Boundary Enforcement` table in `modules/M-*.md` MUST have all four columns filled on every non-header row: Constraint, Tool/Lint/Test (a named rule identifier — not descriptive English like "custom lint" or "structural check"), File Path (resolves to an actual file in the repo root), CI Job (matches a job in the Development Infrastructure module's CI pipeline definition). Vague tool descriptions or empty cells are mechanical findings.

```yaml
- id: CR-L3
  name: "boundary-enforcement-cols"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L4 api-surface-cols

Every `## API Surface` table row in `modules/M-*.md` MUST fill all seven columns: Method+Path, Auth & Role, Success, Error Codes (at least one status code with error-type string, e.g. `400 invalid_request_error`), Request Example (anchor link of the form `[API-NNN](../api/API-NNN-slug.md#anchor)`), Response Example (anchor link), Constraints (not empty; `—` is acceptable only for pure internal endpoints). A literal `{}` or a path-only string without an anchor fails.

```yaml
- id: CR-L4
  name: "api-surface-cols"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L5 module-interface-types

Every type, function, or field referenced in a module's `## Interface Definition` block MUST resolve to a definition either in the same file's Data Model section, in another `modules/M-*.md` Interface Definition or Data Model, or in PRD types explicitly copied inline in the module. Dangling references with zero definition hits across the whole design directory are blockers in single-language strict mode; advisory in polyglot designs.

```yaml
- id: CR-L5
  name: "module-interface-types"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-X1 module-deps-vs-protocols

Every `(caller, callee)` pair implied by any module's `Deps (direct)` cell MUST have a matching row in `README.md`'s `## Module Interaction Protocols` table. Conversely, every Protocols row MUST map back to a declared Deps pair, or be annotated with a cross-cutting note linked from `## Dependency Layering`. Orphan rows on either side (declared dep with no protocol row, or protocol row with no declared dep) are blockers.

```yaml
- id: CR-X1
  name: "module-deps-vs-protocols"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-X2 endpoint-literal-vs-api

Every HTTP method+path literal (e.g. `POST /v1/tasks`) referenced in any module's `## State Management`, `## Key Interactions`, or `## API Surface` MUST exist as an endpoint heading in some `api/API-*.md`. Every endpoint defined in `api/API-*.md` MUST be claimed by at least one module's `## API Surface`. Hook-name-only references without a method+path literal are out of scope for lint. Both directions (module references nonexistent endpoint; endpoint unclaimed by any module) are blockers.

```yaml
- id: CR-X2
  name: "endpoint-literal-vs-api"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["modules/M-*.md", "api/API-*.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-X3 architecture-coverage

Every file under the PRD's `architecture/` directory MUST appear as a row in `README.md`'s `## Implementation Conventions` table (with a Category or PRD Policy cell referencing the topic), or be marked with a one-line `N/A — {reason}` note under Implementation Conventions that names the topic. Silent omission is a mechanical finding.

```yaml
- id: CR-X3
  name: "architecture-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

## CR-X4 analytics-coverage

Every PRD analytics event enumerated in any PRD feature file's `## Analytics` block MUST appear in `README.md`'s `## Analytics Coverage` section as an explicit row, or be covered by a named sweep rule that lists the feature IDs and the emitting channel. Unnamed blanket rules ("all backend features emit audit events" without feature IDs or channel) fail.

```yaml
- id: CR-X4
  name: "analytics-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

## CR-X5 feature-module-traceability

Every PRD `F-NNN` feature MUST appear as a row in `README.md`'s `## Feature-Module Mapping` with at least one `✦` or `△` marker on a module column. Every module with `✦` on a feature row MUST list that feature in its `> **Source Features:**` header line. Every module's Source Features section MUST reference at least one resolvable PRD feature file. Orphaned features (zero module allocation) are blockers; orphaned modules lacking feature trace are mechanical findings.

```yaml
- id: CR-X5
  name: "feature-module-traceability"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["README.md", "modules/M-*.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-X6 dependency-layering

Using the layer assignments in `README.md`'s `## Dependency Layering` table, every dependency edge `A → B` where `layer(B) > layer(A)` extracted from module `Deps (direct)` fields is a reverse-layer import. Reverse-layer imports with no documented cross-cutting exemption (consumer-side interface note linked from Dependency Layering) are blockers — there is no warning tier for this check. Reverse imports are never advisory.

```yaml
- id: CR-X6
  name: "dependency-layering"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-X7 single-source-of-truth

For every ID-prefix convention named in any module's Responsibility or Data Model (e.g. `task_`, `agv_`, `skl_`), the prefix MUST be declared in the authoritative source-of-truth module named in the Architecture Overview. A prefix locally declared in a non-owner module violates the single-source-of-truth invariant and is a blocker. Cross-file copies of data-model definitions, endpoint signatures, or Boundary Enforcement rules MUST be byte-equal to the canonical source or explicitly marked as a quoted excerpt.

```yaml
- id: CR-X7
  name: "single-source-of-truth"
  version: 1.0.0
  checker_type: llm
  severity: critical
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

## CR-X8 readme-references

Every relative path referenced from `README.md` MUST resolve to an existing file: module paths (`modules/M-*.md`), API paths (`api/API-*.md`), PRD feature links (`../../prd/.../features/F-*.md`). The `REVISIONS.md` reference link in `## References` MUST appear if and only if the file exists. Broken references are mechanical findings.

```yaml
- id: CR-X8
  name: "readme-references"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-L01 orchestrator-pure-dispatch

The orchestrator body MUST explicitly forbid: reading leaf files, summarizing content, computing verdicts, rewriting artifacts, and analyzing issue priority. MUST include an explicit "Pure dispatch + bookkeeping only" statement. An orchestrator that does semantic work violates the role boundary and creates non-deterministic round behavior.

```yaml
- id: CR-L01
  name: "orchestrator-pure-dispatch"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-L02 ack-contract-fidelity

Every sub-agent prompt MUST enforce the ACK contract: "Write to final path inside sub-session" and "Task return is one ACK line". Phrases like "return the full output" or "include the content in your reply" are FORBIDDEN. Violating the ACK contract causes the orchestrator to receive inline content instead of a file path, breaking state management.

```yaml
- id: CR-L02
  name: "ack-contract-fidelity"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

## CR-L03 description-is-trigger

SKILL.md `description` MUST answer "when to invoke this skill" — not "what the skill does internally". A description that describes internal mechanics rather than trigger conditions prevents correct skill selection by the routing layer.

```yaml
- id: CR-L03
  name: "description-is-trigger"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L04 criteria-internally-consistent

No two criteria in the target's `review-criteria.md` MUST have `conflicts_with` references that create oscillation-prone pairs per guide §13.1. Oscillating criteria cause the convergence judge to never reach `converged` verdict.

```yaml
- id: CR-L04
  name: "criteria-internally-consistent"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L05 artifact-template-self-contained

The target skill's artifact templates MUST follow the self-contained file principle: module files MUST NOT contain dangling cross-references to sibling files for content. All referenced context (data models, conventions, journey context) MUST be copied inline. A coding agent implementing a module should need to open only that module's file.

```yaml
- id: CR-L05
  name: "artifact-template-self-contained"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L06 writer-prompt-quality-bar

The writer sub-agent prompt MUST describe "what good output looks like" with at least 1 positive example (DO) and at least 1 negative example (DON'T / FORBIDDEN / BAD). Without a quality bar, the writer has no grounding for self-review and produces inconsistent output.

```yaml
- id: CR-L06
  name: "writer-prompt-quality-bar"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L07 reviewer-prompt-discipline

Reviewer prompts MUST use normative language: `MUST`, `MUST NOT`, `FORBIDDEN`. Soft language (`try to`, `prefer`, `ideally`) is FORBIDDEN for hard checks. Soft language in reviewer prompts produces inconsistent issue severity classification and blocker under-reporting.

```yaml
- id: CR-L07
  name: "reviewer-prompt-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L08 tier-mapping-justified

If `model_tier_defaults` in `config.yml` deviates from the guide §20.2 recommended tiers, the deviation MUST be explained in a comment. Unexplained tier changes may indicate copy-paste errors or cost optimizations that degrade output quality.

```yaml
- id: CR-L08
  name: "tier-mapping-justified"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L09 blocker-scope-taxonomy

The writer sub-agent prompt's self-review instructions MUST list all 4 `blocker_scope` values: `global-conflict`, `cross-artifact-dep`, `needs-human-decision`, `input-ambiguity`. Missing scope values cause the reviewer to silently omit blockers that would trigger HITL escalation.

```yaml
- id: CR-L09
  name: "blocker-scope-taxonomy"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-L10 hitl-gates-sensible

`config.yml` `hitl.require_approval` MUST include at minimum: `plan_approval`, `force_continue`, `regression_justification` per guide §18.1. Missing HITL gates allow the skill to proceed autonomously past points that require human judgment.

```yaml
- id: CR-L10
  name: "hitl-gates-sensible"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

## CR-L11 cross-reference-consistency

A stated contract in any artifact MUST agree with the implementation, list, or path it references in another artifact. CR-L04 covers ONLY oscillation-prone `conflicts_with` pairs inside `review-criteria.md`; CR-L11 covers the broader cross-artifact contract — any case where one file declares a name, path, count, or behavior that another file implements differently.

Concrete patterns that violate CR-L11:

- `review-criteria.md` declares `script_path: scripts/X.sh` but the inventory check or scaffold doesn't list `X.sh`.
- A mode file and its canonical counterpart ship two different orchestration models for the same mode, so `SKILL.md` Mode Routing cannot point to a single source of truth.
- A shell script's stated contract in its header comment is contradicted by its actual execution path (e.g., a quoting bug that makes bootstrap impossible).
- An ID, count, or convention referenced in two places drifts because no script enforces consistency.

Severity is `error` rather than `critical` because individual cross-reference inconsistencies usually do not block the round; they degrade clarity over time and bake in drift. Critical-level escalation belongs to CR-L01/CR-L02 (orchestrator pure-dispatch / ACK-contract fidelity), which protect the dispatch loop itself.

```yaml
- id: CR-L11
  name: "cross-reference-consistency"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
  rationale: |
    Round-6 audit found 11 of 21 LLM-tier issues mis-tagged as CR-L04 because
    no broader cross-reference criterion existed. CR-L11 carves out the broader
    scope as its own criterion so future reviewers tag accurately and CR-L04
    stops bearing semantic load it was not designed for.
```

---

## Domain Semantic Criteria (LLM-Type) — System-Design Design Review

These CRs correspond to the semantic dimensions in `design-review-checklist.md`. They are
evaluated by LLM reviewers AFTER the structural lint gate (CR-L1..CR-X8) passes. Per-file
dimensions are dispatched in parallel subagent fan-out; cross-file dimensions are evaluated
once by the main reviewer after subagents return.

Mechanical gaps fully covered by structural lint (L1/L2/L4 for API completeness; L3 for
enforcement coverage) MUST NOT be re-reported here. When a dimension's structural side is
covered by a lint CR, only the semantic side (appropriateness, architectural correctness,
intent) is evaluated.

---

## CR-D01 responsibility-scoping

Each module MUST have a single bounded responsibility with no overlap or leakage into sibling modules. The Responsibilities section MUST state exactly what the module does — not a vague description that could apply to multiple modules. Overlap (same operation owned by two modules) and leakage (module performing operations clearly belonging to another module's domain) are findings.

```yaml
- id: CR-D01
  name: "responsibility-scoping"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D02 nfr-decomposition

Every PRD-level NFR MUST be decomposed to at least one module's NFR section with concrete, measurable per-module budgets (e.g. P99 latency, throughput targets, storage quotas). `README.md`'s NFR Allocation table MUST be consistent with module-level NFR sections. Vague NFR statements (e.g. "must be fast") without numeric budgets are findings. Budget allocations that are numerically plausible but architecturally wrong for the module's actual role are critical-severity findings.

```yaml
- id: CR-D02
  name: "nfr-decomposition"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D03 error-handling-depth

Every API error path MUST be covered in the module's Error Handling section: retry policy, timeout values, and idempotency guarantees MUST be stated for every external call. A module with external dependencies that has no Error Handling section, or whose section omits retry/timeout/idempotency for any external call, is a finding. Vague error handling ("returns error to caller") without stated policy is not sufficient.

```yaml
- id: CR-D03
  name: "error-handling-depth"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D04 testability

Each module MUST state: (a) test strategy (unit / integration / contract / e2e), (b) isolation strategy (how external dependencies are replaced in tests — injectable interfaces, test doubles, mock servers), and (c) fixture sources (where test data comes from). README's Test Strategy section MUST exist and be consistent with per-module Testing sections. Modules with external dependencies that specify no test double strategy are findings. NFR verification methods MUST be stated for runtime-verifiable NFRs.

```yaml
- id: CR-D04
  name: "testability"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D05 risk-coverage

Every high-likelihood or high-impact risk identified in the PRD MUST have a corresponding design mitigation in the affected module's Error Handling, NFR, or Interaction Protocols section. Open Questions and known-unknowns MUST be enumerated per module with a status (open / resolved / deferred). Open Questions requiring a decision that blocks implementation MUST surface in the README's Open Questions section with an owner and deadline.

```yaml
- id: CR-D05
  name: "risk-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D06 self-contained-files

Each module spec MUST be independently readable and actionable by a coding agent without opening any sibling file. All referenced context — data models, conventions, dependency contracts — MUST be copied inline rather than referenced by path. A module that says "see M-003 for the data model" instead of copying the relevant model inline is a finding. The only valid cross-file references are anchor links in API Surface rows (explicit and path-resolvable, covered by CR-L4).

```yaml
- id: CR-D06
  name: "self-contained-files"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "api/API-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D07 interface-protocols

Every cross-module call MUST have an explicit protocol/contract stated in the Module Interaction Protocols table: sync/async classification, retry policy, and idempotency guarantee. A Protocols row with Method/Data Format/Error Strategy cells that are vague ("calls the API", "async message") without concrete protocol details is a finding. CR-X1 covers structural row presence; CR-D07 evaluates whether the row's content is semantically adequate.

```yaml
- id: CR-D07
  name: "interface-protocols"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D08 observability

Each module's logging, metrics, and tracing requirements MUST be stated. At minimum: what events are logged (with level), what metrics are emitted (with unit and cardinality), and whether distributed trace context is propagated. Modules without any observability section (where the module makes external calls or handles user requests) are findings. Observability requirements MUST be consistent with the PRD's Observability Requirements convention if one exists.

```yaml
- id: CR-D08
  name: "observability"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D09 status-lifecycle-correctness

Design-artifact Status values MUST use exactly: `Draft`, `Finalized`, `Implementing`, `Implemented` for document status; and `NotStarted`, `InProgress`, `Done` for implementation tracking. Mixed or custom status values (e.g. `WIP`, `In Review`, `Complete`) are findings. Status assignments MUST be internally consistent — a module marked `Implementing` MUST have at least one impl-tracking field set to `InProgress` or `Done`.

```yaml
- id: CR-D09
  name: "status-lifecycle-correctness"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

## CR-D10 prd-traceability

Every module MUST reference at least one PRD `F-NNN` feature in its Source Features section, and that reference MUST resolve to an actual feature file in the PRD directory. CR-X5 covers the structural presence of Feature-Module Mapping rows; CR-D10 evaluates whether the allocation is substantive — the module's Responsibility and Interface MUST actually deliver the feature's behavior, not merely list the feature ID nominally.

```yaml
- id: CR-D10
  name: "prd-traceability"
  version: 1.0.0
  checker_type: llm
  severity: error
  applies_to: ["modules/M-*.md", "README.md"]
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
