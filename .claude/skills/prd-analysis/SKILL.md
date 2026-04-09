---
name: prd-analysis
description: "Use when the user needs to create a Product Requirements Document, perform product requirements analysis, convert brainstorming notes into structured specs, or prepare requirements for AI coding agents. Triggers: /prd-analysis, 'write a PRD', 'product requirements', 'requirements analysis'."
---

# PRD Analysis — AI-Coding-Ready Requirements

Generate PRDs as a **multi-file directory**. Each feature spec is a self-contained file — coding agents read only the file they need, minimizing context consumption.

## Scope

PRD captures **product-level decisions**: what to build, for whom, why, and at what priority. It does NOT specify implementation-level details — those belong to system-design:

| Belongs in PRD | Belongs in System Design |
|----------------|------------------------|
| "Admin can manage users, Viewer can only read" (permission rules) | Permission middleware implementation, RBAC table schema |
| "User data must comply with GDPR" (compliance requirement) | PII field annotations, data retention cron design |
| "Support English and Chinese" (i18n requirement) | i18n library config, translation lazy loading, fallback strategy |
| "Notify user when task fails" (notification requirement) | Notification queue architecture, delivery retry logic |
| Design token definitions (colors, typography, spacing, motion, breakpoints) | Token-to-code implementation (CSS custom properties, Tailwind config) |
| Component contracts (props, events, slots) | Component file structure, composition patterns |
| Interaction state machines (states, transitions, user feedback) | State store implementation, async patterns, caching |
| Navigation architecture (site map, routes, breadcrumbs) | Route guards, lazy loading, code splitting |
| Form specifications (fields, validation rules, i18n keys) | Form library config, validation execution, server integration |
| Accessibility requirements (WCAG level, ARIA, keyboard, focus management) | a11y testing tools (axe-core), implementation patterns |
| Responsive layout changes per breakpoint | CSS grid implementation, breakpoint utilities |
| Interactive prototypes (seed-quality code for validation) | Prototype-to-Production mapping, refactoring plan |

## Input Modes

```
/prd-analysis                          # interactive mode
/prd-analysis path/to/notes.md         # document-based mode
/prd-analysis --output docs/raw/prd/my-project  # custom output dir
/prd-analysis notes.md --output ./prd  # both
/prd-analysis --review docs/raw/prd/xxx/        # review existing PRD
/prd-analysis --revise docs/raw/prd/xxx/        # change management for existing PRD
```

## Process

1. **Gather requirements** — interactive questioning or parse provided document
2. **Fill gaps** — ask targeted follow-up questions for missing info
3. **Generate PRD files** — using templates in this skill directory
4. **Cross-link** — backfill cross-references that couldn't exist during initial generation: journey Mapped Feature columns, feature Deps, feature Journey Context links, Cross-Journey Patterns "Addressed by Feature" column
5. **Write files** — write all generated files to disk (not yet committed)
6. **Self-review** — read each written file against the review checklist (see Review Checklist below), fix issues directly in files
7. **User review** — user reviews files in their editor, confirms or requests changes
8. **Commit** — commit all files to git

### Review Checklist

Applied as step 6 of the process (after writing, before commit). Check each dimension and fix issues directly in the written files:

| Dimension | Check |
|-----------|-------|
| Traceability | Goal → Journey → Touchpoint → User Story → Feature → Analytics chain is complete: every persona has journeys (happy + error + first-use); every touchpoint and pain point maps to a Feature; every Feature maps back to at least one touchpoint; no orphan features; cross-journey patterns are documented and each pattern is addressed by at least one Feature (or section omitted for single-journey products) |
| Evidence | Every major product decision traces to an evidence source (user research, data, feedback, or explicitly labeled as assumption); assumption-heavy features are flagged as validation risks |
| Competitive context | Competitive landscape section is present (or explicitly marked N/A for internal tools); differentiation is stated; table-stakes features are identified |
| Metrics | Every Goal has baseline + measurement method; every measurement maps to at least one Feature's Analytics event; every Journey Metric has a Verification entry (manual/automated/monitoring + pass/fail criteria) |
| Risks | Every high-likelihood or high-impact risk has a mitigation strategy; affected Features acknowledge the risk; compliance/privacy risks are covered if applicable |
| Priority | Every P0 serves a core journey happy-path touchpoint; Roadmap phases align with Priority (P0→Phase 1, P1→Phase 2); Feature dependencies don't contradict phase ordering |
| Authorization | Authorization model is defined (or N/A); every Feature with access restrictions has a Permission line in Context |
| Privacy | Privacy & Compliance section is present (or explicitly N/A); personal data entities are identified; user rights are stated if regulated |
| Self-containment | Each Feature file can be read and implemented independently — all needed context is inline |
| Testability | **(a)** Every Acceptance Criterion is precise enough to write a test assertion (no vague verbs like "correctly handles", "properly displays" — replace with observable behavior). **(b)** Every Edge Case has Given/When/Then that maps to an automated test. **(c)** Every Feature with non-trivial state or integration has at least one non-behavioral criterion (performance, concurrency, or resource limit). **(d)** Every Feature with a Permission line has at least one edge-case testing unauthorized access. **(e)** Every Journey's Error & Recovery Paths map to at least one Feature's Edge Case or Acceptance Criterion. **(f)** Cross-feature dependencies have at least one integration-level acceptance criterion in the downstream Feature (e.g. "Given F-003 has scheduled a task, when F-005 executes it, then …"). **(g)** Every multi-touchpoint Journey has an E2E Test Scenarios table covering happy, alternative, and error paths with features exercised and expected outcomes. **(h)** Every Feature with non-trivial test setup has a Test Data Requirements section (fixtures, boundary values, preconditions, external stubs) |
| Interaction Design coverage | Every user-facing Feature has an Interaction Design section with Screen & Layout, Component Contracts, Interaction State Machine, Accessibility, Internationalization, and Responsive Behavior filled; Screen/View names are consistent between journey touchpoints and feature files; no user-facing feature has Interaction Design omitted |
| Form specification completeness | (Skip if no features with forms) Every feature with user input has a Form Specification sub-section with field definitions (name, type, validation rules, error messages, conditional visibility, dependencies); submission behavior is defined (success/error handling); multi-step forms have step sequencing |
| Micro-interactions & motion | (Skip if no user-facing interface) Every user-facing feature with key interactions has a Micro-Interactions & Motion sub-section; every animation references duration and easing tokens (no raw ms or cubic-bezier values); every animation has a stated purpose |
| Journey interaction mode coverage | Every journey touchpoint has an Interaction Mode specified (click, form, drag, swipe, keyboard, scroll, hover, voice, scan, etc.); interaction modes are consistent with the corresponding feature's component contracts and state machines |
| Design token completeness | (Skip if no user-facing interface) All token categories (colors, typography, spacing, breakpoints, motion, z-index) are defined in architecture.md; no raw values (hex colors, px sizes) used in feature Interaction Design sections — all visual references use token semantic names |
| State machine integrity | Every Interaction State Machine has no dead states (every state has at least one exit); every transition specifies system feedback; loading states have both success and error exits |
| Frontend stack consistency | (Skip if no user-facing interface) Every user-facing feature's Interaction Design uses patterns compatible with Phase 3 Frontend Stack choices — state machines align with chosen state management library, form specifications use chosen form library conventions, component contracts use chosen framework conventions |
| Component contract consistency | Every component referenced in a feature's Interaction Design section has a Component Contract with props, events, and slots defined; event names follow a consistent convention across features; for features sharing a screen, component nesting and slot-filling rules are explicit |
| Cross-feature event flow | For features with Dependencies: event names in state machine side effects match event names consumed by dependent features' state machines; event payloads (from Component Contract Events) match consumer expectations; integration acceptance criteria (Testability f) reference exact event names |
| Accessibility baseline completeness | (Skip if no user-facing interface) architecture.md Accessibility Baseline section is present and complete (WCAG target level, keyboard navigation policy, screen reader support, focus management, color contrast, reduced motion, touch targets, error identification); per-feature Accessibility sub-sections reference or extend the baseline |
| Accessibility per-feature | Every user-facing feature has an Accessibility sub-section; keyboard navigation covers all interactive elements; ARIA roles are specified for dynamic content; focus management is defined for all modals, drawers, and overlays |
| i18n baseline completeness | (Skip if no user-facing interface) architecture.md Internationalization Baseline section is present and complete (supported languages, default language, RTL support, text externalization convention, key naming convention, date/time format, number format, pluralization rules, content direction); per-feature i18n sub-sections reference or extend the baseline |
| i18n per-feature | Every user-facing feature has an Internationalization sub-section; all user-visible text has an i18n key (no hardcoded strings in component contracts or form specs); format rules are defined for dates, numbers, and plurals |
| Navigation consistency | Every Screen/View in journey touchpoints has a route in architecture.md Navigation Architecture; route params match feature requirements; breadcrumb strategy is defined |
| Page transition completeness | Every journey with multi-step flows has a Page Transitions table with transition type (navigate push/replace, modal, drawer, back), data prefetch strategy, and notes; transition types are consistent with the corresponding feature's state machines |
| Prototype-spec alignment | (Skip if no prototypes) Every prototype screenshot corresponds to a state defined in the feature's Interaction State Machine; no undocumented states visible in prototypes |
| Prototype feedback incorporation | (Skip if no prototypes) Every prototype has evidence of user validation (confirmation date in Prototype Reference); feedback has been categorized (spec change / token change / prototype-only) and incorporated — spec changes reflected in feature files, token changes reflected in architecture.md |
| Prototype archival completeness | (Skip if no prototypes) Prototype source code exists in `{prd-dir}/prototypes/src/`; key state screenshots exist in `{prd-dir}/prototypes/screenshots/`; every user-facing feature's Prototype Reference section has path and confirmation date filled |
| Responsive coverage | Every user-facing feature has a Responsive Behavior sub-section; layout changes are described for at least mobile (< sm) and desktop (>= lg) breakpoints |
| Scope boundary | PRD does not contain implementation-level details that belong in system-design (no middleware implementations, no database schemas, no library configurations, no code-splitting strategies); PRD interaction design uses design token semantic names, not implementation-specific values (no CSS class names, no Tailwind utilities) |
| Notifications | Every feature that triggers user notifications has a Notifications section with channel, recipient, content summary, and user control; features without notifications correctly omit it |
| No ambiguity | No TBD/TODO/vague descriptions remaining |
| Version integrity | If Revision History exists: every Previous Version path resolves to an actual directory; Summary of Changes is present for each entry. If sibling directories with the same product slug exist in the parent directory: this version's Revision History accounts for them (links to predecessor, or is itself the first version). Skip this dimension during the main process step 6 (self-review of initial creation) — it only applies to `--review` mode and `--revise` post-change review (Revise Step 6) |

### Questioning (one at a time, prefer multiple choice)

**Phase 1 — Vision & Context:** problem, vision, success metrics (with baseline + how to measure), competitive landscape (see below), evidence base (see below)
**Phase 2 — Users & Journeys:** personas, then deep-dive each persona's journeys (see below), then identify cross-journey patterns (see below)
**Phase 3 — Frontend Foundation:** (skip if no user-facing interface) frontend tech stack confirmation, design token system, navigation architecture (see below)
**Phase 4 — Features & Interaction Design:** extract user stories from journey touchpoints (see below), derive features from stories, MVP boundary, inputs/outputs, edge cases (see granularity guide below), interaction design for user-facing features (see Interaction Design guide below)
**Phase 5 — Interactive Prototype:** (skip if no user-facing features) generate prototypes per feature, user validates in browser, feedback loops, archive (see below)
**Phase 6 — Technical:** platform, backend tech stack, integrations, data/auth requirements, shared conventions (see below), deployment architecture, observability
**Phase 7 — NFRs & Priority:** performance (including frontend Core Web Vitals), security, scalability, then prioritize using framework below
**Phase 8 — Risks:** technical risks, dependency risks, data/security risks, mitigation strategies

#### Phase 1 Deep-Dive: Competitive Landscape

Understand the market context before defining features. For each major competitor or alternative (including "do nothing"):

1. **Identify alternatives** — what do users currently use to solve this problem? (competitors, manual workarounds, internal tools)
2. **For each alternative:**
   - How does it solve the problem?
   - What does it do well? What are its weaknesses?
   - What's the switching cost for users?
3. **Our differentiation** — what will we do differently or better? Why will users choose us?
4. **Table stakes** — which features are baseline expectations (users won't adopt without them)?

Omit for purely internal tools with no external alternatives. Keep it brief — 1 paragraph per competitor, not a full market research report.

#### Phase 1 Deep-Dive: Evidence Base

Capture the evidence behind product decisions. For each major claim or priority:

1. **What evidence do we have?** Ask the user:
   - User interviews or usability studies?
   - Analytics data (funnel metrics, usage patterns, error rates)?
   - Customer feedback (support tickets, NPS comments, feature requests)?
   - Market research or industry trends?
   - Founder/team intuition (legitimate, but label it explicitly)?
2. **Record the source** — each major decision should trace to an evidence type. This isn't bureaucracy — it lets future team members understand why decisions were made and know when to revisit them.
3. **Flag assumption-heavy areas** — if a major feature is based primarily on intuition without user data, note it as a validation risk in Phase 6.

#### Phase 2 Deep-Dive: User Journeys

User journeys are the bridge between "who the users are" and "what features to build". Spend adequate time here — rushing past journeys leads to orphan features and missed scenarios.

For **each persona**, explore:

1. **Journey inventory** — what are the key journeys this persona takes? (use the checklist in `journey-template.md`: first-time use, core happy path, core unhappy path, return visit, power user, admin, migration)
2. **For each journey:**
   - **Trigger** — what event or need initiates this journey?
   - **Goal** — what is the user trying to accomplish?
   - **Steps** — walk through the journey step by step: what does the user do, what does the system respond?
   - **Alternative paths** — where might the user diverge from the happy path? Why?
   - **Error & recovery paths** — what can go wrong? How does the user recover?
   - **Pain points** — where is there friction, confusion, or frustration?
   - **Emotional arc** — where is the user confident vs. anxious vs. delighted?
3. **Cross-journey patterns** — after all persona journeys are mapped, identify patterns across journeys:
   - **Shared pain points** — the same frustration appears in multiple journeys (implies a high-value feature)
   - **Repeated touchpoints** — different journeys pass through the same screen/action (implies a shared component or hub)
   - **Handoff points** — where one persona's journey output becomes another persona's input (implies integration needs)
   - **Shared infrastructure needs** — multiple journeys require the same system capability (e.g. search, notification, progress tracking)
   - Record these in README.md's Cross-Journey Patterns section — they directly inform feature derivation in Phase 3
4. **Journey metrics** — how do we measure journey success? (completion rate, time to complete, drop-off points)

#### Phase 3: Frontend Foundation

Skip this phase entirely if the product has no user-facing interface (pure API, background service, CLI without TUI). Products with Terminal UI (TUI) enter this phase with reduced scope (see TUI Handling below).

**Step 3.1 — Frontend Tech Stack Confirmation**

Ask the user to confirm (one question at a time, multiple choice):

1. **UI framework:** React / Vue / Svelte / Solid / Angular / Other (specify)
2. **CSS approach:** Tailwind CSS / UnoCSS / CSS Modules / Styled Components / Vanilla CSS / Other
3. **Component library:** Shadcn/ui / Radix UI / Ant Design / Material UI / PrimeVue / Headless UI / None (custom) / Other
4. **State management:** React Context / Redux / Zustand / Pinia / Jotai / Signals / None (component-local) / Other
5. **Build tool:** Vite / Next.js / Nuxt / SvelteKit / Webpack / Other
6. **Form management:** React Hook Form / Formik / VeeValidate / Native / Other
7. **i18n library:** react-i18next / vue-i18n / Paraglide / Custom / Other

Record selections in architecture.md's Frontend Stack section.

**Step 3.2 — Design Token System**

Define the visual design foundation. Present sensible defaults based on the selected component library (e.g. if Shadcn is chosen, propose its default token values), let user adjust.

- If using an existing component library (Shadcn, Ant Design, etc.), extract its default tokens as the baseline; user confirms or overrides
- If building custom, propose a sensible default set (inspired by Tailwind defaults) and iterate
- Tokens must be expressed in the structured format defined in architecture-template.md (tables with Token / Value / Usage columns) that AI agents can parse into code
- Every token must have a semantic name — AI agents reference `color.primary.500`, not `#3b82f6`

Record in architecture.md's Design Token System section.

**Step 3.3 — Navigation Architecture & Information Architecture**

Define the product's navigation structure based on journey touchpoints:

1. **Site map** — Mermaid diagram showing page hierarchy derived from journey Screen/View names
2. **Navigation layers** — Global (always visible), Section (within a section), Contextual (inline)
3. **Route structure** — URL pattern definitions for each Screen/View (view, route pattern, params, query params, auth, layout)
4. **Breadcrumb strategy** — auto-generated from route hierarchy / manual / none
5. **Deep linking** — which views support direct URL access with state restoration

Record in architecture.md's Navigation Architecture section.

**Step 3.4 — Accessibility Baseline**

Confirm the WCAG target level and baseline requirements. Record in architecture.md's Accessibility Baseline section.

**Step 3.5 — Internationalization Baseline**

Confirm supported languages, default language, RTL requirements, text externalization convention. Record in architecture.md's Internationalization Baseline section.

**TUI Handling:** Products with Terminal UI (TUI) enter Phase 3 with reduced scope:
- **Tech stack:** TUI framework (e.g. Ink, Bubbletea, blessed) replaces web framework. Skip CSS approach, web component library, i18n library (unless TUI is multilingual)
- **Design tokens:** Reduced set — colors (terminal palette: 16/256/truecolor), typography (monospace only, no font size scale), spacing (character-based). Skip breakpoints, shadows, border-radius
- **Navigation:** Command structure / screen flow replaces URL routing. Skip breadcrumbs and deep linking
- **Accessibility:** Keyboard navigation is primary. Skip WCAG color contrast (terminal dependent), touch targets, focus indicators (terminal handles this)

#### Phase 4 Step 1: User Story Extraction & Feature Derivation

Before defining features, explicitly derive them from journey touchpoints. This step bridges "what users experience" (journeys) to "what the system provides" (features).

**Step 1 — Extract User Stories from Touchpoints:**

For each journey's Touchpoints table, extract stories in the format: "As a {persona}, I want to {action at this touchpoint}, so that {goal}." One touchpoint may yield multiple stories (e.g. a "Dashboard" touchpoint may need both "view summary" and "filter by date"). Walk through ALL touchpoints across ALL journeys.

**Step 2 — Consolidate & Deduplicate:**

Collect all extracted stories into a flat list. Merge duplicates — different journeys often share the same touchpoint (e.g. both "first-time use" and "return visit" journeys pass through the login screen). Also incorporate stories implied by cross-journey patterns from Phase 2 (shared pain points, repeated touchpoints, handoff points).

**Step 3 — Group Stories into Features:**

Group related stories by shared data model + API + UI surface. Each group becomes a candidate Feature. A Feature may serve multiple stories across different journeys and personas — this M:N mapping is expected and desirable.

**Step 4 — Verify Coverage:**

- Every journey touchpoint has at least one story → at least one Feature
- Every journey pain point has at least one story addressing it → at least one Feature
- No Feature exists without a story tracing back to a touchpoint (no orphan features)
- Cross-journey patterns are covered by at least one Feature each

Only proceed to feature detailing after this derivation is complete. The extracted User Stories become the User Stories section in each feature file.

#### Phase 4 Deep-Dive: Feature Granularity

A feature file should be **one unit of work a coding agent can implement in a single session**. Use these rules:

- **Split when:** a feature has multiple independent user stories for different personas, or involves both a complex backend + complex frontend that could be built separately, or exceeds ~XL effort
- **Merge when:** two features share the same data model, API, and UI — splitting would force the agent to context-switch between tightly coupled files
- **Rule of thumb:** if the Acceptance Criteria section has more than 8-10 items, the feature is likely too big. If it has fewer than 3, it may be too small (consider merging with a related feature)

#### Phase Completion Conditions

Move to the next phase when:

- **Phase 1 → 2:** Problem statement is clear, at least 2 measurable goals defined, scope boundary stated, competitive context captured (or explicitly N/A), evidence base documented
- **Phase 2 → 3:** Every persona has at least one journey with happy path + one error path fully walked through; every touchpoint has Interaction Mode specified; multi-step journeys have Page Transitions defined; cross-journey patterns documented in README (or explicitly N/A for single-journey products); multi-touchpoint journeys have E2E Test Scenarios covering happy, alternative, and error paths; Journey Metrics have Verification entries
- **Phase 3 → 4:** (Skip if no user-facing interface) Frontend tech stack confirmed; design tokens defined (all categories: colors, typography, spacing, breakpoints, motion, z-index); navigation architecture established (site map, routes, breadcrumbs); accessibility baseline set; i18n baseline set; all recorded in architecture.md
- **Phase 4 → 5:** Feature list covers all journey touchpoints, MVP boundary agreed, no feature exceeds XL effort without a split plan; all user-facing features have full Interaction Design section filled (component contracts, state machines, form specifications, micro-interactions & motion, a11y, i18n, responsive); edge cases use Given/When/Then format; features with dependencies have at least one cross-feature integration AC; features with non-trivial test setup have Test Data Requirements
- **Phase 5 → 6:** (Skip if no user-facing features) All user-facing features have confirmed prototypes; feedback has been incorporated into feature specs and design tokens; prototype code and screenshots are archived
- **Phase 6 → 7:** Backend tech stack decided, all external integrations identified, data model entities drafted, shared conventions (API, error handling, testing) defined, authorization model captured (or N/A), privacy requirements captured (or N/A)
- **Phase 7 → 8:** Every feature has Impact/Effort rating and P0/P1/P2 assigned, Roadmap phases mapped, frontend performance metrics included (Core Web Vitals targets for user-facing products)
- **Phase 8 → Generate:** All high-impact risks have mitigation strategies, no open questions remain

#### Phase 4 Deep-Dive: Interaction Design for User-Facing Features

For each user-facing feature (not backend-only), explore:

1. **Screen mapping** — which screen/view does this feature live on? Use the Screen/View names from journey touchpoints. The route must match Navigation Architecture
2. **Component inventory** — identify the UI components needed. For each component, define its contract: Props (inputs), Events (outputs), Slots/Children (composition points). Express as a TypeScript-style interface or structured table
3. **Interaction state machine** — for each component with non-trivial state, define states and transitions using Mermaid stateDiagram. Every state must have at least one exit. States must include: idle, loading, success, error, and any domain-specific states
4. **Form specification** — for features with forms: field definitions (name, type, validation rules, error messages, conditional visibility, dependencies between fields)
5. **Micro-interactions & motion** — for key interactions, specify: trigger, animation type, duration token, easing token, purpose
6. **Accessibility requirements** — WCAG level (or "baseline per architecture.md"), keyboard navigation flow (tab order, shortcuts), ARIA roles and labels, focus management (modal open/close, form submit, inline errors), screen reader announcements for dynamic content
7. **Internationalization requirements** — supported languages (from architecture.md), text externalization keys with prefix `{feature-slug}.`, RTL support, date/time/number format rules, pluralization
8. **Responsive behavior** — reference breakpoint tokens, describe layout changes per breakpoint with specific details (not just "responsive")

**Rules:**
- Define interaction design at the **design token level** — describe structure, behavior, state machines, component contracts, and visual semantics using design token references. Raw visual values (hex colors, px sizes) belong in architecture.md's Design Token System; feature specs reference tokens by semantic name
- **Component contracts are the frontend equivalent of API contracts** — they define the interface that AI agents code against
- State machines must be complete: every user-perceivable state is listed, every transition is explicit
- Accessibility and i18n are NOT optional sections — they are mandatory for every user-facing feature. If a feature has no special a11y needs beyond baseline, state "follows baseline WCAG 2.1 AA from architecture.md"
- Design tokens are referenced by semantic name (e.g. `color.error.500`, `spacing.4`, `motion.duration.fast`), never by raw value
- The Screen/View name in the feature file must match the journey touchpoint's Screen/View column exactly
- If multiple features share the same screen, note which area/section each feature controls

#### Phase 4 Deep-Dive: Notification & Communication

For features that notify users (email, push, in-app, SMS), capture at the product level:

1. **Notification inventory** — which features trigger notifications? What events cause them?
2. **Channel** — how is the user notified? (email / push / in-app / SMS / multiple)
3. **Content summary** — what does the notification say? (not exact copy, but purpose and key info)
4. **User control** — can the user opt out or configure frequency?

Record these in the feature's Notifications section. Omit if the product has no notifications.

#### Phase 5: Interactive Prototype

Skip if the product has no user-facing features. After feature interaction design (Phase 4) is complete, generate interactive prototypes for user validation.

**Step 5.1 — Prototype Generation**

For each user-facing feature (or group of related features sharing a screen):

1. Generate a runnable prototype using the confirmed tech stack (Phase 3)
2. Prototype requirements:
   - Implement the component contracts from the feature's Interaction Design section
   - Apply design tokens (real CSS custom properties / theme values)
   - Implement state machines (all states must be reachable)
   - Include semantic HTML and ARIA attributes (from a11y requirements)
   - Externalize text strings (from i18n requirements) — at minimum, use a key-value structure even if only one language
   - Follow the navigation architecture (routes, breadcrumbs)
   - Be self-contained and runnable (single `npm install && npm run dev` or equivalent)
3. Prototype code quality requirements (prototype is seed code for production):
   - Components match the component tree defined in the feature spec
   - State management follows the chosen approach from Phase 3
   - File structure follows framework conventions
   - No inline styles — use design tokens through the CSS approach chosen
   - No hardcoded strings — use i18n keys

**Step 5.2 — User Validation**

Present the prototype to the user for feedback:

1. Open prototype in browser (via Playwright or local dev server)
2. Walk through each feature's state machine — user verifies each state looks and behaves as expected
3. Collect feedback per category:
   - **Spec change** — the feature's Interaction Design section needs updating (update the feature file)
   - **Token change** — design tokens need adjustment (update architecture.md design tokens)
   - **Prototype-only fix** — implementation detail, doesn't affect spec (fix in prototype code only)

**Step 5.3 — Archive**

After user confirms the prototype:

1. Take screenshots of key states (save to `{prd-dir}/prototypes/screenshots/`)
2. Store prototype source code in `{prd-dir}/prototypes/src/`
3. Record prototype metadata in each feature file's Prototype Reference section

#### Phase 6 Deep-Dive: Authorization & Permissions

After personas are defined, explicitly ask about access control:

1. **Role inventory** — what distinct roles exist? (often maps 1:1 to personas, but not always — e.g. "Admin" persona may have super-admin and org-admin sub-roles)
2. **Permission matrix** — for each feature, which roles can access it? (full access / read-only / no access)
3. **Data visibility** — can all roles see all data, or is data scoped? (e.g. "users see only their own tasks, admins see all")
4. **Escalation** — who can grant/revoke roles?

Record in architecture.md's Authorization Model section. Omit for single-role products.

#### Phase 6 Deep-Dive: Privacy & Compliance

Ask about data handling obligations:

1. **Regulatory requirements** — GDPR, CCPA, HIPAA, SOC 2, or other? If none, note "no specific regulatory requirements"
2. **Personal data inventory** — which data model entities contain personal or sensitive data?
3. **User rights** — must users be able to export, delete, or correct their data?
4. **Data retention** — how long is data kept? Is there an automatic deletion policy?
5. **Consent** — does the product collect data that requires explicit user consent?

Record in architecture.md's Privacy & Compliance section. Omit for internal tools with no personal data.

#### Phase 6 Deep-Dive: Shared Conventions

After tech stack is decided, explicitly ask about conventions that will be shared across all features. These feed directly into architecture.md's Shared Conventions section:

1. **API conventions** — response format (JSON?), authentication method, pagination style, versioning, rate limiting
2. **Error handling** — error response format, error code taxonomy, how to handle 4xx vs 5xx, validation error structure
3. **Testing strategy** — testing frameworks per layer (unit/integration/E2E), coverage targets, what must be tested

These are critical for AI coding agent consistency. Without them, each feature will be implemented with different conventions.

#### Phase 7 Deep-Dive: Priority Framework

Don't just ask "what's P0?" — guide the user through structured evaluation:

1. **Impact/Effort matrix** — for each feature, ask:
   - **Impact:** How many users affected? How severe is the pain without it? (High/Medium/Low)
   - **Effort:** Engineering complexity + calendar time (S/M/L/XL)
2. **Assign priority:**
   - **P0** = High impact, blocks core journey happy path — must ship in MVP
   - **P1** = High impact but has workaround, or medium impact with low effort
   - **P2** = Nice-to-have, low impact, or high effort with uncertain payoff
3. **Validate against journeys** — every P0 feature must serve a touchpoint on a core journey happy path. If a P0 feature only appears in alternative/edge paths, challenge the priority.

#### Phase 8 Deep-Dive: Risk Identification

For each risk, capture: what can go wrong, likelihood, impact, and mitigation. Focus on risks that affect **implementation decisions**:

- **Technical risks** — new/unproven tech, performance unknowns, complex integrations
- **Dependency risks** — third-party API reliability, team/skill availability, upstream deliverables
- **Data & compliance risks** — migration complexity, consistency guarantees, privacy regulation violations, data breach scenarios, consent gaps
- **Scope risks** — ambiguous requirements that could balloon during implementation
- **Validation risks** — features based primarily on assumptions without user data (flagged during Phase 1 Evidence Base)

### Document-Based Mode

Read document → summarize understanding → check gaps against list below → ask targeted questions → generate

**Gap checklist for documents** — scan for missing or vague coverage in these areas:

- [ ] Personas defined with clear goals?
- [ ] User journeys (happy path + error/alternative paths) described or inferrable?
- [ ] Cross-journey patterns identified (shared pain points, repeated touchpoints, handoff points)?
- [ ] Success metrics with measurable targets?
- [ ] Competitive context or alternatives acknowledged?
- [ ] Evidence base for key decisions (data, research, or labeled assumptions)?
- [ ] Feature boundaries clear (what's in/out of MVP)?
- [ ] Edge cases and error handling addressed?
- [ ] Interaction design described for user-facing features (component contracts, state machines, a11y, i18n)?
- [ ] Frontend tech stack specified (framework, CSS, component library, state management)?
- [ ] Design tokens defined (colors, typography, spacing, breakpoints, motion)?
- [ ] Navigation architecture described (site map, routes, breadcrumbs)?
- [ ] Component contracts defined for user-facing features (props, events, slots)?
- [ ] Interaction state machines defined for stateful UI components?
- [ ] Form specifications defined for form-having features (fields, validation, error messages, conditional logic, submission behavior)?
- [ ] Micro-interactions & motion defined for key interactions (trigger, animation, duration token, easing token, purpose)?
- [ ] Interaction Mode specified per journey touchpoint (click, form, drag, swipe, keyboard, etc.)?
- [ ] Page transitions defined for multi-step journeys (transition type, data prefetch, notes)?
- [ ] Architecture-level accessibility baseline defined (WCAG level, keyboard, focus, contrast, motion, touch targets)?
- [ ] Accessibility requirements stated per feature (WCAG level, keyboard, ARIA, focus)?
- [ ] Architecture-level i18n baseline defined (languages, default language, RTL, key convention, format rules)?
- [ ] Internationalization requirements stated per feature (languages, keys, format rules)?
- [ ] Responsive behavior described per breakpoint for user-facing features?
- [ ] Prototype feedback documented and incorporated into specs and design tokens?
- [ ] Prototype source code and screenshots archived (prototypes/src/, prototypes/screenshots/)?
- [ ] Authorization / permission model described (if multi-role)?
- [ ] Privacy / compliance requirements stated (if handling personal data)?
- [ ] Notification requirements captured (if the product notifies users)?
- [ ] Technical stack and integration points specified?
- [ ] Non-functional requirements (performance, security, i18n) stated?
- [ ] Shared conventions (API format, error handling, testing strategy) defined or inferrable?
- [ ] Risks or open questions acknowledged?
- [ ] Priority rationale (not just labels) provided?
- [ ] Edge cases testable (Given/When/Then, not vague descriptions)?
- [ ] Non-functional requirements stated per feature (not just globally)?
- [ ] Test data requirements inferrable for non-trivial features?
- [ ] E2E test scenarios inferrable from journey flows (happy + error paths)?

### Immutability Rule

Whether PRD files can be modified in place depends on their **downstream consumption state** — what has been built on top of them:

| Downstream State | Modify in Place? | Rationale |
|-----------------|-----------------|-----------|
| No design exists | Yes | No downstream consumers to break |
| Design exists, not implemented | Yes + add Revision History entry | Design team needs the change record to update design accordingly |
| Implementation exists | No — create new version | Modifying in place would invalidate implemented code |

Steps 6-7 (self-review, user review) always occur before commit and are part of the creation process — modifying files during these steps is expected regardless of downstream state.

### PRD Review Mode (`--review`)

Review an existing PRD directory for quality, completeness, and consistency. **This mode is read-only** — it reports findings but does not modify any files.

0. **Version discovery** — scan the parent directory for sibling PRD directories with the same product slug (the portion after the date prefix `YYYY-MM-DD-`). If the reviewed directory name does not match the `YYYY-MM-DD-{slug}` pattern (e.g. custom `--output` path), skip this step. If multiple versions exist: identify which version is being reviewed, which is latest (by date prefix), and whether the Revision History in each version forms a consistent chain (each newer version links back to its predecessor). Record this context for subsequent steps.
1. **Read all files** — README.md, journeys/*.md, architecture.md, features/*.md
2. **Run Review Checklist** — check every dimension (including Version integrity), collect findings
3. **Present findings** — if multiple versions were discovered in step 0, lead with a version context block before the findings table:
   ```
   Version context:
     Reviewing: {path of reviewed directory} ({position, e.g. v1 of 2})
     Latest:    {path of latest directory}
     Chain:     {whether Revision History links form a consistent chain}
     ⚠ You are reviewing an older version.       ← only if not latest
   ```
   Then present the structured table of issues with severity (Critical / Important / Suggestion).
4. **Recommend next step:**
   - If issues are minor (wording, missing cross-links): note them for the next revision
   - If issues are significant (missing journeys, orphan features, gaps): recommend `--revise` to address the issues
   - If reviewing an older version: note that the latest version should be reviewed instead, unless the user explicitly requested this version

### PRD Revise Mode (`--revise`)

Interactively modify an existing PRD — whether it's still a draft or already finalized. Auto-detects PRD state, confirms intent with the user, then guides a structured change process with impact analysis and conflict detection.

#### Revise Step 1 — Detect Downstream State & Confirm Intent

Auto-detect what has been built on top of this PRD, then confirm with the user.

**Auto-detection:**

1. **Check for design:** scan for a system-design directory whose `Design Input > Source` references this PRD path
2. **Check for implementation:** if a design exists, read its `Design Input > Status` field — `Implementing` or `Implemented` means code exists

**Ask user to confirm detected state:**

> I detected the following downstream state for this PRD:
> - Design: {found at path / not found}
> - Implementation: {Status field value / N/A}
>
> Is this correct? If not, what's the actual state?

**Resolve action based on confirmed state:**

| Downstream State | Action |
|-----------------|--------|
| No design exists | Modify PRD files directly |
| Design exists, not implemented | Modify PRD files directly + add Revision History entry describing what changed (so design can be updated accordingly) |
| Implementation exists (Status = Implementing or Implemented) | Create new PRD version (new dated directory); original untouched |

If the user disagrees with the auto-detection (e.g. "the design exists but is outdated and will be regenerated"), defer to user judgment.

#### Revise Step 2 — Present PRD Overview

Read and summarize the current PRD so the user has context before describing changes:

- Product name and vision
- Personas and journey count
- Feature count by priority (P0/P1/P2) and roadmap phase
- Key risks and open items (if any)

#### Revise Step 3 — Gather Changes (interactive, one at a time)

Ask the user to select change types (multiple allowed):

1. **Add requirement** — new feature, new journey, or new persona
2. **Modify requirement** — change existing feature behavior, scope, priority, or acceptance criteria
3. **Deprecate requirement** — remove a feature or journey that's no longer needed
4. **Environment change** — external shift (tech stack, competitor, regulation, user feedback) that affects existing requirements

Then deep-dive each selected type:

**Add requirement:**
- What persona does this serve? (existing or new?)
- What journey does it belong to? (existing or new?)
- What touchpoint / pain point does it address?
- What's the expected priority (P0/P1/P2)?
- Does it depend on any existing features?
- Does any existing feature need to change to accommodate this?

**Modify requirement:**
- Which feature(s) / journey(s)?
- What specifically changes? (behavior, scope, priority, acceptance criteria, interaction design)
- Why the change? (new evidence, user feedback, technical constraint, scope adjustment)
- Is the change additive (extending behavior) or breaking (changing existing behavior)?

**Deprecate requirement:**
- Which feature(s) / journey(s)?
- Why? (no longer needed, superseded by another feature, too expensive, invalidated by evidence)
- What replaces it, if anything?

**Environment change:**
- What changed externally? (tech stack shift, new competitor, regulatory change, user research findings)
- Which existing features / journeys are affected?
- Does this change priorities?
- Are new features needed in response?

#### Revise Step 4 — Impact Analysis & Conflict Detection

After gathering all changes, systematically trace their impact through the PRD.

**Impact propagation** — for each changed/added/deprecated item (feature, journey, or persona):

| Check | How |
|-------|-----|
| Journey impact | Which journeys reference the affected feature(s)? Do touchpoints need updating? If a journey itself changed, which features map to its touchpoints? |
| Dependency chain | Which features depend on the affected item? Which features does it depend on? |
| Cross-journey patterns | Does this change affect any documented cross-journey pattern? If a journey is added/removed, do patterns need re-evaluation? |
| Metrics impact | Does the affected item feed a Goal metric? Will removing/changing it leave a metric unmeasured? |
| Roadmap impact | Does this change affect phase ordering? Do dependencies still respect phase boundaries? |
| Risk impact | Does this change introduce new risks or invalidate existing mitigations? |
| Test impact | Which Acceptance Criteria, Edge Cases, and E2E Test Scenarios are invalidated or need updating? Which dependent Features' test cases need regression re-verification? List affected items by Feature/Journey ID |
| Design token impact | Does the change affect design tokens in architecture.md? If so, ALL features referencing those tokens are impacted — check every user-facing feature's Interaction Design section |
| Navigation impact | Does the change add/remove/rename screens? If so, architecture.md Navigation Architecture (site map, routes) and all affected features' Screen & Layout sub-sections need updating |
| Component contract impact | Does the change modify a shared component's contract? If so, check which features use that component and whether their state machines and interactions are still valid |
| Accessibility baseline impact | Does the change affect architecture.md's Accessibility Baseline? If so, every user-facing feature's Accessibility sub-section that references the baseline may need updating |
| i18n baseline impact | Does the change affect architecture.md's Internationalization Baseline? If so, every user-facing feature's i18n sub-section and i18n key prefixes may need updating |
| Form specification impact | Does the change affect a feature's Form Specification (fields, validation, dependencies)? If so, check if the feature's state machine, acceptance criteria, and E2E Test Scenarios still cover the updated form behavior |
| Micro-interaction & motion impact | Does the change introduce, remove, or modify UI interactions? If so, check affected features' Micro-Interactions & Motion sub-sections for consistency with updated state machines and component contracts |
| Interaction mode impact | Does the change modify a journey's touchpoints or interaction patterns? If so, check that the Interaction Mode column is updated and that corresponding feature component contracts support the changed interaction mode |
| Prototype impact | Does the change invalidate existing prototypes? Mark affected prototypes as needing regeneration in the feature's Prototype Reference section; update archival (screenshots and source) after regeneration |

**Conflict detection** — check for these types:

| Conflict Type | What to Check |
|---------------|---------------|
| Dependency conflict | New feature depends on a deprecated feature; modifying a feature breaks a dependent feature's assumptions |
| Priority conflict | A P0 depends on a P1/P2 (phase ordering violation); a new P0 isn't on any core journey happy path |
| Behavior conflict | New requirement contradicts an existing requirement (e.g. "data is public by default" vs. "data is private by default") |
| Scope conflict | Changes push total effort beyond stated MVP boundary without re-scoping |
| Coverage gap | Deprecating a feature leaves a journey touchpoint or pain point with no feature coverage |
| Metric orphan | Removing a feature that was the sole measurement point for a Goal metric |

Present findings to the user before proceeding:
- **Conflicts** — must be resolved before continuing (ask user how to resolve each one)
- **Impacts** — changes that propagate to other files, user confirms awareness
- **Warnings** — potential issues that don't block but should be acknowledged

#### Revise Step 5 — Execute Changes

Based on the downstream state confirmed in Step 1:

**Modify directly (no design, or design exists but not implemented):**
- Update affected files in place
- If design exists: add Revision History entry in README.md summarizing what changed and why — this record helps the design update process (`/system-design --revise`) identify what PRD changes need to propagate

**Create new version (implementation exists):**
- Create new dated directory (e.g. `docs/raw/prd/YYYY-MM-DD-{product-name}/`)
- Copy forward unchanged files
- Apply changes to affected files
- Add Revision History entry linking back to previous version

In both cases:
- Update all cross-references (journey Mapped Feature columns, feature Dependencies, Cross-Journey Patterns "Addressed by Feature" column)
- Mark deprecated features clearly — remove the feature file and remove it from Feature Index, Roadmap, and any Mapped Feature references
- Re-derive affected User Stories if journey touchpoints changed (re-run Phase 3 Step 1 extraction for affected journeys only)

#### Revise Step 6 — Post-Change Review

Run the full Review Checklist on the modified/new PRD, with special attention to:
- Traceability chain integrity after changes
- No orphan features (especially after deprecation)
- No uncovered touchpoints or pain points (especially after deprecation)
- Dependency ordering still valid after priority changes
- Cross-journey patterns still accurate
- All conflicts from Step 4 resolved
- Interaction Design sections consistent with any changed journeys (interaction modes, page transitions, state machines)
- Architecture-level baselines (a11y, i18n, design tokens) still consistent with per-feature sections after changes
- Prototype archival up to date (no stale screenshots or source for changed features)

Then proceed to user review → commit (same as initial creation flow steps 7-8).

**Commit message format:** describe the revision, e.g. "Revise PRD: add F-014 SSO, deprecate F-005, reprioritize F-008 to P0"

## Output Structure

```
{output-dir}/YYYY-MM-DD-{product-name}/
├── README.md           # Product overview + journey index + feature index + roadmap
├── journeys/
│   ├── J-001-{slug}.md # Individual journey spec
│   └── ...
├── architecture.md     # Architecture, tech stack, design tokens, nav, a11y, i18n, data model, NFRs
├── features/
│   ├── F-001-{slug}.md # Self-contained feature spec
│   └── ...
├── prototypes/         # Interactive prototypes (seed code for production)
│   ├── src/            # Runnable prototype source
│   └── screenshots/    # Key state screenshots per feature
```

Use templates: `prd-template.md` (README), `journey-template.md` (individual journeys), `architecture-template.md` (architecture), and `feature-template.md` (feature specs).

**Agent consumption:** read README.md (~concise overview) → read one feature file → implement. Each feature file copies all needed context inline (data models, conventions, journey context), so the feature file alone is sufficient for implementation.

## Output Path

- **Default:** `docs/raw/prd/YYYY-MM-DD-{product-name}/`
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing

## Key Principles

- **One question at a time** — don't overwhelm
- **MVP ruthlessly** — push back on scope creep
- **Minimal context** — agents read one small file, not a giant document
- **Copy, don't reference** — feature files include relevant data models, conventions, and journey context inline
- **No ambiguity** — if a requirement can be interpreted two ways, clarify now
- **Omit empty sections** — if a section has nothing useful, skip it

## Next Steps Hint

After committing, print the following guidance to the user:

```
PRD complete: {output path}

Next steps:
  Interactive — /system-design {output path}
  Automated  — claude -p "generate system design based on {output path}" --auto
```
