---
name: go-to-market
description: "Use when the user needs to create a Go-to-Market strategy, launch plan, pricing strategy, or marketing assets for their product. Triggers: /go-to-market, 'go to market', 'launch strategy', 'pricing strategy', 'GTM plan', 'launch plan'."
---

# Go-to-Market — From Product to Market-Ready Launch

Guide solo founders and small startup teams from finished product to market-ready launch. Produces a comprehensive Go-to-Market strategy through a sequential wizard: 7 strategy documents + actionable templates.

## Pipeline Position

Extends the CoFounder pipeline beyond code delivery:

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

1. Check if a PRD path is provided as argument, OR if a `prd/` directory exists in the workspace, OR if a `docs/raw/prd/` directory exists (scan for the most recent date-prefixed subdirectory).
2. If PRD found → **Chained Mode**: run the PRD Extract procedure (see below) to produce `gtm/.context.md`, then proceed stage by stage.
3. If no PRD → **Standalone Mode** (full interactive Q&A for product context).

**Chained mode — PRD Extract (do this before Stage 1, not per stage):**

Do NOT bulk-load the raw PRD into main context — a 48-feature PRD can easily exceed 100K tokens of feature/journey files, leaving no budget to generate all 7 stages. Instead, dispatch a single `Explore` subagent to read the PRD in parallel and emit a compact context artifact. The main agent never reads feature/journey/architecture files directly.

Dispatch once:

```
Agent({
  subagent_type: "Explore",
  description: "Extract GTM context from PRD",
  prompt: <PRD Extract prompt — see below>
})
```

The subagent writes the result to `gtm/.context.md` (create the `gtm/` directory if absent). All 7 stages consume this artifact. If a stage later discovers a fact it needs is missing from `.context.md`, the stage's topic file may read one specific source file and append the fact to `.context.md` — but bulk re-reading PRD is forbidden.

See the **PRD Extract procedure** section below for the subagent prompt and `.context.md` schema.

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

1. **Context gather** — use the compact GTM context (chained) + prior GTM sections already generated.
   - **Chained mode (PRD present):** Read `gtm/.context.md` once (if not already in main context) and use its sections directly. When a topic file refers to "PRD README" or "features/*.md", treat those as pointers into `.context.md` — do NOT read the raw PRD files. If a fact is genuinely missing from `.context.md`, read the single specific source file, append the fact to `.context.md`, and continue. If you find `.context.md` facts that contradict a prior `gtm/` file, surface the contradiction to the user before proceeding.
   - **Standalone mode:** Use only what was gathered in the SKILL.md gap-fill plus prior `gtm/` files. No PRD to consult.

2. **Gap-fill** — ask the user ONLY what is missing (prefer multiple choice, one question at a time)
3. **Generate** — produce the document. **Every generated file must be self-contained**: include a short "Context" header at the top summarizing the upstream facts this stage depends on (e.g. primary persona, core value prop, price tier names). A reader opening this file alone must be able to act on it without cross-referencing the rest of `gtm/` or the PRD. Do not write "see positioning.md" — copy the 2-3 sentences that matter.

**Context header example:**

Every `gtm/*.md` file begins with a Context section that inlines the upstream facts it depends on:

```markdown
## Context

- **Product:** TaskFlow — AI-powered task management for solo developers
- **Primary persona:** Independent developers juggling multiple side projects  
- **Core value prop:** Reduces daily planning time from 30 min to 5 min
- **Price tier:** Free (up to 3 projects) / Pro $12/mo (unlimited)
- **Primary channels:** Developer communities (DEV.to, Hacker News), Twitter/X
- **Launch date:** 2026-05-15 (public beta)
```

Copy the 3-5 most relevant facts from prior stages. A reader opening this file alone must be able to act on it without cross-referencing other `gtm/` files.
4. **Review gate** — present a summary of the output, then ask:

> **Stage N complete: [Stage Name]**
> [2-3 sentence summary of what was generated]
>
> Options:
> - **Approve** — save and move to next stage
> - **Revise** — tell me what to change
> - **Skip** — move on, come back later
> - **Go back to [previous stage]** — revise an earlier stage

5. On **Approve**: save the document, commit `gtm/.meta.json` with the stage update (`git add gtm/.meta.json && git commit -m "chore(gtm): update meta — {stage} approved"`), then proceed to next stage. Committing `.meta.json` after each stage ensures cascade state survives session interruptions.
6. On **Revise**: regenerate based on feedback, present again
7. On **Skip**: mark as skipped, commit `.meta.json`, proceed (will be flagged incomplete at final review)
8. On **Go back**: revise the earlier stage, then flag downstream documents that may need regeneration

## Cascade Logic

If the user revises an earlier stage, downstream stages must be reviewed (and possibly regenerated).

### Cascade Map

| If Changed | Flag These for Review |
|-----------|----------------------|
| Positioning | Pricing, Channels, Launch Plan, Landing Page, Metrics, Acquisition |
| Pricing | Channels, Launch Plan, Landing Page, Metrics, Acquisition |
| Channels | Launch Plan, Landing Page, Metrics, Acquisition |
| Launch Plan | Landing Page, Metrics |
| Landing Page | Metrics, Acquisition |
| Metrics | Acquisition |

### State Tracking

To make cascades deterministic across sessions and revisions, maintain `gtm/.meta.json`:

```json
{
  "schema_version": 1,
  "stages": {
    "positioning":   { "status": "approved", "version": 2, "updated": "2026-04-16T10:21:00Z" },
    "pricing":       { "status": "approved", "version": 1, "updated": "2026-04-16T10:25:00Z" },
    "channels":      { "status": "stale",    "version": 1, "updated": "2026-04-16T10:28:00Z", "stale_reason": "positioning v1 → v2" },
    "launch-plan":   { "status": "approved", "version": 1, "updated": "2026-04-16T10:31:00Z" },
    "landing-page":  { "status": "skipped",  "version": 0, "updated": null },
    "metrics":       { "status": "pending",  "version": 0, "updated": null },
    "acquisition":   { "status": "pending",  "version": 0, "updated": null }
  }
}
```

**Status values:** `pending` (not started), `approved` (current and accepted), `stale` (an upstream stage changed since this was approved — needs regeneration or explicit re-approval), `skipped` (user opted out for now).

### Cascade Procedure

When the user **approves** a revision to a stage `S`:

1. Bump `stages[S].version`, set `status = approved`, update `updated` to current ISO timestamp.
2. Look up `S` in the Cascade Map. For each downstream stage `D` whose current `status` is `approved`:
   - Set `stages[D].status = stale` and `stages[D].stale_reason = "S v{old} → v{new}"`.
3. Persist `gtm/.meta.json`.
4. Ask the user (single prompt, listing the staled stages):

   > Revising **{S}** invalidated **{D1, D2, ...}** (cascade). For each, choose:
   > - **Regenerate now** — re-run the stage with the new {S}, then prompt for re-approval.
   > - **Flag and continue** — keep current file but leave `status = stale` so the final review surfaces it.
   > - **Re-approve as-is** — mark `status = approved` again without regenerating (only if you've manually verified the stale file is still correct).

5. Apply the user's per-stage choices, updating `gtm/.meta.json` accordingly. If a regenerated stage itself has downstream stages in the Cascade Map, re-run the cascade procedure recursively for that stage (transitive cascade). This continues until no new stages are marked stale.

### Skipped Prerequisite Handling

If a stage's prerequisites include a skipped stage (the `gtm/*.md` file does not exist):
- Inform the user: "Stage N depends on {skipped stage}. That stage was skipped, so the file does not exist."
- Offer options: (a) **Go back** and complete the skipped stage first, or (b) **Continue best-effort** — generate the current stage without that input, noting limitations in the output's Context header.
- If continuing best-effort, add a note to the output: `> **Note:** This document was generated without {skipped stage}. Some recommendations may be incomplete.`

### Final Review Surface

The Final Review step (below) reads `gtm/.meta.json` and lists every stage whose `status` is `stale` or `skipped`. The user must explicitly resolve each one (regenerate, re-approve, or accept skipped) before the final commit.

## PRD Extract Procedure (Chained Mode)

### Subagent Prompt

Dispatch one `Explore` subagent at Mode Detection with this prompt (substitute `{prd-dir}`):

```
Read the following PRD files in parallel and emit a compact GTM context artifact.

Target files (read each exactly once, in parallel):
- {prd-dir}/README.md
- {prd-dir}/features/F-*.md  (use Glob to enumerate, then parallel Read)
- {prd-dir}/journeys/J-*.md  (use Glob to enumerate, then parallel Read)
- {prd-dir}/architecture/deployment.md  (if present)
- {prd-dir}/architecture/dev-workflow.md  (if present)
- {prd-dir}/architecture/tech-stack.md  (if present — for cost signals)

Write the extract to `gtm/.context.md` using the schema below. The goal is to compress the PRD to ~1500–3500 tokens — structured facts only, no prose narrative. Do not paste raw PRD sections; extract and condense.

Schema (use these exact headings; omit any section with no content rather than writing "N/A"):

---
# GTM Context

_Extracted {ISO timestamp} from {prd-dir}_

## Product
- **Name:**
- **Vision:** (one sentence)
- **Problem:** (one paragraph, <60 words)

## Personas
For each persona (derived from README Users + journey persona fields):
- **{name}** — role, situation; primary pain point; frequency/depth of use; where they discover tools; onboarding/activation signals

## Competitive Landscape
For each competitor from README:
- **{name}** — what they do well; where they fall short; differentiation hook if noted

## Features
Table with columns: ID | Name | Priority | 1-liner | Analytics events | Referral/upgrade mechanics (if any)
Keep 1-liner ≤ 15 words. Only list analytics events + mechanics when they exist.

## Journey Signals
Per persona (or per journey if personas map 1:1 to journeys):
- **Pain points verbatim** (top 3–5, for landing-page copy)
- **Completion metrics** — completion rate target, time-to-complete, drop-off points
- **Onboarding / first-run / activation** — described in 1–2 lines each

## Roadmap & MVP
- **MVP scope:** (phase/date if known)
- **Phase breakdown:** P0 / P1 / P2 summary
- **Beta/GA timeline:** (from dev-workflow, if present)

## Architecture Signals
- **Deployment model:** SaaS / self-hosted / CLI / hybrid (from deployment.md)
- **Infrastructure cost drivers:** compute, storage, API limits (from deployment.md or tech-stack.md)
- **Release cadence:** (from dev-workflow.md)
---

Rules:
- Read PRD files in parallel, each exactly once.
- Do not Read the same file twice.
- Do not Grep or explore beyond the listed paths; use Glob only to enumerate features/journeys.
- Do not write or edit anything except `gtm/.context.md`.

On completion, return: "Extract complete: N features, N journeys, N personas. Written to gtm/.context.md."
```

### After Extract

If `.gitignore` does not yet exclude `gtm/.context.md` (either as a line entry or under a broader pattern like `gtm/.context*`), prompt the user to add it before proceeding. `.context.md` is a transient PRD extract, not a spec — see Caching note below.

Read `gtm/.context.md` into main context (once), then present a summary to the user:

> **Extracted from PRD:**
> - Product: [name] — [vision]
> - Target users: [personas]
> - Key features: [top 5–7 by priority]
> - Competitors: [list if found]
>
> Is this accurate? I'll use `gtm/.context.md` as the context for the GTM strategy; I only need to ask you about business-specific details the PRD doesn't cover.

All 7 stages consume `gtm/.context.md`. When a topic file says "extract X from PRD README" or "from features/*.md", treat that as "look up X in `gtm/.context.md`". If a required fact is genuinely missing from `.context.md` (not covered by the schema), read the single specific source file, append the fact to `.context.md`, and continue — **never re-dispatch the Extract subagent or bulk-re-read the PRD**.

### Caching

`gtm/.context.md` is a persistent scratch artifact — it is re-emitted on each chained-mode invocation and should be added to `.gitignore` (see Output Structure below). It is not a spec — `gtm/.meta.json` and the `gtm/*.md` strategy files are the durable outputs.

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
  .context.md                   # (Chained mode only) PRD extract — gitignore it, re-emitted each run
  .meta.json                    # Stage status & cascade state (see Cascade Logic)
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

Path confirmation happens **once before Stage 1** — not per-stage. After confirmation, all stages write to the confirmed directory without re-asking.

## Final Review

**Note:** Templates (generated by `topics/templates.md` after Stage 7) do not have individual review gates — they are generated as a batch and reviewed holistically as part of this final review step.

After all 7 stages + templates are generated:

1. Read `gtm/.meta.json`. List every stage whose status is `stale` or `skipped`. For each, the user must resolve (regenerate / re-approve / leave skipped). Loop until no `stale` stages remain.
2. Generate `gtm/README.md` as executive summary linking all documents (note skipped stages explicitly).
3. Present the complete `gtm/` directory for final review.
4. On approval: commit the entire `gtm/` directory (including `.meta.json`) in a single commit.

## Key Principles

- **Business-first** — strategy and planning over code generation
- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer than open-ended
- **Smart context** — read PRD when available, only ask what's missing
- **Actionable outputs** — not just strategy docs but ready-to-use templates
- **Self-contained outputs** — every `gtm/*.md` file starts with a short Context header inlining the upstream facts it relies on (persona, value prop, price tiers, launch date). A reader should be able to act on any single file without opening the others. Do not cross-reference — copy.
- **YAGNI** — push back on overcomplicating the strategy

## Next Steps Hint

After committing, print:

```
GTM strategy complete: {output path}

Next steps:
  Build landing page — /frontend-design (use landing-page-spec.md as input)
  Review & iterate  — re-run /go-to-market to update specific sections
```
