# Contributing Guide

Thank you for contributing! This document describes the conventions and automated checks used in this project.

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

| Type | Description |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Formatting, missing semi colons, etc. (no code change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | A code change that improves performance |
| `test` | Adding or correcting tests |
| `build` | Changes to build system or external dependencies |
| `ci` | Changes to CI configuration files and scripts |
| `chore` | Other changes that don't modify src or test files |
| `revert` | Reverts a previous commit |

### Examples

```
feat(auth): add OAuth2 login flow
fix: resolve null pointer in user service
docs(readme): update installation instructions
refactor(api): extract validation middleware
test(auth): add integration tests for login
chore: update dependencies
revert: revert "feat(auth): add OAuth2 login flow"

feat(api)!: change response format for /users endpoint

BREAKING CHANGE: The /users endpoint now returns a paginated response.
```

## Issues

### Types

| Type | Label | Title Format |
|------|-------|-------------|
| Bug | `bug` | `[Bug] Brief description` |
| Feature | `feature` | `[Feature] Brief description` |
| Task | `task` | `[Task] Brief description` |
| Enhancement | `enhancement` | `[Enhancement] Brief description` |
| Question | `question` | `[Question] Brief description` |
| Documentation | `documentation` | `[Documentation] Brief description` |

### Required Fields by Type

| Type | Required Fields |
|------|----------------|
| Bug | Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Environment |
| Feature | Description, Motivation, Acceptance Criteria |
| Task | Description, Acceptance Criteria |
| Enhancement | Description, Current Behavior, Proposed Improvement |
| Question | Description, Context |
| Documentation | Description, Affected Sections |

## Pull Requests / Merge Requests

### Types

| Type | Description |
|------|-------------|
| Feature | New functionality |
| Fix | Bug fix |
| Refactor | Code restructuring without behavior change |
| Docs | Documentation only changes |
| Test | Adding or updating tests |
| Chore | Build, CI, dependencies, tooling |

### Title Format

`[Type] Brief description` — e.g. `[Fix] Resolve login timeout on slow connections`

### Required Sections

Every PR/MR description must include:

- **Summary** — Brief description of changes
- **Related Issues** — Linked issue numbers (e.g. `Closes #123`)
- **Changes** — List of changes made
- **Test Plan** — How the changes were tested

## Automated Checks

This project uses automated CI checks to enforce conventions:

- **Issue lint** — When an issue is created or edited, its title format and required fields are automatically checked and corrected by AI
- **PR/MR lint** — When a PR/MR is created or edited, its title format and required sections are automatically checked and corrected by AI
- **Commit message lint** — When a PR/MR is created or updated, all commit messages on the branch are validated against Conventional Commits format. Non-compliant commits will cause the check to fail

Corrections are applied directly and a comment is left explaining what was changed.

## Local Setup

A `commit-msg` git hook validates your commit messages locally before they are pushed.

{HOOK_SETUP}
