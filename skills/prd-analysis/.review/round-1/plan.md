```yaml
mode: from-scratch
delivery_id: 1
round: 1
plan:
  delete: []
  modify: []
  add:
    - path: "SKILL.md"
      template: "common/templates/skill-md-template.md"
      description: "Skill entrypoint with custom mode-routing for the multi-stage interactive PRD pipeline (questioning -> document -> review -> revise -> evolve). Overrides the skeleton-shipped SKILL.md because prd-analysis does not follow the generative-skill subagent pattern; it drives the user dialogue directly. Routes flags --document, --evolve, --review, --revise to the corresponding topic files; default flow runs interactive questioning."
    - path: "common/review-criteria.md"
      template: "common/templates/review-criteria-template.md"
      description: "PRD-specific review criteria (overrides skeleton scaffold). Encodes the ~50-dimension PRD review checklist as YAML criteria with severity, scope, and mechanical-vs-judgment classification, consumed by review-mode.md and review-checklist.md."
    - path: "questioning-phases.md"
      template: null
      description: "Interactive questioning protocol that drives the default mode. Defines the multi-phase dialogue (vision/users -> journeys -> features -> constraints -> design tokens) with per-phase question scripts, depth-budget rules, and exit conditions. Output of this phase is the structured input consumed by document-mode.md."
    - path: "document-mode.md"
      template: null
      description: "Document-mode workflow: parses an existing brainstorming doc / requirements draft (path supplied by user) into the structured PRD artifact set (README + journeys/ + features/ + architecture/) without running the questioning phases. Includes parser heuristics, gap-detection rules, and fallback to targeted questioning when required fields are missing."
    - path: "evolve-mode.md"
      template: null
      description: "Evolve-mode workflow: produces a new PRD iteration on top of a baseline PRD directory. Defines diff-aware feature/journey ID stability, tombstone semantics for deprecated items, evolve-readme generation, and cascade rules when a journey changes that affect downstream features."
    - path: "review-mode.md"
      template: null
      description: "Self-review workflow over a generated PRD bundle. Runs script-first checks (pyramid, ID consistency, cross-references) then dimension-by-dimension judgment review using review-checklist.md. Emits issue files under .review/round-N/issues/ for the revise phase to consume."
    - path: "revise-mode.md"
      template: null
      description: "Revise-mode workflow that consumes review issues and patches the PRD bundle. Defines per-issue dispatch, conflict resolution when multiple issues touch the same artifact leaf, and re-review trigger when a revision changes scope (cascade)."
    - path: "output-discipline.md"
      template: null
      description: "Output hygiene rules: artifact paths use docs/raw/prd/<YYYY-MM-DD>-<product-slug>/ convention, every leaf file is self-contained (inline-copy rule for data models / conventions / journey context), README is index-only with summaries (no full content duplication), and all IDs are zero-padded sequential and stable."
    - path: "parallel-dispatch.md"
      template: null
      description: "Parallel-dispatch protocol for fan-out generation of feature/journey leaves. Defines batch-size budget, trace-id schema (R<round>-W-<NNN>), per-leaf isolation contract, and reduce step that updates the README index after all writers ACK."
    - path: "scope-reference.md"
      template: null
      description: "Scope-and-non-scope reference: enumerates what prd-analysis owns (requirements, journeys, features, design tokens) versus what belongs to system-design (modules, interfaces, data schemas) and autoforge (implementation). Used by questioning-phases and document-mode to detect out-of-scope content and re-route the user."
    - path: "review-checklist.md"
      template: null
      description: "The ~50-dimension PRD review checklist (many dimensions multi-sub-check). Each dimension specifies: prompt, evidence required, severity if violated, scope (README vs leaf vs both). Consumed by review-mode.md; mirrors common/review-criteria.md but in human-readable narrative form for the reviewer agent."
    - path: "prd-template.md"
      template: "common/templates/artifact-template.md"
      description: "PRD README template — the index file at docs/raw/prd/<date>-<slug>/README.md. Sections: vision, target users, journey index, feature index, cross-journey patterns, design tokens, constraints, glossary. Index-only summaries; full content lives in journeys/ and features/ leaves."
    - path: "feature-template.md"
      template: "common/templates/artifact-template.md"
      description: "Feature leaf template (features/F-NNN-slug.md). Self-contained: inline-copies relevant journey context, data models, applicable conventions. Sections: id, title, motivation, user stories, acceptance criteria, state machine, design-token references, dependencies, open questions."
    - path: "journey-template.md"
      template: "common/templates/artifact-template.md"
      description: "Journey leaf template (journeys/J-NNN.md). Self-contained: persona, preconditions, stage-by-stage touchpoint table (stage, screen, action, interaction-mode, system response, pain point), success outcome, related features (back-references), applicable design tokens."
    - path: "architecture-template.md"
      template: "common/templates/artifact-template.md"
      description: "Architecture leaf template (architecture/*.md topic files: data-model, conventions, integrations, design-tokens). These are the source-of-truth blocks that feature/journey leaves inline-copy from per the self-contained-file principle."
    - path: "evolve-readme-template.md"
      template: "common/templates/artifact-template.md"
      description: "Evolve-iteration README template — replaces prd-template.md for evolve-mode output. Adds: baseline-PRD reference, change summary, deprecated-item tombstone index, ID-stability ledger, cascade-impact map. Consumed only when evolve-mode.md is active."
    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "Writer sub-agent prompt for PRD leaf authoring (overrides skeleton scaffold). Specialized for parallel fan-out across journey/feature/architecture leaves: enforces self-contained inline-copy, ID stability, design-token references, and the round-N self-review checklist before ACK."
    - path: "review/cross-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "Cross-reviewer sub-agent prompt for PRD bundles (overrides skeleton scaffold). Verifies cross-leaf consistency: feature<->journey back-references, design-token usage matches definitions, ID monotonicity, README index covers every leaf, glossary terms used consistently."
  keep: []
rationale: |
  prd-analysis is a multi-stage interactive PRD pipeline (questioning + document parsing + review + revise + evolve), not a generative-skill-pattern skill — it drives the user dialogue directly rather than fan-out via a domain-consultant/planner/writer triad. The plan therefore (1) overrides four skeleton-shipped files (SKILL.md, common/review-criteria.md, generate/writer-subagent.md, review/cross-reviewer-subagent.md) with PRD-flavored variants, and (2) adds 14 domain-specific topic and template files that have no counterpart in the document skeleton. All entries align with the prd-analysis.backup baseline inventory; no novel files are introduced beyond that baseline. delete and keep are empty per from-scratch constraint.
```
