# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CoFounder is a Claude Code **plugin** that guides solo founders and small teams through the full business lifecycle: idea -> requirements -> design -> implementation -> launch. Skills live in `skills/` (plugin format) and are loaded via the plugin system.

**Install locally for development:**
```bash
claude --plugin-dir /path/to/cofounder
```

Skills are invoked with the `cofounder:` namespace prefix: `/cofounder:prd-analysis`, `/cofounder:system-design`, etc.

## Pipeline

```
Idea → /cofounder:prd-analysis → /cofounder:system-design → /cofounder:autoforge → /cofounder:go-to-market → Market-Ready Business
                                                                      ↑
                                              /cofounder:dev-conventions (standalone, run anytime)
```

Skills are chainable: `/cofounder:system-design` reads PRD output, `/cofounder:autoforge` reads system design output, `/cofounder:go-to-market` can chain from PRD. `/cofounder:dev-conventions` is standalone — run it at any point to generate repo scaffolding (issue/PR templates, CI lint workflows, git hooks, CONTRIBUTING.md). It is independent of the main pipeline and can be used before or after `/cofounder:autoforge`.

## Meta-Skill

`/cofounder:skill-forge` is a generative skill that generates new generative skills per the generative-skill design guide (`~/Documents/mind/raw/guide/生成式 Skill 设计指南.md`). It is orthogonal to the main pipeline — use it when you want to add a new skill to cofounder (or anywhere else) that produces artifacts from sparse input.

Triggers:
- `/cofounder:skill-forge "I want a skill that ..."` — from-scratch generation
- `/cofounder:skill-forge --target skills/<name> "<change>"` — new-version evolution
- `/cofounder:skill-forge --review --target skills/<name>` — review an existing skill
- `/cofounder:skill-forge --diagnose [--round N | --delivery N]` — pure-script metrics aggregation

See `skills/skill-forge/SKILL.md` for the full mode routing and the generative-skill design guide for methodology.

## Skill Architecture

Each skill follows the same structure:

- **`SKILL.md`** — Entry point. Contains metadata and mode-routing logic that loads only the relevant topic files for the current mode (e.g., initial questioning vs. review vs. evolution). This prevents loading unused workflows into context.
- **Topic files** — Phase-specific instructions (e.g., `questioning-phases.md`, `review-mode.md`, `evolve-mode.md`).
- **Template files** — Output format definitions (e.g., `feature-template.md`, `module-template.md`).
- **Prompt files** (autoforge only) — Agent prompts for planner, developer, tester, reviewer roles.

### Self-Contained File Principle

Every output file (feature spec, module spec, journey map) must be independently readable. All referenced context — data models, conventions, dependencies — is copied inline rather than cross-referenced. This minimizes context consumption when coding agents consume a single spec.

**In practice:** when a template says 'copy applicable conventions from architecture.md', it means copy the relevant text from `architecture/*.md` topic files into the feature/module file inline — not add a file path reference. The consuming agent should never need to open a second file.

### Output Conventions

All generated artifacts use date-prefixed directories:
- PRDs: `docs/raw/prd/YYYY-MM-DD-{product-slug}/`
- System Designs: `docs/raw/design/YYYY-MM-DD-{product-slug}/`
- GTM: `gtm/` (or custom `--output` path)

Multi-file output structure: `README.md` (index with summaries, not full content) + subdirectories for individual specs (`journeys/J-001.md`, `features/F-001-slug.md`, `modules/M-001-slug.md`).

### ID Conventions

- Features: `F-001`, `F-002`, ... (zero-padded, sequential, stable across iterations)
- Journeys: `J-001`, `J-002`, ...
- Modules: `M-001`, `M-002`, ...

## Glossary

Key terms used across skills. Skills reference these definitions rather than redefining them.

| Term | Definition |
|------|-----------|
| **Self-contained file** | A file that can be read and acted on independently. All referenced context (data models, conventions, journey context) is copied inline rather than cross-referenced. A coding agent implementing a feature reads only that feature's file. |
| **Interaction Mode** | The primary user interaction pattern at a journey touchpoint: `click` (mouse click on UI element), `form` (fill and submit form fields), `drag` (drag-and-drop), `keyboard` (keyboard input, shortcuts), `scroll` (scroll-triggered actions), `hover` (hover-triggered tooltips/menus), `swipe` (touch gesture), `voice` (voice command), `scan` (QR/barcode scan). If a touchpoint has multiple modes, list the primary one; details belong in the feature's state machine. |
| **Cross-journey pattern** | A recurring theme observed across multiple user journeys — shared pain points, repeated touchpoints, common infrastructure needs, or handoff points between personas. Documented in the PRD README's Cross-Journey Patterns section. Each pattern should be addressed by at least one feature. |
| **Feature-Module mapping** | A matrix in the system design README linking PRD features (columns) to implementation modules (rows). Symbols: `✦` = module modifies data for this feature, `△` = module provides read-only support. The mapping is the bridge between requirements and implementation. |
| **Touchpoint** | A specific moment in a user journey where the user interacts with the system. Defined by: stage name, screen/view, action, interaction mode, system response, and pain point (if any). Touchpoints drive feature derivation — every feature maps back to at least one touchpoint. |
| **Design token** | A named value (color, spacing, typography, motion, etc.) that represents a design decision. PRD defines token semantics and values; system-design defines the implementation mechanism (CSS custom properties, Tailwind config, terminal constants). Tokens use semantic names (e.g., `color.primary`, `spacing.md`) not raw values. |
| **Tombstone** | In evolve-mode PRDs, a minimal file that marks a feature or journey as deprecated. Contains status, deprecation reason, replacement reference (if any), and link to the original in the baseline PRD. |

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Scope is optional but typically the skill name (e.g., `feat(prd-analysis): ...`).

## Adding or Modifying Skills

When creating a new skill:
1. Create `skills/{skill-name}/SKILL.md` with frontmatter (name, description, trigger conditions)
2. Use mode-routing in SKILL.md to avoid loading all topic files at once
3. Create topic files for each phase/mode
4. Create template files that define output format
5. Ensure output files follow the self-contained principle

When modifying an existing skill, start by reading its `SKILL.md` to understand the mode-routing logic before touching topic or template files. Changes to templates affect all future output — verify the template structure is consistent with the README index format.

## Review Gates

Skills include human review checkpoints before finalizing output:
- `/cofounder:prd-analysis`: ~50 dimension review checklist in `review-checklist.md` (many dimensions have multiple sub-checks)
- `/cofounder:system-design`: structured design review phase
- `/cofounder:autoforge`: approval gates after planning (before execution), progress checks during execution
- `/cofounder:go-to-market`: per-stage approve/revise/skip/go-back logic with cascade updates
