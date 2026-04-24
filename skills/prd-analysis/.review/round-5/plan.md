# Delivery-2 Plan — prd-analysis (Round 5)

```yaml
mode: new-version
delivery_id: 2
previous_delivery: 1
round: 5
plan:
  delete: []
  modify:
    - path: "common/templates/artifact-template.md"
      template: null
      description: "Expand the architecture/nfr.md shape section to prescribe a fourth required dimension — Observability — covering metrics cardinality limits, SLO templates (P99 latency + error-budget burn rate), tracing-span naming conventions (service.operation.phase), and structured-log schemas (required fields per event type). Existing perf / security / a11y content unchanged."
    - path: "generate/writer-subagent.md"
      template: null
      description: "Update the `architecture/<topic>.md (Architecture Topic)` guidance in the writer so that when authoring `nfr.md` the writer MUST emit an Observability subsection alongside performance / security / a11y. No other sub-agent prompt sections change."
  add: []
  keep:
    - path: "SKILL.md"
      rationale: "Mode routing, triggers, and skill frontmatter are unaffected by a PRD-artifact content extension."
    - path: "common/review-criteria.md"
      rationale: "Narrow-change constraint: CR-PRD-L05 remains scoped to perf/security/a11y for delivery-2. Promoting Observability to an enforced CR would cascade into every writer self-review, cross-reviewer, adversarial-reviewer, and reviser — out of scope for a narrow delivery. Observability becomes prescriptive-but-advisory via template + writer prompt only; a future delivery can harden it into CR-PRD-L05 v2 or a new CR-PRD-L07."
    - path: "common/domain-glossary.md"
      rationale: "No new domain terms introduced — observability vocabulary (metric, SLO, span, log) is standard engineering language and does not require glossary augmentation for this narrow delivery."
    - path: "common/config.yml"
      rationale: "No config surface changes (no new modes, flags, or artifact roots)."
    - path: "common/shared-scripts-manifest.yml"
      rationale: "No new scripts added or removed."
    - path: "common/snippets.md"
      rationale: "IPC snippets unchanged."
    - path: "generate/domain-consultant-subagent.md"
      rationale: "Consultant R-001..R-007 requirement schema is reused verbatim; the new observability requirement rides on R-003/R-005 inside the same pyramid."
    - path: "generate/from-scratch.md"
      rationale: "FromScratch flow is unaffected — delivery-2 is a NewVersion extension of an existing skill."
    - path: "generate/new-version.md"
      rationale: "NewVersion flow scaffolding unchanged; this delivery exercises the existing flow rather than modifying it."
    - path: "generate/planner-subagent.md"
      rationale: "Planner contract unchanged — this very file produced this plan using the existing contract."
    - path: "generate/in-generate-review.md"
      rationale: "In-generate review logic unaffected; no new CRs added."
    - path: "review/index.md"
      rationale: "Review-phase routing unchanged."
    - path: "review/cross-reviewer-subagent.md"
      rationale: "Since CR-PRD-L05 is untouched, the cross-reviewer's CR enumeration and dependency-graph logic are unchanged."
    - path: "review/adversarial-reviewer-subagent.md"
      rationale: "Adversarial-review hypotheses target semantic CRs; with CR set unchanged, this prompt is stable."
    - path: "revise/index.md"
      rationale: "Revise-phase routing unchanged."
    - path: "revise/per-issue-reviser-subagent.md"
      rationale: "Per-issue reviser semantics unchanged — no new issue types introduced."
    - path: "shared/judge-subagent.md"
      rationale: "Judge verdict schema and thresholds unchanged."
    - path: "shared/summarizer-subagent.md"
      rationale: "Summarizer writes the CHANGELOG / versions entry; no template changes needed for an incremental content delivery."
    # scripts/* intentionally omitted from keep — scripts are shared infrastructure
    # verified by scaffold-sha in CI; individual listing would bloat the plan and
    # provides no dependency-validation value per guide §10.3 (they are leaf tooling,
    # not domain-fill files).
rationale: |
  Delivery-2 is a NARROW content extension: the consultant clarification says the
  generated PRD artifact's `architecture/nfr.md` should gain an Observability section
  covering (a) metrics cardinality, (b) SLO templates, (c) tracing-span naming,
  (d) structured-log schemas.

  Resolving the target-level confusion: the clarification refers to the PRD ARTIFACT
  that the skill generates, not a skill-internal file. No file literally named
  `architecture/nfr.md` exists inside `skills/prd-analysis/`; the skill prescribes
  such a file's shape via `common/templates/artifact-template.md` and the
  `architecture/<topic>.md` guidance in `generate/writer-subagent.md`. Therefore the
  minimal, correct edit surface is those two skill-source files — they together
  determine what writers emit into every downstream PRD's `architecture/nfr.md`.

  Rejected alternatives and why:
    1. Adding a brand-new file `skills/prd-analysis/architecture/nfr.md` — wrong layer;
       the skill has no such file and would not consume it. That would confuse
       skill-source with artifact-output.
    2. Modifying `common/review-criteria.md` to extend CR-PRD-L05 or add CR-PRD-L07 —
       violates the NARROW-change constraint. Any CR change cascades into writer
       self-reviews, cross-reviewer, adversarial-reviewer, and reviser prompts,
       forcing them into `modify` too. Deferred to a future delivery.
    3. Modifying `generate/domain-consultant-subagent.md` to ask about observability —
       unnecessary; observability is now a fixed template requirement rather than an
       optional domain input, so the existing R-001..R-007 schema suffices.

  The plan therefore modifies exactly 2 files and keeps the remaining 20 skill-source
  files unchanged (scripts/* covered by scaffold-sha and not enumerated individually
  per guide §10.3 scope). Both `modify` edits are additive — existing perf/security/
  a11y text is preserved verbatim, and the new Observability subsection is appended
  as a fourth dimension with identical structural treatment. Downstream writers in
  delivery-2 will therefore produce a strictly richer `architecture/nfr.md` in every
  generated PRD while the skill's CR/review machinery continues to operate on the
  delivery-1 criterion set.
```
