---
issue_id: R1-V-011-ADV
round: 1
file: common/templates/module-template.md
criterion_id: CR-L11
severity: important
source: adversarial-reviewer
reviewer_variant: adversarial
status: new
---

# Frontend / Backend / Testing "deep-dive" content from legacy was preserved but the questioning workflow was lost

## Attack angle

Coverage of legacy concepts (attack vector 12). The legacy `system-design.backup/` had a structured Step 3 questioning phase (Frontend Implementation Architecture deep-dive, Backend i18n Implementation deep-dive, Testing deep-dive — see `system-design.backup/generate-mode.md` lines 10-16). The new skill kept the SECTIONS in `module-template.md` (UI Architecture, Backend i18n Implementation, Test Strategy) but dropped the QUESTIONING that ensures those sections get filled with substantive content.

## Evidence

Legacy `system-design.backup/generate-mode.md` line 16:
> Testing: test pyramid allocation, module test isolation strategy, external dependency test approach, test data management (see Testing Deep-Dive below)

And lines 12-13:
> UI / Frontend implementation architecture: ... prototype assessment, view-to-module mapping, routing implementation, ... (see Frontend Implementation Architecture deep-dive below)
> Backend i18n implementation: ... locale resolution middleware placement, message catalog structure ... (see Backend i18n Implementation deep-dive below)

These deep-dives were targeted dialog flows the consultant ran with the user before the planner ran. They produced concrete answers that filled module-template's UI Architecture / Backend i18n / Test Strategy sections.

New skill — `generate/from-scratch.md`:
- Step 4 domain-consultant clarifies only: PRD path, has-APIs, output directory, ambiguities. No questioning of frontend approach, backend i18n approach, or testing strategy.
- Step 5 planner reads PRD architecture/*.md and clarification.yml. Planner does not have a "questioning" mode — its sole output is `plan.md` with module decomposition.
- Steps 6-12: writers, lint, review, summarizer, judge. None re-questions the user.

`generate/domain-consultant-subagent.md` lines 81-90 enumerates the consultant's clarification scope:
> 1. PRD path
> 2. has-APIs
> 3. Output directory
> 4. Any other ambiguities

No mention of frontend / backend i18n / testing.

## Concrete failure

A writer produces a frontend module M-NNN.md. It MUST fill UI Architecture (component tree, routing, state management, key interactions, performance, a11y, i18n implementation, prototype reuse) per template lines 410-487. The writer reads:
- PRD feature file (which describes user-visible behavior, not implementation choices)
- module-template.md (which has placeholders for these decisions)
- Plan.md (which gives a one-line description)

Nowhere in the writer's input is there a project-level decision on, e.g., "use React + Zustand vs Vue + Pinia" or "use go-i18n message catalog vs nicksnyder/go-i18n". The writer makes ad-hoc choices per module → adjacent modules disagree on stack → CR-D02 (consistency) fires across rows but only if the cross-reviewer notices. CR-D08 (PRD interaction design alignment) does NOT cover stack-internal decisions.

## Severity reasoning

`important`: the design will be produced (the sections will be filled), but the choices will be inconsistent and ungrounded. Coding agents downstream will get conflicting stack signals. This is fixable manually but the skill is supposed to be unattended.

## Fix

Either:

(a) Add to `generate/domain-consultant-subagent.md` Dialogue Protocol a frontend-architecture, backend-i18n, and testing deep-dive when triggered:
- Frontend deep-dive trigger: PRD has any user-facing journey OR `architecture/frontend.md` exists.
- Backend i18n deep-dive trigger: PRD has multiple locales OR `architecture/i18n.md` exists.
- Testing deep-dive trigger: always.

Each deep-dive produces a key in `clarification.yml` (e.g. `frontend_stack: react+zustand`, `i18n_strategy: go-i18n+namespace-per-module`, `test_pyramid: 70/20/10`) that writers consume.

(b) Push the responsibility to a NEW step "Step 4.5 — Stack Decision" before the planner. Stack decisions go into `clarification.yml` as a `stack:` block. Writers MUST consume `stack:` and include it in every module's Relevant Conventions section verbatim.

Without one of these, the new skill silently loses the legacy's most-loaded decision point: "what tech stack are we using?"
