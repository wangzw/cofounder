# Feature Spec Template

Each file is **self-contained** — a coding agent implements the feature by reading only this file.

## Template

The feature file follows this structure. Omit any section that has no useful content.

### Header

```
# F-{001}: {Feature Name}

> **Priority:** P0 | P1 | P2  **Effort:** S | M | L | XL
```

### Context

**Product:** {one sentence describing the product this feature belongs to}

**Relevant architecture:** {only the parts of the architecture this feature touches — 3–5 lines. Copy inline from architecture topic files; do not reference them by path}

**Relevant data models:** {copy entity definitions this feature reads or writes — field names, types, constraints. A coding agent implementing this feature must not need to open a second file to understand the data shape}

**Relevant conventions:** copy applicable convention text from architecture topic files inline — do not reference the files by path. **Copy applicable text inline. Do not write "see \<file\>" — the file paths below identify source documents only.**

- *Coding conventions* (error handling, logging, concurrency policies relevant to this feature) — copy applicable text inline; source: `architecture/coding-conventions.md`
- *Test isolation* (resource isolation, parallel safety rules relevant to this feature's tests) — copy applicable text inline; source: `architecture/test-isolation.md`
- *Security* (input validation, secret handling relevant to this feature) — copy applicable text inline; source: `architecture/security.md`
- *Shared conventions* (API format, error structure) — copy applicable text inline; source: `architecture/shared-conventions.md`
- *Code review policy* (review dimensions applicable to this feature) — when applicable
- *Performance testing* (budgets applicable to this feature) — when applicable
- *Backward compatibility* (API versioning, schema evolution relevant to this feature's API contracts or data models) — when applicable
- *Observability requirements* (mandatory logging events, health checks, metrics) — when applicable
- *AI agent configuration* (instruction file references, maintenance triggers) — when applicable

Omit conventions this feature does not touch (e.g. no API conventions for a pure background-job feature; no concurrency policy for a stateless utility; no backward compatibility for internal-only features with no API).

**Permission:** {which roles can access this feature and at what level — e.g. "Admin: full, Member: read-only, Viewer: no access". Copy from the Authorization Model in architecture. Omit for single-role products or features with no access restrictions}

### User Stories

- As a {persona}, I want to {action}, so that {outcome}.
- As a {persona}, I want to {action}, so that {outcome}.

### Journey Context

Copy the relevant journey context inline. Do not rely on a link being load-bearing.

- **Journey:** J-{NNN}: {journey name} — Touchpoints #{touchpoint numbers} — Pain points: {which pain points this feature resolves}
- **Touchpoint detail** (copy from journey file):

  | # | Stage | User Action | System Response | Screen/View | Interaction Mode | Emotion | Pain Point | Mapped Feature |
  |---|-------|-------------|----------------|------------|-----------------|---------|------------|---------------|
  | {#} | {stage} | {user action} | {response} | {screen} | {mode} | {emotion} | {pain point if any} | F-{NNN} |

- **Journey:** J-{NNN}: {journey name} — Touchpoints #{touchpoint numbers} — Pain points: {which pain points resolved}

  *(Repeat touchpoint table for each journey this feature appears in)*

### Requirements

1. {precise, unambiguous requirement — use "must", "returns", "rejects", not "should" or "might"}
2. ...

### Acceptance Criteria

Behavioral (Given/When/Then):
- Given {precondition}, when {action}, then {result}
- Given {precondition}, when {edge case}, then {result}

{If this feature has dependencies (depends-on), include at least one cross-feature integration criterion. Fill this after completing the Dependencies section, or leave a `[TODO: add integration criterion for F-{dep}]` placeholder and backfill in cross-linking:}
- Given {upstream feature} has {completed its action / produced its output}, when {this feature consumes it}, then {end-to-end observable result}

Non-behavioral (include applicable dimensions, omit the rest):
- **Performance:** {e.g. "Response time must be < 200ms at p95 for N concurrent users"}
- **Resource limits:** {e.g. "Memory usage must stay < 512MB for datasets up to 10k records"}
- **Concurrency:** {e.g. "Must handle 3 simultaneous agents writing to the same store without data loss"}
- **Security / permissions:** {e.g. "Viewer role receives 403 when attempting write operations"}
- **Degradation:** {e.g. "Must function with GitHub API unavailable, using cached data"}

### API Contract

{Only if this feature exposes or consumes APIs. Omit for pure UI or background-job features.}

**`{METHOD} {/path}`**

Request:
```json
{
  "field": "type — description"
}
```

Response (success — {status code}):
```json
{
  "field": "type — description"
}
```

Response (error — {status code}):
```json
{
  "error": "string — error code",
  "message": "string — human-readable description",
  "details": "object | null — per shared conventions error format"
}
```

{Repeat for each endpoint this feature introduces.}

### Interaction Design

{Required for user-facing features (web UI, mobile, desktop, CLI with TUI). Omit only for backend-only features (background jobs, pure API, CLI without TUI, infrastructure).}

#### Screen & Layout

**Screen/View:** {which screen(s) this feature appears on — must match Screen/View names from the Journey Context touchpoint table above}
**Route:** {Web: URL pattern from architecture navigation — must match Route Definitions table. TUI: command/screen identifier from architecture Command Structure, or omit if screen is implicit}
**Layout:** {describe the visual structure using design token references — e.g. "two-column layout, sidebar width `spacing.16`, main content area with `spacing.6` padding, cards with `radius.lg` and `shadow.md`"}

**Design Tokens (inline copy):**

Copy the applicable token definitions from `architecture/design-tokens.md` (or equivalent) inline below. Do not reference the file by path — a coding agent must be able to read only this feature file.

| Token | Value | Purpose |
|-------|-------|---------|
| {token.name} | {value} | {semantic meaning for this feature} |

#### Component Contracts

{For each non-trivial UI component in this feature, define the interface that AI agents code against. Simple leaf components (a button, a label) do not need full contracts — only components with meaningful props, events, or composition points.}

**{ComponentName}**

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| {name} | {type} | Y/N | {value} | {what it controls} |

| Event | Payload | Description |
|-------|---------|-------------|
| {name} | {type} | {when emitted and by what user action} |

| Slot/Children | Purpose | Default Content |
|---------------|---------|-----------------|
| {name} | {what goes here} | {fallback if empty} |

{Repeat for each component.}

#### Interaction State Machine

{For each component with non-trivial state transitions. Use Mermaid stateDiagram.}

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading: {trigger}
    Loading --> Success: {condition}
    Loading --> Error: {condition}
    Error --> Loading: {retry trigger}
    Success --> Idle: {reset trigger}
    Error --> Idle: {dismiss trigger}
```

| From | Event | To | System Feedback | Side Effects |
|------|-------|----|-----------------|-------------|
| {state} | {user action or system event} | {state} | {what the user sees — e.g. spinner, toast, banner} | {API calls, cache invalidation, analytics events} |

**Rules:**
- Every state must have at least one exit (no dead states)
- Every transition must specify system feedback (what the user sees)
- Loading states must have both success AND error exits

#### Form Specification

{Only for features with forms. Omit otherwise.}

| Field | Type | Label (i18n key) | Validation | Error Message (i18n key) | Depends On | Conditional |
|-------|------|-------------------|------------|--------------------------|------------|-------------|
| {name} | text / email / select / checkbox / ... | {feature}.{field}.label | {e.g. required, minLength(3), maxLength(100)} | {feature}.{field}.error.{rule} | {other field name, or —} | {shown when {field} = {value}, or —} |

**Submission behavior:**
- Validation timing: {on blur / on submit / on change after first submit}
- Submit button state: {disabled until valid / always enabled, validate on click}
- Success action: {redirect to {route} / show success state / close modal}
- Error action: {show inline errors / show error banner / show toast}

#### Micro-Interactions & Motion

{Key animations and transitions that provide user feedback. Omit for features with no meaningful motion. All durations and easings MUST use token names — raw millisecond values and raw cubic-bezier expressions are forbidden.}

| Trigger | Element | Animation | Duration Token | Easing Token | Purpose |
|---------|---------|-----------|---------------|-------------|---------|
| {e.g. page enter} | {e.g. main content} | {e.g. fade in + slide up 8px} | motion.duration.normal | motion.easing.out | {e.g. smooth entry} |

#### Accessibility

**WCAG Level:** {2.1 AA / 2.1 AAA — or "baseline per architecture accessibility policy"}

**Keyboard Navigation:**

| Action | Key | Behavior |
|--------|-----|----------|
| {e.g. navigate list} | {e.g. Arrow Up/Down} | {e.g. moves focus between items} |
| {e.g. submit form} | {e.g. Enter} | {e.g. submits if focused on form} |
| {e.g. close modal} | {e.g. Escape} | {e.g. closes modal, returns focus to trigger} |

**ARIA:**

| Element | Role | Label/Description | Live Region |
|---------|------|-------------------|-------------|
| {e.g. search results} | {e.g. region} | {e.g. aria-label="{i18n key}"} | {e.g. polite — announces count changes} |
| {e.g. error message} | {e.g. alert} | — | {e.g. assertive} |

**Focus Management:**
- After modal open: focus moves to {first focusable element / close button}
- After modal close: focus returns to {trigger element}
- After form submit success: focus moves to {success message / next logical element}
- After inline error: focus moves to {first invalid field}

#### Internationalization (Frontend)

{For user-facing features. Omit for backend-only features.}

**Supported Languages:** {from architecture i18n baseline — e.g. en, zh-CN, ja}
**RTL Support:** {yes / no}
**Text Keys:** (prefix: `{feature-slug}.`)

| Key | Default (en) | Context |
|-----|-------------|---------|
| {feature}.title | {text} | {page/section title} |
| {feature}.submit_button | {text} | {CTA button} |
| {feature}.error.required | {text} | {validation error} |

**Format Rules:**

| Data Type | Format | Library/Method |
|-----------|--------|---------------|
| Date | {e.g. locale-aware, relative for < 7 days} | {e.g. date-fns/format with locale} |
| Number | {e.g. locale-aware thousand separator} | {e.g. Intl.NumberFormat} |
| Currency | {e.g. symbol + locale formatting} | {e.g. Intl.NumberFormat with currency} |
| Pluralization | {e.g. ICU MessageFormat} | {per i18n library} |

#### Internationalization (Backend)

{For backend features that return user-visible text (API errors, validation messages, notifications, emails). Omit for single-language backends or features with no locale-dependent output.}

**Locale Resolution:** {from architecture i18n baseline — e.g. Accept-Language header → user preference → default}

**Locale-Dependent Messages:**

| Message / Response | Localized? | How Locale Is Determined | Notes |
|--------------------|-----------|------------------------|-------|
| {e.g. API validation errors} | {yes / no — error codes only} | {e.g. Accept-Language header} | {e.g. client formats from code} |
| {e.g. email notification body} | {yes / no} | {e.g. recipient user preference} | {e.g. template per locale} |

**Timezone Handling:** {from architecture i18n baseline — e.g. store UTC, convert per user timezone on API output}

#### Responsive Behavior

**Web** — Reference breakpoint tokens from architecture Design Token System (copied inline in the Design Tokens table above).

| Breakpoint | Layout Change | Component Change |
|------------|--------------|-----------------|
| < sm (mobile) | {e.g. single column, full-width cards} | {e.g. hamburger menu replaces sidebar} |
| sm – md (tablet) | {e.g. two-column, collapsible sidebar} | {e.g. sidebar as overlay} |
| >= lg (desktop) | {e.g. three-column, fixed sidebar} | {e.g. full sidebar visible} |

**TUI** — Reference terminal size tokens from architecture Design Token System (copied inline above). Replace the web breakpoint table with:

| Terminal Width | Layout Change | Component Change |
|---------------|--------------|-----------------|
| < {breakpoint.sidebar.collapse} | {e.g. sidebar hidden, content full-width} | {e.g. Ctrl+B toggles sidebar} |
| >= {breakpoint.sidebar.collapse} | {e.g. sidebar visible at fixed width} | {e.g. sidebar always shown} |

#### Frontend Draft Reference

{Populated after Phase 5 (Frontend Draft) completes. Omit during initial feature writing. Must be filled for every user-facing feature after the draft is confirmed.}

In the AI-coding era, frontend changes are cheap, so Phase 5 produces a
runnable draft (real code, not a throwaway low-fidelity prototype) used to
validate interaction and visual experience with the user. The draft lives in
the project source tree at the path declared in `architecture/tech-stack.md`
→ "Frontend Implementation Path". system-design plans the production
promotion (i18n, a11y, performance, tests, coding-standard alignment) and
autoforge executes it in place — neither phase re-implements the UI from this
feature spec.

- **Draft path:** `{repo-root}/{frontend-implementation-path}/{feature-area}/` *(repo-relative; the base path is set in `architecture/tech-stack.md`)*
- **Confirmed (experience):** {YYYY-MM-DD}

### State Flow

{Business entity state flow — for features where domain objects have lifecycle states (e.g. orders, approvals, subscriptions). Distinct from the Interaction State Machine above, which tracks UI component states. Omit for stateless CRUD.}

```mermaid
stateDiagram-v2
    [*] --> {State1}
    {State1} --> {State2}: {event}
    {State2} --> {State3}: {event}
    {State3} --> [*]
```

| From | Event | To | Side Effects |
|------|-------|----|-------------|
| {state} | {trigger} | {state} | {what else happens: notifications, data changes, etc.} |

### Edge Cases

{Use the same Given/When/Then format as Acceptance Criteria — every edge case must be testable as an automated test.}

- Given {precondition / unusual state}, when {trigger}, then {observable, assertable result}
- Given {precondition / boundary value}, when {action}, then {observable result}

{If this feature has a Permission line in Context, include at least one unauthorized access edge case:}
- Given {unauthorized role, e.g. "a user with Viewer role"}, when {attempting a restricted action}, then {rejection behavior, e.g. "returns 403 and no data is modified"}

### Test Data Requirements

{Minimum dataset and preconditions needed to verify this feature. Omit for features with trivial or no test data needs.}

| Aspect | Specification |
|--------|---------------|
| Fixtures / seed data | {e.g. "a PRD directory with README.md + 3 feature files with cross-dependencies"} |
| Boundary values | {e.g. "0 tasks, 1 task, 100+ tasks for DAG construction"} |
| Preconditions | {e.g. "a git repo with at least one worktree already created by F-004"} |
| External service stubs | {e.g. "mock gh CLI returning 5 issues; mock Claude API returning structured JSON"} |

### Dependencies

- Depends on: [F-{XXX}](./F-{XXX}-{slug}.md) — {reason: what this feature requires from F-XXX before it can function}
- Blocks: [F-{YYY}](./F-{YYY}-{slug}.md) — {reason: what F-YYY requires from this feature}

### Analytics & Tracking

| Event | Trigger | Payload | Purpose |
|-------|---------|---------|---------|
| {event_name} | {user action that fires it} | {key data fields} | {which Goal metric this feeds} |

### Notifications

{Only if this feature triggers notifications to users. Omit if no notifications.}

| Event | Channel | Recipient | Content Summary | User Control |
|-------|---------|-----------|----------------|-------------|
| {e.g. task failed} | {email / push / in-app / SMS} | {e.g. task owner} | {what the notification communicates} | {e.g. can disable in settings} |

### Risks & Mitigations

{Copy relevant risks from the PRD README that affect this feature — only if applicable, omit otherwise.}

| Risk | Mitigation in this feature |
|------|---------------------------|
| {risk from README} | {how this feature's implementation addresses it} |

### Implementation Notes

- **Approach:** {strategy for implementing this feature}
- **Key files:** {paths to modify (existing codebase) or suggested file structure (new project)}
- **Testing:** {what to test — unit, integration, E2E scenarios}
- **Pitfalls:** {known anti-patterns or gotchas to avoid}

### Open Questions

{Decisions or information gaps that must be resolved before implementation can begin. Remove when resolved.}

| # | Question | Owner | Due | Resolution |
|---|----------|-------|-----|------------|
| 1 | {question} | {person/team} | {date} | {open / {resolution text}} |

---

## Rules

- **Self-contained**: every piece of context a coding agent needs to implement this feature — data models, conventions, journey touchpoints, design tokens — MUST be copied inline. Never say "see architecture.md" or "see J-001". Cross-references for navigation are permitted but must NOT be load-bearing.
- **Omit empty sections**: no API Contract for pure UI features; no Interaction Design for backend-only features (background jobs, pure API, infrastructure); no frontend i18n for backend-only features; no backend i18n for pure UI features or single-language backends; no State Flow for stateless CRUD.
- **All user-facing features must include Interaction Design.** No exceptions.
- **Precise language**: "must", "returns", "rejects" — not "should consider", "might want to".
- **Testable criteria**: every acceptance criterion and edge case maps to an automated test. Edge cases use Given/When/Then, same as acceptance criteria.
- **Design token names, not raw values**: all visual references in Interaction Design MUST use semantic token names (e.g. `color.primary`, `spacing.md`). Raw hex, rem, ms, or px values are forbidden.
- **ID stability**: feature IDs (F-NNN) are zero-padded, sequential, and stable across iterations. Never renumber existing IDs.
- **Motivation ties to evidence**: every major product decision traces to user research, data, competitive analysis, or an explicit assumption label. Assumption-heavy features are flagged as validation risks.
