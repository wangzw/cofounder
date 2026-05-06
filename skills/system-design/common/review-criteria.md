# Review Criteria — system-design

Each criterion is defined below as a human-readable description followed by a YAML code block.
Checker scripts extract only the YAML blocks — the prose is for human readers only. All
`conflicts_with` fields are intentionally empty in v1.

Criteria are partitioned per the dual-criteria from the audit-design guide §1.3:

- **Formal (script-type)** — mechanically expressible AND the result does not imply a
  correctness judgment. Enforced by a per-artifact script under `scripts/check-*.sh` (one
  script per artifact type). Failure is a **necessary condition** preventing convergence
  (guide §5). LLM reviewers MUST NOT also apply these — they were already enforced before
  any LLM dispatch (guide §6 fast-failure).
- **Substantive (LLM-type)** — content correctness, design coherence, cross-leaf
  consistency. Applied by cross-reviewer / adversarial-reviewer. Convergence requires
  substantive PASS in addition to formal PASS.

Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`.

> **`script_path` semantics**: when multiple per-artifact `check-*.sh`
> scripts emit the same CR (e.g. `CR-SD03 no-tbd-remaining` is enforced
> by every per-artifact checker against its own scope), the `script_path`
> field names the **canonical primary owner**. `run-checkers.sh`
> auto-discovers and invokes every applicable `check-*.sh` regardless
> of this field; the canonical owner is purely a documentation pointer
> for "where to look first when triaging this CR-id".

---

## Formal Criteria (Script-Type)

These criteria are evaluated mechanically by per-artifact scripts under `scripts/`. The
script emits one issue per finding in the schema documented in `common/issue-schema.md`.

---

## CR-SD01 readme-shape

The `<design-dir>/README.md` MUST exist and contain a structured index of the bundle:
- a section that enumerates every `M-NNN` module file under `modules/`
- when `api/` exists, a section that enumerates every `API-NNN` API file
- a one-line product / system identification near the top

Missing index entries break downstream consumption — `/cofounder:autoforge` and reviewers
both walk the README to discover modules.

```yaml
- id: CR-SD01
  name: "readme-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-readme.sh
  severity: critical
  conflicts_with: []
  priority: 1
```

---

## CR-SD02 feature-module-matrix-present

The README MUST contain a "Feature-Module Mapping" matrix table: feature columns crossed
with module rows, marked with `✦` (module modifies data for that feature) or `△` (module
provides read-only support). The matrix is the bridge between PRD requirements and
system-design modules — without it, traceability cannot be established.

```yaml
- id: CR-SD02
  name: "feature-module-matrix-present"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-readme.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD03 no-tbd-remaining

No `TBD`, `TODO`, `FIXME`, or `PLACEHOLDER` tokens remain anywhere in the design bundle.
Every per-artifact `check-*.sh` enforces this against its own scope.

```yaml
- id: CR-SD03
  name: "no-tbd-remaining"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-readme.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD04 module-id-monotonic

Module files under `modules/` MUST follow the `M-NNN-{slug}.md` pattern with IDs starting
at `M-001` and increasing without gaps. Gaps or duplicates corrupt downstream references
(matrix columns, cross-module dependency declarations).

```yaml
- id: CR-SD04
  name: "module-id-monotonic"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD05 feature-module-mapping-bidirectional

Every feature `F-NNN` declared in the linked PRD MUST appear in the matrix with at least
one `✦` cell. Every module `M-NNN` declared in `modules/` MUST be referenced from at least
one matrix cell. Bidirectional traceability prevents orphan features and orphan modules.

```yaml
- id: CR-SD05
  name: "feature-module-mapping-bidirectional"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-feature-module-mapping.sh
  severity: critical
  conflicts_with: []
  priority: 1
```

---

## CR-SD06 module-required-sections

Each module file MUST contain the canonical sections: `## Responsibilities`,
`## Public Interfaces`, `## Data Models`, `## Dependencies`, `## Boundary Enforcement`.
These structure module specs so that coding agents can locate each kind of contract
without re-parsing every file.

```yaml
- id: CR-SD06
  name: "module-required-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD07 module-interface-types

Every entry in a module's `## Public Interfaces` section MUST declare a type signature
(function signature, request/response shape, or schema reference). An interface without a
type signature is unimplementable.

```yaml
- id: CR-SD07
  name: "module-interface-types"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD08 module-deps-vs-protocols

Every entry in a module's `depends_on` (frontmatter or `## Dependencies` section) MUST
reference a declared protocol/contract — i.e. either the depended-on module's
`## Public Interfaces` entry or an `API-NNN` endpoint.

```yaml
- id: CR-SD08
  name: "module-deps-vs-protocols"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD09 boundary-enforcement-cols

The `## Boundary Enforcement` table inside each module file MUST contain the required
columns: `Boundary`, `Mechanism`, `Enforced At`, `Failure Mode`. Without these columns
the boundary contract is ambiguous.

```yaml
- id: CR-SD09
  name: "boundary-enforcement-cols"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD10 api-id-monotonic

API files under `api/` MUST follow the `API-NNN-{slug}.md` pattern with IDs starting at
`API-001` and increasing without gaps.

```yaml
- id: CR-SD10
  name: "api-id-monotonic"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-api.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD11 api-per-endpoint-blocks

Each endpoint section in an API file MUST declare `Method`, `Path`, `Request`, `Response`,
and `Errors`. A missing slot makes the endpoint unimplementable.

```yaml
- id: CR-SD11
  name: "api-per-endpoint-blocks"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-api.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD12 api-surface-cols

Each API file MUST contain a top-level "Surface" table with columns at minimum:
`Endpoint`, `Method`, `Auth`, `Idempotent`. The surface table is the at-a-glance overview
required by reviewers.

```yaml
- id: CR-SD12
  name: "api-surface-cols"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-api.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD13 endpoint-literal-vs-api

Every literal `METHOD /path` mentioned in a module file MUST appear in some API doc's
endpoint blocks. A literal endpoint reference with no API contract is a phantom dependency.

```yaml
- id: CR-SD13
  name: "endpoint-literal-vs-api"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-api.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD14 architecture-coverage

Every architecture topic referenced from the linked PRD's architecture index MUST be
covered by at least one module or by an explicit "Out of scope" declaration in the design
README. Uncovered topics are silent regressions.

```yaml
- id: CR-SD14
  name: "architecture-coverage"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-architecture-coverage.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD15 analytics-coverage

Every analytics event declared in the PRD MUST be emitted by at least one module's
documented behavior. Modules emitting events not present in the PRD are also flagged.

```yaml
- id: CR-SD15
  name: "analytics-coverage"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-analytics-coverage.sh
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## CR-SD16 dependency-layering

Module dependency edges MUST not introduce cycles, and MUST not invert declared
architectural layering (e.g. domain modules may not depend on transport modules).

```yaml
- id: CR-SD16
  name: "dependency-layering"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dependency-layering.sh
  severity: critical
  conflicts_with: []
  priority: 1
```

---

## CR-SD17 placeholder-json

JSON code blocks (e.g. example request bodies) MUST be parseable JSON; placeholder strings
like `<TODO>` or `...` inside JSON blocks are forbidden.

```yaml
- id: CR-SD17
  name: "placeholder-json"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-placeholder-json.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD18 readme-references

Every link from `README.md` to `modules/`, `api/`, or other bundle files MUST resolve to
an existing file. Dangling references corrupt navigation.

```yaml
- id: CR-SD18
  name: "readme-references"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-readme-references.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SD19 single-source-of-truth

A given fact (e.g. an endpoint signature, a data-model field) MUST appear in exactly one
authoritative location and be referenced from elsewhere — not duplicated. Duplication
risks divergence across rounds.

```yaml
- id: CR-SD19
  name: "single-source-of-truth"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-single-source-of-truth.sh
  severity: warning
  conflicts_with: []
  priority: 3
```

---

## CR-SDFM01 readme-frontmatter

The README MUST carry a frontmatter block with required fields: `id`, `title`, `owner`,
`status`, `version`, `prd_ref`. Missing frontmatter breaks downstream indexing.

```yaml
- id: CR-SDFM01
  name: "readme-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-readme.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SDFM02 module-frontmatter

Each module MUST carry frontmatter: `id` (matching `M-NNN`), `title`, `owner`, `status`,
`version`, `depends_on` (a YAML list, possibly empty).

```yaml
- id: CR-SDFM02
  name: "module-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-module.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-SDFM03 api-frontmatter

Each API file MUST carry frontmatter: `id` (matching `API-NNN`), `title`, `owner`,
`status`, `version`, `module_ref` (the M-NNN id of the owning module).

```yaml
- id: CR-SDFM03
  name: "api-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-api.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## CR-IS01 issue-schema-conformance

Every issue file under `<artifact-root>/.review/round-<N>/issues/` MUST conform to the
on-disk schema defined in `common/issue-schema.md`. This is review-artifact self-closure
(guide §10).

```yaml
- id: CR-IS01
  name: "issue-schema-conformance"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-issue.sh
  severity: error
  applies_to: [".review/round-*/issues/*.md"]
  conflicts_with: []
  priority: 2
```

---

## Audit-Artifact Schema Criteria (CR-CL / CR-PL / CR-SR / CR-RO / CR-RI / CR-VD / CR-VS / CR-CH)

These criteria audit LLM-produced artifacts of the review pipeline itself
(guide §10 self-closure). Each pairs with a per-artifact check script.
`CR-CH*` audits the script-produced `compacted-history.md` summary
written by `scripts/compact-delivery.sh` when the user runs `--compact`
to retire intermediate review rounds before transitioning to the next
pipeline stage.

```yaml
- id: CR-CL01
  name: "clarification-required-keys-present"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-clarification.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-CL02
  name: "clarification-flat-keys-first"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-clarification.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-PL01
  name: "plan-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-plan.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-PL02
  name: "plan-add-modify-entry-shape"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-plan.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR01
  name: "self-review-required-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR02
  name: "self-review-fail-blocker-scope"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-SR03
  name: "self-review-status-fail-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-self-review.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RO01
  name: "reviewer-output-json-valid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-reviewer-output.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RO02
  name: "reviewer-output-issue-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-reviewer-output.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RI01
  name: "round-index-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-round-index.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-RI02
  name: "round-index-state-counts-sum-to-total"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-round-index.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VD01
  name: "verdict-required-fields"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-verdict.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VD02
  name: "verdict-next-action-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-verdict.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VS01
  name: "version-required-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-version.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-VS02
  name: "version-converged-only"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-version.sh
  severity: error
  conflicts_with: []
  priority: 2
- id: CR-CH01
  name: "compacted-history-required-frontmatter"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-compacted-history.sh
  severity: error
  conflicts_with: []
  priority: 3
- id: CR-CH02
  name: "compacted-history-final-round-monotonic"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-compacted-history.sh
  severity: error
  conflicts_with: []
  priority: 3
- id: CR-RV01
  name: "revisions-required-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-revisions.sh
  severity: error
  conflicts_with: []
  priority: 2
```

---

## Substantive Criteria (LLM-Type)

These criteria require human-like judgment and are checked by the cross-reviewer (and
adversarial-reviewer for novel issues). Failures block convergence just like formal
failures, but are detected by LLM dispatch rather than by a script.

---

## CR-META-mechanize criteria-evolution-suggestion

Substantive reviewers emit findings under this criterion when they observe a recurring
pattern that COULD be lifted into a formal (script-tier) check (guide §8 formal/substantive
evolution). The finding is informational — the reviser does not "fix" it on the artifact;
instead, a maintainer reviewing repeated CR-META-mechanize findings should consider adding
a new per-artifact `check-*.sh` rule.

```yaml
- id: CR-META-mechanize
  name: "criteria-evolution-suggestion"
  version: 1.0.0
  checker_type: llm
  severity: info
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-META-adversarial novel-adversarial-finding

Adversarial-reviewer emits findings under this criterion when its probe surfaces a real
issue that does not match any existing CR-SD## category. The reviser handles the artifact
fix; a maintainer reviewing repeated CR-META-adversarial findings should consider creating
a new substantive criterion.

```yaml
- id: CR-META-adversarial
  name: "novel-adversarial-finding"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-SD-DESIGN01 module-cohesion

Each module's `## Responsibilities` section describes a single, cohesive concern. A module
that bundles unrelated responsibilities (e.g. authentication AND billing) is a substantive
design defect: future changes will repeatedly couple unrelated diff scopes.

```yaml
- id: CR-SD-DESIGN01
  name: "module-cohesion"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-SD-DESIGN02 dependency-direction-rationale

When a module declares a non-obvious dependency direction (e.g. higher-level module
depending on lower-level module via callback), the design must justify the choice in
prose. Unjustified inverted dependencies invite future refactors.

```yaml
- id: CR-SD-DESIGN02
  name: "dependency-direction-rationale"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-SD-DESIGN03 boundary-enforcement-justified

Each row in a module's `## Boundary Enforcement` table describes a real failure mode that
the design actually defends against. Boilerplate or copy-paste boundary entries
("validation: at API layer") that don't engage with the module's actual contract are
substantive defects.

```yaml
- id: CR-SD-DESIGN03
  name: "boundary-enforcement-justified"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-SD-DESIGN04 data-model-normalization

Data models declared across modules MUST not silently duplicate the same logical entity
under different shapes. Normalization decisions (denormalization for read perf, projection
views, etc.) MUST be called out explicitly.

```yaml
- id: CR-SD-DESIGN04
  name: "data-model-normalization"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: full_scan
```

---

## CR-SD-DESIGN05 api-versioning-strategy

When the design declares public APIs, the bundle MUST describe a versioning strategy
(URL prefix, header negotiation, separate spec files for v2, etc.). Missing versioning
strategy implies frozen-forever APIs.

```yaml
- id: CR-SD-DESIGN05
  name: "api-versioning-strategy"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: full_scan
```

---

## CR-SD-DESIGN06 failure-modes

Every module specifies how it behaves when its dependencies fail (timeout, 5xx, malformed
response). A module without failure-mode documentation is unsafe to operate.

```yaml
- id: CR-SD-DESIGN06
  name: "failure-modes"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-SD-DESIGN07 observability-coverage

Each module documents the metrics, structured logs, and trace spans it emits. Modules
with no observability story cannot be operated in production.

```yaml
- id: CR-SD-DESIGN07
  name: "observability-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-SD-DESIGN08 security-considerations

Modules touching authentication, authorization, PII, or external networks MUST document
the security considerations they apply (input validation, output sanitization, least-
privilege, audit logging). Silent omission of security boundaries is a critical defect.

```yaml
- id: CR-SD-DESIGN08
  name: "security-considerations"
  version: 1.0.0
  checker_type: llm
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: full_scan
```

---

## CR-SD-DESIGN09 ui-promotion-action-set

Every frontend module (Type = frontend) MUST declare a `Promotion action` value of
`Promote`, `Extend`, or `Rewrite` in its UI Architecture section, MUST record the
corresponding `Draft path` (or `—` for `Rewrite` / net-new views with no PRD draft),
and MUST be consistent with the README Production Promotion Plan and View / Screen Index
rows for the views it owns. A frontend module without a Promotion action makes
autoforge guess whether to harden existing draft code or rewrite from scratch — this
is the primary handoff signal between design and execution.

```yaml
- id: CR-SD-DESIGN09
  name: "ui-promotion-action-set"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-SD-DESIGN10 ui-hardening-coverage

Every frontend module with `Promotion action = Promote` or `Extend` MUST include a
`### Promotion Requirements` subsection covering all five hardening categories:
**i18n integration**, **Accessibility**, **Performance**, **Tests**, and
**Coding-standard alignment**. Each row MUST describe both the current draft state
and the hardening required; rows declared `N/A` MUST include a one-line rationale.
Missing categories let production-quality concerns silently fall through the
PRD-draft → autoforge handoff (the PRD draft was experience-validation only and
explicitly skipped these concerns). Rewrite modules MAY omit this subsection
because autoforge implements them from scratch under standard production
conventions.

```yaml
- id: CR-SD-DESIGN10
  name: "ui-hardening-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-SD-DESIGN11 cross-journey-coverage

The README's `## Cross-Journey Patterns Coverage` table MUST contain one row for every
Cross-Journey Pattern listed in the source PRD's `README.md` "Cross-Journey Patterns"
section. Each row MUST identify (a) the source PRD features, (b) the design module(s)
that realize the pattern, and (c) the realization mechanism (shared module, common
middleware, infrastructure module, or an explicit "no shared module — accepted
duplication because <reason>" rationale). Patterns missing from the design lose the
PRD's primary cross-cutting traceability signal — recurring pain points, repeated
touchpoints, and persona handoff requirements that the PRD identified as cross-cutting
become invisible to autoforge planning.

```yaml
- id: CR-SD-DESIGN11
  name: "cross-journey-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```
