# Stage 2: Pricing Strategy

This file contains instructions for generating the pricing strategy document. It builds on the positioning (Stage 1) and references `references/pricing-models.md` for domain knowledge.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` (generated in Stage 1) — personas, differentiators, competitive matrix
- `references/pricing-models.md` — pricing model comparison, tier design principles, price point guidelines

## Context Gathering

### Chained Mode (PRD exists)
Extract from PRD:
- **Feature list with priorities** — from `features/*.md` (P0, P1, P2 tags help define tier boundaries)
- **Usage patterns** — from `journeys/*.md` (frequency, depth of use per persona)
- **Technical constraints** — from `architecture.md` (any infrastructure cost implications for pricing: compute, storage, API limits)

### From Stage 1 (Positioning)
- **Target personas** — who are we pricing for?
- **Competitors** — what are their price points?
- **Differentiators** — what justifies premium or discount positioning?

## Gap-Fill Questions

Ask one at a time, only if not already answered:

1. "What pricing model are you leaning toward? (A) Freemium — free tier + paid (B) Free trial — full access for limited time (C) Paid only — no free option (D) Usage-based — pay per consumption (E) Not sure — help me decide"
   - If (E): use `references/pricing-models.md` Model Comparison to recommend based on product type and target persona
2. "What's your primary revenue goal for the first 6 months? (A) Maximize user adoption (grow fast, monetize later) (B) Revenue from day one (sustainable growth) (C) Validate willingness to pay (testing pricing) (D) Not sure"
3. "Do you know your competitors' pricing? If so, share what you know."
   - Use this to anchor price point recommendations
4. "Is there a natural usage metric to price on? (e.g., number of projects, API calls, team members, storage) (A) Yes — [describe] (B) Not really — feature-based tiers make more sense (C) Not sure"

## Document Generation

Generate `pricing-strategy.md` with these sections:

### Pricing Model
Which model and why. Reference the persona from positioning — explain why this model fits their buying behavior. 2-3 sentences.

### Tier Structure
Table format:

| | Free / Starter | Pro | Enterprise (if applicable) |
|---|---|---|---|
| **Target user** | [persona] | [persona] | [persona] |
| **Price** | $0 | $X/mo ($Y/yr) | $Z/mo or custom |
| **Feature 1** | [scope] | [scope] | [scope] |
| **Feature 2** | [scope] | [scope] | [scope] |
| ... | ... | ... | ... |
| **Support** | [level] | [level] | [level] |
| **Limits** | [limits] | [limits] | [limits] |

### Price Point Justification
For each paid tier:
- What value does it deliver? (quantify if possible)
- How does this compare to competitors?
- What's the implied value-to-price ratio?

### Free-to-Paid Boundary
Explicitly define:
- What is included in free (must deliver real standalone value)
- What triggers the upgrade need (positive signal, not artificial limit)
- Expected conversion rate assumption (typical SaaS: 2-5% freemium, 10-25% trial)

### Upgrade Triggers
List 3-5 specific moments when a free user naturally needs to upgrade. For each:
- **Trigger:** What happens (e.g., "user invites a 4th team member")
- **Gate:** What they hit (e.g., "free tier limited to 3 collaborators")
- **Message:** What they see (e.g., "Upgrade to Pro to invite unlimited team members")

### Competitor Pricing Comparison
Table comparing your pricing vs. 2-3 competitors:

| | Your Product | Competitor A | Competitor B |
|---|---|---|---|
| Free tier | [Y/N + scope] | [Y/N + scope] | [Y/N + scope] |
| Entry price | $X/mo | $X/mo | $X/mo |
| Mid-tier price | $X/mo | $X/mo | $X/mo |
| Enterprise | [pricing model] | [pricing model] | [pricing model] |
| **Positioning** | [cheaper/similar/premium] | | |

### Anti-Patterns to Avoid
3-5 pricing mistakes specific to this product (sourced from `references/pricing-models.md` Anti-Patterns section, filtered for relevance).

## Output

Write to `gtm/pricing-strategy.md`. Present a summary to the user and enter the review gate.
