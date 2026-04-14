# Stage 6: Metrics & Success Criteria

This file contains instructions for generating the metrics and success criteria document. It draws from all prior stages to define measurable goals for each launch phase.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — personas (who are we measuring?)
- `gtm/pricing-strategy.md` — pricing model (determines revenue metrics)
- `gtm/channels.md` — channels (determines acquisition metrics)
- `gtm/launch-plan.md` — phases and timeline (determines when to measure what)
- `gtm/landing-page-spec.md` — CTA strategy and conversion design (determines conversion metrics)

## Gap-Fill Questions

Ask one at a time, only if not already answered:

1. "What analytics tools do you plan to use? (A) Google Analytics (B) Mixpanel (C) PostHog (D) Amplitude (E) Plausible/Simple Analytics (F) None yet — recommend one (G) Other — specify"
   - If (F): Recommend based on product type and budget. PostHog for self-hosted/privacy-conscious, Mixpanel for product analytics focus, Google Analytics for basic web metrics.
2. "What does 'activation' mean for your product — when has a user gotten real value? (A) Completed onboarding (B) Used the core feature once (C) Created their first [item] (D) Invited a team member (E) Other — describe"
3. "Do you have revenue targets? (A) Yes — $[X] MRR by month 3 (B) No specific target — just want to see traction (C) Revenue isn't the goal yet — focus on adoption"

## Document Generation

Generate `metrics.md` with these sections:

### Metric Framework
Brief explanation of the metrics framework used. AARRR (Acquisition, Activation, Retention, Revenue, Referral) adapted to this product's stage:

| Stage | Metric | Definition | Tool |
|-------|--------|------------|------|
| Acquisition | [metric] | [definition] | [tool] |
| Activation | [metric] | [definition] | [tool] |
| Retention | [metric] | [definition] | [tool] |
| Revenue | [metric] | [definition] | [tool] |
| Referral | [metric] | [definition] | [tool] |

### KPIs by Launch Phase

#### Pre-Launch
| KPI | Target | How to Measure |
|-----|--------|---------------|
| Waitlist signups | [target] | [tool/method] |
| Beta user feedback score | [target] | [tool/method] |
| ... | ... | ... |

#### Launch Week (Week 1)
| KPI | Target | How to Measure |
|-----|--------|---------------|
| Total signups | [target] | [tool/method] |
| Activation rate | [target %] | [tool/method] |
| Traffic sources | [breakdown] | [tool/method] |
| ... | ... | ... |

#### Post-Launch Month 1
| KPI | Target | How to Measure |
|-----|--------|---------------|
| D7 retention | [target %] | [tool/method] |
| Activation rate | [target %] | [tool/method] |
| NPS score | [target] | [tool/method] |
| MRR (if paid) | [target] | [tool/method] |
| ... | ... | ... |

#### Month 3
| KPI | Target | How to Measure |
|-----|--------|---------------|
| Monthly active users | [target] | [tool/method] |
| D30 retention | [target %] | [tool/method] |
| MRR | [target] | [tool/method] |
| Churn rate | [target %] | [tool/method] |
| Channel ROI | [per-channel breakdown] | [tool/method] |
| ... | ... | ... |

### Tracking Plan
Events that need to be instrumented:

| Event Name | Trigger | Properties | Stage |
|-----------|---------|------------|-------|
| `signup_completed` | User finishes registration | source, plan | Acquisition |
| `onboarding_completed` | User finishes onboarding | time_to_complete | Activation |
| `core_action_performed` | User does the key action | [specifics] | Activation |
| `upgrade_initiated` | User starts upgrade flow | from_plan, to_plan | Revenue |
| `invite_sent` | User invites someone | method | Referral |
| ... | ... | ... | ... |

### Alerting Thresholds
Metrics that should trigger action if they cross a threshold:

| Metric | Alert If | Action |
|--------|---------|--------|
| Activation rate | < [X%] for 3 consecutive days | Investigate onboarding funnel, user interviews |
| Day-1 retention | < [X%] | Review first-run experience |
| Churn rate | > [X%] monthly | Churn interviews, feature gap analysis |
| Error rate | > [X%] of sessions | Engineering triage |

## Output

Write to `gtm/metrics.md`. Present a summary to the user and enter the review gate.
