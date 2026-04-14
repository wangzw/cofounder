# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CoFounder is a suite of interconnected Claude Code skills that guide solo founders and small teams through the full business lifecycle: idea -> requirements -> design -> implementation -> launch. Skills live in `.claude/skills/` and are auto-discovered by Claude Code.

## Pipeline

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

Skills are chainable: `/system-design` reads PRD output, `/autoforge` reads system design output, `/go-to-market` can chain from PRD. `/dev-conventions` is standalone and generates repo scaffolding (templates, hooks, CI).

## Skill Architecture

Each skill follows the same structure:

- **`SKILL.md`** — Entry point. Contains metadata and mode-routing logic that loads only the relevant topic files for the current mode (e.g., initial questioning vs. review vs. evolution). This prevents loading unused workflows into context.
- **Topic files** — Phase-specific instructions (e.g., `questioning-phases.md`, `review-mode.md`, `evolve-mode.md`).
- **Template files** — Output format definitions (e.g., `feature-template.md`, `module-template.md`).
- **Prompt files** (autoforge only) — Agent prompts for planner, developer, tester, reviewer roles.

### Self-Contained File Principle

Every output file (feature spec, module spec, journey map) must be independently readable. All referenced context — data models, conventions, dependencies — is copied inline rather than cross-referenced. This minimizes context consumption when coding agents consume a single spec.

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

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Scope is optional but typically the skill name (e.g., `feat(prd-analysis): ...`).

## Adding or Modifying Skills

When creating a new skill:
1. Create `.claude/skills/{skill-name}/SKILL.md` with frontmatter (name, description, trigger conditions)
2. Use mode-routing in SKILL.md to avoid loading all topic files at once
3. Create topic files for each phase/mode
4. Create template files that define output format
5. Ensure output files follow the self-contained principle

When modifying an existing skill, start by reading its `SKILL.md` to understand the mode-routing logic before touching topic or template files. Changes to templates affect all future output — verify the template structure is consistent with the README index format.

## Review Gates

Skills include human review checkpoints before finalizing output:
- `/prd-analysis`: 130+ dimension review checklist in SKILL.md
- `/system-design`: structured design review phase
- `/autoforge`: approval gates after planning (before execution), progress checks during execution
- `/go-to-market`: per-stage approve/revise/skip/go-back logic with cascade updates
