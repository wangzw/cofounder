# Document-Based Mode — PRD Analysis

This file contains instructions for document-based PRD analysis (when a notes/requirements document is provided as input). It supplements `questioning-phases.md`.

---

## Document-Based Mode

Read document → summarize understanding → check gaps against list below → ask targeted questions → generate

**Gap checklist for documents** — scan for missing or vague coverage in these areas:

- [ ] Personas defined with clear goals?
- [ ] User journeys (happy path + error/alternative paths) explicitly described (or clearly implied with enough detail to write acceptance criteria)?
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
- [ ] Architecture-level i18n baseline defined — frontend (languages, default language, RTL, key convention, format rules) and/or backend (locale resolution, error message localization, timezone handling)?
- [ ] Frontend internationalization requirements stated per user-facing feature (languages, keys, format rules)?
- [ ] Backend internationalization requirements stated per feature returning user-visible text (locale-dependent messages, locale resolution strategy)?
- [ ] Responsive behavior described per breakpoint for user-facing features?
- [ ] Prototype feedback documented and incorporated into specs and design tokens?
- [ ] Prototype source code archived (prototypes/src/{feature-slug}/) and visual records archived (prototypes/screenshots/{feature-slug}/ — browser screenshots for web, teatest golden files for TUI)?
- [ ] Authorization / permission model described (if multi-role)?
- [ ] Privacy / compliance requirements stated (if handling personal data)?
- [ ] Notification requirements captured (if the product notifies users)?
- [ ] Technical stack and integration points specified?
- [ ] Non-functional requirements (performance, security, i18n) stated?
- [ ] Shared conventions (API format, error handling, testing strategy) explicitly defined (or derivable from the document without assumptions)?
- [ ] Coding conventions defined (code organization, naming, interface design, dependency wiring, error propagation, logging, config access, concurrency)?
- [ ] Test isolation policies defined (resource isolation, no global mutable state, random ports, temp dirs, process cleanup, race detection, timeouts, directory independence)?
- [ ] Development workflow defined (prerequisites, local setup, CI gates, build matrix, release process, dependency management)?
- [ ] Security coding policy defined (input validation, secret handling, dependency scanning, injection prevention, auth enforcement)?
- [ ] Backward compatibility policy defined (API versioning, breaking changes, data schema evolution — or N/A for v1)?
- [ ] Git & Branch Strategy defined (naming, merge strategy, protection rules, PR conventions, commit format)?
- [ ] Code review policy defined (dimensions, approvals, SLA, automated vs human, severity levels)?
- [ ] Observability requirements defined at policy level (mandatory events, health checks, metrics/SLOs, alerting, audit trail)?
- [ ] Performance testing policy defined (regression detection, budgets, load testing, resource limits)?
- [ ] Development Infrastructure feature present (auto-derived from convention sections) with concrete deliverables (linter config, CI pipeline, pre-commit hooks, test helpers, security scanning, AI agent instruction files, etc.)?
- [ ] AI agent configuration defined (instruction files, structure policy, convention references, maintenance policy, context budget)?
- [ ] Deployment architecture defined (environments, local dev setup, environment parity, config management, data migration, CD pipeline, environment isolation, IaC)?
- [ ] Deployment Infrastructure feature present (auto-derived from Deployment Architecture) with concrete deliverables (env setup, config templates, migration tooling, CD pipeline, isolation config)?
- [ ] Risks or open questions acknowledged?
- [ ] Priority rationale (not just labels) provided?
- [ ] Edge cases testable (Given/When/Then, not vague descriptions)?
- [ ] Non-functional requirements stated per feature (not just globally)?
- [ ] Test data requirements inferrable for non-trivial features?
- [ ] E2E test scenarios inferrable from journey flows (happy + error paths)?

## Remediation

For each gap identified above, use the corresponding phase and deep-dive in `questioning-phases.md` to fill it:

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

Run the relevant questioning phase for each gap — do not attempt to fill gaps without the structured deep-dive guidance.
