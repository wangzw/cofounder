# Document-Based Mode — PRD Analysis

This file contains instructions for document-based PRD analysis. Use this mode when the user
supplies an existing brainstorming document, requirements draft, or partial spec as input instead
of going through the interactive questioning phases. Document-mode parses the supplied file into
the structured PRD artifact set (`README.md` + `journeys/` + `features/` + `architecture/`)
without running the questioning phases end-to-end; gaps trigger targeted fallback questioning
against the relevant phase in `questioning-phases.md`.

---

## When to Activate Document-Mode

Activate this mode when the user invokes the skill with `--document <path>` or explicitly hands
over a file (brainstorm notes, user-story map, raw requirements doc, Notion export, etc.) and asks
to derive a PRD from it. Do NOT activate when the user provides a previously generated PRD bundle
for review or evolution — use `--review` or `--evolve` respectively.

---

## Step 1 — Ingest and Summarize

1. Read the entire supplied document.
2. Produce a one-paragraph summary of what you understood: product name, primary personas, core
   problem, proposed solution, and scope hints.
3. Present the summary to the user and ask for a quick confirmation or correction before
   proceeding. This surfaces fundamental misreads early and prevents wasted gap-filling.

---

## Step 2 — Parser Heuristics

When parsing the document, apply the following heuristics to map free-form content onto PRD
structure:

| Source signal | Maps to |
|---------------|---------|
| "as a <role>" / "the user wants" / persona descriptions | Persona → `architecture/personas.md` |
| Step-by-step flows / user stories / "when X, then Y" | Journey touchpoints → `journeys/J-NNN.md` |
| Feature requests / bullet lists of capabilities | Feature items → `features/F-NNN-slug.md` |
| KPIs / success metrics / OKRs | Goals + Metrics → README |
| Competitor names / "unlike X" / "better than Y" | Competitive Landscape → README |
| Color hex codes / font names / spacing values | Design tokens (flag for normalization) → `architecture/design-tokens.md` |
| "must not" / "out of scope" / "phase 2 only" | Constraints / out-of-scope notes → README |
| "assuming" / "TBD" / open questions | Gap candidates — flag for targeted questioning |
| Technical stack mentions (React, Postgres, etc.) | Tech stack → `architecture/` topic |
| Compliance terms (GDPR, HIPAA, SOC2) | Privacy & compliance → README |
| Deployment / environment descriptions | Deployment → `architecture/deployment.md` |
| Auth roles / permission levels | Authorization model → `architecture/authorization.md` |

If a passage does not fit any mapping, note it as an **unclassified fragment** and present it to
the user at gap-review time (Step 3).

---

## Step 3 — Gap Detection

After parsing, run the gap checklist below. For each item, mark it one of:

- **PRESENT** — document contains sufficient information to draft this dimension
- **PARTIAL** — document contains hints but not enough to write a complete spec
- **ABSENT** — document has no signal for this dimension

**Gap checklist** (scan for missing or vague coverage in these areas):

- [ ] Personas defined with clear goals?
- [ ] User journeys (happy path + error/alternative paths) explicitly described (or clearly implied
  with enough detail to write acceptance criteria)?
- [ ] Cross-journey patterns identified (shared pain points, repeated touchpoints, handoff points)?
- [ ] Success metrics with measurable targets?
- [ ] Competitive context or alternatives acknowledged?
- [ ] Evidence base for key decisions (data, research, or labeled assumptions)?
- [ ] Feature boundaries clear (what's in/out of MVP)?
- [ ] Edge cases and error handling addressed?
- [ ] Interaction design described for user-facing features (component contracts, state machines,
  a11y, i18n)?
- [ ] Frontend tech stack specified (framework, CSS, component library, state management)?
- [ ] Design tokens defined (colors, typography, spacing, breakpoints, motion)?
- [ ] Navigation architecture described (site map, routes, breadcrumbs)?
- [ ] Component contracts defined for user-facing features (props, events, slots)?
- [ ] Interaction state machines defined for stateful UI components?
- [ ] Form specifications defined for form-having features (fields, validation, error messages,
  conditional logic, submission behavior)?
- [ ] Micro-interactions and motion defined for key interactions (trigger, animation, duration
  token, easing token, purpose)?
- [ ] Interaction Mode specified per journey touchpoint (click, form, drag, swipe, keyboard,
  scroll, hover, voice, scan)?
- [ ] Page transitions defined for multi-step journeys (transition type, data prefetch, notes)?
- [ ] Architecture-level accessibility baseline defined (WCAG level, keyboard, focus, contrast,
  motion, touch targets)?
- [ ] Accessibility requirements stated per feature (WCAG level, keyboard, ARIA, focus)?
- [ ] Architecture-level i18n baseline defined (languages, default language, RTL, key convention,
  format rules, locale resolution, timezone handling)?
- [ ] Frontend internationalization requirements stated per user-facing feature?
- [ ] Backend internationalization requirements stated per feature returning user-visible text?
- [ ] Responsive behavior described per breakpoint for user-facing features?
- [ ] Prototype feedback documented and incorporated?
- [ ] Authorization / permission model described (if multi-role)?
- [ ] Privacy / compliance requirements stated (if handling personal data)?
- [ ] Notification requirements captured (if the product notifies users)?
- [ ] Technical stack and integration points specified?
- [ ] Non-functional requirements (performance, security, i18n) stated?
- [ ] Shared conventions (API format, error handling, testing strategy) explicitly defined?
- [ ] Coding conventions defined (code organization, naming, interface design, dependency wiring,
  error propagation, logging, config access, concurrency)?
- [ ] Test isolation policies defined (resource isolation, no global mutable state, random ports,
  temp dirs, process cleanup, race detection, timeouts)?
- [ ] Development workflow defined (prerequisites, local setup, CI gates, build matrix, release
  process, dependency management)?
- [ ] Security coding policy defined (input validation, secret handling, dependency scanning,
  injection prevention, auth enforcement)?
- [ ] Backward compatibility policy defined (API versioning, breaking changes, data schema
  evolution — or N/A for v1)?
- [ ] Git and branch strategy defined (naming, merge strategy, protection rules, PR conventions,
  commit format)?
- [ ] Code review policy defined (dimensions, approvals, SLA, automated vs human, severity
  levels)?
- [ ] Observability requirements defined (mandatory events, health checks, metrics/SLOs, alerting,
  audit trail)?
- [ ] Performance testing policy defined (regression detection, budgets, load testing, resource
  limits)?
- [ ] Development Infrastructure feature present (auto-derived from convention sections) with
  concrete deliverables (linter config, CI pipeline, pre-commit hooks, test helpers, security
  scanning, AI agent instruction files)?
- [ ] AI agent configuration defined (instruction files, structure policy, convention references,
  maintenance policy, context budget)?
- [ ] Deployment architecture defined (environments, local dev setup, environment parity, config
  management, data migration, CD pipeline, environment isolation)?
- [ ] Deployment Infrastructure feature present (auto-derived from Deployment Architecture)?
- [ ] Risks or open questions acknowledged?
- [ ] Priority rationale (not just labels) provided?
- [ ] Edge cases testable (Given/When/Then form, not vague descriptions)?
- [ ] Non-functional requirements stated per feature (not just globally)?
- [ ] Test data requirements inferrable for non-trivial features?
- [ ] E2E test scenarios inferrable from journey flows (happy + error paths)?

---

## Step 4 — Gap Presentation and Targeted Questioning

Present the gap summary to the user before generating any artifacts:

1. List ABSENT and PARTIAL dimensions grouped by topic area.
2. For dimensions marked ABSENT or PARTIAL, ask whether to:
   - **Fill via targeted questioning** — run the relevant phase/deep-dive from
     `questioning-phases.md` for that dimension.
   - **Leave as assumption** — the writer will note the assumption inline and flag it for
     future validation.
   - **Mark out of scope** — the product genuinely does not need that dimension (e.g. a CLI tool
     does not need responsive breakpoints).

Do not batch all gaps into one massive question block. Group related gaps together by the phase
they belong to (see Remediation Map below) and ask per group, waiting for a response before moving
on. Present at most 3–4 groups per round.

---

## Step 5 — Fallback to Targeted Questioning

For each gap dimension where the user chose "Fill via targeted questioning", route to the
corresponding phase and deep-dive in `questioning-phases.md`:

| Gap Area | Questioning Phase | Deep-Dive |
|----------|------------------|-----------|
| Vision, problem, goals | Phase 1 | — |
| Personas, journeys | Phase 2 | User Journeys deep-dive |
| Competitive landscape | Phase 1 | Competitive Landscape deep-dive |
| Evidence base | Phase 1 | Evidence Base deep-dive |
| Frontend foundation (tokens, navigation, a11y, i18n) | Phase 3 | Frontend Foundation deep-dive |
| Features, interaction design, forms | Phase 4 | Interaction Design, Form Specification deep-dives |
| Prototypes | Phase 5 | Prototypes deep-dive |
| Architecture conventions | Phase 6 | Development Infrastructure, Deployment Infrastructure, AI Agent Configuration deep-dives |
| Authorization, privacy | Phase 6 | Authorization, Privacy deep-dives |
| Prioritization, roadmap | Phase 7 | — |
| Risks | Phase 8 | — |

Run only the specific deep-dive sub-questions relevant to the identified gap — do not replay the
entire phase. Merge the answers with the parsed document content before proceeding to generation.

---

## Step 6 — Artifact Generation

Once gaps are resolved (either by targeted questioning or accepted as assumptions), proceed to
generate the full PRD artifact set following `output-discipline.md`:

1. **README.md** — index-only, using `prd-template.md` structure.
2. **`journeys/J-NNN.md`** — one file per journey, using `journey-template.md`.
3. **`features/F-NNN-slug.md`** — one file per feature, using `feature-template.md`.
4. **`architecture/*.md`** — topic files (design tokens, conventions, deployment, etc.) using
   `architecture-template.md`.

Apply the parallel-dispatch protocol from `parallel-dispatch.md` for fan-out generation of
journey and feature leaves.

Each leaf file MUST be self-contained: copy relevant journey context, data models, and applicable
conventions inline — do not cross-reference other files by path.

All raw values from the source document (hex codes, raw `px`/`ms` values, inline color strings)
MUST be normalized to semantic design token names in `architecture/design-tokens.md` and
referenced by token name in feature leaves.

Unclassified fragments from Step 2 that were not resolved in gap questioning MUST be placed in
the README `Open Questions` section.

---

## Step 7 — Assumption Audit

After generation, present a consolidated assumption log to the user:

- List every item marked as assumption during gap resolution.
- For each: state the assumption, the feature/section it affects, and the suggested validation
  method (user interview, A/B test, prototype, data pull).

This log becomes the PRD's `Open Questions` and `Risks` sections if not already populated.
