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
