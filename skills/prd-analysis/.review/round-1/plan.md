# Round 1 Plan — prd-analysis (FromScratch, delivery 1)

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
      description: "Plugin entry point for /cofounder:prd-analysis. Frontmatter (name=prd-analysis, version=0.1.0, description per R-001) + mode-routing table dispatching to FromScratch / NewVersion / --review / --revise / --diagnose paths inherited from skeleton/document, with PRD-specific artifact root docs/raw/prd/YYYY-MM-DD-{product-slug}/."
    - path: "common/review-criteria.md"
      template: "common/templates/review-criteria-template.md"
      description: "Authoritative checker registry: 5 script-type CRs (CR-S-001 artifact-pyramid-shape, CR-S-002 leaf-size-cap ≤300 lines, CR-S-003 id-format-and-uniqueness for F-/J-/M-NNN, CR-S-004 cross-link-integrity, CR-S-005 self-contained-discipline section-header presence) and 6 LLM-type CRs (CR-L-001 scope-discipline, CR-L-002 journey-feature-coverage, CR-L-003 cross-journey-pattern-resolution, CR-L-004 self-contained-readability, CR-L-005 mvp-discipline, CR-L-006 ambiguity-elimination) per R-005/R-006."
    - path: "common/domain-glossary.md"
      template: null
      description: "PRD-domain glossary: artifact (the dated PRD pyramid directory), leaf (single ≤300-line markdown file: feature/journey/architecture topic), feature (F-NNN), journey (J-NNN), module (M-NNN, referenced from system-design boundary), touchpoint, cross-journey pattern, self-contained leaf, design token, tombstone — aligned with R-002/R-003/R-004 and project CLAUDE.md Glossary so all subagents share vocabulary."
    - path: "common/templates/artifact-template.md"
      template: "common/templates/artifact-template.md"
      description: "Skeleton of one PRD leaf (feature template): required section headers Data Models / Conventions / Journey Context / State Machine / Acceptance Criteria so writers produce CR-S-005-passing leaves and CR-L-004-readable content; ≤300-line cap reminder inline."
    - path: "generate/domain-consultant-subagent.md"
      template: null
      description: "Round-0 clarifier subagent prompt: ingests sparse one-line product idea (plus optional @-expanded directory references like notes.md), asks targeted PRD-shaping questions (target users, primary journeys, must-have vs. nice-to-have, success metrics, constraints), and writes .review/round-0/clarification/<ISO>.yml with R-001..R-007 normalized requirements. Honors hitl_mode=delegated-proceed."
    - path: "generate/planner-subagent.md"
      template: null
      description: "Decomposes the clarified PRD scope into a leaf-writing fan-out plan: enumerates one writer task per journey (J-NNN), per feature (F-NNN), per architecture topic, plus README.md + architecture.md + REVISIONS.md (if --revise). Emits .review/round-N/plan.md with add/modify/delete/keep lists and per-leaf template assignments; HITL approval gate before dispatch."
    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "Authors one PRD leaf (one feature OR one journey OR one architecture topic OR README/architecture index) per dispatch, COPYING data models / conventions / journey context inline (self-contained discipline). Performs FULL_PASS self-review against the 5 script-CR + 6 LLM-CR checklist; writes leaf + .review/round-N/self-reviews/<trace_id>.md."
    - path: "review/cross-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "Constructive LLM reviewer: evaluates the assembled PRD pyramid against CR-L-001..CR-L-006 (scope-discipline, journey-feature coverage, cross-journey-pattern resolution, self-contained-readability, mvp-discipline, ambiguity-elimination); emits one .review/round-N/issues/<id>.md per finding with severity, evidence, and suggested-fix."
    - path: "review/adversarial-reviewer-subagent.md"
      template: null
      description: "Adversarial LLM reviewer: stress-tests the same CR-L set from a hostile-coder-agent perspective — tries to find a feature leaf that cannot be implemented without opening another file (CR-L-004 break), an MVP feature secretly nice-to-have (CR-L-005), or a touchpoint with no addressing feature (CR-L-002). Same issue-file output shape as cross-reviewer; complementary, not redundant."
    - path: "revise/per-issue-reviser-subagent.md"
      template: null
      description: "Per-issue reviser subagent: consumes one .review/round-N/issues/<id>.md, mutates the affected PRD leaf (or README/architecture.md) to resolve the cited CR violation while preserving unaffected sections, and rewrites the leaf to its final path. One issue → one dispatch → one Write."
  keep: []
rationale: |
  Standard FromScratch 10-leaf set per planner-subagent.md §Output Contract for variant=document.
  No variant-specific extensions needed (R-002 confirmed document-only; no code-execution / schema /
  hybrid behaviors per variant_replay). Templates assigned per skeleton/document: SKILL.md, review-criteria,
  writer, cross-reviewer, and artifact-template inherit skill-forge templates; domain-glossary, planner,
  domain-consultant, adversarial-reviewer, and per-issue-reviser are template:null because they encode
  PRD-domain specifics (F-/J-/M-NNN IDs, pyramid shape, journey-feature coverage, MVP discipline) that
  no shared template captures cleanly. Shared summarizer/judge are intentionally omitted from the add list
  — skeleton baselines suffice for delivery-1 (no PRD-specific aggregation overrides identified in R-001..R-007).
```
