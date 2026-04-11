---
name: dev-conventions
description: "Generate development convention files for GitHub or GitLab projects: Issue/PR/MR templates, CI/CD lint workflows, git hooks, and CONTRIBUTING.md. Triggers: /dev-conventions, 'setup conventions', 'add issue templates', 'add PR templates'."
---

# Dev Conventions — Project Convention Generator

Generate platform-native development convention files for a target project. Produces Issue/PR/MR templates, CI/CD workflows for AI-powered lint and auto-correction, local git hooks for Conventional Commits, and a CONTRIBUTING.md.

## Input

```
/dev-conventions
```

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

```
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
```
