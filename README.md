# DevForge

Claude Code skills for turning ideas into production code through a structured pipeline: requirements analysis, system design, and automated multi-agent implementation.

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

## Workflow

```
Idea → /prd-analysis → /system-design → /autoforge → Production Code
```

## Installation

Clone this repo into your workspace. The skills are automatically discovered by Claude Code from `.claude/skills/`.

```sh
git clone <repo-url> devforge
```

## License

MIT
