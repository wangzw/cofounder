# SaaS Pricing Models Reference

This file provides domain knowledge for the pricing strategy stage. The skill references these patterns when generating pricing recommendations.

---

## Model Comparison

| Model | How It Works | Best For | Risk |
|-------|-------------|----------|------|
| Freemium | Free tier with limited features, paid tiers unlock more | Products with viral/network effects, low marginal cost per user | Free users never convert; support costs for non-paying users |
| Free Trial | Full access for limited time (7-30 days), then paid | Products where value is clear once experienced; complex products | Users don't activate during trial; long trials delay revenue |
| Paid Only | No free option, pay from day one | Niche B2B with clear ROI; products replacing expensive alternatives | Higher acquisition friction; harder to get initial traction |
| Usage-Based | Pay per unit of consumption (API calls, storage, seats) | Infrastructure/API products; products with variable usage | Revenue unpredictable; hard to forecast; sticker shock risk |
| Hybrid | Freemium or trial + usage-based components | Products with both casual and power users | Pricing complexity; harder to communicate |
| Per-Seat | Fixed price per user per month/year | Team collaboration tools; products where value scales with team size | Seat gaming (shared accounts); discourages adoption |
| Flat Rate | Single price, all features included | Simple products; products targeting simplicity as differentiator | Leaves money on the table from high-value users |

## Tier Design Principles

### The 3-Tier Standard
Most SaaS products use 3 tiers. Each tier should have a clear target persona:

| Tier | Target | Purpose |
|------|--------|---------|
| Free / Starter | Individual, evaluator | Reduce friction, demonstrate value, feed funnel |
| Pro / Growth | Small team, serious user | Core revenue driver, most users land here |
| Enterprise / Scale | Large org, high-value | Revenue maximizer, custom needs |

### Free-to-Paid Boundary
The boundary between free and paid is the most critical pricing decision. Principles:
- Free tier must deliver real value (not a crippled demo)
- Free tier must naturally create desire for paid features
- The trigger to upgrade should be a **positive signal** (growing usage, team growth) not a **negative one** (hitting arbitrary limits)

### Upgrade Triggers (What Makes Users Pay)
- **Feature gates:** Key features locked behind paid tier (e.g., advanced analytics, integrations, custom branding)
- **Usage limits:** Quantity limits on free tier (e.g., 3 projects, 100 API calls/month, 1GB storage)
- **Collaboration limits:** Free for individuals, paid for teams (e.g., sharing, multiplayer, team management)
- **Support tier:** Free = community/docs, Paid = email/chat, Enterprise = dedicated/SLA

## Price Point Guidelines

### Anchoring to Value
- Price should be 10-20% of the value delivered (if your tool saves $1000/month, charge $100-200)
- Use competitor pricing as anchoring reference, not as ceiling
- Annual discount of 15-20% is standard (incentivizes commitment, improves cash flow)

### Common Price Ranges (SaaS benchmarks — verify current rates at launch time)
- **Developer tools:** $10-30/month individual, $20-50/seat/month team
- **Productivity SaaS:** $5-15/month individual, $8-25/seat/month team
- **B2B Platform:** $50-200/month starter, $200-500/month growth, custom enterprise
- **API/Infrastructure:** Usage-based, typically $0.001-0.01 per unit with free tier

## Anti-Patterns to Flag

- **Too many tiers** (>4) — confuses buyers, slows decision-making
- **Feature-gated basics** — locking essential features makes free tier feel hostile
- **No annual option** — missing easy revenue optimization
- **Identical competitor pricing** — signals no differentiation
- **Pricing page hidden** — transparency builds trust, especially for SMB/indie buyers
- **Enterprise-only pricing** — "Contact sales" as the only option repels solo founders and small teams
