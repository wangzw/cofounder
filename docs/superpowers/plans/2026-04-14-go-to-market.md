# `/go-to-market` Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a DevForge skill that guides solo founders and small startup teams from finished product to market-ready launch through a sequential 7-stage wizard producing GTM strategy documents and actionable templates.

**Architecture:** The skill follows DevForge's three-layer pattern: `SKILL.md` (router + mode detection + process flow) dispatches to `topics/` files (stage-specific instructions) which reference `references/` files (domain knowledge). Output is a `gtm/` directory with 7 strategy documents + a `templates/` subdirectory of ready-to-use marketing assets.

**Tech Stack:** Markdown skill files (no runtime code). Follows patterns established by `/prd-analysis` and `/system-design` skills.

---

### Task 1: Create Directory Structure

**Files:**
- Create: `.claude/skills/go-to-market/SKILL.md` (placeholder)
- Create: `.claude/skills/go-to-market/topics/` (directory)
- Create: `.claude/skills/go-to-market/references/` (directory)

- [ ] **Step 1: Create the skill directory and subdirectories**

Run:
```bash
mkdir -p .claude/skills/go-to-market/topics .claude/skills/go-to-market/references
```

- [ ] **Step 2: Create a minimal SKILL.md to verify discovery**

Write `.claude/skills/go-to-market/SKILL.md`:

```markdown
---
name: go-to-market
description: "Use when the user needs to create a Go-to-Market strategy, launch plan, pricing strategy, or marketing assets for their product. Supports chained mode (reads existing PRD) and standalone mode (interactive Q&A). Triggers: /go-to-market, 'go to market', 'launch strategy', 'pricing strategy', 'GTM plan', 'launch plan'."
---

# Go-to-Market — From Product to Market-Ready Launch

(Content will be added in Task 3)
```

- [ ] **Step 3: Verify directory structure**

Run:
```bash
find .claude/skills/go-to-market -type f -o -type d | sort
```

Expected:
```
.claude/skills/go-to-market
.claude/skills/go-to-market/references
.claude/skills/go-to-market/SKILL.md
.claude/skills/go-to-market/topics
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/go-to-market/
git commit -m "feat(go-to-market): scaffold skill directory structure"
```

---

### Task 2: Write Reference Files

These provide domain knowledge that topic files reference. Write them first so topic files can reference specific sections.

**Files:**
- Create: `.claude/skills/go-to-market/references/pricing-models.md`
- Create: `.claude/skills/go-to-market/references/channel-playbooks.md`
- Create: `.claude/skills/go-to-market/references/launch-timeline-examples.md`

- [ ] **Step 1: Write pricing-models.md**

Write `.claude/skills/go-to-market/references/pricing-models.md`:

```markdown
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

### Common Price Ranges (2024-2025 SaaS benchmarks)
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
```

- [ ] **Step 2: Write channel-playbooks.md**

Write `.claude/skills/go-to-market/references/channel-playbooks.md`:

```markdown
# Distribution Channel Playbooks Reference

This file provides domain knowledge for the distribution channels stage. The skill references these playbooks when generating channel-specific strategies.

---

## Channel Matrix

| Channel | Effort | Time to Impact | Cost | Best For |
|---------|--------|---------------|------|----------|
| Product Hunt | Medium | Immediate (launch day) | Free | B2C, developer tools, design tools |
| Hacker News (Show HN) | Low | Immediate | Free | Developer tools, open source, technical products |
| Reddit / Niche communities | Medium | 1-4 weeks | Free | Products solving specific community pain points |
| Twitter/X | Medium | 2-8 weeks | Free | Products with visual appeal, developer tools, thought leadership |
| LinkedIn | Medium | 2-8 weeks | Free | B2B, professional tools, enterprise-adjacent |
| SEO / Content marketing | High | 3-6 months | Free-Low | Products solving searchable problems |
| Email outreach | Medium | 1-4 weeks | Free-Low | B2B with identifiable prospects |
| Paid search (Google Ads) | Low | Immediate | High | Products solving high-intent search queries |
| Paid social | Medium | 1-4 weeks | Medium-High | B2C, visual products, brand awareness |
| Partnerships / Integrations | High | 1-3 months | Free | Products that complement existing tools |
| Open source / Developer community | High | 3-12 months | Free | Developer tools, infrastructure |
| Indie Hacker communities | Low | 1-2 weeks | Free | Solo founder tools, bootstrapped products |
| YouTube / Video content | High | 2-6 months | Low-Medium | Products that benefit from demos, tutorials |
| Newsletters (sponsor or own) | Medium | 1-4 weeks | Low-Medium | Niche audiences with newsletter culture |
| App Store / Marketplace listings | Medium | 2-8 weeks | Free-Low | Products with marketplace presence (Shopify, Slack, etc.) |

## Per-Channel Playbooks

### Product Hunt
- **When:** Launch day or scheduled Product Hunt launch
- **Prep (2-4 weeks before):**
  - Create maker profile, follow hunters
  - Prepare: tagline (60 chars), description (260 chars), first comment (tell your story), 3-5 screenshots/GIF, optional video
  - Line up hunter (optional but helpful for reach)
  - Notify existing network to support on launch day
- **Launch day:**
  - Post at 12:01am PT (start of PH day)
  - Respond to every comment within 1 hour
  - Share on social (Twitter, LinkedIn) with PH link
  - Email existing list
- **Post-launch:** Follow up with upvoters, write a "lessons learned" post

### Hacker News (Show HN)
- **When:** When you have a working product to demonstrate
- **Format:** "Show HN: [Product Name] – [one-line description]"
- **Body:** 2-3 paragraphs: what it does, why you built it, what's interesting technically
- **Timing:** Weekday mornings (US time zones), avoid major news days
- **Key:** Be authentic, technical, and transparent. HN rewards honesty about trade-offs.
- **Anti-pattern:** Don't be salesy. Don't ask for upvotes. Don't use marketing speak.

### SEO / Content Marketing
- **Keyword research:** Identify 10-20 keywords your target users search for
- **Content types:** How-to guides, comparison pages ("X vs Y"), use case pages, documentation
- **Technical SEO:** Fast page load, mobile-friendly, proper meta tags, structured data
- **Timeline:** 3-6 months to see meaningful organic traffic
- **Quick wins:** Target long-tail keywords with low competition first

### Email Outreach (B2B)
- **Find prospects:** LinkedIn Sales Navigator, company directories, conference attendee lists
- **Personalize:** Reference their specific problem, company, or recent activity
- **Template structure:** [1 sentence about them] + [1 sentence about you] + [1 specific value prop] + [low-friction CTA]
- **Follow-up:** 3-touch sequence over 2 weeks, then stop
- **Anti-pattern:** Don't mass-blast. Don't use "I hope this email finds you well."

### Twitter/X Launch Thread
- **Structure:** 5-7 tweets: Hook → Problem → Solution → Key features (2-3) → Social proof/traction → CTA
- **Timing:** Weekday 9-11am in your audience's timezone
- **Engagement:** Reply to every response, retweet supporters, tag relevant people
- **Visuals:** At least 1 screenshot/GIF per tweet

### LinkedIn
- **Format:** Personal story post (not company page), 1300-1800 characters
- **Structure:** Hook (first 2 lines are crucial) → Story/journey → What you built → Results/traction → Ask
- **Timing:** Tuesday-Thursday, 8-10am in target timezone
- **Key:** Professional tone, emphasize business impact over technical details

### Indie Hacker Communities
- **Where:** Indie Hackers (indiehackers.com), r/SideProject, r/SaaS, Hacker News, Twitter indie maker community
- **Approach:** Share the journey, not just the product. Revenue numbers, lessons, failures are valued.
- **Posts:** "I built X in Y weeks", milestone posts ($100 MRR, first customer, etc.), ask for feedback
- **Key:** Authenticity and transparency. These communities detect and reject marketing speak.

## Budget Allocation Guidelines

| Budget Range | Recommended Split |
|-------------|------------------|
| $0 (organic only) | 100% time investment: PH + HN + communities + SEO content + social |
| Under $500 | 70% organic + 30% newsletter sponsorships or small paid experiments |
| $500-$2,000 | 50% organic + 30% targeted paid search + 20% paid social/sponsorships |
| $2,000+ | 40% organic + 40% paid (search + social) + 20% partnerships/events |
```

- [ ] **Step 3: Write launch-timeline-examples.md**

Write `.claude/skills/go-to-market/references/launch-timeline-examples.md`:

```markdown
# Launch Timeline Examples Reference

This file provides domain knowledge for the launch plan stage. The skill references these templates when generating phased launch timelines.

---

## Timeline Templates

### Template A: Lean Launch (Solo Founder, $0 Budget)

**Pre-Launch (2-3 weeks)**
| Week | Actions |
|------|---------|
| Week -3 | Set up landing page with email capture, start social presence, write launch content |
| Week -2 | Invite 5-10 beta users, collect feedback, fix critical issues |
| Week -1 | Prepare PH listing, draft Show HN post, write launch emails, schedule social posts |

**Launch Week**
| Day | Actions |
|-----|---------|
| Monday | Product Hunt launch at 12:01am PT, share on social, email beta users |
| Tuesday | Show HN post, engage with PH comments, respond to feedback |
| Wednesday | Share on indie hacker communities (r/SideProject, Indie Hackers) |
| Thursday | LinkedIn post, email personal network |
| Friday | Publish "launch retrospective" blog post, follow up with engaged users |

**Post-Launch (4 weeks)**
| Week | Actions |
|------|---------|
| Week 1 | Follow up with all signups, onboarding calls for first 10 users, track activation |
| Week 2 | Iterate on top feedback, publish first content piece (SEO), start building email list |
| Week 3 | Second content piece, guest post or podcast outreach, analyze first metrics |
| Week 4 | Monthly retrospective: what worked, what didn't, adjust channel mix |

### Template B: Small Team Launch (2-5 people, $500-$2,000 Budget)

**Pre-Launch (4-6 weeks)**
| Week | Actions |
|------|---------|
| Week -6 | Landing page live, SEO keyword research, start content pipeline |
| Week -5 | Beta program (20-50 users), set up analytics/tracking |
| Week -4 | Collect beta testimonials, refine messaging based on feedback |
| Week -3 | Prepare all launch assets (PH, HN, social, emails, press kit) |
| Week -2 | Soft launch to waitlist, fix issues, train support |
| Week -1 | Final QA, pre-schedule social posts, brief team on launch day roles |

**Launch Week**
| Day | Actions |
|-----|---------|
| Monday | Product Hunt launch, social blitz, email blast |
| Tuesday | Show HN, respond to all channels, paid search campaign starts |
| Wednesday | Community posts (Reddit, Indie Hackers, niche forums), press outreach |
| Thursday | LinkedIn campaign, partner co-promotion, first retargeting ads |
| Friday | Week recap, publish launch story, thank supporters |

**Post-Launch (8 weeks)**
| Week | Actions |
|------|---------|
| Week 1-2 | Onboard all signups, identify activation blockers, ship quick fixes |
| Week 3-4 | Publish 2-3 SEO articles, start newsletter, A/B test landing page |
| Week 5-6 | Analyze channel ROI, double down on top 2 channels, cut underperformers |
| Week 7-8 | Plan next feature release, build case studies from early customers |

### Template C: Waitlist-First Launch

**Waitlist Phase (4-8 weeks)**
| Week | Actions |
|------|---------|
| Week 1-2 | Landing page with waitlist, start social content, build anticipation |
| Week 3-4 | Share progress updates ("building in public"), early access for top waitlist |
| Week 5-6 | Expand early access in waves, collect testimonials |
| Week 7-8 | Full product ready, prepare launch assets |

Then follow Template A or B for the actual launch.

## Go/No-Go Criteria

Before moving from pre-launch to launch, check:

| Criterion | Minimum Threshold |
|-----------|------------------|
| Product stability | No P0 bugs, <3 P1 bugs, core flow works reliably |
| Onboarding flow | New user can get value within 5 minutes without hand-holding |
| Landing page | Live, loads in <3s, clear value prop, working signup |
| Analytics | Core events tracking: signup, activation, key feature usage |
| Support channel | At least one channel monitored (email, chat, or community) |
| Launch assets | PH listing ready, social posts drafted, email copy written |
| Beta validation | At least 5 users have completed core flow successfully |

## Phase Definitions

| Phase | Duration | Focus | Key Metric |
|-------|----------|-------|------------|
| Pre-Launch | 2-8 weeks | Build anticipation, validate with beta users, prepare assets | Waitlist signups, beta user feedback |
| Launch Week | 5-7 days | Maximum visibility, engage every channel | Signups, traffic, PH rank, HN points |
| Post-Launch Month 1 | 4 weeks | Activate users, fix friction, ship feedback | Activation rate, D7 retention, NPS |
| Growth Month 2-3 | 8 weeks | Scale what works, build content engine, optimize funnel | MRR, channel ROI, organic traffic |
```

- [ ] **Step 4: Commit reference files**

```bash
git add .claude/skills/go-to-market/references/
git commit -m "feat(go-to-market): add reference files for pricing, channels, and timelines"
```

---

### Task 3: Write SKILL.md Router

The main entry point. Handles mode detection, PRD extraction, and sequential stage dispatch.

**Files:**
- Modify: `.claude/skills/go-to-market/SKILL.md`

- [ ] **Step 1: Write the complete SKILL.md**

Write `.claude/skills/go-to-market/SKILL.md`:

```markdown
---
name: go-to-market
description: "Use when the user needs to create a Go-to-Market strategy, launch plan, pricing strategy, or marketing assets for their product. Supports chained mode (reads existing PRD) and standalone mode (interactive Q&A). Triggers: /go-to-market, 'go to market', 'launch strategy', 'pricing strategy', 'GTM plan', 'launch plan'."
---

# Go-to-Market — From Product to Market-Ready Launch

Guide solo founders and small startup teams from finished product to market-ready launch. Produces a comprehensive Go-to-Market strategy through a sequential wizard: 7 strategy documents + actionable templates.

## Pipeline Position

Extends the DevForge pipeline beyond code delivery:

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

## Input Modes

```
/go-to-market                              # standalone mode (interactive Q&A)
/go-to-market --output path/to/gtm         # standalone with custom output dir
/go-to-market path/to/prd/                 # chained mode (reads PRD)
/go-to-market path/to/prd/ --output ./gtm  # chained with custom output
```

## Mode Detection

1. Check if a PRD path is provided as argument, OR if a `prd/` directory exists in the workspace
2. If PRD found → **Chained Mode** (read topic: `topics/positioning.md` with PRD extraction)
3. If no PRD → **Standalone Mode** (full interactive Q&A for product context)

## Stage Routing

The skill processes 7 stages sequentially. After detecting mode, read and execute each topic file in order:

| Stage | Read This File | Output |
|-------|---------------|--------|
| 1. Positioning & Messaging | `topics/positioning.md` | `gtm/positioning.md` |
| 2. Pricing Strategy | `topics/pricing.md` | `gtm/pricing-strategy.md` |
| 3. Distribution Channels | `topics/channels.md` | `gtm/channels.md` |
| 4. Launch Plan | `topics/launch-plan.md` | `gtm/launch-plan.md` |
| 5. Landing Page Spec | `topics/landing-page.md` | `gtm/landing-page-spec.md` |
| 6. Metrics & Success Criteria | `topics/metrics.md` | `gtm/metrics.md` |
| 7. Customer Acquisition Playbook | `topics/acquisition.md` | `gtm/acquisition-playbook.md` |

After all 7 stages: read `topics/templates.md` to generate `gtm/templates/` directory, then generate `gtm/README.md`.

Read ONLY the current stage's topic file — do not read ahead. Each topic file contains all instructions needed for that stage.

## Per-Stage Process

Every stage follows the same pattern:

1. **Context gather** — pull relevant info from PRD (chained) + prior GTM sections already generated
2. **Gap-fill** — ask the user ONLY what is missing (prefer multiple choice, one question at a time)
3. **Generate** — produce the document
4. **Review gate** — present a summary of the output, then ask:

> **Stage N complete: [Stage Name]**
> [2-3 sentence summary of what was generated]
>
> Options:
> - **Approve** — save and move to next stage
> - **Revise** — tell me what to change
> - **Skip** — move on, come back later
> - **Go back to [previous stage]** — revise an earlier stage

5. On **Approve**: save the document, proceed to next stage
6. On **Revise**: regenerate based on feedback, present again
7. On **Skip**: mark as skipped, proceed (will be flagged incomplete at final review)
8. On **Go back**: revise the earlier stage, then flag downstream documents that may need regeneration

## Cascade Logic

If the user revises an earlier stage, flag dependent stages:

| If Changed | Flag These for Review |
|-----------|----------------------|
| Positioning | Pricing, Channels, Landing Page, Acquisition |
| Pricing | Channels, Launch Plan, Landing Page, Metrics |
| Channels | Launch Plan, Metrics |
| Launch Plan | Landing Page, Metrics |
| Landing Page | Metrics |
| Metrics | Acquisition |

Ask: "This change may affect [list]. Want me to regenerate those sections, or just flag them for manual review?"

## PRD Extraction (Chained Mode)

When a PRD directory is found, extract and present to user before gap-filling:

| PRD Source | Extract |
|-----------|---------|
| `README.md` | Product name, vision, problem statement, target audience, competitive landscape |
| `features/*.md` or `features/F-*.md` | Feature list, user stories, acceptance criteria |
| `journeys/*.md` or `journeys/J-*.md` | User personas, workflows, pain points |
| `architecture.md` + `architecture/*.md` | Tech stack, integrations, deployment model |

Present extraction summary:
> **Extracted from PRD:**
> - Product: [name] — [vision]
> - Target users: [personas]
> - Key features: [list top 5-7]
> - Competitors: [list if found]
> - Tech stack: [summary]
>
> Is this accurate? I'll use this as context for the GTM strategy. I only need to ask you about business-specific details the PRD doesn't cover.

## Standalone Mode Gap-Fill

When no PRD exists, ask these context questions before starting Stage 1 (one at a time, multiple choice where possible):

1. "What does your product do? (1-2 sentences)"
2. "Who is your target user? (A) Individual developers (B) Small teams (C) Enterprise (D) Consumers (E) Other — describe"
3. "What problem does it solve?"
4. "What are your top 2-3 competitors or alternatives (including 'do nothing')?"
5. "What's your key differentiator — why will users choose you?"
6. "Is the product live yet? (A) Yes, live with users (B) Live, no users yet (C) MVP ready (D) Still building"

## Output Structure

```
gtm/
  README.md                     # Executive summary, links to all sections
  positioning.md                # ~500-800 words
  pricing-strategy.md           # ~600-1000 words
  channels.md                   # ~500-800 words
  launch-plan.md                # ~800-1200 words
  landing-page-spec.md          # ~600-1000 words
  metrics.md                    # ~400-600 words
  acquisition-playbook.md       # ~600-1000 words
  templates/
    launch-checklist.md         # Pre-launch / launch day / post-launch tasks
    emails/
      launch-announcement.md    # For existing audience / mailing list
      onboarding-welcome.md     # Post-signup drip email
      follow-up-inactive.md     # Re-engagement email
    social/
      product-hunt.md           # PH tagline, description, first comment, maker comment
      twitter-thread.md         # Launch thread (5-7 tweets)
      linkedin-post.md          # Professional launch announcement
      hacker-news.md            # Show HN post title + body
```

## Output Path

- **Default:** `gtm/` in the workspace root
- **Custom:** `--output <dir>` overrides the directory
- Confirm path with user before writing

## Final Review

After all 7 stages + templates are generated:

1. Generate `gtm/README.md` as executive summary linking all documents
2. List any skipped stages
3. Present the complete `gtm/` directory for final review
4. On approval: commit the entire `gtm/` directory in a single commit

## Key Principles

- **Business-first** — strategy and planning over code generation
- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer than open-ended
- **Smart context** — read PRD when available, only ask what's missing
- **Actionable outputs** — not just strategy docs but ready-to-use templates
- **YAGNI** — push back on overcomplicating the strategy

## Next Steps Hint

After committing, print:

```
GTM strategy complete: {output path}

Next steps:
  Build landing page — /frontend-design (use landing-page-spec.md as input)
  Review & iterate  — re-run /go-to-market to update specific sections
```
```

- [ ] **Step 2: Verify the file is well-formed**

Run:
```bash
head -5 .claude/skills/go-to-market/SKILL.md
```

Expected:
```
---
name: go-to-market
description: "Use when the user needs to create a Go-to-Market strategy, launch plan, pricing strategy, or marketing assets for their product. Supports chained mode (reads existing PRD) and standalone mode (interactive Q&A). Triggers: /go-to-market, 'go to market', 'launch strategy', 'pricing strategy', 'GTM plan', 'launch plan'."
---
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/go-to-market/SKILL.md
git commit -m "feat(go-to-market): write SKILL.md router with mode detection and stage dispatch"
```

---

### Task 4: Write Stage 1 — Positioning Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/positioning.md`

- [ ] **Step 1: Write positioning.md**

Write `.claude/skills/go-to-market/topics/positioning.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/positioning.md
git commit -m "feat(go-to-market): add positioning topic file (stage 1)"
```

---

### Task 5: Write Stage 2 — Pricing Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/pricing.md`

- [ ] **Step 1: Write pricing.md**

Write `.claude/skills/go-to-market/topics/pricing.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/pricing.md
git commit -m "feat(go-to-market): add pricing topic file (stage 2)"
```

---

### Task 6: Write Stage 3 — Channels Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/channels.md`

- [ ] **Step 1: Write channels.md**

Write `.claude/skills/go-to-market/topics/channels.md`:

```markdown
# Stage 3: Distribution Channels

This file contains instructions for generating the distribution channels strategy. It builds on positioning (Stage 1) and pricing (Stage 2), and references `references/channel-playbooks.md` for domain knowledge.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — target persona, where they spend time
- `gtm/pricing-strategy.md` — pricing model (affects channel fit: free products favor viral channels)
- `references/channel-playbooks.md` — channel matrix, per-channel playbooks, budget allocation

## Gap-Fill Questions

Ask one at a time, only if not already answered:

1. "What's your launch marketing budget? (A) $0 — organic only (B) Under $500 (C) $500-$2,000 (D) $2,000+ (E) Flexible — depends on ROI"
2. "Where does your target audience currently hang out online? (pick all that apply) (A) Twitter/X (B) LinkedIn (C) Reddit (D) Hacker News (E) Indie Hacker communities (F) Industry-specific forums (G) Slack/Discord communities (H) YouTube (I) Not sure"
3. "Do you have any existing audience? (A) Yes — email list (how many?) (B) Yes — social following (which platform?) (C) Yes — existing product with users (D) No — starting from zero"
4. "Is your product visual enough for demos/screenshots to sell it? (A) Yes — very visual, screenshots tell the story (B) Somewhat — needs explanation alongside visuals (C) Not really — value is in the workflow, not the UI (D) No UI — API/backend/CLI tool"

## Document Generation

Generate `channels.md` with these sections:

### Channel Strategy Overview
2-3 sentences on the overall approach. Reference persona from positioning — where do they discover new tools?

### Ranked Channel List
Rank 5-8 channels by priority. Use data from `references/channel-playbooks.md` Channel Matrix, filtered by relevance to this product's persona and budget.

| Priority | Channel | Effort | Expected Impact | Cost | Timeline |
|----------|---------|--------|----------------|------|----------|
| 1 | [channel] | [L/M/H] | [L/M/H] | [cost] | [time to results] |
| 2 | ... | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... |

### Per-Channel Playbook
For the top 3-5 channels, provide a **specific, actionable playbook** (not generic advice). Adapt the relevant playbook from `references/channel-playbooks.md` to this product:

For each channel:
- **Why this channel:** 1-2 sentences connecting persona + product to channel
- **What to do:** Step-by-step actions (specific to this product, not generic)
- **When:** Timing relative to launch (pre-launch, launch day, post-launch)
- **Expected outcome:** What success looks like (realistic, not aspirational)
- **Key metric:** What to measure

### Community Targets
List 5-10 specific communities where target users gather:
- **Name** — e.g., "r/SaaS", "Indie Hackers", "DevOps Slack community"
- **Size** — approximate member count
- **Approach** — how to engage without being spammy (participate first, then share)
- **Timing** — when to start engaging (weeks before launch, launch day, etc.)

### SEO Keyword Targets (if applicable)
If SEO is in the channel mix, list 10-15 target keywords:

| Keyword | Monthly Volume | Competition | Content Type | Priority |
|---------|---------------|-------------|-------------|----------|
| [keyword] | [est. volume] | [L/M/H] | [blog/landing/docs] | [1-3] |

### Budget Allocation
If budget > $0, reference `references/channel-playbooks.md` Budget Allocation Guidelines and provide a specific breakdown:

| Channel | Monthly Budget | Expected CPA | Expected Signups |
|---------|---------------|-------------|-----------------|
| [channel] | $X | $X | X-Y |
| ... | ... | ... | ... |
| **Total** | $X | $X avg | X-Y |

## Output

Write to `gtm/channels.md`. Present a summary to the user and enter the review gate.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/channels.md
git commit -m "feat(go-to-market): add channels topic file (stage 3)"
```

---

### Task 7: Write Stage 4 — Launch Plan Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/launch-plan.md`

- [ ] **Step 1: Write launch-plan.md**

Write `.claude/skills/go-to-market/topics/launch-plan.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/launch-plan.md
git commit -m "feat(go-to-market): add launch plan topic file (stage 4)"
```

---

### Task 8: Write Stage 5 — Landing Page Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/landing-page.md`

- [ ] **Step 1: Write landing-page.md**

Write `.claude/skills/go-to-market/topics/landing-page.md`:

```markdown
# Stage 5: Landing Page Spec

This file contains instructions for generating the landing page specification. It builds on positioning, pricing, and launch plan (Stages 1, 2, 4). This is a content and structure spec — not code. It can be passed to a frontend-design skill or developer for implementation.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — value prop, taglines, elevator pitch, differentiators
- `gtm/pricing-strategy.md` — tier structure, price points
- `gtm/launch-plan.md` — launch approach (affects CTA: waitlist vs. signup vs. free trial)

## Gap-Fill Questions

Ask one at a time, only if not already answered:

1. "What should the primary CTA be? (A) Sign up for free (B) Start free trial (C) Join waitlist (D) Book a demo (E) Download / Install (F) Other — describe"
2. "Do you have any social proof to include? (A) Beta user testimonials (B) Usage stats (e.g., '500 developers trust us') (C) Notable companies/users (D) Open source stars/community (E) None yet — I'll add later"
3. "Do you have a product demo or screenshots ready? (A) Yes — screenshots/GIFs (B) Yes — video demo (C) Not yet — use placeholder descriptions (D) Product is CLI/API — no visual demo"

## Document Generation

Generate `landing-page-spec.md` with these sections:

### Page Structure Overview
Ordered list of sections from top to bottom. Standard SaaS landing page structure, adapted to this product:

1. Hero
2. Social Proof Bar (if available)
3. Problem/Pain
4. Solution/Features
5. How It Works
6. Pricing
7. Testimonials (if available)
8. FAQ
9. Final CTA

### Section-by-Section Spec

For each section, provide:

#### 1. Hero
- **Headline:** [Use the best tagline from positioning.md, or a new one]
- **Subheadline:** [1-2 sentences expanding on the headline — use elevator pitch as basis]
- **CTA button:** [Primary CTA text] + [secondary CTA if applicable, e.g., "See demo"]
- **Visual:** [Description of hero image/screenshot/animation]
- **Above the fold:** Everything in this section must be visible without scrolling

#### 2. Social Proof Bar
- **Content:** [Logos, stats, or testimonial snippet]
- **Note:** Skip if no social proof available yet. Add placeholder: "As seen in / Trusted by [placeholder]"

#### 3. Problem/Pain
- **Headline:** [Problem-focused headline]
- **Body:** 2-3 pain points the target user experiences, written in their language
- **Format:** Icon + short description for each pain point

#### 4. Solution/Features
- **Headline:** [Solution-focused headline]
- **Features:** 3-6 key features, each with:
  - Feature name
  - One-sentence description
  - Screenshot/visual description
- **Format:** Alternating left-right layout or grid

#### 5. How It Works
- **Headline:** "How it works" or similar
- **Steps:** 3-4 steps showing the user journey from signup to value
  - Step number + title + description + visual

#### 6. Pricing
- **Headline:** "Simple, transparent pricing" or similar
- **Content:** Embed tier structure from `pricing-strategy.md`
- **CTA:** Per-tier CTA buttons
- **Note:** Highlight recommended tier

#### 7. Testimonials
- **Content:** 2-3 testimonials (real or placeholder format)
- **Format:** Quote + name + title + company + photo placeholder

#### 8. FAQ
- **Questions:** 5-8 common questions, derived from:
  - Positioning objections (competitive concerns)
  - Pricing questions ("Is there a free tier?", "Can I cancel anytime?")
  - Product questions ("Does it integrate with X?", "Is my data secure?")

#### 9. Final CTA
- **Headline:** [Action-oriented closing headline]
- **CTA button:** Same as hero CTA
- **Subtext:** Low-risk reassurance ("Free forever plan", "No credit card required", "Cancel anytime")

### SEO Metadata
- **Page title:** [60 chars max, includes product name + key benefit]
- **Meta description:** [155 chars max, includes CTA]
- **OG title:** [Same as page title or shorter variant]
- **OG description:** [Same as meta description or shorter variant]
- **OG image:** [Description of what the social preview image should show]

### CTA Strategy
- **Primary CTA:** [text, appears in hero + final section + sticky header]
- **Secondary CTA:** [text, appears alongside primary where appropriate]
- **Urgency/scarcity:** [if applicable: "Limited beta spots", "Launch pricing ends [date]"]
- **Trust signals near CTA:** [e.g., "No credit card required", "Free tier available", "SOC 2 compliant"]

## Output

Write to `gtm/landing-page-spec.md`. Present a summary to the user and enter the review gate.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/landing-page.md
git commit -m "feat(go-to-market): add landing page topic file (stage 5)"
```

---

### Task 9: Write Stage 6 — Metrics Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/metrics.md`

- [ ] **Step 1: Write metrics.md**

Write `.claude/skills/go-to-market/topics/metrics.md`:

```markdown
# Stage 6: Metrics & Success Criteria

This file contains instructions for generating the metrics and success criteria document. It draws from all prior stages to define measurable goals for each launch phase.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — personas (who are we measuring?)
- `gtm/pricing-strategy.md` — pricing model (determines revenue metrics)
- `gtm/channels.md` — channels (determines acquisition metrics)
- `gtm/launch-plan.md` — phases and timeline (determines when to measure what)

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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/metrics.md
git commit -m "feat(go-to-market): add metrics topic file (stage 6)"
```

---

### Task 10: Write Stage 7 — Acquisition Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/acquisition.md`

- [ ] **Step 1: Write acquisition.md**

Write `.claude/skills/go-to-market/topics/acquisition.md`:

```markdown
# Stage 7: Customer Acquisition Playbook

This file contains instructions for generating the customer acquisition playbook. It is the final strategy stage, drawing on all prior stages to create an actionable guide for acquiring and retaining customers.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — personas, value prop, messaging
- `gtm/pricing-strategy.md` — free-to-paid boundary, upgrade triggers
- `gtm/channels.md` — ranked channels, community targets
- `gtm/launch-plan.md` — launch phases, timeline
- `gtm/metrics.md` — KPIs, activation definition, tracking plan

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

Write to `gtm/acquisition-playbook.md`. Present a summary to the user and enter the review gate.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/acquisition.md
git commit -m "feat(go-to-market): add acquisition topic file (stage 7)"
```

---

### Task 11: Write Templates Topic

**Files:**
- Create: `.claude/skills/go-to-market/topics/templates.md`

- [ ] **Step 1: Write templates.md**

Write `.claude/skills/go-to-market/topics/templates.md`:

```markdown
# Template Generation

This file contains instructions for generating the `gtm/templates/` directory after all 7 strategy stages are complete. Templates are ready-to-use marketing assets derived from the strategy documents.

---

## Prerequisites

Read all 7 GTM strategy documents before generating templates:
- `gtm/positioning.md` — messaging, taglines, value prop
- `gtm/pricing-strategy.md` — tiers, pricing
- `gtm/channels.md` — channel strategy
- `gtm/launch-plan.md` — timeline, phases
- `gtm/landing-page-spec.md` — CTA, messaging
- `gtm/metrics.md` — KPIs
- `gtm/acquisition-playbook.md` — onboarding, retention

## Template Outputs

Generate each file in `gtm/templates/`. Each template should be immediately usable — the user copies, personalizes slightly, and sends/posts.

### gtm/templates/launch-checklist.md

Actionable checklist with three phases. Derive tasks from `launch-plan.md`:

```markdown
# Launch Checklist

## Pre-Launch
- [ ] Landing page live and tested on mobile
- [ ] Analytics/tracking implemented (see metrics.md)
- [ ] Onboarding flow tested with 3+ external users
- [ ] Social accounts set up and profile completed
- [ ] [product-specific tasks from launch-plan.md]
- [ ] Product Hunt listing drafted
- [ ] Show HN post drafted
- [ ] Email templates finalized
- [ ] Social posts scheduled
- [ ] Support channel ready (email/chat/community)
- [ ] Go/no-go criteria met (see launch-plan.md)

## Launch Day
- [ ] [day-by-day actions from launch-plan.md launch week]
- [ ] Monitor analytics dashboard
- [ ] Respond to all comments/feedback within 2 hours
- [ ] Share launch on personal social accounts
- [ ] Email existing contacts/list

## Post-Launch (Week 1)
- [ ] Follow up with all signups personally (first 50)
- [ ] Compile day-1 metrics (see metrics.md targets)
- [ ] Identify and fix top 3 friction points
- [ ] [product-specific post-launch tasks]
- [ ] Write and publish launch retrospective
```

### gtm/templates/emails/launch-announcement.md

```markdown
# Launch Announcement Email

**Subject line options:**
1. [Product Name] is live — [key benefit]
2. Introducing [Product Name]: [tagline from positioning.md]
3. We built [Product Name] to solve [problem] — it's ready

**Body:**

Hi [Name],

[1 sentence: what you built and why — from elevator pitch in positioning.md]

[1 sentence: what's special about it — from key differentiator]

[2-3 bullet points: top features/benefits]

[CTA button: from landing-page-spec.md primary CTA]

[1 sentence: low-risk reassurance — "It's free to start" / "No credit card needed"]

[Sign-off with personal touch — "I'd love your feedback"]

[Name]
```

### gtm/templates/emails/onboarding-welcome.md

```markdown
# Welcome / Onboarding Email

**Sent:** Immediately after signup
**Subject:** Welcome to [Product Name] — here's how to get started

**Body:**

Hi [Name],

Thanks for signing up for [Product Name]!

Here's how to get started in [X] minutes:

1. [First step from acquisition-playbook.md onboarding flow]
2. [Second step]
3. [Third step — the activation action]

[CTA button: "Get started" → link to first onboarding step]

If you have any questions, just reply to this email — I read every one.

[Name]
[Title, Product Name]
```

### gtm/templates/emails/follow-up-inactive.md

```markdown
# Re-engagement Email (Inactive User)

**Sent:** 7 days after signup with no activation
**Subject options:**
1. Still figuring out [Product Name]? Here's a quick win
2. [Name], you're one step away from [key benefit]

**Body:**

Hi [Name],

I noticed you signed up for [Product Name] but haven't [activation action] yet.

Most users find that [activation action] is where the magic happens — it usually takes about [X] minutes.

[CTA button: "Try it now" → deep link to activation step]

If something's not working or you have questions, I'd genuinely love to hear about it — just reply here.

[Name]
```

### gtm/templates/social/product-hunt.md

```markdown
# Product Hunt Launch Assets

**Tagline (60 chars max):**
[Derived from positioning.md taglines — pick the most concise]

**Description (260 chars max):**
[Condensed elevator pitch from positioning.md]

**First Comment (Maker Story):**
Hey PH! 👋

I'm [Name], and I built [Product Name] because [personal story: why this problem matters to you].

[1 sentence: what it does]

[1 sentence: what makes it different — from key differentiators]

[1 sentence: current status — "It's live and free to try" / "We've been in beta with X users"]

I'd love your feedback — happy to answer any questions here!

**Gallery:**
1. [Hero screenshot description]
2. [Key feature screenshot]
3. [Key feature screenshot]
4. [Optional: GIF showing core workflow]
5. [Optional: video thumbnail]
```

### gtm/templates/social/twitter-thread.md

```markdown
# Twitter/X Launch Thread

**Tweet 1 (Hook):**
[Attention-grabbing opener — problem statement or bold claim]

[Product Name] — [tagline]

🧵 Here's what we built and why:

**Tweet 2 (Problem):**
[Describe the problem in the user's language — from positioning.md problem statement]

**Tweet 3 (Solution):**
[What Product Name does differently — from value prop and differentiators]

[Screenshot/GIF]

**Tweet 4 (Key Feature 1):**
[Top feature with benefit — not just what it does but why it matters]

[Screenshot/GIF]

**Tweet 5 (Key Feature 2):**
[Second feature with benefit]

[Screenshot/GIF]

**Tweet 6 (Social proof / traction):**
[Beta results, user testimonials, or early metrics]

"[Quote from beta user]"

**Tweet 7 (CTA):**
[Product Name] is [live / free to try / in beta].

[Link]

[Pricing summary — "Free tier available" / "Starts at $X/mo"]

If you found this useful, RT tweet 1 to help us spread the word 🙏
```

### gtm/templates/social/linkedin-post.md

```markdown
# LinkedIn Launch Post

[Hook — first 2 lines are critical, must stop the scroll]

[2-3 sentences: personal story — why you built this, what frustrated you]

[1 sentence: what you built]

[2-3 bullet points: key benefits (business impact, not features)]

[1 sentence: traction or validation — "We've been testing with X users who..."]

[CTA: link + what to do ("Try it free at [link]")]

[2-3 relevant hashtags]
```

### gtm/templates/social/hacker-news.md

```markdown
# Show HN Post

**Title:**
Show HN: [Product Name] – [one-line description, technical angle preferred]

**Body:**

[What it does — 2-3 sentences, be specific and technical]

[Why I built it — the personal problem or observation that led to this]

[What's interesting technically — architecture choice, approach, or trade-off that HN readers would find compelling]

[Current status — live, beta, open source, etc.]

[Link]

I'd love feedback, especially on [specific area — UX, pricing, technical approach, etc.].
```

## README Generation

After all templates are written, generate `gtm/README.md`:

```markdown
# Go-to-Market Strategy: [Product Name]

> Generated by DevForge `/go-to-market` on [date]

## Executive Summary
[2-3 sentences: what the product is, who it's for, and the launch strategy]

## Strategy Documents

| Document | Description |
|----------|-------------|
| [positioning.md](positioning.md) | Value proposition, messaging, competitive positioning |
| [pricing-strategy.md](pricing-strategy.md) | Pricing model, tier structure, competitor comparison |
| [channels.md](channels.md) | Distribution channels ranked by priority with playbooks |
| [launch-plan.md](launch-plan.md) | Phased timeline: pre-launch, launch week, post-launch |
| [landing-page-spec.md](landing-page-spec.md) | Page structure, section copy, SEO, CTA strategy |
| [metrics.md](metrics.md) | KPIs per phase, tracking plan, alerting thresholds |
| [acquisition-playbook.md](acquisition-playbook.md) | Funnel, onboarding, retention, churn prevention |

## Ready-to-Use Templates

| Template | Description |
|----------|-------------|
| [templates/launch-checklist.md](templates/launch-checklist.md) | Pre-launch / launch day / post-launch task list |
| [templates/emails/](templates/emails/) | Launch announcement, welcome, re-engagement emails |
| [templates/social/](templates/social/) | Product Hunt, Twitter, LinkedIn, Hacker News posts |

## Key Decisions
- **Pricing model:** [model from pricing-strategy.md]
- **Primary channel:** [#1 channel from channels.md]
- **Launch type:** [type from launch-plan.md]
- **Primary CTA:** [CTA from landing-page-spec.md]
- **Success metric (week 1):** [target from metrics.md]
```

## No Review Gate for Templates

Templates are generated as a batch after the final strategy stage. They do not have individual review gates — they are reviewed as part of the final holistic review (as defined in SKILL.md).

## Output

Write all template files to `gtm/templates/` and `gtm/README.md`. Then trigger the SKILL.md final review.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/go-to-market/topics/templates.md
git commit -m "feat(go-to-market): add templates topic file for marketing asset generation"
```

---

### Task 12: Update README.md and Final Commit

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the project README to include /go-to-market**

Add the new skill to `README.md` after the `/autoforge` section and update the workflow diagram.

In the `## Skills` section, after the `/autoforge` block, add:

```markdown
### `/go-to-market` — Launch Strategy

Guides solo founders and small startup teams from finished product to market-ready launch through a sequential 7-stage wizard.

- Chained mode (reads PRD) or standalone interactive mode
- 7 stages: positioning, pricing, channels, launch plan, landing page spec, metrics, acquisition playbook
- Outputs: strategy documents + ready-to-use templates (emails, social posts, launch checklist)
- Review gates with cascade logic for revisions
```

Update the `## Workflow` section:

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

- [ ] **Step 2: Verify the full skill file tree**

Run:
```bash
find .claude/skills/go-to-market -type f | sort
```

Expected:
```
.claude/skills/go-to-market/SKILL.md
.claude/skills/go-to-market/references/channel-playbooks.md
.claude/skills/go-to-market/references/launch-timeline-examples.md
.claude/skills/go-to-market/references/pricing-models.md
.claude/skills/go-to-market/topics/acquisition.md
.claude/skills/go-to-market/topics/channels.md
.claude/skills/go-to-market/topics/landing-page.md
.claude/skills/go-to-market/topics/launch-plan.md
.claude/skills/go-to-market/topics/metrics.md
.claude/skills/go-to-market/topics/positioning.md
.claude/skills/go-to-market/topics/pricing.md
.claude/skills/go-to-market/topics/templates.md
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add /go-to-market skill to project README and update workflow diagram"
```

---

### Task 13: Smoke Test

**Files:**
- None (verification only)

- [ ] **Step 1: Verify SKILL.md frontmatter is valid**

Run:
```bash
head -4 .claude/skills/go-to-market/SKILL.md
```

Expected: YAML frontmatter with `name: go-to-market` and `description:` field.

- [ ] **Step 2: Verify all topic files referenced in SKILL.md exist**

Check that each file in the Stage Routing table exists:
```bash
for f in topics/positioning.md topics/pricing.md topics/channels.md topics/launch-plan.md topics/landing-page.md topics/metrics.md topics/acquisition.md topics/templates.md; do
  test -f .claude/skills/go-to-market/$f && echo "OK: $f" || echo "MISSING: $f"
done
```

Expected: All 8 files show "OK".

- [ ] **Step 3: Verify all reference files exist**

```bash
for f in references/pricing-models.md references/channel-playbooks.md references/launch-timeline-examples.md; do
  test -f .claude/skills/go-to-market/$f && echo "OK: $f" || echo "MISSING: $f"
done
```

Expected: All 3 files show "OK".

- [ ] **Step 4: Verify no broken cross-references in topic files**

Check that topic files reference the correct reference files:
```bash
grep -r "references/" .claude/skills/go-to-market/topics/ | grep -v ".md:" || echo "No references found"
```

Manually verify that each referenced file path matches an actual file in `references/`.

- [ ] **Step 5: Invoke the skill to verify it loads**

Run `/go-to-market` in Claude Code. Verify:
- The skill loads without errors
- Mode detection prompt appears (checks for `prd/` directory)
- In standalone mode: first context question is asked
- Cancel after verifying it loads correctly
