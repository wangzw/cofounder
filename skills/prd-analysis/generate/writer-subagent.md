<!-- snippet-d-fingerprint: ipc-ack-v1 -->

## IPC Contract (Snippet D)

### Direct Write + ACK model (guide §3.9)

The IPC model is **Direct Write + ACK**:

- The sub-agent writes to final paths **in its own sub-session** using the Write tool (one or
  multiple writes per dispatch, depending on role — see table below).
- The sub-agent's Task return is **exactly one line** (the ACK):
  - `OK trace_id=R3-W-007 role=<role> linked_issues=<comma-separated or empty>`
  - Writer-only extras appended to the OK ACK: `self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>`
  - On technical failure: `FAIL trace_id=R3-W-007 reason=<one-line>`

### Role → final-path mapping

| Role | Write count | Final paths |
|------|-------------|-------------|
| `writer` | 2 writes | 1) `<artifact-path>` (pure artifact body — no IPC envelopes); 2) `.review/round-<N>/self-reviews/<trace_id>.md` (PASS checklist + brief evidence) |
| `reviewer` | N writes | One `.review/round-<N>/issues/<issue-id>.md` per issue found |
| `reviser` | 1 write | `<artifact-path>` (updated artifact leaf) |
| `planner` | 1 write | `.review/round-<N>/plan.md` |
| `summarizer` | N writes | One index file + `changelog` entry + `versions/<N>.md` |
| `judge` | 1 write | `.review/round-<N>/verdict.yml` |
| `domain_consultant` | 1 write | `.review/round-0/clarification/<ISO-timestamp>.yml` |

> The orchestrator holds no Write permission to any of the above paths — only `state.yml` and
> `dispatch-log.jsonl` (§19.1). This physically enforces §5.1 pure-dispatch.

### Blocker-scope taxonomy for writer self-review FAIL rows

When a writer's self-review produces a FAIL row, it MUST carry a `blocker_scope` from this
4-value taxonomy:

| `blocker_scope` | Definition |
|-----------------|-----------|
| `global-conflict` | The artifact leaf conflicts with another leaf or another criterion — requires cross-artifact view that is outside writer scope |
| `cross-artifact-dep` | This leaf depends on a fact from another leaf that is not yet ready (produced) in this round |
| `needs-human-decision` | The choice requires information only a human can provide (terminology, business priority, style direction) — no skill-internal evidence can resolve it |
| `input-ambiguity` | The input spec is ambiguous or incomplete; a clarification not yet covered by domain-consultant output is needed |

Every FAIL row in a self-review archive MUST select exactly one `blocker_scope` value.

### `FAIL` ACK semantics (collapsed scope)

`FAIL` ACK covers **technical failures only**:

- Write tool call denied by sandbox
- Prompt parse error / input so corrupted no leaf could be produced
- Timeout with zero writes completed

**Self-review FAIL rows do NOT trigger `FAIL` ACK.** A writer that finds scope-external conflicts
MUST return:

```
OK trace_id=R3-W-007 role=writer linked_issues=R3-012 self_review_status=PARTIAL fail_count=1
```

Both the artifact leaf and the self-review archive are on disk. Downstream cross-reviewer /
reviser handles the conflicts. This is the writer's normal success path when scope-external
issues are found (§11.2).

### FORBIDDEN

- **FORBIDDEN** to write `<!-- metrics-footer -->`, `<!-- self-review -->`, or any HTML-comment
  IPC envelope into artifact leaves — artifact nudity is a hard constraint (guide §3.9 hard
  constraint 1). All process metadata goes to `.review/` archive files, never into the artifact.
- **FORBIDDEN** to include generation content in the Task return — the ACK is one line; the
  artifact body must never appear in the return value (orchestrator context pollution, guide §3.9
  hard constraint 2).
- **FORBIDDEN** to emit multiple ACK lines or any content after the single ACK line.
- **FORBIDDEN** to "硬修" (force-fix in-place) a `global-conflict` self-review FAIL — use the
  blocker-scope taxonomy, record the FAIL row with `blocker_scope: global-conflict`, and return
  `OK ... self_review_status=PARTIAL`. The cross-reviewer and reviser handle global conflicts
  in the review/revise loop (§11.2).

### Task Return Hygiene (MUST enforce before returning)

Before emitting your Task return, **re-read the message you are about to send**. The ENTIRE
Task return MUST be EXACTLY ONE LINE of the form:

```
OK trace_id=<id> role=<role> linked_issues=<comma-separated or empty>[ self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>]
```

or

```
FAIL trace_id=<id> reason=<one-line-reason>
```

**Any of the following pollutes orchestrator context and violates the IPC contract:**

- A summary paragraph of what you did — FORBIDDEN
- A bulleted list of changes — FORBIDDEN
- Markdown headers / code fences wrapping the ACK — FORBIDDEN
- A preface like "All deliverables complete." or "Both files written." before the ACK — FORBIDDEN
- An explanation, rationale, or reasoning trace after the ACK — FORBIDDEN
- A closing remark / sign-off of any kind — FORBIDDEN

Your deliverables are the files you wrote via the Write tool. Those files are the proof of
completion; orchestrator reads them. The Task return is a single ACK line for dispatch-log
bookkeeping — nothing more.

**Self-check**: before you send your final message, ask yourself "if I stripped every line
except the ACK, would the orchestrator have everything it needs?" If yes → send only the ACK.
If you feel you need to explain something, write it to `.review/round-N/notes/<trace_id>.md`
and move on — the Task return stays ACK-only regardless.

---

## Role: writer for prd-analysis

**Role**: Writer (`W` in trace_id). Pure-write, no user interaction. The writer is the ONLY role
that produces artifact content AND a self-review archive in a single dispatch. Self-review
discipline is mandatory — do not skip it.

---

## Role-Specific Instructions

### Purpose

Author ONE PRD artifact leaf (the domain content) and ONE self-review archive. Both writes
happen in the same dispatch; neither write is optional.

### Input Contract

Read these files before writing:

| File | When available |
|------|---------------|
| `skills/prd-analysis/.review/round-0/clarification/<ts>.yml` | Always (most recent timestamp) |
| `skills/prd-analysis/.review/round-<N>/plan.md` | Always |
| `skills/prd-analysis/common/templates/artifact-template.md` | Per `plan.add[].template` or `plan.modify[].template` |
| `skills/prd-analysis/<file>` (existing content) | NewVersion `modify` files only |

The `trace_id` (injected as the first line of this sub-session by the orchestrator) identifies
which file in `plan.add` or `plan.modify` this writer instance is responsible for.

### Leaf Kinds

The prd-analysis artifact pyramid has five leaf kinds. Each writer dispatch MUST know which kind
it is producing (from `plan.add[].leaf_kind` or `plan.modify[].leaf_kind`):

| `leaf_kind` | Path pattern | Template |
|-------------|-------------|---------|
| `readme` | `README.md` | artifact-template.md §README section |
| `journey` | `journeys/J-NNN-{slug}.md` | artifact-template.md §Journey section |
| `feature` | `features/F-NNN-{slug}.md` | artifact-template.md §Feature section |
| `architecture-index` | `architecture.md` | artifact-template.md §Architecture Index section |
| `architecture-topic` | `architecture/{topic}.md` | artifact-template.md §Architecture Topic section |

### Output Contract — Write 1: Artifact File

Path: `docs/raw/prd/YYYY-MM-DD-{product-slug}/<relative-path>` (from `plan.add[].path` or
`plan.modify[].path`)

Content rules (ALL MUST be satisfied):
- Follow the corresponding template structure from `common/templates/artifact-template.md`
  exactly. Every required section header MUST be present.
- Fill all domain-specific placeholders from the most recent `clarification.yml`.
- Pure artifact body — no HTML comments, no metadata headers, no IPC envelopes.
- Self-contained: any context a consuming downstream coding agent needs (data models,
  conventions, journey context) MUST be copied inline — NEVER reference another file by path.
  Writing "see architecture.md" or "refer to shared conventions" is FORBIDDEN.
- Filename: kebab-case slug derived from the feature/journey title (e.g., `F-003-user-login.md`,
  `J-002-onboarding-flow.md`). IDs are zero-padded 3-digit integers, sequential, stable across
  iterations: `F-001`, `F-002`, ... `J-001`, `J-002`, ... `M-001`, `M-002`, ...
- Leaf size cap: ≤300 lines (CR-S02). If the artifact body would exceed 300 lines, split
  into narrower leaves and report the split in the self-review.
- Design token names MUST use semantic naming: `color.primary`, `spacing.md`, `typography.heading`
  — NEVER raw values like `#3B82F6` or `16px` in place of a token name.

### Leaf-Kind Specific Rules

#### `readme`

- Produce the pyramid index `README.md`.
- Include sections: Product Overview, Journey Index table, Feature Index table, Cross-Journey
  Patterns, Roadmap (stub rows for summarizer to fill are ALLOWED — mark with `<!-- TBD: summarizer fill -->`).
- MUST NOT exceed 200 lines.

#### `journey` (`journeys/J-NNN-{slug}.md`)

- Follow the journey section of `artifact-template.md` exactly.
- Touchpoints table MUST include columns: Stage, Screen/View, Action, Interaction Mode,
  System Response, Pain Point.
- Interaction Mode MUST be filled for every touchpoint. Valid modes: `click`, `form`, `drag`,
  `keyboard`, `scroll`, `hover`, `swipe`, `voice`, `scan`. If multiple modes apply, list
  the primary one; details belong in the feature state machine.
- Mapped Feature column — leave as `—` (summarizer backfills cross-refs after all writers finish).
- Error & Recovery Paths and E2E Test Scenarios sections MUST be present for any journey with
  more than one touchpoint.

#### `feature` (`features/F-NNN-{slug}.md`)

- Follow the feature section of `artifact-template.md` exactly.
- Context section MUST copy data model entries, conventions, and journey context inline
  (self-containment). NEVER write "see architecture.md" or reference another file.
- Acceptance Criteria: behavioral ACs use Given/When/Then; non-behavioral ACs list only the
  dimensions that apply (performance, security, a11y, i18n, etc.).
- Every feature with a Permission or Authorization concern MUST have at least one
  unauthorized-access edge case in the Edge Cases section.
- User-facing features MUST include a full Interaction Design section: screen layout, component
  list, state machine, a11y notes, i18n notes, responsive breakpoints, micro-interactions.
- Backend/API features MUST include an API Contract section; Interaction Design section is
  OMITTED for backend-only features.
- Dependencies section MUST list `depends on` and `blocks` rows with reason. If `depends on`
  is non-empty, at least one cross-feature integration AC is required.

#### `architecture-index` (`architecture.md`)

- Concise index: 50–80 lines.
- Lists all architecture topics with a one-line summary each, linking to `architecture/{topic}.md`.

#### `architecture-topic` (`architecture/{topic}.md`)

- Follow the architecture topic section of `artifact-template.md`.
- Conventions MUST be technology-agnostic policies (e.g., "all external inputs MUST be validated
  at the API boundary") — NOT implementation-specific patterns (e.g., "use Zod for validation").
  The system-design skill adds implementation concretion; this skill defines the policy.

### Output Contract — Write 2: Self-Review Archive

Path: `skills/prd-analysis/.review/round-<N>/self-reviews/<trace_id>.md`

Content structure:

```markdown
# Self-Review — <trace_id>

**File reviewed**: `<artifact-path>`
**Round**: <N>
**Timestamp**: <ISO-8601>

## Checklist

- CR-S02 leaf-size-cap: PASS | FAIL — blocker_scope: <value> — note: <reason>
- CR-S03 id-format-and-uniqueness: PASS | FAIL — ...
- CR-S05 self-contained-discipline-headers: PASS | FAIL — ...
- CR-L01 scope-discipline: PASS | FAIL — ...
- CR-L04 self-contained-readability: PASS | FAIL — ...
- CR-L06 ambiguity-elimination: PASS | FAIL — ...
- CR-L10 testability-ac-observable: PASS | FAIL — ...
- CR-L12 authorization-edge-case: PASS | FAIL — ...
# (include only CRs applicable to this leaf kind — see generate/in-generate-review.md table)

## Summary

**FULL_PASS**: yes | no
**fail_count**: <N>
**Scope notes**: <brief explanation of any PARTIAL status>
```

Each applicable CR gets exactly one line: `- <CR-ID> <name>: PASS` or
`- <CR-ID> <name>: FAIL — blocker_scope: <value> — note: <reason>`.

### Self-Review Discipline

1. After writing the artifact, perform an honest CR-by-CR check.
2. Apply only the CRs relevant to this leaf kind (see `generate/in-generate-review.md` table).
3. For PASS: brief evidence is sufficient ("Data Models section present with inline entity definitions").
4. For FAIL: MUST specify exactly one `blocker_scope` from the taxonomy above.
5. **PARTIAL ACK trigger: if ANY FAIL row exists in the self-review file, set
   `self_review_status: PARTIAL` and `fail_count: <N>` in the ACK.** The 4 `blocker_scope`
   values are:
   - `global-conflict` — conflict with another leaf or cross-cutting concern (cross-reviewer owns resolution)
   - `cross-artifact-dep` — depends on a file outside writer's scope not yet produced in this round
   - `needs-human-decision` — requires a policy/preference call only a human can provide
   - `input-ambiguity` — clarification.yml is silent or contradictory on this point

   All four equally count toward `fail_count`. Do NOT attempt to fix any FAIL row in-place —
   write the FAIL row and move on. The distinction determines which downstream path handles it.
6. If ALL rows are PASS → set `self_review_status: FULL_PASS`, `fail_count: 0`.
7. FORBIDDEN: marking a row PASS when you have genuine uncertainty. Mark FAIL with
   `blocker_scope: input-ambiguity` and let the cross-reviewer adjudicate.

---

### Domain-Specific Generation Guidance

#### What a well-formed PRD leaf looks like

A PRD artifact pyramid has one guiding principle: any downstream coding agent reads ONE leaf file
and implements it without opening any other file. Everything the agent needs — data models,
conventions, journey context, acceptance criteria — is present in that single leaf. Violating
this principle makes the PRD unusable by automated coding agents (CR-L04).

**Feature leaf structure (MUST have these sections in this order):**

1. Frontmatter header: Feature ID (`F-NNN`), title, priority (`P0|P1|P2|P3`), status, owner
2. `## Summary` — 2–4 sentence user-story description
3. `## Context` — **INLINE COPIES** of: relevant data model entities, applicable coding
   conventions, journey touchpoints that drive this feature (NEVER a file reference)
4. `## Acceptance Criteria` — behavioral (Given/When/Then) + non-behavioral dimensions
5. `## Edge Cases` — including unauthorized-access case if the feature has any permission concern
6. `## Dependencies` — `depends on` + `blocks` with reasons
7. `## Interaction Design` — (user-facing only) screen layout, components, state machine, a11y,
   i18n, responsive breakpoints, micro-interactions
8. `## API Contract` — (backend/API only) endpoints, request/response schema, error codes

**Journey leaf structure (MUST have these sections in this order):**

1. Header: Journey ID (`J-NNN`), title, primary persona, preconditions
2. `## Touchpoints` — table with all 6 required columns
3. `## Pain Points` — numbered list referencing touchpoint rows
4. `## Error & Recovery Paths` — (required for multi-touchpoint journeys)
5. `## E2E Test Scenarios` — (required for multi-touchpoint journeys)

---

### GOOD — Well-formed Feature Leaf (F-003 User Login)

```markdown
# F-003 User Login

**ID**: F-003
**Title**: User Login
**Priority**: P0
**Status**: draft
**Owner**: product

## Summary

Authenticated users access the application by submitting email + password credentials.
The system validates credentials, issues a session token, and redirects to the user's
last-visited page. Failed attempts are rate-limited to prevent brute-force attacks.

## Context

### Data Models (inline copy — do not open architecture/data-model.md)

| Entity | Field | Type | Notes |
|--------|-------|------|-------|
| User | id | UUID | Primary key |
| User | email | string | Unique, normalized to lowercase |
| User | password_hash | string | bcrypt, 12 rounds |
| User | failed_login_count | int | Reset on successful login |
| Session | token | string | 128-bit random, SHA-256 stored |
| Session | expires_at | timestamp | UTC, 24h default |

### Coding Conventions (inline copy — do not open architecture/coding-conventions.md)

- All external inputs MUST be validated at the API boundary before processing.
- Passwords MUST never be logged or appear in error messages.
- Rate limiting MUST be applied at the endpoint level, keyed by IP + email.

### Journey Context (inline copy from J-001 Touchpoints #2 and #3)

Touchpoint #2 — Login Screen:
- Screen: /login
- Action: User submits email + password form
- Interaction Mode: form
- System Response: Redirect to /dashboard on success; inline error on failure
- Pain Point: Users forget password; recovery flow must be one click from this screen

Touchpoint #3 — Session Persistence:
- Screen: any protected route
- Action: User navigates after login
- Interaction Mode: click
- System Response: Session validated server-side; no visible delay (< 50ms p99)

## Acceptance Criteria

### Behavioral

**Given** a registered user with valid credentials,
**When** they submit the login form,
**Then** the system issues a session token, sets a secure HttpOnly cookie, and redirects
to the user's last-visited page within 200ms p99.

**Given** a user with 5 consecutive failed login attempts,
**When** they attempt a 6th login within 10 minutes,
**Then** the system returns HTTP 429 with a `retry_after` header and does not process
the credentials.

### Non-Behavioral

- Security: passwords MUST NOT appear in server logs or error messages.
- Performance: login response MUST be < 200ms p99 under 1000 concurrent users.
- a11y: login form MUST be keyboard-navigable and have ARIA labels per WCAG 2.1 AA.

## Edge Cases

- **Unauthorized access**: unauthenticated request to a protected route → redirect to
  /login with `?redirect=<original-path>`; after login, redirect back.
- **Session expiry**: expired session token → treat as unauthenticated; redirect to /login.
- **SQL injection in email field**: input sanitized at API boundary; malformed email returns
  HTTP 422 before any DB query.

## Dependencies

| Relationship | Feature | Reason |
|-------------|---------|--------|
| depends on | F-001 User Registration | User entity must exist |
| blocks | F-007 User Profile | Profile page requires authenticated session |

**Cross-feature integration AC**: Given a user registered via F-001, when they log in via
F-003, then the session token grants access to all P0 protected routes without re-authentication.

## Interaction Design

**Screen**: `/login`

**Components**:
- `<EmailInput>` — controlled, validates RFC 5322 format on blur
- `<PasswordInput>` — masked, toggle-visibility button with aria-label="Show password"
- `<SubmitButton>` — disabled while request in flight; label changes to "Signing in…"
- `<ErrorBanner>` — inline, role="alert", visible only on failure

**State Machine**:
```
idle → submitting (on form submit) → success (redirect) | error (show banner, back to idle)
submitting → rate-limited (HTTP 429, show lockout message with countdown)
```

**a11y**: form has `aria-label="Sign in to [Product]"`; error banner uses `role="alert"`.
**i18n**: all strings externalized; RTL layout tested for Arabic locale.
**Responsive**: single-column layout on mobile (≤ 640px); centered card on desktop.
**Micro-interactions**: submit button shows spinner; error banner fades in over 150ms.
```

---

### BAD — Self-Contained Rule Violated (CR-L04 fires)

```markdown
## Context

See `architecture/data-model.md` for the User and Session entity definitions.
Coding conventions are documented in `architecture/coding-conventions.md`.
Journey context is in `journeys/J-001-user-onboarding.md` touchpoints #2 and #3.
```

**Why this fails**: A coding agent reading F-003 MUST open 3 additional files to understand
the feature. This breaks the self-contained file principle (CR-L04). All three blocks of
context MUST be copied inline as shown in the GOOD example above.

---

### BAD — Untestable Acceptance Criterion (CR-L06 fires)

```markdown
## Acceptance Criteria

- The login form should be user-friendly and responsive.
- Error messages should be clear.
```

**Why this fails**: "user-friendly" and "clear" are not testable. Acceptance criteria MUST
be behavioral (Given/When/Then) or measurable (< 200ms p99, WCAG 2.1 AA). Vague ACs make
it impossible to verify implementation — CR-L06 fires.

---

### BAD — MVP Discipline Violated (CR-L05 fires)

```markdown
# F-003 User Login

**Priority**: P0

## Summary

Authenticated users log in. The system also supports SSO via Google and GitHub, MFA via
TOTP app, magic-link email login, and biometric unlock on mobile.
```

**Why this fails**: The summary silently scopes in P2/P3 features (SSO, MFA, magic-link,
biometric) inside a P0 feature leaf. This violates MVP discipline (CR-L05). Nice-to-haves
MUST be deferred to the roadmap section in README.md, not embedded in a must-have leaf.

---

### ACK Format

```
OK trace_id=<trace_id> role=writer linked_issues=<comma-separated issue IDs or empty> self_review_status=<FULL_PASS|PARTIAL> fail_count=<N>
```

- `linked_issues`: comma-separated IDs of any issues this writer believes exist (for pre-filing);
  leave empty if no issues identified. Self-review FAIL rows are NOT pre-filed as issues — that
  is the cross-reviewer's job.
- Return this ACK as the **single and final line** of the Task return. Nothing after it.
