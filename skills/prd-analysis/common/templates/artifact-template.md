# Artifact Template — prd-analysis

This file defines the canonical section layout for every leaf type produced by
`prd-analysis`. Writers MUST pick the matching sub-template by leaf path and MUST author
the leaf using only the section headings and required fields defined below.

PRDs are authored as a **multi-file pyramid** under
`docs/raw/prd/YYYY-MM-DD-{product-slug}/`. Five leaf types exist:

1. `README.md` — pyramid apex (product overview + journey/feature/cross-journey indices + roadmap).
2. `journeys/J-NNN-{slug}.md` — individual user journey leaf.
3. `features/F-NNN-{slug}.md` — self-contained feature leaf.
4. `architecture.md` — architecture index leaf (~50–80 lines, links only).
5. `architecture/{topic}.md` — individual architecture topic leaf (tech-stack, data-model,
   nfr, security, observability, ...).

## Universal Rules (apply to ALL leaves)

- **Leaf size budget**: every leaf MUST be ≤ 300 lines. Split larger content across multiple
  leaves; never inflate a single leaf past the budget.
- **Self-contained inline copy**: each leaf MUST be independently readable. Any referenced
  context (data models, conventions, journey context, acceptance criteria format, token
  values, API contract schema) MUST be copied inline as actual text, NOT linked by path.
  A coding agent opening one feature file MUST have everything needed to implement that
  feature — never "see architecture.md" or "refer to J-001". Hyperlinks are allowed for
  navigation only; they MUST NOT be load-bearing.
- **ID format**: IDs are zero-padded sequential: `F-001`, `F-002`, `J-001`, `J-002`,
  `M-001`, `M-002`. Slugs are kebab-case, ASCII lowercase, no trailing hyphens.
- **Design tokens**: ALL visual values MUST be referenced by semantic token name
  (e.g., `color.primary.500`, `spacing.4`, `radius.lg`, `motion.duration.normal`). Raw
  values (e.g., `#2563EB`, `16px`, `300ms`) are FORBIDDEN outside `architecture/design-tokens.md`.
- **Omit-if-empty**: a section with no useful content MUST be omitted entirely rather than
  filled with placeholders like "TBD" or "N/A". Empty sections are FORBIDDEN.
- **PRD scope discipline**: PRD content captures product-level decisions (what, for-whom,
  why, priority, acceptance). Implementation-level decisions (code organization, framework
  choice within a module, internal class design) belong to system-design, NOT to this PRD.
- **No IPC envelopes**: leaves MUST NOT contain HTML comments like `<!-- self-review -->`,
  `<!-- metrics-footer -->`, or `<!-- dispatch-log -->`. Process metadata belongs in
  `.review/`, never in an artifact leaf.

---

## README Template — `README.md`

The pyramid apex. **Navigational only** — no feature details, no architecture deep-dives.

### Required Sections (in order)

1. **Header**
   ```
   # PRD: {Product Name}

   > {One-sentence product vision}
   ```
2. **Problem & Goals** — problem statement (2–3 sentences), goals table
   (Metric | Target | Baseline | How to Measure), in/out-of-scope bullet.
3. **Evidence Base** — table (Decision | Evidence Type | Source | Confidence). Low-confidence
   rows MUST be flagged as validation risks in the Risks section.
4. **Users** — table (Persona | Role | Primary Goal). Persona names MUST match those used in
   every `journeys/J-NNN-*.md` leaf (persona-consistency).
5. **User Journeys** — table (ID | Journey | Persona | Key Pain Points | Spec). `Spec` column
   links to `journeys/J-NNN-{slug}.md`.
6. **Cross-Journey Patterns** — table (Pattern | Affected Journeys | Implication | Addressed by
   Feature). Every row MUST have at least one feature in `Addressed by Feature`; unaddressed
   patterns are scope gaps. Omit the entire section iff only one journey exists.
7. **Feature Index** — table (ID | Feature | Type | Impact | Effort | Priority | Deps | Spec).
   `Type` ∈ {UI, API, Backend} (comma-separated if multi); `Priority` ∈ {P0, P1, P2}.
8. **Risks** — table (Risk | Likelihood | Impact | Mitigation | Affected Features).
9. **Roadmap** — default mapping: Phase 1 = all P0, Phase 2 = P1, Phase 3 = P2. Overrides
   MUST carry an explicit one-line rationale.

### Optional Sections

- **Competitive Landscape** — omit for purely internal tools. If present: table (Alternative |
  How It Solves | Strengths | Weaknesses) + 1–2 sentence differentiation + table-stakes note.
- **References** — footer links to `journeys/`, `architecture.md`, `REVISIONS.md` (evolve mode only).

### Forbidden in README

- Feature bodies, acceptance criteria, state machines, API schemas — those belong in
  `features/F-NNN-*.md`.
- Architecture topic content — those belong in `architecture/{topic}.md`.
- Revision history — lives in `REVISIONS.md`, created on first `--evolve`.

---

## Journey Template — `journeys/J-NNN-{slug}.md`

One file per user journey. Bridges personas (README) and features (features/).

### Required Sections (in order)

1. **Header**
   ```
   # J-NNN: {Journey Name}

   **Persona:** {who — MUST match a row in README Users table}
   **Trigger:** {what event or need initiates this journey}
   **Goal:** {what the user is trying to accomplish}
   **Frequency:** {daily | weekly | on-demand | one-time}
   ```
2. **Journey Flow** — Mermaid `flowchart` diagram showing happy path + key branches.
3. **Touchpoints** — table with **all six required columns**:

   | # | Stage | User Action | System Response | Screen/View | Interaction Mode | Emotion | Pain Point | Mapped Feature |
   |---|-------|-------------|-----------------|-------------|------------------|---------|------------|----------------|

   **Every touchpoint MUST populate**:
   - `Stage` — logical phase (Discovery | Onboarding | Core Task | Completion | Return | Recovery | other-documented).
   - `Screen/View` — consistent screen name (same screen across journeys MUST use the same name).
   - `User Action` — what the user does, from the user's perspective.
   - `System Response` — what the system does in reply.
   - `Interaction Mode` — primary pattern ∈ {click, form, drag, keyboard, scroll, hover, swipe, voice, scan, long-press}.
   - `Pain Point` — friction/frustration encountered at this step, or `—` if none.

   Columns `Emotion` (positive/neutral/negative) and `Mapped Feature` (backfilled in cross-linking)
   are also required but may hold `—` during initial writing.

4. **Alternative Paths** — table (Condition | Diverges at | Path | Rejoins at).
5. **Error & Recovery Paths** — table (Error Scenario | Occurs at | User Sees | Recovery
   Action | Mapped Feature). Every error MUST trace to a testable criterion (Edge Case or
   Acceptance Criterion) in a feature leaf.

### Optional Sections

- **Page Transitions** — table (From | To | Transition Type | Data Prefetch | Notes). Omit for
  single-screen journeys.
- **E2E Test Scenarios** — table (Scenario | Path | Steps | Features Exercised | Expected
  Outcome). Required for multi-touchpoint journeys; omit only for single-touchpoint journeys.
- **Journey Metrics** — table (Metric | Target | Baseline | Measurement | Verification).

### Rules

- Every feature MUST map to at least one journey touchpoint (enforced at cross-review).
- Every pain point SHOULD have feature coverage; uncovered pain points are scope gaps.
- Journey content MUST be copied inline into the consuming feature leaf's Journey Context;
  a coding agent reading a feature file MUST NOT need to open the journey file.

---

## Feature Template — `features/F-NNN-{slug}.md`

Each feature leaf MUST be fully self-contained. A coding agent implements the feature by
reading only this file — no other file should be required.

### Required Sections (in order)

1. **Header**
   ```
   # F-NNN: {Feature Name}

   > **Priority:** P0 | P1 | P2   **Effort:** S | M | L | XL
   ```
   **Priority rationale** MUST appear in the next line as a one-sentence justification
   (e.g., "P0 because every pilot user hit this pain point in interview batch 1").
2. **Context** — inline copy of:
   - Product one-sentence summary.
   - Relevant architecture fragments this feature touches (3–5 lines, copied inline).
   - Relevant data model entities (copied inline from `architecture/data-model.md`).
   - Relevant conventions (copied inline from the applicable `architecture/*.md` topic files:
     coding-conventions, test-isolation, security, shared-conventions, observability, etc.).
     Copy only policies this feature actually touches; omit the rest.
   - Permission line (role → access level) copied inline from `architecture/auth-model.md`
     if the feature has access restrictions; omit for single-role products.
3. **User Stories** — bullets of the form `As a {persona}, I want to {action}, so that {outcome}.`
4. **Journey Context** — for each mapped journey: one line naming the journey, touchpoint
   numbers, pain points resolved. The relevant touchpoint details MUST be copied inline below
   the line (not merely linked).
5. **Requirements** — numbered list of precise, unambiguous requirements.
6. **Acceptance Criteria** —
   - Behavioral: Given/When/Then format, one bullet per criterion. MUST be testable
     (automatable).
   - If the feature has `Depends on` entries, include at least one cross-feature integration
     criterion.
   - Non-behavioral: include applicable dimensions (Performance, Resource limits, Concurrency,
     Security/permissions, Degradation). Each MUST be measurable (p95 latency bound, memory
     bound, throughput bound). Omit dimensions that don't apply.
7. **Edge Cases** — same Given/When/Then format as Acceptance Criteria. Every edge case MUST
   be testable. If the feature has a Permission line, include at least one unauthorized-access
   edge case.
8. **Dependencies** — bullets of the form:
   - `Depends on: F-XXX — {reason}`
   - `Blocks: F-YYY — {reason}`

### Optional Sections (include only when applicable)

- **API Contract** — endpoint tables with request/response schemas. Omit for pure UI or
  pure background-job features.
- **Interaction Design** — required for user-facing features; omit for backend-only features.
  Includes: Screen & Layout (tokens only, no raw values), Component Contracts (Prop/Event/Slot
  tables), Interaction State Machine (Mermaid `stateDiagram-v2` + transition table), Form
  Specification, Micro-Interactions & Motion (Duration/Easing tokens only), Accessibility
  (WCAG level, Keyboard Navigation, ARIA, Focus Management), i18n (Frontend + Backend as
  applicable), Responsive Behavior (breakpoint tokens only).
- **State Flow** — domain-entity state machine (Mermaid `stateDiagram-v2`); distinct from
  Interaction State Machine. Omit for stateless CRUD.
- **Test Data Requirements** — table (Aspect | Specification). Omit when trivial.
- **Analytics & Tracking** — table (Event | Trigger | Payload | Purpose).
- **Notifications** — table (Event | Channel | Recipient | Content Summary | User Control).
- **Risks & Mitigations** — copy relevant rows from README Risks, scoped to this feature.
- **Implementation Notes** — Approach, Key files, Testing, Pitfalls.

### Forbidden in Feature Leaves

- Cross-references of the form "see architecture.md for tokens" — MUST copy the specific
  tokens this feature uses inline.
- Cross-references of the form "see J-003 for user context" — MUST copy the touchpoint
  details this feature implements inline.
- Raw visual values — MUST use semantic design tokens.
- Implementation-level decisions beyond "Approach" / "Key files" hints — those belong to
  system-design.

---

## Architecture Index Template — `architecture.md`

Index only. Target ≤ 80 lines. Contains a high-level diagram plus a single topic table. No
topic content lives here.

### Required Sections (in order)

1. **Header** — `# Architecture: {Product Name}`.
2. **High-Level Architecture** — one Mermaid diagram OR one short textual description of the
   major components and their relationships.
3. **Architecture Index** — table with one row per topic file that actually exists:

   | Topic | File | Summary |
   |-------|------|---------|
   | {Topic Name} | [{file}.md](architecture/{file}.md) | {one-line summary} |

   Rows for topics whose file is omitted MUST NOT appear.

### Forbidden in the Architecture Index

- Policy text, token values, schema tables, convention lists — all belong in
  `architecture/{topic}.md`.
- Cross-linking to feature or journey leaves (architecture.md is a pyramid-apex index for
  architecture only, not a global cross-link hub).

---

## Architecture Topic Template — `architecture/{topic}.md`

One file per topic. Each file is standalone — agents read only the topics relevant to the
feature they are implementing. The canonical topic set is:

- `tech-stack.md`, `design-tokens.md` (omit if no UI), `navigation.md` (omit if no UI or
  single-view), `accessibility.md` (omit if no UI), `i18n.md`, `data-model.md`, `external-deps.md`,
  `coding-conventions.md`, `test-isolation.md`, `security.md`, `dev-workflow.md`,
  `git-strategy.md`, `code-review.md`, `observability.md`, `performance.md`,
  `backward-compat.md` (omit for v1/MVP), `ai-agent-config.md`, `deployment.md`,
  `shared-conventions.md`, `auth-model.md` (omit if single-role), `privacy.md` (omit if no PII),
  `nfr.md`.

### Universal Rules for Topic Leaves

- Each topic leaf MUST be a standalone document — no "see other-topic.md for details"
  cross-links that carry load-bearing content. If topic A needs policy text that also lives
  in topic B, the text MUST be copied into A (and into features that consume A).
- Topic files contain **policies**, not **implementation patterns**. System-design
  translates policies to stack-specific patterns downstream.
- Design token values live ONLY in `design-tokens.md`. All other leaves (features,
  journeys, other topic files) reference tokens by **semantic name** and MUST NOT embed raw
  values.
- The following topic files MUST be present in every PRD (no omission): `coding-conventions.md`,
  `test-isolation.md`, `security.md`, `dev-workflow.md`, `git-strategy.md`, `code-review.md`,
  `observability.md`, `performance.md`, `ai-agent-config.md`, `shared-conventions.md`,
  `nfr.md`.
- Omission rules for conditional topics are fixed: `design-tokens.md`, `navigation.md`,
  `accessibility.md` — omit iff no user-facing interface; `auth-model.md` — omit iff
  single-role; `privacy.md` — omit iff no personal data; `backward-compat.md` — omit for
  v1/MVP (note intended future strategy in the file instead, or skip entirely).

### Required per-Topic Shape

Every topic leaf MUST include:

1. **Header** — `# {Topic Title}`.
2. **One or more tables or sub-sections** covering the topic's policy surface. The exact
   section list is topic-specific; author the minimum set of tables/sub-sections needed to
   make the topic independently actionable by a coding agent (e.g., `security.md` needs an
   Aspect/Policy table covering input validation, secrets, auth enforcement, TLS, and
   at-rest encryption — see the example below; `data-model.md` needs an entity table plus
   relationships; `nfr.md` needs a Dimension/Target/Rationale table). Policy rows MUST be
   concrete enough to be verifiable.
3. **Policy statements only** — no code samples, no framework-specific APIs, no file paths
   that assume a particular project layout.

### Example: minimum-viable `architecture/security.md`

```markdown
# Security Coding Policy

| Aspect | Policy |
|--------|--------|
| Input validation | All external input validated at system boundaries. |
| Boundary definition | HTTP handlers, CLI parsers, file readers, message consumers. |
| Secret handling | Never in source code, logs, error messages, or VCS history. |
| Dependency scanning | Vulnerability scanning in CI; critical CVEs block merge. |
| Injection prevention | Never concatenate user input into commands/queries/templates. |
| Auth enforcement | Every entry point independently verifies permissions. |
| Sensitive data in transit | All external connections use TLS. |
| Sensitive data at rest | Passwords hashed; PII encrypted at rest. |
```

---

## Cross-Leaf Consistency (enforced at cross-review)

- Every `F-NNN` in the README Feature Index MUST have exactly one corresponding
  `features/F-NNN-{slug}.md` file (no orphans, no duplicates).
- Every `J-NNN` in the README User Journeys table MUST have exactly one corresponding
  `journeys/J-NNN-{slug}.md` file.
- Every feature leaf MUST map to at least one journey touchpoint via its Journey Context.
- Every journey pain point SHOULD have feature coverage (warning-level if uncovered).
- Every Cross-Journey Pattern MUST have at least one feature in its `Addressed by Feature`
  column (error-level if uncovered).
- Persona names MUST be identical across README Users, journey Persona header, and feature
  User Stories.
- Design token names referenced in feature leaves MUST exist in `architecture/design-tokens.md`
  (or its omission is justified by "no UI").
- Every architecture topic file listed in the `architecture.md` Architecture Index MUST
  exist on disk; every topic file on disk MUST appear in the index.
