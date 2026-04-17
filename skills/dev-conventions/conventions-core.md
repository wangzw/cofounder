# Core Development Conventions

## Commit Message Format

Standard [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

| Type | Description |
|------|-------------|
| feat | A new feature |
| fix | A bug fix |
| docs | Documentation only changes |
| style | Formatting, missing semi colons, etc. (no code change) |
| refactor | Code change that neither fixes a bug nor adds a feature |
| perf | A code change that improves performance |
| test | Adding or correcting tests |
| build | Changes to build system or external dependencies |
| ci | Changes to CI configuration files and scripts |
| chore | Other changes that don't modify src or test files |
| revert | Reverts a previous commit |

### Rules

- Subject line MUST NOT exceed 72 characters
- `type` and `description` are REQUIRED; `scope` is OPTIONAL
- Body MUST be separated from subject by a blank line
- Footer supports `Closes #123`, `Refs #456`, `BREAKING CHANGE:` etc.

### Validation Regex

```
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$
```

## Issue Types and Required Fields

### Bug

- **Title:** `[Bug] <brief description>`
- **Required fields:** Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Environment

### Feature

- **Title:** `[Feature] <brief description>`
- **Required fields:** Description, Motivation, Acceptance Criteria

### Task

- **Title:** `[Task] <brief description>`
- **Required fields:** Description, Acceptance Criteria

### Enhancement

- **Title:** `[Enhancement] <brief description>`
- **Required fields:** Description, Current Behavior, Proposed Improvement

### Question

- **Title:** `[Question] <brief description>`
- **Required fields:** Description, Context

### Documentation

- **Title:** `[Documentation] <brief description>`
- **Required fields:** Description, Affected Sections

## PR / MR Types and Required Fields

### Types

| Type | Description |
|------|-------------|
| Feature | New functionality |
| Fix | Bug fix |
| Refactor | Code restructuring without behavior change |
| Docs | Documentation only changes |
| Test | Adding or updating tests |
| Chore | Build, CI, dependencies, tooling |

### Required Fields (all types)

- **Title:** `[Type] <brief description>`
- **Summary:** Brief description of changes
- **Related Issues:** Linked issue numbers
- **Changes:** List of changes made
- **Test Plan:** How the changes were tested
