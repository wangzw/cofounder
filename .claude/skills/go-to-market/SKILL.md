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
