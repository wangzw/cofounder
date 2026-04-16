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

Run: `git commit --allow-empty -m "bad message"`
Expected: Commit rejected with ERROR message about Conventional Commits format.

Run: `git commit --allow-empty -m "feat: test message"`
Expected: Commit succeeds with exit code 0.
