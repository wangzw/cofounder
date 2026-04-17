# Stage 5: Landing Page Spec

This file contains instructions for generating the landing page specification. It builds on positioning, pricing, and launch plan (Stages 1, 2, 4). This is a content and structure spec — not code. It can be passed to a frontend-design skill or developer for implementation.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — value prop, taglines, elevator pitch, differentiators
- `gtm/pricing-strategy.md` — tier structure, price points
- `gtm/channels.md` — primary channels (affects which audiences and messaging the page needs to convert; also informs social proof emphasis)
- `gtm/launch-plan.md` — launch approach (affects CTA: waitlist vs. signup vs. free trial)

### Chained Mode (PRD exists)

Re-read these PRD sections before generating (do not rely solely on prior `gtm/` files):
- `features/*.md` — top features for hero messaging, feature highlights section
- `journeys/*.md` — key pain points for problem/pain section, user language for copy

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

Write to `{output_dir}/landing-page-spec.md`. Present a summary to the user and enter the review gate.
