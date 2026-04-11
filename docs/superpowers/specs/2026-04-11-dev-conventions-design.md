# Dev Conventions Skill — Design Spec

## Overview

A single Claude Code skill (`/dev-conventions`) that generates platform-native development convention files for GitHub or GitLab projects. It produces Issue/PR/MR templates, CI/CD workflows for AI-powered lint and auto-correction, local git hooks for Conventional Commits enforcement, and a human-readable `CONTRIBUTING.md`.

### Goals

- Enforce consistent Issue, PR/MR, and Commit conventions across projects
- Automate compliance checking via CI/CD with Claude Code CLI for AI-powered direct editing
- Provide local git hooks as a first line of defense for commit message quality
- Deliver as a DevForge skill that works on any target project

### Non-Goals

- Platform-specific features (GitLab epics/weights, GitHub Projects) — content is identical across platforms
- Custom convention types beyond the standard set — types are fixed
- Auto-fixing commit messages in CI (requires rebase, too risky)

## Skill Structure

```
.claude/skills/dev-conventions/
├── SKILL.md                        # Skill entry point, interaction flow
├── conventions-core.md             # Shared core conventions definition
├── templates/
│   ├── github/
│   │   ├── issue-bug.yml           # GitHub Issue template: Bug (YAML form)
│   │   ├── issue-feature.yml       # GitHub Issue template: Feature
│   │   ├── issue-task.yml          # GitHub Issue template: Task
│   │   ├── issue-enhancement.yml   # GitHub Issue template: Enhancement
│   │   ├── issue-question.yml      # GitHub Issue template: Question
│   │   ├── issue-documentation.yml # GitHub Issue template: Documentation
│   │   ├── config.yml              # Template chooser config
│   │   ├── pull-request.md         # GitHub PR template
│   │   ├── lint-issue.yml          # GitHub Actions: Issue lint & fix
│   │   ├── lint-pr.yml             # GitHub Actions: PR lint & fix
│   │   └── lint-commits.yml        # GitHub Actions: Commit message check
│   └── gitlab/
│       ├── issue-bug.md            # GitLab Issue template: Bug
│       ├── issue-feature.md        # GitLab Issue template: Feature
│       ├── issue-task.md           # GitLab Issue template: Task
│       ├── issue-enhancement.md    # GitLab Issue template: Enhancement
│       ├── issue-question.md       # GitLab Issue template: Question
│       ├── issue-documentation.md  # GitLab Issue template: Documentation
│       ├── merge-request.md        # GitLab MR template
│       └── lint-conventions.yml    # GitLab CI: lint stages
├── hooks/
│   ├── commit-msg.sh               # commit-msg hook script
│   ├── husky-setup.md              # Husky installation prompt
│   └── pre-commit-setup.md         # pre-commit installation prompt
└── contributing-template.md        # CONTRIBUTING.md template
```

## Core Conventions

### Commit Message Format

Standard [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Allowed types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Rules:**
- Subject line must not exceed 72 characters
- `type` and `description` are required; `scope` is optional
- Body must be separated from subject by a blank line
- Footer supports `Closes #123`, `BREAKING CHANGE:`, etc.

### Issue Types and Required Fields

| Type          | Required Fields                                                        |
|---------------|------------------------------------------------------------------------|
| Bug           | Title, Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Environment |
| Feature       | Title, Description, Motivation, Acceptance Criteria                    |
| Task          | Title, Description, Acceptance Criteria                                |
| Enhancement   | Title, Description, Current Behavior, Proposed Improvement             |
| Question      | Title, Description, Context                                            |
| Documentation | Title, Description, Affected Sections                                  |

**Title format:** `[Type] Brief description` — e.g. `[Bug] Login fails when password contains special characters`

### PR / MR Types and Required Fields

**Types:** Feature, Fix, Refactor, Docs, Test, Chore

**Required fields (all types):**
- Title: `[Type] Brief description`
- Summary: Brief description of changes
- Related Issues: Linked issue numbers
- Changes: List of changes made
- Test Plan: How the changes were tested

## CI/CD: Automated Lint and AI Correction

### Trigger Conditions

| Platform | Event              | Trigger                                    |
|----------|--------------------|--------------------------------------------|
| GitHub   | Issue opened/edited | `issues: [opened, edited]`                |
| GitHub   | PR opened/edited    | `pull_request: [opened, edited]`           |
| GitLab   | Issue created/updated | Webhook triggers a pipeline job via GitLab API trigger token |
| GitLab   | MR opened/updated   | `rules: - if: $CI_PIPELINE_SOURCE == "merge_request_event"` |

### Lint and Fix Flow

1. **Extract content** — via `gh` / `glab` CLI, get title, body, labels
2. **Claude Code CLI analysis** — pass content + convention rules, check compliance
3. **Non-compliant → Claude Code CLI generates corrected content**
4. **Direct edit** — update title, body, labels via `gh` / `glab` CLI
5. **Leave comment** — explain what was corrected so the author is informed

### Claude Code CLI Invocation

Run in non-interactive mode via `claude -p`:

```bash
ISSUE_BODY=$(gh issue view $ISSUE_NUMBER --json title,body,labels --jq '.')
CONVENTIONS=$(cat .github/CONVENTIONS.md)

claude -p "You are a dev conventions linter. Given the following conventions:
${CONVENTIONS}

And the following issue content:
${ISSUE_BODY}

Check compliance. If non-compliant, output the corrected JSON with fields: title, body, labels.
If compliant, output: {\"compliant\": true}"
```

Corrected content is written back via `gh issue edit` / `glab issue update`.

### Commit Message CI Check

In PR/MR pipelines, validate all branch commits against the Conventional Commits regex:

```bash
git log origin/main..HEAD --pretty=format:"%s" | while read msg; do
  echo "$msg" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'
done
```

Non-compliant commits mark the check as failed. No auto-fix (rewriting commit history is too risky).

### Required Secrets

| Platform | Secret                   | Purpose                  |
|----------|--------------------------|--------------------------|
| GitHub   | `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code CLI auth    |
| GitLab   | `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code CLI auth    |

## Local Git Hooks

### Hook Tool Detection

```
Scan target project root
    ↓
package.json exists? → Husky
    ↓ (no)
pyproject.toml / requirements.txt / setup.py exists? → pre-commit
    ↓ (no)
go.mod exists? → pre-commit
    ↓ (no)
Ask user: Husky / pre-commit / native script
```

### Husky Configuration (Node.js)

1. Check if `husky` is installed; if not, run `npm install --save-dev husky`
2. Run `npx husky init` if `.husky/` does not exist
3. Write `.husky/commit-msg`:

```bash
#!/bin/sh
commit_msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'

if ! echo "$commit_msg" | grep -qE "$pattern"; then
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo ""
  echo "Expected: <type>(<scope>): <description>"
  echo "Types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
  echo ""
  echo "Your message: $commit_msg"
  exit 1
fi
```

### pre-commit Configuration (Python / Go / Other)

1. Check if `pre-commit` is installed; prompt to install if needed
2. Generate `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.6.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
        args:
          - feat
          - fix
          - docs
          - style
          - refactor
          - perf
          - test
          - build
          - ci
          - chore
          - revert
```

3. Run `pre-commit install --hook-type commit-msg`

### Native Script Fallback

For projects not using the above toolchains, generate `scripts/install-hooks.sh` that copies the hook script to `.git/hooks/`.

## CONTRIBUTING.md Generation

Dynamically generated from the actual configuration applied to the project. Structure:

1. **Commit Messages** — format, allowed types, examples
2. **Issues** — types, required fields per type, title format
3. **Pull Requests / Merge Requests** — types, required fields, title format
4. **Automated Checks** — what the CI checks, how corrections work
5. **Local Setup** — hook tool installation instructions (specific to detected toolchain)

Content is populated from `conventions-core.md` and the actual generated files to ensure documentation stays consistent with configuration.

## Skill Interaction Flow (SKILL.md)

### Trigger

```
/dev-conventions
```

### Steps

**Step 1: Platform Detection**
- Read `git remote -v` output
- Contains `github.com` → GitHub
- Contains `gitlab.com` or recognized self-hosted GitLab → GitLab
- Cannot determine → Ask: "Is this a GitHub or GitLab project?"

**Step 2: Tech Stack Detection**
- Scan for `package.json` → Node.js
- Scan for `pyproject.toml` / `requirements.txt` / `setup.py` → Python
- Scan for `go.mod` → Go
- None matched → "other"

**Step 3: Hook Tool Confirmation**
- Node.js → "Will use Husky for git hooks. OK?"
- Python/Go → "Will use pre-commit for git hooks. OK?"
- Other → "Which hook tool? (A) Husky (B) pre-commit (C) Native script"

**Step 4: Conflict Detection**
- Check for existing `.github/ISSUE_TEMPLATE/` or `.gitlab/issue_templates/`
- Check for existing CI workflow/pipeline files
- Check for existing `.husky/` or `.pre-commit-config.yaml`
- Conflicts found → ask per item: "Overwrite / Merge / Skip?"

**Step 5: Generate Files**
- Copy platform-appropriate Issue/PR/MR templates to target directories
- Generate CI workflow/pipeline configuration
- Configure git hooks via selected tool
- Generate `CONTRIBUTING.md`

**Step 6: Output Summary**
- List all generated/modified files
- Remind user to configure `CLAUDE_CODE_OAUTH_TOKEN` secret
- Remind user to review `CONTRIBUTING.md`

### Idempotency

The skill can be run multiple times safely. Step 4 conflict detection prevents accidental overwrites of user-customized configuration.

### Error Handling

- Not in a git repository → error and exit
- No remote URL and user declines to select platform → error and exit
- Hook tool installation fails → skip hook config, inform user to install manually, proceed with remaining files

## Generated File Layout

### GitHub Project

```
target-project/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug.yml
│   │   ├── feature.yml
│   │   ├── task.yml
│   │   ├── enhancement.yml
│   │   ├── question.yml
│   │   ├── documentation.yml
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
│       ├── lint-issue.yml
│       ├── lint-pr.yml
│       └── lint-commits.yml
├── CONTRIBUTING.md
└── .husky/commit-msg  (or .pre-commit-config.yaml)
```

### GitLab Project

```
target-project/
├── .gitlab/
│   ├── issue_templates/
│   │   ├── Bug.md
│   │   ├── Feature.md
│   │   ├── Task.md
│   │   ├── Enhancement.md
│   │   ├── Question.md
│   │   └── Documentation.md
│   └── merge_request_templates/
│       └── Default.md
├── .gitlab-ci.yml  (or .gitlab/ci/lint-conventions.yml with include)
├── CONTRIBUTING.md
└── .husky/commit-msg  (or .pre-commit-config.yaml)
```

For GitLab CI integration, if `.gitlab-ci.yml` already exists, the skill generates `.gitlab/ci/lint-conventions.yml` as a separate file and instructs the user to add an `include` directive. If no existing CI config, the skill generates a standalone `.gitlab-ci.yml`.
