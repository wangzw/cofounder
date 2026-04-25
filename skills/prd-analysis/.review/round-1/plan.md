```yaml
mode: from-scratch
delivery_id: 1
round: 1
plan:
  delete: []
  modify: []
  add:
    - path: "SKILL.md"
      template: "skills/skill-forge/common/templates/skill-md-template.md"
      description: "Entry-point orchestrator for prd-analysis: frontmatter, Mode Routing (5 modes), Bootstrap Precheck, Core Contract, Orchestrator Dispatch Contract (Snippet C), --diagnose Mode, Model Tiers with per-dispatch override table, CLI Flags, and Configuration & Subagent Files index."

    - path: "common/review-criteria.md"
      template: "skills/skill-forge/common/templates/review-criteria-template.md"
      description: "PRD-domain review criteria: structural checks CR-S01..CR-S15 (inherited from skill-forge baseline, applied to generated PRD artifacts) plus semantic checks CR-L01..CR-L16 covering persona realism, journey causal flow, feature-journey traceability, MVP boundary discipline, success-criteria measurability, business-priority justification, terminology consistency, glossary coverage, scope discipline, self-containment audit, cross-journey pattern derivation, and design-token semantics."

    - path: "common/domain-glossary.md"
      template: null
      description: "PRD-domain glossary defining canonical terms used by the domain-consultant and writers: touchpoint, persona, user journey, feature, MVP boundary, design token, interaction mode, cross-journey pattern, feature-module mapping, tombstone, self-contained file — sourced from cofounder/CLAUDE.md Glossary and the backup SKILL.md domain vocabulary."

    - path: "generate/domain-consultant-subagent.md"
      template: null
      description: "Domain-consultant sub-agent prompt for prd-analysis: elicits R-001..R-007 (skill slug, artifact type, output layout, CLI surface, script criteria, LLM criteria, baseline) from sparse product descriptions or @-referenced brainstorm files, applying PRD-domain clarification heuristics before writing clarification.yml."

    - path: "generate/planner-subagent.md"
      template: null
      description: "Planner sub-agent prompt for prd-analysis: derives the per-round file plan from clarification.yml, emitting add/modify/delete/keep lists for the PRD artifact pyramid (README, journeys, features, architecture topic files) using PRD-domain naming conventions (F-NNN, J-NNN)."

    - path: "generate/writer-subagent.md"
      template: "skills/skill-forge/common/templates/writer-subagent-template.md"
      description: "Writer sub-agent prompt for prd-analysis: authors PRD artifact leaves (journey specs, feature specs, architecture topic files, README index) following PRD templates, self-contained file principle, and PRD-specific quality bar (DO/DON'T examples); includes mandatory self-review pass against common/review-criteria.md before ACK."

    - path: "review/cross-reviewer-subagent.md"
      template: "skills/skill-forge/common/templates/cross-reviewer-template.md"
      description: "Cross-reviewer sub-agent prompt for prd-analysis: runs script-type checks (CR-S01..CR-S15) on generated PRD files and files structural issue reports under .review/round-N/issues/, focusing on pyramid index consistency, ID format validity, frontmatter completeness, and dispatch-log snippet presence."

    - path: "review/adversarial-reviewer-subagent.md"
      template: "skills/skill-forge/common/templates/cross-reviewer-template.md"
      description: "Adversarial-reviewer sub-agent prompt for prd-analysis: applies LLM-type checks (CR-L01..CR-L16) to stress-test the PRD for persona realism, journey causal completeness, feature-journey traceability, MVP boundary discipline, measurable success criteria, and self-contained leaf compliance; files semantic issue reports."

    - path: "revise/per-issue-reviser-subagent.md"
      template: null
      description: "Per-issue reviser sub-agent prompt for prd-analysis: receives a single open issue file and the linked artifact leaf, applies the minimal targeted fix to the leaf following PRD conventions (preserving ID stability, self-containment, and inline context copies), then writes the updated leaf and ACKs."

    - path: "shared/summarizer-subagent.md"
      template: null
      description: "Summarizer sub-agent prompt for prd-analysis: aggregates a completed round's self-reviews, issues, and verdict into .review/versions/N.md (round summary) plus a CHANGELOG entry in the target PRD's CHANGELOG.md; produces the pyramid index README update if the round introduced new features or journeys."

    - path: "shared/judge-subagent.md"
      template: null
      description: "Judge sub-agent prompt for prd-analysis: reads open-issue count, blocker count, and round history to emit a verdict.yml (converged | needs-revision | oscillating | diverging) with a PRD-domain convergence rationale; never reads artifact leaves directly."

    - path: "common/templates/feature-template.md"
      template: "skills/skill-forge/common/skeleton/document/common/templates/artifact-template.md"
      description: "Self-contained PRD feature spec template (F-NNN-{slug}.md): sections for Overview, User Story, Acceptance Criteria, State Machine, Interaction Mode, Inline Data Model, Inline Journey Context, Inline Conventions, Dependencies, and MVP Boundary note — sourced from backup feature-template.md."

    - path: "common/templates/journey-template.md"
      template: null
      description: "Self-contained PRD journey spec template (J-NNN-{slug}.md): sections for Persona, Goal, Pre-conditions, Touchpoint table (stage, screen, action, interaction mode, system response, pain point), Mapped Features, and Post-conditions — sourced from backup journey-template.md."

    - path: "common/templates/architecture-template.md"
      template: null
      description: "PRD architecture index template (architecture.md) and topic-file shape reference: index lists all topic files with one-line summaries and Mermaid dependency diagram; each topic file (tech-stack, data-model, design-tokens, etc.) is standalone and self-contained — sourced from backup architecture-template.md."

    - path: "common/templates/prd-readme-template.md"
      template: "skills/skill-forge/common/skeleton/document/common/templates/review-readme-template.md"
      description: "PRD pyramid README template: product overview, persona summary, journey index table (J-NNN links), feature index table (F-NNN, priority, MVP flag, journey refs), cross-journey patterns section, design-token reference, and roadmap — sourced from backup prd-template.md."

  keep: []
rationale: |
  FromScratch mode with no consultant (clarification.yml no_consultant=true; all R-001..R-003
  confirmed from backup, R-004..R-007 deferred to defaults). The document skeleton variant drives
  the top-level directory shape (SKILL.md, common/, generate/, review/, revise/, shared/). All
  8 sub-agent roles are listed because the backup review/ directory has a cross-reviewer but no
  adversarial-reviewer or shared/ roles — those must be authored fresh. Four PRD artifact
  templates (feature, journey, architecture, prd-readme) are added as domain-specific files
  because they contain PRD-specific section shapes not covered by the generic artifact-template.md
  in the document skeleton. summarizer-subagent.md and judge-subagent.md are included (not just
  optional) because the PRD summarizer must also update the target PRD's CHANGELOG.md pyramid
  entry, which requires PRD-domain awareness beyond the generic shared/ stubs.
```
