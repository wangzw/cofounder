# Artifact Template — prd-analysis

This file is READ by `generate/writer-subagent.md` when authoring PRD leaves. It defines
what "good" PRD artifact output looks like: directory layout, per-file frontmatter, required
sections, self-containedness rules, and leaf-size limits. Follow every section exactly.

Variant: **Document** (PRD artifacts are human-readable markdown directories).

---

## Canonical Directory Layout

```
docs/raw/prd/YYYY-MM-DD-<product-slug>/
├── README.md                          # Pyramid apex: product index (≤ 120 lines)
├── journeys/
│   ├── J-001-<slug>.md               # One file per user journey, self-contained
│   └── J-002-<slug>.md
├── features/
│   ├── F-001-<slug>.md               # One file per feature, fully self-contained
│   └── F-002-<slug>.md
├── architecture.md                    # Index only (~50–80 lines); links to topic files
├── architecture/
│   ├── tech-stack.md
│   ├── data-model.md
│   ├── coding-conventions.md
│   └── nfr.md                        # perf + security + a11y (CR-PRD-L05)
├── REVISIONS.md                       # Optional — only after first --revise cycle
└── prototypes/                        # Optional
    ├── src/
    └── screenshots/
```

Rules:
- No single file MAY exceed **300 lines** (CR-PRD-S08). Split oversized content into additional
  sibling leaves.
- `README.md` is an INDEX, not a monolith. It lists summaries only; full content lives in leaves.
- `architecture.md` is an INDEX (~50–80 lines); full architecture content lives in `architecture/`.

---

## README.md Shape

```markdown
---
title: "<Product Name> — Product Requirements Document"
product_name: "<ProductName>"
date: "YYYY-MM-DD"
stakeholders:
  - "<name or role>"
  - "<name or role>"
version: "1.0"
status: "draft | review | approved"
---

# <Product Name> — PRD

## Product Overview

<!-- 3–5 sentences: problem, target user(s), core value proposition -->

## Feature Index

| ID | Feature | Priority | Status | Mapped Journeys |
|----|---------|----------|--------|----------------|
| [F-001](features/F-001-<slug>.md) | <Feature Name> | P0/P1/P2 | draft | J-001, J-002 |

## Journey Index

| ID | Persona | Journey Name | Touchpoints |
|----|---------|-------------|-------------|
| [J-001](journeys/J-001-<slug>.md) | <Persona> | <Journey Name> | <N> |

## Cross-Journey Patterns

<!-- Required section — CR-PRD-L06. Name every recurring theme observed across ≥2 journeys:
     shared pain points, common infrastructure, persona handoffs. If none, write "None identified." -->

| Pattern | Journeys | Notes |
|---------|---------|-------|
| <Pattern Name> | J-001, J-002 | <one-line description> |

## Roadmap

<!-- Optional but recommended: map features to release milestones -->

| Milestone | Features | Target Date |
|-----------|---------|-------------|
| MVP | F-001, F-002 | YYYY-MM-DD |
```

Required frontmatter keys (CR-PRD-S01): `title`, `product_name`, `date`, `stakeholders`.
Missing any of these keys causes script checker failures and breaks downstream skill lookups.

---

## journeys/J-NNN-`<slug>`.md Shape

```markdown
---
id: J-001
persona: "<Persona Name>"
status: "draft | review | approved"
---

# J-001 — <Journey Name>

## Persona Context

<!-- 2–4 sentences: who this person is, their goal, their baseline frustration -->

## Touchpoint Sequence

| # | Stage | Screen / View | Action | Interaction Mode | System Response | Pain Point |
|---|-------|--------------|--------|-----------------|-----------------|------------|
| 1 | <stage> | <view name> | <what user does> | click / form / drag / keyboard / scroll / hover / swipe / voice / scan | <what system does> | <pain or empty> |
| 2 | ... | | | | | |

## Mapped Features

<!-- List every feature that addresses a touchpoint in this journey -->

| Touchpoint # | Feature ID | Feature Name |
|-------------|-----------|-------------|
| 1 | F-001 | <Feature Name> |
```

- File name pattern: `J-NNN-<slug>.md` (CR-PRD-S03).
- Frontmatter MUST declare `id: J-NNN` matching the file name.
- Each touchpoint row MUST have exactly one `interaction_mode` value from the glossary.
- Leaf MUST be ≤ 300 lines (CR-PRD-S08).

---

## features/F-NNN-`<slug>`.md Shape

```markdown
---
id: F-001
priority: P0 | P1 | P2
status: "draft | review | approved"
---

# F-001 — <Feature Name>

## Journey Backreferences

<!-- Required: every feature MUST map to ≥1 journey touchpoint (CR-PRD-L02) -->

| Journey | Touchpoint # | Stage | Pain Point Addressed |
|---------|-------------|-------|---------------------|
| [J-001](../journeys/J-001-<slug>.md) | 3 | <stage> | <pain point> |

## Description

<!-- 2–5 sentences: what the feature does and why it exists -->

## Acceptance Criteria

- [ ] <criterion 1 — testable, user-visible behaviour>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Inline Data Model

<!-- REQUIRED for any feature that stores or retrieves data.
     Copy the relevant entity definitions here — do NOT link to data-model.md.
     A coding agent reads only this file; all context must be present. -->

```typescript
// Example — replace with actual entities
interface ExampleEntity {
  id: string;          // UUID
  createdAt: Date;
  // ... fields
}
```

## Inline Conventions

<!-- REQUIRED: copy the coding conventions that apply to implementing this feature.
     Do NOT write "see architecture/coding-conventions.md". Inline relevant excerpts. -->

- **Language / Runtime**: <e.g., TypeScript 5, Node 20>
- **Framework**: <e.g., React 18 with hooks>
- **Error handling**: <e.g., thrown errors wrapped in Result<T, E> type>
- **Testing**: <e.g., Vitest unit tests, Playwright E2E>
- <add or remove lines as needed for this feature>

## Out of Scope

<!-- Optional but recommended: explicitly list what this feature does NOT cover -->
```

- File name pattern: `F-NNN-<slug>.md` (CR-PRD-S02).
- Frontmatter MUST declare `id: F-NNN` matching the file name.
- Self-containedness is mandatory (CR-PRD-L01): inline the data model AND conventions. A coding
  agent implementing this feature reads ONLY this file. It MUST NOT need to open any other file.
- Leaf MUST be ≤ 300 lines (CR-PRD-S08).

---

## architecture.md Shape (Index Only)

```markdown
# Architecture — <Product Name>

> This file is an index. All architecture content lives in the `architecture/` subdirectory.
> No implementation details are written here.

## Topic Files

| File | Contents |
|------|---------|
| [tech-stack.md](architecture/tech-stack.md) | Languages, frameworks, infrastructure choices |
| [data-model.md](architecture/data-model.md) | Entity definitions, relationships, storage schema |
| [coding-conventions.md](architecture/coding-conventions.md) | Style, error handling, testing patterns |
| [nfr.md](architecture/nfr.md) | Performance targets, security posture, accessibility requirements |

## Navigation

<!-- One sentence per topic that tells a reader what question each file answers -->
- **tech-stack.md** — "What tools are we building with?"
- **data-model.md** — "What does the data look like?"
- **coding-conventions.md** — "How do we write code consistently?"
- **nfr.md** — "What quality bar must the system meet?"
```

Rules:
- `architecture.md` length target: 50–80 lines.
- Every `architecture/<topic>.md` file MUST be listed here (CR-PRD-S05).
- No topic file may be listed that does not exist on disk (CR-PRD-S05).

---

## architecture/`<topic>`.md Shape

Each topic file is self-contained and covers exactly one concern. Required topics:

| File | Minimum Contents |
|------|-----------------|
| `tech-stack.md` | Runtime, language version, primary frameworks, cloud/infra decisions |
| `data-model.md` | Entity definitions, field types, relationships, storage engine |
| `coding-conventions.md` | Language style, naming, error handling, test patterns |
| `nfr.md` | Performance targets (p95 latency, throughput), security posture (auth, encryption, OWASP coverage), accessibility requirements (WCAG level, a11y tooling) |

`nfr.md` MUST cover all three non-functional dimensions — performance, security, and a11y — to
satisfy CR-PRD-L05. An architecture section missing `nfr.md` or any of these three dimensions
fails this criterion.

---

## REVISIONS.md Shape (Optional)

Only written after the first `--revise` cycle. If no revisions have occurred, omit the file.

```markdown
# Revisions Log

## Rev-001 — YYYY-MM-DD

**Trigger**: `--revise` session
**Changed**:
- F-002: updated acceptance criteria (section: Acceptance Criteria)
- J-001: added touchpoint 4 (screen: Dashboard)

**Reason**: <one-sentence rationale>

---

## Rev-002 — YYYY-MM-DD
...
```

Rules (CR-PRD-S07):
- Every entry MUST reference at least one valid feature or journey ID present in the current tree.
- Each `--revise` session MUST add an entry. An absent entry means the session is untracked.

---

## prototypes/ Shape (Optional)

```
prototypes/
├── src/            # Runnable prototype source (HTML/CSS/JS or framework code)
└── screenshots/    # Static screenshots of prototype state (PNG/JPG, named by screen)
```

No review criteria enforce prototype presence; this directory is informational.

---

## Positive Example — Minimal Self-Contained Feature File

The following is a well-formed `F-001-user-login.md`. A coding agent can implement the login
feature by reading only this file.

```markdown
---
id: F-001
priority: P0
status: draft
---

# F-001 — User Login

## Journey Backreferences

| Journey | Touchpoint # | Stage | Pain Point Addressed |
|---------|-------------|-------|---------------------|
| [J-001](../journeys/J-001-onboarding.md) | 2 | Authentication | No unified login entry point |

## Description

Provides a credential-based login screen that authenticates registered users and issues a
session token. Supports email + password; no OAuth in MVP scope.

## Acceptance Criteria

- [ ] User can submit email + password and receive a session cookie on success.
- [ ] Invalid credentials return HTTP 401 with a user-friendly error message.
- [ ] Five consecutive failures lock the account for 15 minutes.

## Inline Data Model

```typescript
interface User {
  id: string;        // UUID v4
  email: string;     // unique, lowercase-normalised
  passwordHash: string; // bcrypt, 12 rounds
  failedAttempts: number;
  lockedUntil: Date | null;
  createdAt: Date;
}

interface Session {
  token: string;     // 256-bit random, base64url
  userId: string;
  expiresAt: Date;   // 7 days from creation
}
```

## Inline Conventions

- **Language / Runtime**: TypeScript 5, Node 20
- **Framework**: Express 4 with class-validator for input validation
- **Password hashing**: bcrypt via `bcryptjs`, 12 rounds minimum
- **Error handling**: Thrown errors use `AppError(code, message)` wrapper; HTTP layer maps codes
  to status codes in `src/middleware/error-handler.ts`
- **Testing**: Vitest unit tests for service layer; Playwright E2E for login flow

## Out of Scope

- OAuth / social login (post-MVP)
- Two-factor authentication (post-MVP)
- Password reset flow — covered in F-003
```

Why this example passes all applicable CRs:
- CR-PRD-S02: file named `F-001-user-login.md`; frontmatter declares `id: F-001` ✓
- CR-PRD-L01: data model (User, Session) and conventions copied inline — no cross-file deps ✓
- CR-PRD-L02: journey back-reference to J-001, touchpoint 2 ✓
- CR-PRD-S08: well under 300 lines ✓

---

## Negative Example — Feature with Cross-File Reference (Violates CR-PRD-L01)

The following is a **malformed** `F-002-user-profile.md`. Do NOT write features like this.

```markdown
---
id: F-002
priority: P1
status: draft
---

# F-002 — User Profile

## Journey Backreferences

| Journey | Touchpoint # | Stage | Pain Point Addressed |
|---------|-------------|-------|---------------------|
| [J-002](../journeys/J-002-profile.md) | 1 | Settings | No editable profile |

## Description

Allows users to update their display name and avatar.

## Acceptance Criteria

- [ ] User can update display name and avatar.

## Data Model

See `architecture/data-model.md` for the User entity definition.        ← VIOLATION

## Conventions

Follow the patterns in `architecture/coding-conventions.md`.            ← VIOLATION
```

Annotation of fired CRs:

- **CR-PRD-L01 fires** (`feature-files-self-contained`): The feature references
  `architecture/data-model.md` and `architecture/coding-conventions.md` instead of inlining
  the relevant content. A coding agent reading only this file will not know what fields the
  `User` entity has or how to handle errors. The file is not independently readable.

Fix: copy the `User` entity fields relevant to profile editing inline under "Inline Data Model",
and copy the applicable conventions inline under "Inline Conventions".

---

## Leaf Size Enforcement

CR-PRD-S08 (`leaf-size-within-limit`) fires if any single artifact file exceeds **300 lines**.

When a feature or journey file approaches the limit:
1. Move the "Out of Scope" or secondary acceptance criteria to a companion note file
   (`features/F-NNN-<slug>-notes.md`) and link to it as a non-load-bearing reference.
2. Split a large journey (many touchpoints) into sub-journeys
   (`J-001-a-<slug>.md`, `J-001-b-<slug>.md`) and add an entry in the journey index.
3. Never exceed 300 lines by merging multiple features into one file.

The 300-line limit applies to every leaf: README.md, journey files, feature files, architecture
topic files, REVISIONS.md, and any optional files. `architecture.md` (the index) MUST be kept
to 50–80 lines by design.

---

## Pyramid Index Requirement

A valid PRD output satisfies all of the following:

1. `README.md` exists at the artifact root and contains a Feature Index table and a Journey
   Index table linking to every leaf.
2. `features/` and `journeys/` subdirectories exist; each leaf has a unique, stable ID.
3. `architecture.md` lists every file under `architecture/`; no orphans, no missing files
   (CR-PRD-S05).
4. No single file exceeds 300 lines (CR-PRD-S08).
5. README cross-journey patterns section is present (CR-PRD-L06).

A flat single-file PRD (one large document with all content) violates CR-PRD-S08, CR-PRD-L01,
and the pyramid index requirement. The summarizer and downstream coding agents both depend on
the multi-file pyramid shape.
