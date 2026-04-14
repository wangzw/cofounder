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
