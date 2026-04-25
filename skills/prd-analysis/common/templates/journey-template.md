## Template Usage Notes

This template is the canonical scaffold for a single PRD journey leaf (`journeys/J-NNN-{slug}.md`).

1. **Every section is REQUIRED.** Do not omit any section. Sections with no content yet MUST contain a placeholder comment explaining why, not a silent omission. The only exception is "Open Questions," which may be `None` when fully resolved.
2. **Persona block is self-contained (CR-L10).** Even if a separate `personas/` file exists for this persona, the full Persona block (Name, Role, Context, Motivation, Success Metric) MUST be copied inline into this journey leaf. A coding agent or reviewer reading this file MUST NOT need to open any other file to understand who the persona is.
3. **Every touchpoint MUST have an Interaction Mode (CR-L13).** The value MUST be one of the canonical glossary enumeration values: `click`, `form`, `drag`, `keyboard`, `scroll`, `hover`, `swipe`, `voice`, `scan`. No other values are permitted. Do not leave the cell blank or write "TBD."
4. **Every Mapped Feature must reverse-map (CR-L03).** Each feature listed in the frontmatter `mapped_features` array MUST appear in the "Mapped Features" table below with at least one touchpoint reference and a role. Conversely, the feature leaf's frontmatter `journeys:` field MUST include this journey's ID (J-NNN). The mapping is bidirectional — verify both directions before marking the journey accepted.

---

```markdown
---
id: J-NNN
slug: {journey-slug}
title: {Journey Title}
persona: {persona-name}
goal: {one-sentence outcome the persona pursues}
priority: P0 | P1 | P2 | P3
status: draft | accepted | implemented | deprecated
mapped_features: [F-NNN, F-MMM]
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---

# J-NNN: {Journey Title}

## Persona
**Name**: {Persona Name}
**Role**: {role / job title}
**Context**: {1-2 sentences describing where + when this persona uses the product}
**Motivation**: {what drives them — explicit, named}
**Success Metric**: {how they measure their own success in this journey}

{Self-contained per CR-L10 — even if a separate persona file exists, the journey leaf MUST inline this block.}

## Goal
{1-2 paragraphs explaining the outcome the persona pursues + why it matters.}

## Pre-conditions
- {what must be true before journey starts}
- {persona state, system state, environment}

## Touchpoint Table

| Step | Stage | Screen / View | Action | Interaction Mode | System Response | Pain Point |
|------|-------|---------------|--------|------------------|-----------------|------------|
| J-NNN.1 | {stage} | {screen} | {action} | {mode per glossary: click/form/drag/keyboard/scroll/hover/swipe/voice/scan} | {system response} | {pain or None} |
| J-NNN.2 | ... | ... | ... | ... | ... | ... |

{Notes:}
- Touchpoint IDs use J-NNN.<step-num>; step numbers are sequential starting at 1.
- Interaction mode REQUIRED per CR-L13 (one of the glossary values).
- Pain point: state explicitly or write `None`. Empty cells fail CR-L02.

## Mapped Features

| Feature ID | Touchpoint | Role |
|------------|------------|------|
| F-NNN | J-NNN.2 | trigger |
| F-MMM | J-NNN.5 | downstream |

{Every feature listed in frontmatter `mapped_features` MUST appear in this table with the touchpoint(s) it triggers + role (trigger | downstream | passive).}

## Post-conditions
- {persona state after journey completes successfully}
- {system state after journey completes}

## Failure / Off-Path Handling
{For each touchpoint with pain point ≠ None, describe what happens when the user errors or abandons. Required for CR-L02 journey-causal-flow completeness.}

| Touchpoint | Failure Mode | Recovery |
|------------|--------------|----------|
| J-NNN.3 | User leaves the form | Save draft; resume on return |

## Cross-Journey Connections
- **Hand-off to**: {other journey ID + the touchpoint that triggers the hand-off, or "None"}
- **Hand-off from**: {other journey ID + touchpoint, or "None"}
- **Shared pain points with**: {comma-separated journey IDs sharing recurring pain — feeds README cross-journey-patterns section}

## Open Questions
- {questions to resolve before journey is accepted}

## Change Log
- YYYY-MM-DD: created
```
