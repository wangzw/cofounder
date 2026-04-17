# Native Script Setup Instructions

Use when no project-wide hook framework (Husky, pre-commit) is appropriate. This installs the commit-msg hook directly into `.git/hooks/` via a one-line installer the user runs once after clone.

## Steps

1. Copy `hooks/commit-msg.sh` (from this skill directory) to `scripts/git-hooks/commit-msg.sh` in the target project.
   - Ensure executable: `chmod +x scripts/git-hooks/commit-msg.sh`
2. Copy `hooks/install-hooks.sh.tpl` (from this skill directory) to `scripts/install-hooks.sh` in the target project.
   - Strip the `.tpl` extension.
   - Ensure executable: `chmod +x scripts/install-hooks.sh`
3. Inform the user to run the installer once: `bash scripts/install-hooks.sh`
4. (Optional) Add an entry in the project README under "Setup" pointing to the installer.

## Why two files

- `commit-msg.sh` is the hook itself — checked into the repo so all contributors share the same validation logic.
- `install-hooks.sh` is the installer — bridges the checked-in source to `.git/hooks/`, which is per-clone and not in version control.

## Verification

After the user runs the installer:

```bash
echo "bad message" | .git/hooks/commit-msg /dev/stdin
# Expected: ERROR about Conventional Commits format

echo "feat: test message" | .git/hooks/commit-msg /dev/stdin
# Expected: no error, exit code 0
```
