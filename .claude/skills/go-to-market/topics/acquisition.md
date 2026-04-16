# Stage 7: Customer Acquisition Playbook

This file contains instructions for generating the customer acquisition playbook. It is the final strategy stage, drawing on all prior stages to create an actionable guide for acquiring and retaining customers.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — personas, value prop, messaging
- `gtm/pricing-strategy.md` — free-to-paid boundary, upgrade triggers
- `gtm/channels.md` — ranked channels, community targets
- `gtm/launch-plan.md` — launch phases, timeline
- `gtm/landing-page-spec.md` — CTA strategy, onboarding entry points
- `gtm/metrics.md` — KPIs, activation definition, tracking plan

### Chained Mode (PRD exists)

Re-read these PRD sections before generating (do not rely solely on prior `gtm/` files):
- `journeys/*.md` — onboarding flow, first-run experience, activation moments
- `features/*.md` — viral/sharing features, referral mechanics, upgrade triggers

## Gap-Fill Questions

Minimal at this stage — most context comes from prior stages. Ask only if unclear:

1. "How should new users first experience the product? (A) Self-serve — sign up and start immediately (B) Guided onboarding — step-by-step walkthrough (C) White-glove — personal setup call for each user (D) Depends on tier — self-serve for free, guided for paid"
2. "What's your capacity for personal outreach? (A) I can do 5-10 personal touches per week (B) I can handle 10-30 per week (C) Very limited — needs to be mostly automated (D) I have a team member for this"

## Document Generation

Generate `acquisition-playbook.md` with these sections:

### Acquisition Funnel Overview
Visual description of the funnel for this product:
```
[Awareness] → [Interest] → [Signup] → [Activation] → [Retention] → [Revenue] → [Referral]
```
For each stage, 1 sentence on what happens and what the user experiences.

### Top-of-Funnel Tactics
For each of the top 3 channels (from `channels.md`):
- **Channel:** [name]
- **Tactic:** Specific action to drive awareness
- **Content:** What to create/post (specific to this product)
- **Frequency:** How often
- **Expected volume:** Realistic traffic/leads estimate

### Onboarding Flow Design
Step-by-step onboarding from signup to activation:

| Step | User Action | System Response | Goal |
|------|------------|----------------|------|
| 1 | Signs up | Welcome screen with 3-step overview | Set expectations |
| 2 | [action] | [response] | [goal] |
| ... | ... | ... | ... |

Design principles:
- Time to value: user should experience core value within [X] minutes
- Progressive disclosure: don't show everything at once
- Clear next action: every screen has one obvious thing to do

### Activation Checklist
Define the "aha moment" — the actions that predict long-term retention:

| Action | Why It Matters | How to Encourage |
|--------|---------------|-----------------|
| [action 1] | [correlation with retention] | [nudge strategy] |
| [action 2] | ... | ... |
| ... | ... | ... |

**Activation target:** [X]% of signups should complete [Y] actions within [Z] days.

### Retention Hooks
Mechanisms that bring users back:

| Hook | Type | Trigger | Expected Effect |
|------|------|---------|----------------|
| [hook] | [email/push/in-app] | [when/what triggers it] | [why it brings them back] |
| ... | ... | ... | ... |

Types of hooks:
- **Habit hooks:** Regular triggers (daily digest, weekly summary)
- **Social hooks:** Activity from teammates or community
- **Progress hooks:** Milestones, streaks, achievements
- **Value hooks:** New content, features, or data relevant to them

### Churn Signals & Prevention
Early warning signs that a user is about to churn, and what to do:

| Signal | Detection | Intervention |
|--------|----------|-------------|
| No login for 7 days | Analytics event absence | Re-engagement email (see templates) |
| [signal] | [how to detect] | [what to do] |
| ... | ... | ... |

### Feedback Collection Plan
How to systematically collect user feedback:

| Method | When | Who | What to Ask |
|--------|------|-----|------------|
| In-app survey (NPS) | Day 14 after signup | All active users | "How likely are you to recommend?" + open text |
| User interview | First 30 days | First 10-20 users | Discovery: what brought them, what's working, what's missing |
| Churn survey | On cancellation | Churned users | "What's the main reason you're leaving?" (multiple choice) |
| Feature request tracking | Ongoing | All users | In-app feedback widget or email |

## Output

Write to `{output_dir}/acquisition-playbook.md`. Present a summary to the user and enter the review gate.
