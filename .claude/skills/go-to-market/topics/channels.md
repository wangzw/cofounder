# Stage 3: Distribution Channels

This file contains instructions for generating the distribution channels strategy. It builds on positioning (Stage 1) and pricing (Stage 2), and references `references/channel-playbooks.md` for domain knowledge.

---

## Prerequisites

Read before generating:
- `gtm/positioning.md` — target persona, where they spend time
- `gtm/pricing-strategy.md` — pricing model (affects channel fit: free products favor viral channels)
- `references/channel-playbooks.md` — channel matrix, per-channel playbooks, budget allocation

### Chained Mode (PRD exists)

Re-read these PRD sections before generating (do not rely solely on prior `gtm/` files):
- `journeys/*.md` — personas, workflows, where users currently discover tools
- `README.md` — target audience description, competitive landscape
- `architecture/deployment.md` — deployment model (affects distribution: self-hosted vs. SaaS vs. CLI)

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

Write to `{output_dir}/channels.md`. Present a summary to the user and enter the review gate.
