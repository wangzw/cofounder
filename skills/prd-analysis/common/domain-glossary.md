# Domain Glossary — prd-analysis

This file defines domain-specific terms used by the domain-consultant sub-agent to disambiguate user intent during the clarification phase. The `glossary-probe.sh` script reads this file to compute `glossary_hit`, which the orchestrator uses to decide whether to dispatch the domain-consultant.

| Term | Definition | Aliases |
|------|-----------|---------|
| `feature` | A bounded user-facing capability with its own acceptance criteria and ID `F-NNN` | epic, capability, story-set, user story |
| `journey` | A persona's end-to-end touchpoint sequence with ID `J-NNN` | flow, user flow, scenario, use case |
| `touchpoint` | One discrete interaction row in a journey's touchpoint table, defined by screen, action, and system response | step, interaction, moment |
| `persona` | A named user archetype with goals, frequency, and pain points driving the product design | user type, role, actor |
| `cross-journey pattern` | A recurring theme observed across multiple user journeys — shared pain points, repeated touchpoints, or common infrastructure needs | shared concern, cross-cutting concern |
| `tombstone` | A minimal file marking a deprecated feature or journey in evolve-mode, containing deprecation reason and replacement reference | deprecated stub, deprecation marker |
| `interaction mode` | The primary input mechanism at a touchpoint: `click`, `form`, `drag`, `keyboard`, `scroll`, `hover`, `swipe`, `voice`, or `scan` | input type, input method |
| `design token` | A named value (color, spacing, typography, motion) representing a design decision; PRD defines token semantics and values | token, style variable, design variable |
| `acceptance criterion` | A testable condition that must be true for a feature to be considered complete | AC, acceptance condition, done criterion |
| `PRD` | Product Requirements Document — the primary artifact produced by this skill; captures journeys, features, personas, and design tokens | product spec, requirements doc |
