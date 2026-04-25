# Review Criteria — prd-analysis

Each criterion is defined below as a human-readable description followed by a YAML code block. Checker scripts extract only the YAML blocks — the prose is for human readers only. All `conflicts_with` fields are intentionally empty in v1; oscillation-prone pairs are tracked via CR-L04 (criteria-internally-consistent, LLM check) rather than hard-coded exclusions.

Criteria are grouped into **Structural (script-type)** and **Semantic (LLM-type)**. Severity-to-priority mapping: `critical = 1`, `error = 2`, `warning = 3`. Script-type criteria (CR-S01..CR-S15) apply to the prd-analysis META-skill files (SKILL.md, sub-agent prompts, config, scripts) and to structural properties of generated PRD artifact pyramids. LLM-type criteria (CR-L01..CR-L16) apply to the content of PRD pyramid leaves (journey specs, feature specs, architecture topic files, README index) produced by the writers in each review round.

---

## Criteria Index

| ID | Name | Type | Severity | Applicable Artifact Types |
|----|------|------|----------|--------------------------|
| CR-S01 | skill-md-frontmatter | script | error | skill_md |
| CR-S02 | mode-routing-complete | script | error | skill_md |
| CR-S03 | config-schema-valid | script | error | skill_md |
| CR-S04 | criteria-yaml-valid | script | error | review_criteria |
| CR-S05 | scripts-inventory-match | script | critical | skill_md |
| CR-S06 | scaffold-sha-pinned | script | critical | skill_md |
| CR-S07 | dependencies-loadable | script | error | skill_md |
| CR-S08 | ipc-footer-present | script | critical | sub_agent_prompt |
| CR-S09 | dispatch-log-snippet | script | critical | skill_md |
| CR-S10 | trace-id-format | script | error | sub_agent_prompt, skill_md |
| CR-S11 | index-consistency | script | error | prd_artifact_leaf |
| CR-S12 | changelog-consistency | script | error | prd_artifact_leaf |
| CR-S13 | criteria-consistency | script | error | review_criteria |
| CR-S14 | drift-check | script | error | prd_artifact_leaf |
| CR-S15 | skill-md-cost-control-sections | script | error | skill_md |
| CR-L01 | persona-realism | llm | error | prd_artifact_leaf |
| CR-L02 | journey-causal-flow | llm | error | prd_artifact_leaf |
| CR-L03 | feature-journey-traceability | llm | error | prd_artifact_leaf |
| CR-L04 | mvp-boundary-discipline | llm | error | prd_artifact_leaf |
| CR-L05 | success-criteria-measurable | llm | error | prd_artifact_leaf |
| CR-L06 | business-priority-justification | llm | warning | prd_artifact_leaf |
| CR-L07 | terminology-consistency | llm | error | prd_artifact_leaf, domain_glossary |
| CR-L08 | glossary-coverage | llm | warning | domain_glossary |
| CR-L09 | scope-discipline | llm | error | prd_artifact_leaf |
| CR-L10 | self-containment | llm | error | prd_artifact_leaf |
| CR-L11 | cross-journey-pattern-derivation | llm | error | prd_artifact_leaf |
| CR-L12 | design-token-semantics | llm | warning | prd_artifact_leaf |
| CR-L13 | interaction-mode-explicit | llm | warning | prd_artifact_leaf |
| CR-L14 | acceptance-criteria-state-machine | llm | error | prd_artifact_leaf |
| CR-L15 | tombstone-completeness | llm | error | prd_artifact_leaf |
| CR-L16 | review-criteria-coverage | llm | error | review_criteria |

---

## Structural Criteria (Script-Type)

---

## CR-S01 skill-md-frontmatter

SKILL.md MUST have frontmatter with `name`, `version`, `description` keys. `description` MUST be ≤ 1024 characters and MUST start with the literal phrase "Use when" per guide §21.1. A SKILL.md that violates this contract cannot be correctly loaded by the plugin routing layer.

PASS: frontmatter block is present, starts with `---`, and contains `name:`, `version:`, `description:` keys; description begins with "Use when".

FAIL: frontmatter missing or `description` begins with "This skill" instead of "Use when".

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

---

## CR-S02 mode-routing-complete

The mode-routing table in SKILL.md MUST list all base modes (from-scratch, new-version, review, revise) plus `--diagnose`. Every row in the routing table MUST include a "Loaded Files" column documenting which topic files are loaded for that mode. Missing rows leave a mode undispatchable and the orchestrator cannot load the correct context.

PASS: routing table has 5 rows, each with a non-empty "Loaded Files" cell.

FAIL: `--diagnose` mode row is absent from the table.

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

---

## CR-S03 config-schema-valid

`config.yml` MUST contain all §21.2 top-level keys including `tool_permissions`, `model_tier_defaults`, and `hitl`. A missing key causes the orchestrator to fall back to undefined defaults, producing non-deterministic behavior across environments.

PASS: `config.yml` contains all required top-level keys and parses as valid YAML.

FAIL: `model_tier_defaults` key absent; orchestrator inherits caller session's model tier.

```yaml
- id: CR-S03
  name: "config-schema-valid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-config-schema.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S04 criteria-yaml-valid

Every criterion entry in `common/review-criteria.md` MUST have the required fields: `id`, `name`, `version`, `checker_type`, `severity`, `conflicts_with`, `priority`, `incremental_skip`. `checker_type` MUST be one of `script`, `llm`, or `hybrid`. Malformed criterion entries are silently skipped by checker scripts, creating invisible gaps in review coverage.

PASS: all YAML blocks in this file parse correctly and contain every required key with valid values.

FAIL: a criterion block is missing the `severity` field; `check-criteria-yaml.sh` rejects the entry and it is never run.

```yaml
- id: CR-S04
  name: "criteria-yaml-valid"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-criteria-yaml.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S05 scripts-inventory-match

All required shell scripts MUST exist and be executable. The inventory is defined in `shared-scripts-manifest.yml`. Missing or non-executable scripts cause silent failures in the review round when the cross-reviewer invokes them.

PASS: every script listed in `shared-scripts-manifest.yml` exists on disk and has executable permission.

FAIL: `scripts/check-index-consistency.sh` is present but not executable; cross-reviewer silently skips CR-S11 at runtime.

```yaml
- id: CR-S05
  name: "scripts-inventory-match"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scripts-inventory.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-S06 scaffold-sha-pinned

`scripts/metrics-aggregate.sh` and `scripts/lib/aggregate.py` sha256 hashes MUST match the values recorded in `shared-scripts-manifest.yml`. These files are shared infrastructure; silent divergence causes cross-skill metrics incompatibility and breaks `--diagnose` output.

PASS: sha256 of both files matches manifest entries exactly.

FAIL: `aggregate.py` was edited locally; sha diverges from manifest; `--diagnose` produces results that cannot be compared against other skills.

```yaml
- id: CR-S06
  name: "scaffold-sha-pinned"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scaffold-sha.sh
  severity: critical
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## CR-S07 dependencies-loadable

The target skill's `scripts/check-dependencies.sh` MUST verify that all runtime dependencies are loadable: `git ≥ 2.0`, `bash ≥ 4.0`, `python3 ≥ 3.8` per guide §21.0. Missing version checks allow the skill to silently run in unsupported environments, producing hard-to-debug failures during PRD generation.

PASS: `check-dependencies.sh` contains version assertions for `git`, `bash`, and `python3` with the correct minimum versions.

FAIL: `check-dependencies.sh` only verifies `git` and `python3`; missing `bash` version check allows the skill to run under bash 3 on macOS with incompatible associative array syntax.

```yaml
- id: CR-S07
  name: "dependencies-loadable"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-dependencies.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S08 ipc-footer-present

Every sub-agent prompt MUST contain the Snippet D fingerprint verbatim (`<!-- snippet-d-fingerprint: ipc-ack-v1 -->`). Snippet D is the IPC footer that instructs the sub-agent to write output to the final path inside the sub-session and return exactly one ACK line. Without it, sub-agents return content inline and break the orchestrator's dispatch loop.

PASS: `grep -r "snippet-d-fingerprint: ipc-ack-v1"` matches all 7 standalone sub-agent prompt files.

FAIL: `generate/writer-subagent.md` lacks the fingerprint comment; writer returns a full artifact body inline, polluting orchestrator context.

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

---

## CR-S09 dispatch-log-snippet

The SKILL.md orchestrator body MUST contain the Snippet C fingerprint verbatim. Snippet C is the dispatch-log write pattern that ensures every sub-agent invocation is recorded in `dispatch-log.jsonl` for observability and retry recovery. Without Snippet C the orchestrator cannot be audited and `--diagnose` round-level metrics are missing.

PASS: SKILL.md contains the literal `<!-- snippet-c-fingerprint: dispatch-log-v1 -->` comment.

FAIL: SKILL.md omits the fingerprint; `check-dispatch-log-snippet.sh` fails; dispatch events are not logged.

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

---

## CR-S10 trace-id-format

All `trace_id` occurrences in the generated skill MUST use the format `R<N>-<role-letter>-<nnn>` where `role-letter` ∈ `{C, P, W, V, R, S, J}` per guide §3.5. Malformed trace IDs break log correlation and metrics aggregation in `--diagnose` mode.

PASS: every `trace_id` field in example YAML and dispatch-log entries matches `R\d+-[CPWVRSJ]-\d{3}`.

FAIL: a sub-agent prompt uses `R1-writer-001` with the full role name instead of the role letter code; log correlation fails.

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

---

## CR-S11 index-consistency

`README.md` and `architecture.md` index tables MUST list every file in `journeys/`, `features/`, and `architecture/` respectively, and list no entries that lack a corresponding file on disk. An inconsistent index causes the summarizer to produce an incorrect version summary and misleads coding agents about the full feature set.

PASS: `check-index-consistency.sh` reports 0 orphaned entries and 0 missing entries after comparing index tables to directory listings.

FAIL: `features/F-007-pdf-export.md` was added by a writer but the README feature index table still has only F-001..F-006; cross-reviewer detects the gap.

```yaml
- id: CR-S11
  name: "index-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-index-consistency.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S12 changelog-consistency

`CHANGELOG.md` entries and `.review/versions/<N>.md` files MUST be 1:1 with matching `delivery_id`, `change_summary`, and `affected_leaves`. `delivery_id` MUST be monotonic with no gaps. Divergence indicates the summarizer wrote a version entry that did not propagate into the artifact's CHANGELOG.

PASS: `CHANGELOG.md` has 2 entries for delivery_id 1 and 2; `.review/versions/` has `1.md` and `2.md`; all summaries match.

FAIL: `.review/versions/3.md` exists but `CHANGELOG.md` has no delivery_id=3 entry; gap detected by `check-changelog-consistency.sh`.

```yaml
- id: CR-S12
  name: "changelog-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-changelog-consistency.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S13 criteria-consistency

Every criterion listed in the "Criteria Index" table at the top of this file MUST have a corresponding H2 section and YAML block below. No H2 section may exist that is absent from the index table. Orphan entries or missing entries break the cross-reviewer's ability to verify coverage.

PASS: index table lists 31 criteria; exactly 31 H2 sections and 31 YAML blocks exist below the table.

FAIL: CR-L16 appears in the index table but its H2 section was accidentally omitted; cross-reviewer cannot locate the criterion definition.

```yaml
- id: CR-S13
  name: "criteria-consistency"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-criteria-yaml.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S14 drift-check

Between consecutive review rounds, the artifact leaf on disk MUST match the last writer's or reviser's committed output (verified via sha256 recorded in `.review/round-<N>/state.yml`). Any sha divergence not attributable to a reviser write indicates an out-of-band modification. Out-of-band modifications break reproducibility and version traceability.

PASS: sha256 of `features/F-003.md` at round-2 start matches the sha recorded in `round-1/state.yml`.

FAIL: sha256 diverges between rounds with no reviser dispatch in the log; indicates manual edit outside the skill loop.

```yaml
- id: CR-S14
  name: "drift-check"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-scaffold-sha.sh
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-S15 skill-md-cost-control-sections

The target's `SKILL.md` MUST include the cost-control sections that the `skill-md-template.md` template bakes in: a `## Model Tiers` heading, a `### Per-dispatch model override` subsection with the role→tier→Agent-tool-`model` mapping table, and a `## CLI Flags` table containing at minimum the rows `--full`, `--no-consultant`, `--tier <role>=<tier>`, and `--max-iterations N`.

These sections are the orchestrator-facing contract for cost control. Without them, the orchestrator inherits the parent session's model (typically `opus`) across every sub-agent dispatch, and users have no documented way to skip the domain-consultant or override tiers per role. The check is structural — regex anchors against H2/H3 headings, the role table header, and backtick-quoted flag literals. It does not validate the prose inside each section; that is covered by LLM checks.

PASS: SKILL.md contains `## Model Tiers`, `### Per-dispatch model override`, the role-tier table header row, and a `## CLI Flags` table with all four required flag rows.

FAIL: SKILL.md was generated without the cost-control sections; every sub-agent dispatch runs at the caller's opus tier; `--no-consultant` flag is undocumented.

```yaml
- id: CR-S15
  name: "skill-md-cost-control-sections"
  version: 1.0.0
  checker_type: script
  script_path: scripts/check-skill-md-sections.sh
  severity: error
  conflicts_with: []
  priority: 1
  incremental_skip: per_file
```

---

## Semantic Criteria (LLM-Type)

---

## CR-L01 persona-realism

Each user journey persona MUST feel real: it MUST have a name, a role or demographic context, an explicit motivation, and a stated goal for the journey. Personas described only as "User" or "Customer" without contextual grounding produce feature sets that lack empathy and fail stakeholder review.

PASS: Persona section reads "Priya, a 32-year-old freelance designer, wants to invoice clients without switching tools. Goal: complete a new invoice in under 2 minutes."

FAIL: Persona section reads "The user wants to create an invoice." — no name, no context, motivation implicit.

```yaml
- id: CR-L01
  name: "persona-realism"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L02 journey-causal-flow

Each touchpoint in a journey spec MUST logically lead to the next. The system response of touchpoint N MUST set up the pre-condition for touchpoint N+1. Gaps in causal flow indicate missing states or features that will surface as integration bugs during implementation.

PASS: Touchpoint 2 "User submits invoice form → system validates and creates draft" correctly precedes Touchpoint 3 "User reviews draft → system shows preview with Send button enabled."

FAIL: Touchpoint 2 "User clicks Send" immediately follows Touchpoint 1 "User opens app" with no intermediate steps that populate invoice data — causal gap detected.

```yaml
- id: CR-L02
  name: "journey-causal-flow"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L03 feature-journey-traceability

Every feature in the feature index MUST map back to ≥1 touchpoint in a journey spec. Orphan features — those not referenced by any touchpoint — indicate gold-plating or missing journey coverage and MUST be either linked to an existing touchpoint or removed from scope.

PASS: F-007 "Invoice PDF Export" references J-002 Touchpoint 4 "User downloads invoice" in its `Source Journeys` field.

FAIL: F-012 "Admin Analytics Dashboard" has no `Source Journeys` field and no journey touchpoint references it — orphan feature.

```yaml
- id: CR-L03
  name: "feature-journey-traceability"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L04 mvp-boundary-discipline

Every feature's priority field (P0/P1/P2) and MVP flag MUST be explicitly justified with a reasoning statement covering impact on the core happy-path and effort trade-off. Features marked P0 that serve non-critical paths inflate MVP scope and delay launch.

PASS: "Priority: P0 — MVP: yes. Justification: core happy path (J-001 Touchpoint 3). Without this feature, users cannot complete the primary conversion event. Low implementation effort (single form, existing auth system)."

FAIL: "Priority: P0 — MVP: yes." with no Justification field — reviewer cannot assess whether the P0 assignment is warranted.

```yaml
- id: CR-L04
  name: "mvp-boundary-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L05 success-criteria-measurable

Each feature MUST have Acceptance Criteria that are precise enough to write automated test assertions. Vague verbs — "correctly handles", "properly displays", "works as expected" — are FORBIDDEN. Every AC MUST specify observable system behavior: what appears on screen, what API response is returned, what state changes occur.

PASS: "AC-1: When a valid invoice is submitted, the system returns HTTP 201 with an `invoice_id` field and the invoice appears in the user's draft list within 1 second."

FAIL: "AC-1: The system correctly processes the invoice submission." — no observable behavior, no measurable threshold.

```yaml
- id: CR-L05
  name: "success-criteria-measurable"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L06 business-priority-justification

Each feature's `Priority` field MUST include explicit reasoning covering both business impact (user value delivered, revenue or retention effect) and implementation effort (relative complexity). A priority assignment without reasoning is untestable by stakeholders and breeds scope creep.

PASS: "Priority: P1. Impact: enables repeat-use (retention driver). Effort: medium — requires email template system not in MVP stack. Deferred to Phase 2."

FAIL: "Priority: P1." — no impact or effort reasoning provided.

```yaml
- id: CR-L06
  name: "business-priority-justification"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L07 terminology-consistency

Every domain term used across journey specs, feature specs, and architecture topic files MUST match the canonical definition in `common/domain-glossary.md`. Divergent synonyms (e.g. "touchpoint" vs. "interaction point", "persona" vs. "actor") across leaves create ambiguity for coding agents consuming individual files.

PASS: all journey files use "touchpoint" consistently; interaction-mode values match the glossary enumeration (click, form, drag, swipe, keyboard, scroll, hover, voice, scan).

FAIL: J-002 uses "user step" where J-001 uses "touchpoint" and F-005 uses "interaction point" — three terms for the same concept across three leaves.

```yaml
- id: CR-L07
  name: "terminology-consistency"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L08 glossary-coverage

Every domain term that appears in any PRD artifact leaf and is not a common English word MUST have an entry in `common/domain-glossary.md`. Missing glossary entries force coding agents to guess term meaning from context, producing inconsistent implementation interpretations.

PASS: `domain-glossary.md` contains entries for "touchpoint", "interaction mode", "cross-journey pattern", "feature-module mapping", "tombstone", "design token", and "self-contained file."

FAIL: Feature files reference "permission boundary" repeatedly but `domain-glossary.md` has no entry for this term.

```yaml
- id: CR-L08
  name: "glossary-coverage"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L09 scope-discipline

Features MUST describe WHAT the system does (requirements), not HOW it does it (implementation). Technology choices, library names, SQL schemas, API endpoint paths, and infrastructure decisions belong in system-design, not in the PRD. Scope violations create premature implementation lock-in and conflict with system-design output.

PASS: "The system MUST store user invoice data persistently and retrieve it within 500ms for lists up to 1000 items." — observable behavior, no implementation prescription.

FAIL: "The system MUST use PostgreSQL with a JSONB column for invoice line items and a GIN index for full-text search." — implementation detail, belongs in system-design.

```yaml
- id: CR-L09
  name: "scope-discipline"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L10 self-containment

Each feature leaf MUST be independently readable and implementable by a coding agent without opening any other file. This requires: all relevant data models copied inline (not referenced by path), applicable conventions copied inline, permission model stated inline, and journey context for the primary touchpoint summarized inline.

PASS: F-005 "Send Invoice" includes an inline copy of the Invoice data model fields, an inline excerpt of the error-handling convention from architecture, and a one-paragraph inline summary of J-002's relevant touchpoint.

FAIL: F-005 says "See `architecture/data-model.md` for the Invoice schema" and "Follow conventions in `architecture/coding-conventions.md`." — coding agent must open two additional files.

```yaml
- id: CR-L10
  name: "self-containment"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L11 cross-journey-pattern-derivation

The PRD README MUST include a "Cross-Journey Patterns" section. Every cross-journey pattern documented there MUST be addressed by ≥1 feature. Patterns with no addressing feature represent known shared pain points that will be re-discovered as duplicate work during implementation.

PASS: Pattern "Authentication wall appears at multiple journey entry points" is addressed by F-001 "Unified Auth Gate" which is referenced in the pattern row.

FAIL: Pattern "All journeys require user to be logged in" is listed in the README but no feature addresses authentication as a shared infrastructure concern — pattern unaddressed.

```yaml
- id: CR-L11
  name: "cross-journey-pattern-derivation"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L12 design-token-semantics

All token references in feature Interaction Design sections MUST use semantic names (e.g. `color.primary`, `spacing.md`, `motion.duration.normal`), not raw values (hex colors, pixel counts, milliseconds). All applicable token categories MUST be declared in `architecture/design-tokens.md` or equivalent architecture topic file.

PASS: State machine transition note reads "Fade in using `motion.duration.fast` and `motion.easing.standard`."

FAIL: State machine transition note reads "Fade in over 200ms with cubic-bezier(0.4, 0, 0.2, 1)." — raw values, not semantic tokens.

```yaml
- id: CR-L12
  name: "design-token-semantics"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L13 interaction-mode-explicit

Every touchpoint in a journey spec MUST specify an interaction mode drawn from the canonical enumeration: `click`, `form`, `drag`, `keyboard`, `scroll`, `hover`, `swipe`, `voice`, `scan`. The stated interaction mode MUST be consistent with the corresponding feature's component contracts and state machine transitions.

PASS: Touchpoint "User selects payment method" has `Interaction Mode: click` and the linked feature's state machine shows a `click(option)` transition on the payment method selector component.

FAIL: Touchpoint "User enters invoice details" has no Interaction Mode field — reviewer cannot verify consistency with the feature's component contract.

```yaml
- id: CR-L13
  name: "interaction-mode-explicit"
  version: 1.0.0
  checker_type: llm
  severity: warning
  conflicts_with: []
  priority: 3
  incremental_skip: per_file
```

---

## CR-L14 acceptance-criteria-state-machine

Features that manage multi-step or stateful workflows MUST include an explicit state machine: named states, transitions with trigger events, system feedback for each transition, and no dead states (every state has ≥1 exit). Loading states MUST have both success and error exits. Implicit state described only in prose produces undiscoverable edge cases.

PASS: Feature "Invoice Send Flow" has states `[idle, composing, validating, sending, sent, error]` with all transitions and feedback specified; `sending` state has both `→ sent` (on success) and `→ error` (on failure) exits.

FAIL: Feature "Invoice Send Flow" describes the flow in a numbered list — "1. User fills form. 2. System validates. 3. Invoice is sent." — no explicit states, no error exit visible.

```yaml
- id: CR-L14
  name: "acceptance-criteria-state-machine"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L15 tombstone-completeness

In evolve-mode (new-version) PRDs, every deprecated feature or journey MUST have a tombstone file that contains: `status: deprecated`, `deprecation_reason` (one sentence), `replacement_ref` (path to replacing feature/journey or `none`), and an `original_ref` link to the baseline PRD version. Incomplete tombstones break the evolve flatten algorithm and version traceability.

PASS: `features/F-003-legacy-export.md` tombstone contains all four required fields and `original_ref` resolves to a valid baseline path.

FAIL: `features/F-003-legacy-export.md` tombstone contains only `status: deprecated` and a one-line note; `replacement_ref` and `original_ref` are missing — flatten algorithm cannot resolve the deprecation chain.

```yaml
- id: CR-L15
  name: "tombstone-completeness"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```

---

## CR-L16 review-criteria-coverage

The `applicable_artifact_types` field of each criterion in this file MUST cover every leaf shape that prd-analysis produces. The full set of leaf shapes is: `prd_artifact_leaf` (journey files, feature files, architecture topic files, README), `domain_glossary`, `sub_agent_prompt`, `skill_md`, and `review_criteria`. No leaf shape produced by the skill may be entirely uncovered by at least one criterion.

PASS: the union of all `applicable_artifact_types` values across all 31 CR entries covers all five leaf shapes: `prd_artifact_leaf`, `domain_glossary`, `sub_agent_prompt`, `skill_md`, and `review_criteria`.

FAIL: `sub_agent_prompt` appears in no criterion's `applicable_artifact_types`; the adversarial reviewer has no criterion to apply against sub-agent prompt files, leaving them unreviewed.

```yaml
- id: CR-L16
  name: "review-criteria-coverage"
  version: 1.0.0
  checker_type: llm
  severity: error
  conflicts_with: []
  priority: 2
  incremental_skip: per_file
```
