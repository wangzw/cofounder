# CoFounder

AI-powered skills that guide solo founders and small teams through the full business lifecycle — from idea to product to market-ready launch. Your AI co-founder for requirements, design, implementation, and go-to-market.

## Skills

### `/prd-analysis` — Product Requirements

Generates PRDs as multi-file directories. Each feature spec is self-contained so coding agents read only the file they need, minimizing context consumption.

- Interactive, document-based, or brainstorm-to-PRD input modes
- Outputs: README overview, feature specs, user journey maps, architecture summary
- Structured review phase with checklists

### `/system-design` — Technical Design

Transforms a PRD into implementation-ready system design documents with module decomposition, interface definitions, and data models.

- PRD-based, document-based, or interactive input modes
- Outputs: design overview, module specs, API contracts
- Incremental design mode for existing codebases
- Built-in design review and revision workflows

### `/autoforge` — Automated Implementation

Orchestrates parallel agent teams to turn a system design into tested, PRD-validated code. Each module gets its own team (Planner, Developer, Tester, Reviewer) working in isolated git worktrees.

- Dependency-aware phase execution with parallel module teams
- Retry loops with automatic failure recovery
- PRD acceptance testing with requirements traceability
- Human review gates between planning and execution

### `/go-to-market` — Launch Strategy

Guides solo founders and small startup teams from finished product to market-ready launch through a sequential 7-stage wizard.

- Chained mode (reads PRD) or standalone interactive mode
- 7 stages: positioning, pricing, channels, launch plan, landing page spec, metrics, acquisition playbook
- Outputs: strategy documents + ready-to-use templates (emails, social posts, launch checklist)
- Review gates with cascade logic for revisions

### `/dev-conventions` — Development Conventions

Generates convention files for GitHub or GitLab projects: issue/PR/MR templates, CI/CD lint workflows, git hooks, and CONTRIBUTING.md.

- Detects platform (GitHub/GitLab) and package manager automatically
- Conventional Commits enforcement via hooks (Husky, pre-commit, or shell)
- CI/CD workflows for commit message linting

## Workflow

```
Idea → /prd-analysis → /system-design → /autoforge → /go-to-market → Market-Ready Business
```

## Installation

Clone this repo into your workspace. The skills are automatically discovered by Claude Code from `.claude/skills/`.

```sh
git clone git@github.com:wangzw/cofounder.git
```

## Roadmap

See [todo.md](todo.md) for planned skills covering business modeling, growth, customer ops, content strategy, pitch decks, team operations, legal templates, retrospectives, and pivot analysis.

## License

MIT
