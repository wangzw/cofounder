# Round-1 Plan — prd-analysis (FromScratch)

Target: `skills/prd-analysis/` (document variant)
Trace: R1-P-001
Clarification source: `.review/round-0/clarification/2026-04-24T10:52:00Z.yml`
Skeleton DOMAIN_FILL sentinels found in 8 files (via `grep -rln 'DOMAIN_FILL' skills/prd-analysis/`).

```yaml
mode: from-scratch
delivery_id: 1
round: 1
plan:
  delete: []
  modify: []
  add:
    - path: "common/review-criteria.md"
      template: "common/templates/review-criteria-template.md"
      description: "Populate the 8 structural (CR-S01..S08) and 5 semantic (CR-L01..L05) review criteria for PRD artifacts, as YAML blocks with id/name/version/checker_type/severity/conflicts_with/priority/incremental_skip fields. Key domain inputs: R-005 (PRD-S01..S08 structural criteria — readme-frontmatter-complete, features-have-ids, journeys-have-ids, feature-files-self-contained, architecture-index-matches-topic-files, wikilink-targets-exist, revisions-log-consistency, leaf-size-within-limit), R-006 (PRD-L01..L05 semantic criteria — feature-to-journey-mapping, mvp-discipline, feature-boundaries-clear, non-functional-requirements-present, cross-journey-patterns-identified)."
      key_sources: [R-001, R-002, R-003, R-005, R-006]

    - path: "common/domain-glossary.md"
      template: null
      description: "Populate domain-glossary table with PRD-specific terms the domain-consultant uses to disambiguate user intent. Must include: feature (F-NNN-<slug>.md self-contained spec), journey (J-NNN-<slug>.md touchpoint sequence), touchpoint, architecture topic file, wikilink, tombstone, evolve baseline, self-contained file, product slug, revision log. Include aliases for common user phrasings (e.g., 'user story' → journey, 'epic' → feature cluster, 'spec' → feature file)."
      key_sources: [R-001, R-003, R-007, domain_terms_aligned]

    - path: "common/templates/artifact-template.md"
      template: "common/templates/artifact-template.md"
      description: "Define canonical structure for PRD artifact files: README.md (product index with title/product-name/date/stakeholders frontmatter + feature/journey tables + cross-journey patterns), journeys/J-NNN-<slug>.md (persona + touchpoint sequence + pain points), features/F-NNN-<slug>.md (self-contained spec with inline data model, conventions, journey backreferences, acceptance criteria — MUST be independently readable per R-003), architecture.md (~50-80 line index), architecture/<topic>.md (tech-stack, data-model, coding-conventions, nfr), REVISIONS.md (optional post-revise), prototypes/ (optional). Include minimal valid example of each leaf type. Enforce leaf-size ≤ 300 lines (CR-S08)."
      key_sources: [R-003, R-005, R-006]

    - path: "generate/domain-consultant-subagent.md"
      template: null
      description: "Populate the consultant's domain clarification role for PRD generation. Must enumerate the R-001..R-007 fields the consultant confirms with the user: R-001 product name/slug, R-002 artifact type (always 'document'), R-003 pyramid structure (README + journeys/ + features/ + architecture/ + optional REVISIONS/prototypes), R-004 mode understanding (interactive / document-input / --review / --revise / --evolve), R-005 structural criteria awareness, R-006 semantic criteria awareness, R-007 evolve-mode baseline immutability. Describe dialogue behavior for sparse idea input vs. @notes.md document input, gap-filling question pattern, and exit condition (all R-001..R-007 confirmed). Specify clarification.yml output shape mirroring round-0 example."
      key_sources: [R-001, R-002, R-003, R-004, R-007]

    - path: "generate/writer-subagent.md"
      template: "common/templates/writer-subagent-template.md"
      description: "Populate writer role definition for PRD leaves. Describe 'good output' for each artifact type — README index vs. journey leaf vs. feature leaf vs. architecture topic. Enumerate applicable CRs from in-generate-review.md mapping: feature files must satisfy CR-S04 (self-contained, no cross-refs), CR-L01 (journey mapping), CR-L03 (no overlap); journey files must satisfy CR-S03 (J-NNN IDs); architecture topics must satisfy CR-S05 (index consistency) and CR-L04 (NFRs). Include one positive example (well-formed F-NNN feature with inlined data model) and one negative example (feature that cross-refs another feature file — violates CR-S04). Embed the 4 blocker_scope values. Specify input contract (reads clarification.yml + plan.md assigned leaf path) and 2-write output contract (artifact leaf + self-review)."
      key_sources: [R-003, R-005, R-006]

    - path: "generate/in-generate-review.md"
      template: null
      description: "Populate the CR applicability table mapping PRD artifact file types to CR subsets. Rows: README.md (CR-S01 frontmatter, CR-S05 index-consistency, CR-L05 cross-journey-patterns), journeys/J-*.md (CR-S03 IDs, CR-S08 leaf-size, CR-L01 feature-mapping back-ref), features/F-*.md (CR-S02 IDs, CR-S04 self-contained, CR-S06 wikilink-targets, CR-S08 leaf-size, CR-L01 journey-mapping, CR-L02 MVP-discipline, CR-L03 feature-boundaries), architecture.md (CR-S05), architecture/<topic>.md (CR-L04 NFR, CR-S06), REVISIONS.md (CR-S07, only if present). Preserve the PASS/FAIL line format and blocker-scope taxonomy from the skeleton."
      key_sources: [R-005, R-006]

    - path: "review/cross-reviewer-subagent.md"
      template: "common/templates/cross-reviewer-template.md"
      description: "Populate cross-reviewer role for PRD semantic review. List LLM-type criteria CR-L01..L05 from R-006 with concrete check procedures: CR-L01 walk every feature and confirm ≥1 journey touchpoint reference; CR-L02 scan for speculative/scope-creep features not tied to stated problem; CR-L03 diff feature boundaries for overlap; CR-L04 confirm architecture topics cover perf/security/a11y; CR-L05 identify recurring themes across journeys and confirm README cross-journey-patterns section names them. Specify skip-set discipline (reuse `.review/round-<N>/skip-set.yml`), forced-full override for new-version first round, and self-review FAIL-row escalation protocol (convert global-conflict FAILs into cross-reviewer issues)."
      key_sources: [R-003, R-006]

    - path: "review/adversarial-reviewer-subagent.md"
      template: null
      description: "Populate adversarial reviewer with PRD-specific attack angles: (1) hunt for features that silently cross-reference data models defined in other feature files (violates CR-S04 self-contained principle — common failure mode when writer takes shortcuts); (2) hunt for hidden MVP scope-creep (speculative 'v2' sections embedded inside MVP features — CR-L02); (3) hunt for orphaned journeys (journey with no feature mapping) or orphaned features (feature with no journey touchpoint — CR-L01); (4) hunt for architecture-index drift (topic file present but not listed in architecture.md, or listed but file missing — CR-S05); (5) for --evolve output, hunt for mutation of predecessor baseline (violates R-007 immutability). Specify trigger: fires only when state.yml adversarial_review_triggered flag set (critical/error issues from cross-reviewer). Describe no-op ACK behavior when flag absent."
      key_sources: [R-005, R-006, R-007]

    - path: "revise/per-issue-reviser-subagent.md"
      template: null
      description: "Populate per-issue reviser with PRD-specific revision discipline. Domain rules: (1) when fixing a feature file, NEVER add a cross-reference to another feature file to resolve a data-model issue — instead inline the data-model fragment (preserves CR-S04); (2) when fixing a journey-feature mapping issue, update BOTH the journey's touchpoint list AND the feature's journey back-reference (both sides must stay consistent); (3) when fixing an architecture-index drift, update architecture.md index AND ensure the topic file exists/has content — never delete the topic file to satisfy the index unless issue explicitly requests removal; (4) for --evolve deltas, NEVER modify baseline files — only write delta + tombstones per R-007. Regression-protection: before write, verify no previously resolved issue re-opens. Skeleton-protection: do not touch `scripts/` or `common/snippets.md`."
      key_sources: [R-003, R-005, R-007]

  keep: []

rationale: |
  FromScratch plan: skeleton scaffolded 8 files with DOMAIN_FILL sentinels that writers must
  populate with PRD-specific domain content, drawn from R-001..R-007 in the round-0
  clarification. All 8 files are listed under `add` per the FromScratch convention (delete/keep
  must be empty, modify is empty because no pre-existing non-skeleton files exist). No files
  outside the DOMAIN_FILL set are added — the planner-subagent.md, shared/summarizer-subagent.md,
  and shared/judge-subagent.md skeletons are already domain-agnostic and correct post-scaffold
  (no DOMAIN_FILL markers). The 8 writer targets split across three concerns: (a) criteria/glossary
  definition (review-criteria, domain-glossary, artifact-template, in-generate-review) driven by
  R-005/R-006; (b) per-role sub-agent prompts (domain-consultant, writer, cross-reviewer,
  adversarial-reviewer, per-issue-reviser) that encode R-003 pyramid shape and R-007 evolve-mode
  immutability into role-specific discipline. Writers can fan out in parallel — no leaf depends on
  another writer's output within round 1.
```
