# `/go-to-market` Skill Design Spec

**Date:** 2026-04-14
**Status:** Approved
**Author:** Zhanwei Wang

## Overview

`/go-to-market` is a DevForge skill that guides solo founders and small startup teams from finished product to market-ready launch. It produces a comprehensive Go-to-Market strategy through a sequential wizard, generating 7 strategy documents and actionable templates.

### Pipeline Position

Extends the DevForge pipeline beyond code delivery:

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

### Target Users

- Solo founders and indie hackers who need structured business guidance
- Small startup teams with technical expertise but limited marketing experience

## Input Modes

### Chained Mode

Invoked after `/autoforge` or when a `prd/` directory exists in the workspace. Auto-reads PRD documents to extract product context, then asks only gap-filling questions for business-specific inputs.

**Detection logic:** On invocation, check for a `prd/` directory. If found, enter chained mode.

### Standalone Mode

Invoked independently without prior DevForge output. Falls back to full interactive Q&A to gather product context, target market, and business goals.

## PRD Extraction Logic (Chained Mode)

When a `prd/` directory is detected, the skill reads and maps:

| PRD Source | Extracted Info | Used In |
|-----------|---------------|---------|
| `prd/README.md` | Product name, vision, problem statement, target audience | Positioning, Landing Page |
| `prd/feature-*.md` | Feature list, user stories, acceptance criteria | Pricing tiers, Landing Page features section |
| `prd/user-journeys.md` | User personas, workflows, pain points | Positioning personas, Acquisition onboarding flow |
| `prd/architecture.md` | Tech stack, integrations, constraints | Channels (developer-focused or not), Pricing (usage-based feasibility) |

**Gap-fill questions in chained mode** are limited to business-specific inputs that PRDs don't cover:

- Revenue goals and pricing intent
- Marketing budget and resource constraints
- Target launch date
- Competitor pricing (PRD may have competitors but rarely their pricing)
- Preferred distribution channels
- Team size and who handles what

**In standalone mode**, the skill asks all of the above plus product context questions (what the product does, who it's for, key features, competitors).

The skill clearly presents what it extracted from the PRD before asking gap-fill questions, so the user can correct any misinterpretation.

## Sequential Wizard Flow

The skill processes 7 stages in fixed order. Each stage follows the same pattern:

1. **Context gather** — Pull relevant info from PRD (if available) + prior GTM sections
2. **Gap-fill** — Ask the user only what's missing (multiple-choice preferred, one question at a time)
3. **Generate** — Produce the document
4. **Review gate** — Present output, get user approval before moving on

### Stage Order and Dependencies

| Stage | Output File | Feeds From |
|-------|------------|------------|
| 1. Positioning & Messaging | `positioning.md` | PRD (target users, features, competitive landscape) |
| 2. Pricing Strategy | `pricing-strategy.md` | Positioning + PRD (feature tiers) |
| 3. Distribution Channels | `channels.md` | Positioning + Pricing (budget, audience) |
| 4. Launch Plan | `launch-plan.md` | Positioning + Pricing + Channels |
| 5. Landing Page Spec | `landing-page-spec.md` | Positioning + Pricing + Launch Plan |
| 6. Metrics & Success Criteria | `metrics.md` | All prior stages |
| 7. Customer Acquisition Playbook | `acquisition-playbook.md` | All prior stages |

After all 7 stages complete, the skill generates the `templates/` directory and the `README.md` executive summary.

### Example Gap-Fill Questions Per Stage

- **Positioning:** "Who are your top 2-3 competitors?" / "What's your one-sentence differentiator?"
- **Pricing:** "What pricing model are you leaning toward? (A) Freemium (B) Free trial (C) Paid-only (D) Usage-based"
- **Channels:** "What's your launch marketing budget? (A) $0 - organic only (B) Under $500 (C) $500-$2000 (D) $2000+"
- **Launch Plan:** "What's your target launch date?" / "Do you want a beta/waitlist phase?"

## Review Gates & Iteration

Each stage has a review gate before proceeding.

### User Decisions at Each Gate

- **Approve** — Document is saved, move to next stage
- **Revise** — User provides feedback, skill regenerates the section
- **Skip** — Mark as skipped, move on (user can come back later)
- **Go back** — Revisit and revise a previous stage (triggers cascade updates to dependent stages)

### Cascade Logic for Revisions

If the user revises an earlier stage, the skill flags downstream documents that may be affected:

- Changing positioning → flags pricing, channels, landing page, acquisition playbook
- Changing pricing → flags channels, launch plan, landing page, metrics

The skill asks: "This change may affect [list]. Want me to regenerate those sections, or just flag them for manual review?"

### Final Review

After all 7 stages + templates are generated, the skill produces `README.md` as an executive summary linking all documents, and presents the complete `gtm/` directory for a final holistic review before committing to git.

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

### Document Specifications

| Document | Key Sections |
|----------|-------------|
| `positioning.md` | Problem statement, target persona(s), value proposition, elevator pitch, taglines (3 variants), competitive matrix, differentiators |
| `pricing-strategy.md` | Pricing model rationale, tier breakdown (features per tier), price points with justification, competitor pricing comparison, free-vs-paid boundary, upgrade triggers |
| `channels.md` | Ranked channel list with effort/impact scores, per-channel playbook (what to do, when, expected outcome), community list, SEO keyword targets |
| `launch-plan.md` | 3-phase timeline (pre-launch, launch week, post-launch 30 days), daily/weekly milestones, task owners (if team), go/no-go criteria |
| `landing-page-spec.md` | Section-by-section copy (hero, features, social proof, pricing, CTA), SEO metadata (title, description, OG tags), above-the-fold wireframe description, CTA strategy |
| `metrics.md` | KPIs per launch phase, tracking plan (what tool measures what), target numbers for week 1 / month 1 / month 3, alerting thresholds |
| `acquisition-playbook.md` | Top-of-funnel tactics, onboarding flow design, activation checklist, retention hooks, churn signals, feedback collection plan |

## Skill File Structure

Following DevForge's existing patterns (e.g., `/prd-analysis`):

```
skills/go-to-market/
  SKILL.md                      # Router — entry point, mode detection, dispatches to topics
  topics/
    positioning.md              # Stage 1 instructions + PRD extraction logic
    pricing.md                  # Stage 2 instructions + gap-fill questions
    channels.md                 # Stage 3 instructions
    launch-plan.md              # Stage 4 instructions
    landing-page.md             # Stage 5 instructions
    metrics.md                  # Stage 6 instructions
    acquisition.md              # Stage 7 instructions
    templates.md                # Template generation instructions
  references/
    pricing-models.md           # Reference: common SaaS pricing patterns
    channel-playbooks.md        # Reference: per-channel tactics library
    launch-timeline-examples.md # Reference: example timelines for different product types
```

### SKILL.md Responsibilities

- Detect input mode (chained vs. standalone) by checking for `prd/` directory
- If chained: extract product name, target users, features, competitive info from PRD
- If standalone: initiate full interactive Q&A for product context
- Route to each topic file sequentially (stage 1 through 7)
- After all stages: generate `templates/` and `README.md`
- Commit the entire `gtm/` directory to git in a single commit after final review approval

### Reference Files

Provide the skill with domain knowledge — common pricing patterns, channel tactics, and timeline templates — so generated outputs are grounded in real GTM practices rather than generic advice.

## Design Decisions

1. **Business-first** — Strategy and planning over code generation
2. **Sequential wizard (v1)** — Each section builds on the previous for coherence; may evolve to dependency-graph parallelism in future versions
3. **Smart context** — Reads PRD when available, only asks what's missing
4. **Actionable outputs** — Not just strategy docs but ready-to-use templates (emails, social posts, launch checklists)
5. **Review gates with cascade** — Revising early stages flags downstream impacts

## Future Considerations (Out of Scope for v1)

- **Dependency-graph parallelism** — Generate independent stages concurrently
- **Integration with `/autoforge`** — Auto-scaffold landing page code from `landing-page-spec.md`
- **Analytics setup** — Generate tracking code snippets alongside `metrics.md`
- **A/B testing** — Generate variant copies for landing page and email templates
- **Localization** — Multi-language GTM outputs
