```yaml
mode: from-scratch
delivery_id: 1
round: 1

plan:
  delete: []
  keep: []
  modify: []

  add:
    # ─────────────────────────────────────────────────────────────────
    # 1. Skill entry — overrides the skeleton SKILL.md so trigger phrases,
    #    pipeline-position note, mode table (generate / --review / --revise /
    #    --diagnose), and the domain-specific structural-lint reference are
    #    correct for system-design.
    # ─────────────────────────────────────────────────────────────────
    - path: "SKILL.md"
      template: "common/templates/skill-md-template.md"
      description: "Orchestrator entry: cofounder plugin frontmatter, trigger phrases, mode-routing table (generate / --review / --revise / --diagnose), pipeline note (consumes prd-analysis output, feeds autoforge), and pointers to system-design-specific subagent prompts and structural-lint scripts."

    # ─────────────────────────────────────────────────────────────────
    # 2. Common — domain glossary + review-criteria (skeleton placeholders
    #    are generic; both must be replaced with system-design-specific
    #    content). Snippets/config/shared-scripts-manifest stay at skeleton
    #    default (orchestrator-protocol content is generic and reusable).
    # ─────────────────────────────────────────────────────────────────
    - path: "common/domain-glossary.md"
      template: null
      description: "System-design domain terms: module, API surface, Boundary Enforcement, Feature-Module mapping matrix, Implementation Conventions table, Dependency Layering, Status lifecycle (Draft/Finalized/Implementing/Implemented), Impl tri-state (NotStarted/InProgress/Done), structural-lint vs design-review, self-contained file."

    - path: "common/review-criteria.md"
      template: "common/templates/review-criteria-template.md"
      description: "CR-NNN catalog covering every dimension from legacy design-review-checklist.md (LLM type) and every structural-lint check L1..L5 + X1..X8 (script type, with check_script field referencing scripts/check-*.sh). Each CR has id, severity, type, description, and (when type=script) check_script path."

    # ─────────────────────────────────────────────────────────────────
    # 3. Templates — system-design-specific writer artifact templates.
    #    These are what the writer fan-out reads (one writer per module
    #    reads only module-template.md, etc.). Mined verbatim-where-applicable
    #    from legacy design-template.md, module-template.md, api-template.md.
    # ─────────────────────────────────────────────────────────────────
    - path: "common/templates/design-readme-template.md"
      template: null
      description: "README template: design overview, module index, Feature-Module mapping matrix (✦ / △ symbols), Module Interaction Protocols, Implementation Conventions table, Dependency Layering, Analytics Coverage. Mined from legacy design-template.md."

    - path: "common/templates/module-template.md"
      template: null
      description: "Self-contained per-module template: Status, Source Features, Responsibilities, Data Models (inline), Interfaces, API Surface (seven-col table), Boundary Enforcement (four-col), Module Deps, Test Strategy, Open Questions. Mined from legacy module-template.md."

    - path: "common/templates/api-template.md"
      template: null
      description: "Self-contained per-API template with the seven required per-endpoint subsections (Request, Response, Status codes, Error model, Auth, Rate limits, Examples). Mined from legacy api-template.md; basis for L1 and L2 lint."

    - path: "common/templates/revision-entry-template.md"
      template: null
      description: "REVISIONS.md append-entry template (date, source REVIEW/LINT id, modules touched, summary). Used by --revise mode summarizer."

    # ─────────────────────────────────────────────────────────────────
    # 4. Generate-mode subagent prompts — must be customised for system-design.
    #    Skeleton variants are generic. Domain-consultant prompt is replaced
    #    so it asks system-design-relevant questions when --no-consultant is
    #    not set (PRD path? draft path? interactive? has APIs?).
    # ─────────────────────────────────────────────────────────────────
    - path: "generate/domain-consultant-subagent.md"
      template: null
      description: "System-design domain consultant: clarifies input mode (PRD-based / draft-based / interactive), --output dir override, whether project has APIs (controls api/ directory generation), evolved-PRD handling. Writes flat keys SKILL_NAME, SKILL_VERSION, SKILL_DESCRIPTION, ARTIFACT_ROOT plus R-001..R-006 normalized requirements."

    - path: "generate/planner-subagent.md"
      template: null
      description: "System-design planner: reads PRD/draft, derives module decomposition + Feature-Module matrix + dependency layering + API/no-API decision, emits plan.add list with one entry per module file (modules/M-NNN-{slug}.md), one per API file (api/API-NNN-{slug}.md when applicable), and README.md. Writes round-N/plan.md."

    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "System-design writer (parallel fan-out, one per artifact leaf): reads only its assigned slice (one module's PRD features + module template, OR one API's surface + api template, OR README + design-readme template). Produces self-contained artifact + self-review file under .review/round-N/self-reviews/."

    # ─────────────────────────────────────────────────────────────────
    # 5. Review-mode subagent prompts — customised for system-design's
    #    two-phase quality gate (structural-lint scripts run BEFORE LLM
    #    cross/adversarial review).
    # ─────────────────────────────────────────────────────────────────
    - path: "review/cross-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "System-design cross-reviewer: applies design-review-checklist dimensions (CR type=LLM only — script-type CRs are filtered out because run-checkers.sh already covered them). Produces REVIEW-NNN.md issue files under .review/round-N/issues/."

    - path: "review/adversarial-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "System-design adversarial reviewer: attacks the design — NFR violations (latency budgets, scale limits), race conditions, missing failure modes, security holes (authz boundaries, secret-handling), missing observability, untested error paths. Produces REVIEW-NNN-ADV.md issue files."

    # ─────────────────────────────────────────────────────────────────
    # 6. Revise-mode subagent prompts — customised so per-issue reviser
    #    consumes both REVIEW-*.md (semantic) and LINT-*.md (mechanical).
    # ─────────────────────────────────────────────────────────────────
    - path: "revise/per-issue-reviser-subagent.md"
      template: null
      description: "System-design per-issue reviser: reads ONE open issue (REVIEW-* or LINT-*), opens only the affected module/api/README leaf, applies the minimal fix in-place, re-runs the relevant check_script (when issue is script-type), appends a REVISIONS.md entry. Re-runs run-checkers.sh after batch."

    # ─────────────────────────────────────────────────────────────────
    # 7. Mode index/routing files — overrides over skeleton because the
    #    system-design pipeline wires in the structural-lint catalog and
    #    has the unique two-phase quality gate.
    # ─────────────────────────────────────────────────────────────────
    - path: "generate/from-scratch.md"
      template: null
      description: "Generate-mode FromScratch entry: 11-step pipeline that calls scripts/run-checkers.sh (which now includes the 13 system-design lint scripts) BEFORE dispatching cross/adversarial reviewers. Adapted from legacy generate-mode.md Step 9 (lint pre-pass) + Step 10 (LLM review)."

    - path: "generate/new-version.md"
      template: null
      description: "Generate-mode NewVersion entry: forced full cross-review on first new-version round; planner emits delta plan against existing modules/api; revise/lint loop unchanged from FromScratch. Adapted from legacy revise-mode.md."

    - path: "review/index.md"
      template: null
      description: "--review mode entry: read-only over an existing design dir. Step 1 runs scripts/run-checkers.sh and emits LINT-NNN.md issue files; Step 2 dispatches cross-reviewer + adversarial-reviewer in parallel and emits REVIEW-NNN.md issue files. Mechanical findings never reach LLM reviewers."

    - path: "revise/index.md"
      template: null
      description: "--revise mode entry: consume newest unapplied REVIEW-*.md + LINT-*.md, dispatch per-issue revisers, re-run run-checkers.sh (gate), summarizer appends REVISIONS.md entry, applied files renamed to *.applied.md via git-tracked mv."

    # ─────────────────────────────────────────────────────────────────
    # 8. Domain-specific structural-lint scripts — one shell script per
    #    legacy check (L1..L5 per-file + X1..X8 cross-file). Aggregated by
    #    the existing scripts/run-checkers.sh skeleton (which auto-discovers
    #    check-*.sh under scripts/). Each is its own writer dispatch in
    #    delivery 1; bash-only, no third-party deps. Naming follows legacy
    #    structural-lint.md headings.
    # ─────────────────────────────────────────────────────────────────
    - path: "scripts/check-api-per-endpoint-blocks.sh"
      template: null
      description: "L1 lint: each api/API-*.md endpoint MUST have all seven required subsections (Request, Response, Status codes, Error model, Auth, Rate limits, Examples). Bash-only; emits .review/round-N/issues/LINT-NNN.md per violation."

    - path: "scripts/check-placeholder-json.sh"
      template: null
      description: "L2 lint: forbid placeholder JSON tokens (TODO, ..., <...>, FIXME) inside ```json blocks across all api/ and modules/ files. Bash-only."

    - path: "scripts/check-boundary-enforcement-cols.sh"
      template: null
      description: "L3 lint: every Boundary Enforcement table in modules/*.md MUST have all four columns filled (no empty / TBD cells). Bash-only."

    - path: "scripts/check-api-surface-cols.sh"
      template: null
      description: "L4 lint: every module's API Surface table MUST fill all seven columns per row. Bash-only."

    - path: "scripts/check-module-interface-types.sh"
      template: null
      description: "L5 lint: type names referenced in any module's Interfaces section MUST resolve to a definition either inline in the same module file or in an explicitly-imported sibling. Bash-only."

    - path: "scripts/check-module-deps-vs-protocols.sh"
      template: null
      description: "X1 lint: every Module Deps edge declared in modules/*.md MUST appear as a row in README.md's Module Interaction Protocols table, and vice versa. Bash-only."

    - path: "scripts/check-endpoint-literal-vs-api.sh"
      template: null
      description: "X2 lint: every endpoint literal (METHOD /path) referenced in any module's API Surface MUST exist in api/*.md, and every api/*.md endpoint MUST be claimed by at least one module's API Surface. Bash-only."

    - path: "scripts/check-architecture-coverage.sh"
      template: null
      description: "X3 lint: every file under PRD architecture/ MUST appear as a row in README.md's Implementation Conventions table OR be marked `N/A — {reason}`. Bash-only; relative-path-resolves PRD dir from artifact root."

    - path: "scripts/check-analytics-coverage.sh"
      template: null
      description: "X4 lint: every PRD Analytics event MUST appear in README.md's Analytics Coverage section, owned by at least one module. Bash-only."

    - path: "scripts/check-feature-module-traceability.sh"
      template: null
      description: "X5 lint: every PRD F-NNN feature MUST be referenced (✦ or △) in at least one cell of the Feature-Module matrix, and every module column in the matrix MUST list its source features. Bash-only."

    - path: "scripts/check-dependency-layering.sh"
      template: null
      description: "X6 lint: forward-only dependency layering — no reverse-layer imports in Module Deps. Reverse imports are BLOCKERS (severity=blocker), not warnings. Bash-only."

    - path: "scripts/check-single-source-of-truth.sh"
      template: null
      description: "X7 lint: invariants like data-model definitions, endpoint signatures, and Boundary Enforcement rules MUST have exactly one canonical home; cross-file copies MUST be byte-equal or marked as a quoted excerpt. Bash-only."

    - path: "scripts/check-readme-references.sh"
      template: null
      description: "X8 lint: every relative path referenced from README.md MUST resolve to an existing file (modules/M-*.md, api/API-*.md, ../../prd/.../features/F-*.md). Bash-only."

rationale: |
  FromScratch invariant honoured: delete/keep/modify are empty. The add list has 27 entries — the
  9 standard writer-authored files (SKILL.md + glossary + criteria + the 6 customised subagent
  prompts) plus 14 system-design-specific files the skeleton does NOT scaffold: 4 artifact
  templates (design-readme/module/api/revision-entry), 4 mode-routing overrides
  (from-scratch.md, new-version.md, review/index.md, revise/index.md — needed because the
  generic skeleton flow has no two-phase quality gate or PRD-architecture coverage logic), and
  13 domain-specific lint scripts covering legacy structural-lint.md L1..L5 + X1..X8 verbatim
  (one writer dispatch per script enables parallel authoring and lets run-checkers.sh
  auto-discover them via scripts/check-*.sh). All other skeleton files (config.yml, snippets.md,
  shared-scripts-manifest.yml, the 28 standard skill-forge scripts, shared/summarizer-subagent.md,
  shared/judge-subagent.md, generate/in-generate-review.md) are kept at skeleton-default — their
  generic content (orchestrator-protocol snippets, summarizer/judge tier-light protocols) is
  domain-agnostic and needs no system-design-specific override.
```
