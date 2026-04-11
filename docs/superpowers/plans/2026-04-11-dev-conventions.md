# Dev Conventions Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a `/dev-conventions` Claude Code skill that generates platform-native development convention files (Issue/PR/MR templates, CI/CD workflows, git hooks, CONTRIBUTING.md) for GitHub or GitLab projects.

**Architecture:** A single skill with `SKILL.md` as the entry point, a shared `conventions-core.md` defining the canonical rules, platform-specific template files under `templates/github/` and `templates/gitlab/`, hook scripts under `hooks/`, and a `contributing-template.md` for generating `CONTRIBUTING.md`. The skill detects the target platform and tech stack, then copies/adapts templates to the target project.

**Tech Stack:** Claude Code skill (markdown prompts), GitHub Actions YAML, GitLab CI YAML, Conventional Commits, Husky (Node.js), pre-commit (Python/Go), shell scripts.

**Spec:** `docs/superpowers/specs/2026-04-11-dev-conventions-design.md`

---

### Task 1: Create Core Conventions Definition

**Files:**
- Create: `.claude/skills/dev-conventions/conventions-core.md`

- [ ] **Step 1: Create conventions-core.md**

This is the single source of truth for all convention rules, referenced by SKILL.md, CI workflows, and CONTRIBUTING.md generation.

```markdown
# Core Development Conventions

## Commit Message Format

Standard [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0:

\`\`\`
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
\`\`\`

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

\`\`\`
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$
\`\`\`

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
```

- [ ] **Step 2: Verify the file is well-formed**

Run: `cat .claude/skills/dev-conventions/conventions-core.md | head -5`
Expected: The first lines of the file are displayed correctly.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/dev-conventions/conventions-core.md
git commit -m "feat(dev-conventions): add core conventions definition"
```

---

### Task 2: Create GitHub Issue Templates (YAML Form)

**Files:**
- Create: `.claude/skills/dev-conventions/templates/github/issue-bug.yml`
- Create: `.claude/skills/dev-conventions/templates/github/issue-feature.yml`
- Create: `.claude/skills/dev-conventions/templates/github/issue-task.yml`
- Create: `.claude/skills/dev-conventions/templates/github/issue-enhancement.yml`
- Create: `.claude/skills/dev-conventions/templates/github/issue-question.yml`
- Create: `.claude/skills/dev-conventions/templates/github/issue-documentation.yml`
- Create: `.claude/skills/dev-conventions/templates/github/config.yml`

- [ ] **Step 1: Create issue-bug.yml**

```yaml
name: Bug Report
description: Report a bug
title: "[Bug] "
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: |
        Thank you for reporting a bug. Please fill out the sections below.
  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear and concise description of the bug.
    validations:
      required: true
  - type: textarea
    id: steps-to-reproduce
    attributes:
      label: Steps to Reproduce
      description: Steps to reproduce the behavior.
      placeholder: |
        1. Go to '...'
        2. Click on '...'
        3. See error
    validations:
      required: true
  - type: textarea
    id: expected-behavior
    attributes:
      label: Expected Behavior
      description: What you expected to happen.
    validations:
      required: true
  - type: textarea
    id: actual-behavior
    attributes:
      label: Actual Behavior
      description: What actually happened.
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: OS, browser, runtime version, etc.
      placeholder: |
        - OS: [e.g. macOS 15.0]
        - Browser: [e.g. Chrome 130]
        - Runtime: [e.g. Node.js 22]
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other context, screenshots, or logs.
    validations:
      required: false
```

- [ ] **Step 2: Create issue-feature.yml**

```yaml
name: Feature Request
description: Suggest a new feature
title: "[Feature] "
labels: ["feature"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear and concise description of the feature.
    validations:
      required: true
  - type: textarea
    id: motivation
    attributes:
      label: Motivation
      description: Why is this feature needed? What problem does it solve?
    validations:
      required: true
  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: How do we know this feature is complete?
      placeholder: |
        - [ ] Criterion 1
        - [ ] Criterion 2
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other context, mockups, or references.
    validations:
      required: false
```

- [ ] **Step 3: Create issue-task.yml**

```yaml
name: Task
description: A task to be completed
title: "[Task] "
labels: ["task"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear description of the task.
    validations:
      required: true
  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: How do we know this task is done?
      placeholder: |
        - [ ] Criterion 1
        - [ ] Criterion 2
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other context or references.
    validations:
      required: false
```

- [ ] **Step 4: Create issue-enhancement.yml**

```yaml
name: Enhancement
description: Suggest an improvement to existing functionality
title: "[Enhancement] "
labels: ["enhancement"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear description of the enhancement.
    validations:
      required: true
  - type: textarea
    id: current-behavior
    attributes:
      label: Current Behavior
      description: How does the current functionality work?
    validations:
      required: true
  - type: textarea
    id: proposed-improvement
    attributes:
      label: Proposed Improvement
      description: What should be improved and how?
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other context or references.
    validations:
      required: false
```

- [ ] **Step 5: Create issue-question.yml**

```yaml
name: Question
description: Ask a question about the project
title: "[Question] "
labels: ["question"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What is your question?
    validations:
      required: true
  - type: textarea
    id: context
    attributes:
      label: Context
      description: What have you tried or looked at so far?
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other relevant information.
    validations:
      required: false
```

- [ ] **Step 6: Create issue-documentation.yml**

```yaml
name: Documentation
description: Report a documentation issue or suggest an improvement
title: "[Documentation] "
labels: ["documentation"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What documentation needs to be added or changed?
    validations:
      required: true
  - type: textarea
    id: affected-sections
    attributes:
      label: Affected Sections
      description: Which parts of the documentation are affected?
    validations:
      required: true
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Any other context or references.
    validations:
      required: false
```

- [ ] **Step 7: Create config.yml**

```yaml
blank_issues_enabled: false
contact_links: []
```

- [ ] **Step 8: Verify all GitHub issue template files exist**

Run: `ls -la .claude/skills/dev-conventions/templates/github/issue-*.yml .claude/skills/dev-conventions/templates/github/config.yml`
Expected: 7 files listed (6 issue templates + config.yml).

- [ ] **Step 9: Commit**

```bash
git add .claude/skills/dev-conventions/templates/github/
git commit -m "feat(dev-conventions): add GitHub issue templates"
```

---

### Task 3: Create GitHub PR Template

**Files:**
- Create: `.claude/skills/dev-conventions/templates/github/pull-request.md`

- [ ] **Step 1: Create pull-request.md**

```markdown
## [Type] Title

<!-- Replace [Type] with one of: Feature, Fix, Refactor, Docs, Test, Chore -->

## Summary

<!-- Brief description of the changes -->

## Related Issues

<!-- Link to related issues: Closes #123, Refs #456 -->

## Changes

<!-- List the changes made -->

- 

## Test Plan

<!-- How were the changes tested? -->

- 

## Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] Tests have been added/updated
- [ ] Documentation has been updated (if applicable)
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/dev-conventions/templates/github/pull-request.md
git commit -m "feat(dev-conventions): add GitHub PR template"
```

---

### Task 4: Create GitHub Actions Workflows

**Files:**
- Create: `.claude/skills/dev-conventions/templates/github/lint-issue.yml`
- Create: `.claude/skills/dev-conventions/templates/github/lint-pr.yml`
- Create: `.claude/skills/dev-conventions/templates/github/lint-commits.yml`

- [ ] **Step 1: Create lint-issue.yml**

```yaml
name: Lint Issue

on:
  issues:
    types: [opened, edited]

permissions:
  issues: write

jobs:
  lint-issue:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Get issue content
        id: issue
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh issue view ${{ github.event.issue.number }} \
            --json title,body,labels \
            --jq '.' > /tmp/issue.json

      - name: Lint and fix issue
        env:
          CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
        run: |
          ISSUE_CONTENT=$(cat /tmp/issue.json)
          CONVENTIONS=$(cat CONTRIBUTING.md)

          RESULT=$(claude -p "You are a dev conventions linter. You MUST output valid JSON only, no other text.

          Given the following conventions:
          ${CONVENTIONS}

          And the following issue content:
          ${ISSUE_CONTENT}

          Check if the issue complies with the conventions (title format, required fields).
          If non-compliant, output corrected JSON: {\"compliant\": false, \"title\": \"corrected title\", \"body\": \"corrected body\", \"labels\": [\"label\"], \"corrections\": [\"list of corrections made\"]}
          If compliant, output: {\"compliant\": true}")

          echo "${RESULT}" > /tmp/result.json

      - name: Apply corrections
        if: success()
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          COMPLIANT=$(jq -r '.compliant' /tmp/result.json)

          if [ "$COMPLIANT" = "false" ]; then
            TITLE=$(jq -r '.title' /tmp/result.json)
            BODY=$(jq -r '.body' /tmp/result.json)
            CORRECTIONS=$(jq -r '.corrections | join("\n- ")' /tmp/result.json)

            gh issue edit ${{ github.event.issue.number }} \
              --title "${TITLE}" \
              --body "${BODY}"

            gh issue comment ${{ github.event.issue.number }} \
              --body "**Auto-formatted by conventions linter:**

          - ${CORRECTIONS}

          See [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md) for the full conventions guide."
          fi
```

- [ ] **Step 2: Create lint-pr.yml**

```yaml
name: Lint Pull Request

on:
  pull_request:
    types: [opened, edited]

permissions:
  pull-requests: write

jobs:
  lint-pr:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Get PR content
        id: pr
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh pr view ${{ github.event.pull_request.number }} \
            --json title,body,labels \
            --jq '.' > /tmp/pr.json

      - name: Lint and fix PR
        env:
          CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
        run: |
          PR_CONTENT=$(cat /tmp/pr.json)
          CONVENTIONS=$(cat CONTRIBUTING.md)

          RESULT=$(claude -p "You are a dev conventions linter. You MUST output valid JSON only, no other text.

          Given the following conventions:
          ${CONVENTIONS}

          And the following pull request content:
          ${PR_CONTENT}

          Check if the PR complies with the conventions (title format, required sections: Summary, Related Issues, Changes, Test Plan).
          If non-compliant, output corrected JSON: {\"compliant\": false, \"title\": \"corrected title\", \"body\": \"corrected body\", \"corrections\": [\"list of corrections made\"]}
          If compliant, output: {\"compliant\": true}")

          echo "${RESULT}" > /tmp/result.json

      - name: Apply corrections
        if: success()
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          COMPLIANT=$(jq -r '.compliant' /tmp/result.json)

          if [ "$COMPLIANT" = "false" ]; then
            TITLE=$(jq -r '.title' /tmp/result.json)
            BODY=$(jq -r '.body' /tmp/result.json)
            CORRECTIONS=$(jq -r '.corrections | join("\n- ")' /tmp/result.json)

            gh pr edit ${{ github.event.pull_request.number }} \
              --title "${TITLE}" \
              --body "${BODY}"

            gh pr comment ${{ github.event.pull_request.number }} \
              --body "**Auto-formatted by conventions linter:**

          - ${CORRECTIONS}

          See [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md) for the full conventions guide."
          fi
```

- [ ] **Step 3: Create lint-commits.yml**

```yaml
name: Lint Commits

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  lint-commits:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Validate commit messages
        run: |
          PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'
          ERRORS=""

          while IFS= read -r msg; do
            if ! echo "$msg" | grep -qE "$PATTERN"; then
              ERRORS="${ERRORS}\n  - ${msg}"
            fi
          done < <(git log origin/${{ github.base_ref }}..HEAD --pretty=format:"%s")

          if [ -n "$ERRORS" ]; then
            echo "::error::The following commit messages do not follow Conventional Commits format:${ERRORS}"
            echo ""
            echo "Expected format: <type>(<scope>): <description>"
            echo "Allowed types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
            echo "Max subject length: 72 characters"
            exit 1
          fi

          echo "All commit messages are compliant."
```

- [ ] **Step 4: Verify all workflow files exist**

Run: `ls -la .claude/skills/dev-conventions/templates/github/lint-*.yml`
Expected: 3 files listed (lint-issue.yml, lint-pr.yml, lint-commits.yml).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/dev-conventions/templates/github/lint-*.yml
git commit -m "feat(dev-conventions): add GitHub Actions lint workflows"
```

---

### Task 5: Create GitLab Issue Templates

**Files:**
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-bug.md`
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-feature.md`
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-task.md`
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-enhancement.md`
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-question.md`
- Create: `.claude/skills/dev-conventions/templates/gitlab/issue-documentation.md`

- [ ] **Step 1: Create issue-bug.md**

```markdown
<!-- Title format: [Bug] Brief description -->

## Description

<!-- A clear and concise description of the bug -->

## Steps to Reproduce

1. 
2. 
3. 

## Expected Behavior

<!-- What you expected to happen -->

## Actual Behavior

<!-- What actually happened -->

## Environment

- OS: 
- Browser: 
- Runtime: 

## Additional Context

<!-- Any other context, screenshots, or logs -->

/label ~bug
```

- [ ] **Step 2: Create issue-feature.md**

```markdown
<!-- Title format: [Feature] Brief description -->

## Description

<!-- A clear and concise description of the feature -->

## Motivation

<!-- Why is this feature needed? What problem does it solve? -->

## Acceptance Criteria

- [ ] 
- [ ] 

## Additional Context

<!-- Any other context, mockups, or references -->

/label ~feature
```

- [ ] **Step 3: Create issue-task.md**

```markdown
<!-- Title format: [Task] Brief description -->

## Description

<!-- A clear description of the task -->

## Acceptance Criteria

- [ ] 
- [ ] 

## Additional Context

<!-- Any other context or references -->

/label ~task
```

- [ ] **Step 4: Create issue-enhancement.md**

```markdown
<!-- Title format: [Enhancement] Brief description -->

## Description

<!-- A clear description of the enhancement -->

## Current Behavior

<!-- How does the current functionality work? -->

## Proposed Improvement

<!-- What should be improved and how? -->

## Additional Context

<!-- Any other context or references -->

/label ~enhancement
```

- [ ] **Step 5: Create issue-question.md**

```markdown
<!-- Title format: [Question] Brief description -->

## Description

<!-- What is your question? -->

## Context

<!-- What have you tried or looked at so far? -->

## Additional Context

<!-- Any other relevant information -->

/label ~question
```

- [ ] **Step 6: Create issue-documentation.md**

```markdown
<!-- Title format: [Documentation] Brief description -->

## Description

<!-- What documentation needs to be added or changed? -->

## Affected Sections

<!-- Which parts of the documentation are affected? -->

## Additional Context

<!-- Any other context or references -->

/label ~documentation
```

- [ ] **Step 7: Verify all GitLab issue template files exist**

Run: `ls -la .claude/skills/dev-conventions/templates/gitlab/issue-*.md`
Expected: 6 files listed.

- [ ] **Step 8: Commit**

```bash
git add .claude/skills/dev-conventions/templates/gitlab/
git commit -m "feat(dev-conventions): add GitLab issue templates"
```

---

### Task 6: Create GitLab MR Template

**Files:**
- Create: `.claude/skills/dev-conventions/templates/gitlab/merge-request.md`

- [ ] **Step 1: Create merge-request.md**

```markdown
<!-- Title format: [Type] Brief description -->
<!-- Type: Feature, Fix, Refactor, Docs, Test, Chore -->

## Summary

<!-- Brief description of the changes -->

## Related Issues

<!-- Link to related issues: Closes #123, Refs #456 -->

## Changes

<!-- List the changes made -->

- 

## Test Plan

<!-- How were the changes tested? -->

- 

## Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] Tests have been added/updated
- [ ] Documentation has been updated (if applicable)
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/dev-conventions/templates/gitlab/merge-request.md
git commit -m "feat(dev-conventions): add GitLab MR template"
```

---

### Task 7: Create GitLab CI Lint Pipeline

**Files:**
- Create: `.claude/skills/dev-conventions/templates/gitlab/lint-conventions.yml`

- [ ] **Step 1: Create lint-conventions.yml**

```yaml
stages:
  - lint

lint-issue:
  stage: lint
  image: node:22
  rules:
    - if: $CI_PIPELINE_SOURCE == "trigger" && $LINT_TARGET == "issue"
  before_script:
    - npm install -g @anthropic-ai/claude-code
    - apt-get update && apt-get install -y glab
  script:
    - |
      ISSUE_CONTENT=$(glab issue view "$ISSUE_IID" --output json)
      CONVENTIONS=$(cat CONTRIBUTING.md)

      RESULT=$(claude -p "You are a dev conventions linter. You MUST output valid JSON only, no other text.

      Given the following conventions:
      ${CONVENTIONS}

      And the following issue content:
      ${ISSUE_CONTENT}

      Check if the issue complies with the conventions (title format, required fields).
      If non-compliant, output corrected JSON: {\"compliant\": false, \"title\": \"corrected title\", \"body\": \"corrected body\", \"labels\": [\"label\"], \"corrections\": [\"list of corrections made\"]}
      If compliant, output: {\"compliant\": true}")

      echo "${RESULT}" > /tmp/result.json
      COMPLIANT=$(jq -r '.compliant' /tmp/result.json)

      if [ "$COMPLIANT" = "false" ]; then
        TITLE=$(jq -r '.title' /tmp/result.json)
        BODY=$(jq -r '.body' /tmp/result.json)
        CORRECTIONS=$(jq -r '.corrections | join("\n- ")' /tmp/result.json)

        glab issue update "$ISSUE_IID" --title "${TITLE}" --description "${BODY}"
        glab issue note "$ISSUE_IID" --message "**Auto-formatted by conventions linter:**

      - ${CORRECTIONS}

      See CONTRIBUTING.md for the full conventions guide."
      fi

lint-mr:
  stage: lint
  image: node:22
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  before_script:
    - npm install -g @anthropic-ai/claude-code
    - apt-get update && apt-get install -y glab
  script:
    - |
      MR_CONTENT=$(glab mr view "$CI_MERGE_REQUEST_IID" --output json)
      CONVENTIONS=$(cat CONTRIBUTING.md)

      RESULT=$(claude -p "You are a dev conventions linter. You MUST output valid JSON only, no other text.

      Given the following conventions:
      ${CONVENTIONS}

      And the following merge request content:
      ${MR_CONTENT}

      Check if the MR complies with the conventions (title format, required sections: Summary, Related Issues, Changes, Test Plan).
      If non-compliant, output corrected JSON: {\"compliant\": false, \"title\": \"corrected title\", \"body\": \"corrected body\", \"corrections\": [\"list of corrections made\"]}
      If compliant, output: {\"compliant\": true}")

      echo "${RESULT}" > /tmp/result.json
      COMPLIANT=$(jq -r '.compliant' /tmp/result.json)

      if [ "$COMPLIANT" = "false" ]; then
        TITLE=$(jq -r '.title' /tmp/result.json)
        BODY=$(jq -r '.body' /tmp/result.json)
        CORRECTIONS=$(jq -r '.corrections | join("\n- ")' /tmp/result.json)

        glab mr update "$CI_MERGE_REQUEST_IID" --title "${TITLE}" --description "${BODY}"
        glab mr note "$CI_MERGE_REQUEST_IID" --message "**Auto-formatted by conventions linter:**

      - ${CORRECTIONS}

      See CONTRIBUTING.md for the full conventions guide."
      fi

lint-commits:
  stage: lint
  image: alpine:latest
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  script:
    - |
      PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'
      ERRORS=""

      while IFS= read -r msg; do
        if ! echo "$msg" | grep -qE "$PATTERN"; then
          ERRORS="${ERRORS}\n  - ${msg}"
        fi
      done < <(git log "origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}..HEAD" --pretty=format:"%s")

      if [ -n "$ERRORS" ]; then
        echo "ERROR: The following commit messages do not follow Conventional Commits format:${ERRORS}"
        echo ""
        echo "Expected format: <type>(<scope>): <description>"
        echo "Allowed types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
        echo "Max subject length: 72 characters"
        exit 1
      fi

      echo "All commit messages are compliant."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/dev-conventions/templates/gitlab/lint-conventions.yml
git commit -m "feat(dev-conventions): add GitLab CI lint pipeline"
```

---

### Task 8: Create Git Hook Files

**Files:**
- Create: `.claude/skills/dev-conventions/hooks/commit-msg.sh`
- Create: `.claude/skills/dev-conventions/hooks/husky-setup.md`
- Create: `.claude/skills/dev-conventions/hooks/pre-commit-setup.md`

- [ ] **Step 1: Create commit-msg.sh**

```bash
#!/bin/sh
commit_msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'

if ! echo "$commit_msg" | grep -qE "$pattern"; then
  echo ""
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo ""
  echo "  Expected: <type>(<scope>): <description>"
  echo "  Types:    feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
  echo "  Max length: 72 characters (subject line)"
  echo ""
  echo "  Your message: $commit_msg"
  echo ""
  echo "  Examples:"
  echo "    feat(auth): add OAuth2 login"
  echo "    fix: resolve null pointer in user service"
  echo "    docs(readme): update installation instructions"
  echo ""
  exit 1
fi
```

- [ ] **Step 2: Create husky-setup.md**

This prompt instructs the skill on how to set up Husky in the target project.

```markdown
# Husky Setup Instructions

## Steps

1. Check if `husky` is listed in `devDependencies` of `package.json`. If not:
   - Run: `npm install --save-dev husky`

2. Check if `.husky/` directory exists. If not:
   - Run: `npx husky init`

3. Write the commit-msg hook to `.husky/commit-msg`:
   - Copy the contents of `hooks/commit-msg.sh` to `.husky/commit-msg`
   - Ensure the file is executable: `chmod +x .husky/commit-msg`

## Verification

Run: `echo "bad message" | npx husky .husky/commit-msg /dev/stdin`
Expected: ERROR message about Conventional Commits format.

Run: `echo "feat: test message" | npx husky .husky/commit-msg /dev/stdin`
Expected: No error, exit code 0.
```

- [ ] **Step 3: Create pre-commit-setup.md**

This prompt instructs the skill on how to set up pre-commit in the target project.

```markdown
# pre-commit Setup Instructions

## Steps

1. Check if `pre-commit` is available. If not, inform the user:
   - Python: `pip install pre-commit`
   - Homebrew: `brew install pre-commit`

2. Check if `.pre-commit-config.yaml` exists in the target project root.
   - If it exists, append the conventional-pre-commit hook to the existing `repos` list
   - If it does not exist, create `.pre-commit-config.yaml` with the following content:

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

3. Run: `pre-commit install --hook-type commit-msg`

## Verification

Run: `git commit --allow-empty -m "bad message"`
Expected: Commit rejected with conventional-pre-commit error.

Run: `git commit --allow-empty -m "feat: test message"`
Expected: Commit succeeds.
```

- [ ] **Step 4: Verify all hook files exist**

Run: `ls -la .claude/skills/dev-conventions/hooks/`
Expected: 3 files listed (commit-msg.sh, husky-setup.md, pre-commit-setup.md).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/dev-conventions/hooks/
git commit -m "feat(dev-conventions): add git hook scripts and setup guides"
```

---

### Task 9: Create CONTRIBUTING.md Template

**Files:**
- Create: `.claude/skills/dev-conventions/contributing-template.md`

- [ ] **Step 1: Create contributing-template.md**

This is the template the skill uses to generate `CONTRIBUTING.md` in the target project. The skill fills in the `{HOOK_SETUP}` placeholder based on the detected toolchain.

```markdown
# Contributing Guide

Thank you for contributing! This document describes the conventions and automated checks used in this project.

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/) v1.0.0.

### Format

\`\`\`
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
\`\`\`

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

\`\`\`
feat(auth): add OAuth2 login flow
fix: resolve null pointer in user service
docs(readme): update installation instructions
refactor(api): extract validation middleware
test(auth): add integration tests for login
chore: update dependencies
revert: revert "feat(auth): add OAuth2 login flow"

feat(api)!: change response format for /users endpoint

BREAKING CHANGE: The /users endpoint now returns a paginated response.
\`\`\`

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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/dev-conventions/contributing-template.md
git commit -m "feat(dev-conventions): add CONTRIBUTING.md template"
```

---

### Task 10: Create SKILL.md Entry Point

**Files:**
- Create: `.claude/skills/dev-conventions/SKILL.md`

- [ ] **Step 1: Create SKILL.md**

```markdown
---
name: dev-conventions
description: "Generate development convention files for GitHub or GitLab projects: Issue/PR/MR templates, CI/CD lint workflows, git hooks, and CONTRIBUTING.md. Triggers: /dev-conventions, 'setup conventions', 'add issue templates', 'add PR templates'."
---

# Dev Conventions — Project Convention Generator

Generate platform-native development convention files for a target project. Produces Issue/PR/MR templates, CI/CD workflows for AI-powered lint and auto-correction, local git hooks for Conventional Commits, and a CONTRIBUTING.md.

## Input

\`\`\`
/dev-conventions
\`\`\`

## Convention Reference

Read `conventions-core.md` in this skill directory for the canonical rules (commit format, issue types, PR/MR types, required fields). All generated files MUST be consistent with this definition.

## Process

### Step 1: Platform Detection

Detect the target platform from the git remote URL:

1. Run `git remote -v` and inspect the output
2. If the URL contains `github.com` → **GitHub**
3. If the URL contains `gitlab.com` or a known self-hosted GitLab domain → **GitLab**
4. If neither can be determined → Ask the user: "Is this a GitHub or GitLab project?"
5. If not in a git repository → Report error and stop

### Step 2: Tech Stack Detection

Scan the project root to determine the tech stack:

1. If `package.json` exists → **Node.js**
2. Else if `pyproject.toml`, `requirements.txt`, or `setup.py` exists → **Python**
3. Else if `go.mod` exists → **Go**
4. Else → **other**

### Step 3: Hook Tool Confirmation

Based on the detected tech stack, confirm the git hook tool:

- **Node.js** → Inform the user: "Will use Husky for git hooks. OK?" If declined, offer alternatives.
- **Python or Go** → Inform the user: "Will use pre-commit for git hooks. OK?" If declined, offer alternatives.
- **Other** → Ask: "Which git hook tool would you like? (A) Husky (B) pre-commit (C) Native shell script"

### Step 4: Conflict Detection

Check for existing files that would be overwritten:

**GitHub:**
- `.github/ISSUE_TEMPLATE/` directory
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/lint-issue.yml`, `.github/workflows/lint-pr.yml`, `.github/workflows/lint-commits.yml`

**GitLab:**
- `.gitlab/issue_templates/` directory
- `.gitlab/merge_request_templates/` directory
- `.gitlab-ci.yml` or `.gitlab/ci/lint-conventions.yml`

**Both:**
- `.husky/commit-msg` (if Husky selected)
- `.pre-commit-config.yaml` (if pre-commit selected)
- `CONTRIBUTING.md`

For each conflict found, ask the user: "File `{path}` already exists. (A) Overwrite (B) Skip"

### Step 5: Generate Files

Based on the detected platform, generate files by reading templates from this skill directory and writing them to the target project.

#### GitHub

1. Read each template from `templates/github/issue-*.yml` and `templates/github/config.yml`
   - Write to `.github/ISSUE_TEMPLATE/{name}.yml` (rename: `issue-bug.yml` → `bug.yml`, etc.)
2. Read `templates/github/pull-request.md`
   - Write to `.github/PULL_REQUEST_TEMPLATE.md`
3. Read each template from `templates/github/lint-*.yml`
   - Write to `.github/workflows/{name}.yml`

#### GitLab

1. Read each template from `templates/gitlab/issue-*.md`
   - Write to `.gitlab/issue_templates/{Name}.md` (rename: `issue-bug.md` → `Bug.md`, etc.)
2. Read `templates/gitlab/merge-request.md`
   - Write to `.gitlab/merge_request_templates/Default.md`
3. Read `templates/gitlab/lint-conventions.yml`
   - If `.gitlab-ci.yml` does NOT exist: write as `.gitlab-ci.yml`
   - If `.gitlab-ci.yml` EXISTS: write to `.gitlab/ci/lint-conventions.yml` and inform the user to add `include: - local: '.gitlab/ci/lint-conventions.yml'` to their `.gitlab-ci.yml`

#### Git Hooks

Based on the selected hook tool:

**Husky:** Follow the instructions in `hooks/husky-setup.md`
**pre-commit:** Follow the instructions in `hooks/pre-commit-setup.md`
**Native script:** 
  - Write `hooks/commit-msg.sh` to `scripts/install-hooks.sh` (wrapped in an installer that copies to `.git/hooks/commit-msg`)
  - Inform the user to run `bash scripts/install-hooks.sh`

#### CONTRIBUTING.md

1. Read `contributing-template.md`
2. Replace `{HOOK_SETUP}` based on the selected hook tool:
   - **Husky:** "### Setup\n\nHooks are managed by [Husky](https://typicode.github.io/husky/). They are installed automatically when you run `npm install`. If hooks are not active, run:\n\n```bash\nnpx husky init\n```"
   - **pre-commit:** "### Setup\n\nHooks are managed by [pre-commit](https://pre-commit.com/). Install them with:\n\n```bash\npip install pre-commit\npre-commit install --hook-type commit-msg\n```"
   - **Native:** "### Setup\n\nRun the hook installer script:\n\n```bash\nbash scripts/install-hooks.sh\n```"
3. Write to `CONTRIBUTING.md` in the project root

### Step 6: Output Summary

Print a summary of all generated files:

\`\`\`
## Generated Files

- `.github/ISSUE_TEMPLATE/bug.yml` (or GitLab equivalent)
- `.github/ISSUE_TEMPLATE/feature.yml`
- ... (list all files)
- `.github/workflows/lint-issue.yml`
- `.github/workflows/lint-pr.yml`
- `.github/workflows/lint-commits.yml`
- `.husky/commit-msg` (or pre-commit equivalent)
- `CONTRIBUTING.md`

## Next Steps

1. Configure the `CLAUDE_CODE_OAUTH_TOKEN` secret in your repository settings
   - GitHub: Settings → Secrets and variables → Actions → New repository secret
   - GitLab: Settings → CI/CD → Variables → Add variable
2. Review `CONTRIBUTING.md` and adjust if needed
3. Commit all generated files
\`\`\`
```

- [ ] **Step 2: Verify the SKILL.md is well-formed**

Run: `head -5 .claude/skills/dev-conventions/SKILL.md`
Expected: The YAML frontmatter begins with `---`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/dev-conventions/SKILL.md
git commit -m "feat(dev-conventions): add SKILL.md entry point"
```

---

### Task 11: Verify Complete Skill Structure

**Files:**
- None (verification only)

- [ ] **Step 1: Verify the full directory structure**

Run: `find .claude/skills/dev-conventions -type f | sort`

Expected output:
```
.claude/skills/dev-conventions/SKILL.md
.claude/skills/dev-conventions/contributing-template.md
.claude/skills/dev-conventions/conventions-core.md
.claude/skills/dev-conventions/hooks/commit-msg.sh
.claude/skills/dev-conventions/hooks/husky-setup.md
.claude/skills/dev-conventions/hooks/pre-commit-setup.md
.claude/skills/dev-conventions/templates/github/config.yml
.claude/skills/dev-conventions/templates/github/issue-bug.yml
.claude/skills/dev-conventions/templates/github/issue-documentation.yml
.claude/skills/dev-conventions/templates/github/issue-enhancement.yml
.claude/skills/dev-conventions/templates/github/issue-feature.yml
.claude/skills/dev-conventions/templates/github/issue-question.yml
.claude/skills/dev-conventions/templates/github/issue-task.yml
.claude/skills/dev-conventions/templates/github/lint-commits.yml
.claude/skills/dev-conventions/templates/github/lint-issue.yml
.claude/skills/dev-conventions/templates/github/lint-pr.yml
.claude/skills/dev-conventions/templates/github/pull-request.md
.claude/skills/dev-conventions/templates/gitlab/issue-bug.md
.claude/skills/dev-conventions/templates/gitlab/issue-documentation.md
.claude/skills/dev-conventions/templates/gitlab/issue-enhancement.md
.claude/skills/dev-conventions/templates/gitlab/issue-feature.md
.claude/skills/dev-conventions/templates/gitlab/issue-question.md
.claude/skills/dev-conventions/templates/gitlab/issue-task.md
.claude/skills/dev-conventions/templates/gitlab/lint-conventions.yml
.claude/skills/dev-conventions/templates/gitlab/merge-request.md
```

- [ ] **Step 2: Verify cross-references**

Check that SKILL.md references all template files that exist:

- `conventions-core.md` — referenced in Step 5 preamble ✓
- `templates/github/issue-*.yml` — referenced in Step 5 GitHub section ✓
- `templates/github/config.yml` — referenced in Step 5 GitHub section ✓
- `templates/github/pull-request.md` — referenced in Step 5 GitHub section ✓
- `templates/github/lint-*.yml` — referenced in Step 5 GitHub section ✓
- `templates/gitlab/issue-*.md` — referenced in Step 5 GitLab section ✓
- `templates/gitlab/merge-request.md` — referenced in Step 5 GitLab section ✓
- `templates/gitlab/lint-conventions.yml` — referenced in Step 5 GitLab section ✓
- `hooks/husky-setup.md` — referenced in Step 5 Git Hooks section ✓
- `hooks/pre-commit-setup.md` — referenced in Step 5 Git Hooks section ✓
- `hooks/commit-msg.sh` — referenced in Step 5 Git Hooks section ✓
- `contributing-template.md` — referenced in Step 5 CONTRIBUTING.md section ✓

- [ ] **Step 3: Final commit with all files**

If any files were missed in prior commits:

```bash
git add .claude/skills/dev-conventions/
git status
```

If there are uncommitted files:

```bash
git commit -m "feat(dev-conventions): complete skill file structure"
```
