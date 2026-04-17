# Stage 1: Positioning & Messaging

This file contains instructions for generating the positioning and messaging document. It is the first stage — all subsequent stages build on its output.

---

## Context Gathering

### Chained Mode (PRD exists)
Extract from PRD:
- **Problem statement** — from `README.md` Problem & Goals section
- **Target personas** — from `README.md` Users section and `journeys/*.md` persona fields
- **Competitive landscape** — from `README.md` Competitive Landscape section
- **Key features** — from `features/*.md` feature names and descriptions
- **Vision** — from `README.md` header and vision statement

### Standalone Mode
These are already gathered by SKILL.md's standalone gap-fill. Use those answers.

## Gap-Fill Questions

Ask one at a time, only if not already answered by PRD or prior input:

1. "What is the single most important pain point your product solves?"
2. "How would you describe your target user in one sentence? (job title, company size, situation)"
3. "Who are your top 2-3 competitors? For each, what do they do well and where do they fall short?"
   - If PRD has a competitive landscape, present it and ask: "Is this still accurate? Anything to add?"
4. "What makes your product different? Pick the closest: (A) Significantly cheaper (B) Much easier to use (C) Solves a problem others don't (D) Better for a specific niche (E) Superior technology/performance (F) Multiple of these — describe"
5. "How do you want your brand to feel? (A) Professional & trustworthy (B) Fun & approachable (C) Technical & cutting-edge (D) Simple & minimal (E) Other — describe"

Stop asking when you have enough to write the positioning doc. Not every question needs to be asked — skip questions that are already answered from context.

## Document Generation

Generate `positioning.md` with these sections:

### Problem Statement
2-3 sentences describing the problem in the user's language. No jargon. A target user reading this should think "yes, that's exactly my problem."

### Target Persona(s)
For each persona (1-3 max):
- **Who:** Job title, company size, situation
- **Pain:** Their specific frustration
- **Current solution:** What they use today and why it's inadequate
- **Desired outcome:** What success looks like for them

### Value Proposition
One sentence: "We help [persona] achieve [outcome] by [how], unlike [alternative] which [limitation]."

### Elevator Pitch
3-4 sentences that could be delivered in 30 seconds. Covers: problem, solution, why now, why us.

### Taglines
Three variants:
1. **Functional** — describes what it does ("Project management for remote teams")
2. **Benefit-driven** — describes the outcome ("Ship projects 2x faster")
3. **Emotional** — connects to feeling ("Finally, project management that doesn't suck")

### Competitive Matrix
Table comparing your product against 2-3 competitors across 4-6 key dimensions. Use checkmarks, partial marks, and X marks. Include a "Why we win" row at the bottom.

| Dimension | Your Product | Competitor A | Competitor B |
|-----------|-------------|--------------|--------------|
| [Key feature 1] | ... | ... | ... |
| [Key feature 2] | ... | ... | ... |
| ... | ... | ... | ... |
| **Why we win** | [summary] | | |

### Key Differentiators
Bullet list of 3-5 specific, defensible differentiators. Each should be:
- Specific (not "better UX" but "setup in under 2 minutes vs. 30-minute onboarding")
- Verifiable (a user can confirm it's true)
- Meaningful (it matters to the target persona)

### Messaging Don'ts
3-5 things to avoid in marketing copy for this specific product (e.g., "Don't compare to Enterprise tools — our audience doesn't use them", "Don't lead with technical architecture — lead with time saved").

## Output

Write to `gtm/positioning.md`. Present a summary to the user and enter the review gate (as defined in SKILL.md).
