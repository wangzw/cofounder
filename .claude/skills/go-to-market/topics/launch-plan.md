# Stage 4: Launch Plan

This file contains instructions for generating the phased launch plan. It builds on positioning, pricing, and channels (Stages 1-3), and references `references/launch-timeline-examples.md` for timeline templates.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — personas, messaging
- `gtm/pricing-strategy.md` — pricing model, tiers
- `gtm/channels.md` — ranked channels, per-channel playbooks
- `references/launch-timeline-examples.md` — timeline templates, go/no-go criteria, phase definitions

## Gap-Fill Questions

Ask one at a time, only if not already answered:

1. "What's your target launch date? (A) ASAP — product is ready (B) Within 2 weeks (C) Within 1 month (D) Within 2-3 months (E) No specific date — flexible"
2. "Do you want a beta/waitlist phase before public launch? (A) Yes — I want early feedback before going public (B) No — go straight to public launch (C) Already done — I have beta users (D) Not sure"
3. "How many people are working on the launch? (A) Just me (B) 2-3 people (C) 4-5 people (D) 6+ people"
4. "What does launch success look like for week 1? (A) Any signups — proving there's interest (B) 50-100 signups (C) 100-500 signups (D) First paying customer (E) Specific number — [specify]"

## Document Generation

Select the closest timeline template from `references/launch-timeline-examples.md` based on team size and budget:
- Solo founder, $0 → Template A (Lean Launch)
- Small team, budget → Template B (Small Team Launch)
- Waitlist phase → Template C + A or B

Adapt the template to this specific product, incorporating the channel playbooks from Stage 3.

Generate `launch-plan.md` with these sections:

### Launch Strategy Summary
3-4 sentences describing the overall launch approach: what type (lean, waitlist, big bang), why it fits this product, and what success looks like.

### Go/No-Go Criteria
Adapt from `references/launch-timeline-examples.md` Go/No-Go Criteria table. Customize thresholds to this product:

| Criterion | Threshold | Current Status |
|-----------|-----------|----------------|
| [criterion] | [specific threshold] | [ ] Ready / [ ] Not ready |
| ... | ... | ... |

### Pre-Launch Phase
**Duration:** [X weeks]
**Goal:** [specific goal]

Week-by-week table:
| Week | Actions | Owner | Deliverable |
|------|---------|-------|-------------|
| Week -N | [actions] | [who] | [what's done] |
| ... | ... | ... | ... |

### Launch Week
Day-by-day table:
| Day | Actions | Owner | Channels |
|-----|---------|-------|----------|
| Monday | [actions] | [who] | [which channels] |
| ... | ... | ... | ... |

### Post-Launch Phase (30 days)
Week-by-week table:
| Week | Focus | Actions | Key Metric |
|------|-------|---------|------------|
| Week 1 | [focus] | [actions] | [metric] |
| ... | ... | ... | ... |

### Task Owners (if team > 1)
| Person/Role | Responsibilities |
|-------------|-----------------|
| [role] | [what they own] |
| ... | ... |

### Risk Mitigation
3-5 launch-specific risks and mitigation:
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | [L/M/H] | [L/M/H] | [action] |

## Output

Write to `gtm/launch-plan.md`. Present a summary to the user and enter the review gate.
