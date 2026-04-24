<!-- planner-subagent output; trace_id=R1-P-001; mode=from-scratch; delivery_id=1; round=1 -->

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
      description: "Entry point for prd-analysis: frontmatter (name, description, triggers), mode routing (interactive FromScratch | document-based FromScratch | --review | --revise | --evolve), input modes, output structure (docs/raw/prd/YYYY-MM-DD-{product-slug}/ pyramid), and pointers into common/, generate/, review/, revise/, shared/."
    - path: "common/review-criteria.md"
      template: "common/templates/review-criteria-template.md"
      description: "Canonical review criteria for PRD artifacts — script-type CRs (pyramid shape, leaf size <300 lines, F-/J-/M-NNN ID format, cross-reference integrity, required template sections, kebab-case slug naming, artifact-nudity) and LLM-type CRs (self-contained principle, PRD-vs-system-design scope discipline, journey-to-feature coverage, touchpoint completeness, design-token semantic naming, testable acceptance criteria, priority rationale, persona consistency, NFR coverage)."
    - path: "common/domain-glossary.md"
      template: null
      description: "PRD-domain vocabulary: PRD, Journey, Touchpoint, Interaction Mode, Feature, Module (reference), Persona, Cross-Journey Pattern, Design Token, Acceptance Criterion, Priority (P0/P1/P2), NFR, Tombstone (evolve-mode), Self-Contained Leaf. Cites cofounder root CLAUDE.md glossary and scopes terms to PRD (non-implementation) usage."
    - path: "common/templates/artifact-template.md"
      template: "common/templates/artifact-template.md"
      description: "Domain-specific leaf templates for PRD artifacts — authors the canonical section layout for each PRD leaf type (journey leaf, feature leaf, architecture topic leaf, plus README.md index shape). Replaces the skeleton placeholder with PRD-specific required fields (touchpoints: stage/screen/action/interaction-mode/system-response/pain-point; features: acceptance criteria, priority rationale, mapped journeys, deps) and the self-contained-inline-copy principle."
    - path: "generate/domain-consultant-subagent.md"
      template: null
      description: "PRD-specific domain consultant prompt: drives the interactive questioning phase when /prd-analysis runs with sparse input. Asks product-scope questions (problem, target persona, core journeys, priority, NFRs) and produces clarification.yml R-001..R-007 (product-slug, primary personas, journey list, feature seed, priority policy, NFR applicability, evolve-baseline). Triggers §3.8 probe → deferred questions when user is vague."
    - path: "generate/planner-subagent.md"
      template: null
      description: "PRD planner prompt: consumes clarification.yml and emits plan.md listing which journey-, feature-, and architecture-topic leaves to add/modify/keep per round. FromScratch = journeys + features + architecture topics derived from clarification; NewVersion/evolve = diff against versions/<N-1>.md producing delete/modify/add/keep. Enforces per-leaf self-contained principle when assigning writers."
    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "PRD writer prompt: authors individual PRD leaves (README.md, journeys/J-NNN.md, features/F-NNN.md, architecture.md index, architecture/*.md topics) from plan.md entries. Enforces self-contained copy-inline rule (no orphan cross-refs), <300-line leaf budget, template section conformance, ID format, design-token semantic naming, and PRD-vs-system-design scope discipline."
    - path: "review/cross-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "PRD cross-reviewer prompt: reviews one leaf at a time against neighbors within the same artifact (feature↔journey, feature↔cross-journey pattern, architecture topic↔feature NFR). Emits one issue file per finding under .review/round-<N>/issues/. Focuses on intra-artifact coherence: journey-to-feature coverage, cross-ref integrity, persona consistency, terminology alignment with domain-glossary.md."
    - path: "review/adversarial-reviewer-subagent.md"
      template: null
      description: "PRD adversarial reviewer prompt: red-teams the PRD for scope drift into implementation detail (system-design territory), vague acceptance criteria, untestable NFRs, missing edge-case touchpoints, under-specified personas, and priority rationale gaps. Writes one issue file per flaw found."
    - path: "revise/per-issue-reviser-subagent.md"
      template: null
      description: "PRD per-issue reviser prompt: consumes one issue file + the affected PRD leaf and rewrites only the minimal span needed to resolve the issue while preserving self-contained-inline-copy invariants, ID stability, and neighbor cross-refs. Produces updated leaf as the single write per dispatch."
  keep: []
rationale: |
  Standard 9-file FromScratch set for the document-variant skeleton, tailored to the PRD domain
  per clarification R-001..R-006. One novel file is flagged: `common/templates/artifact-template.md`
  is listed (template field points to the skeleton placeholder) because PRDs have multiple distinct
  leaf types (journey, feature, architecture topic, README index) rather than a single uniform
  artifact — the writer must author PRD-specific section layouts inline, not just reuse the generic
  placeholder. Shared summarizer/judge prompts are intentionally omitted from `add:` because the
  skeleton defaults in shared/ are sufficient for the document variant (no PRD-specific
  customization identified in the clarification).
```
