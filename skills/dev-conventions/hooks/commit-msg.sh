#!/bin/sh
commit_msg=$(cat "$1")
pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'

# Skip validation for merge commits (e.g. "Merge branch 'foo' into main")
# and `git revert`-generated messages (e.g. 'Revert "feat: ..."').
first_line=$(echo "$commit_msg" | head -n 1)
case "$first_line" in
  "Merge "*|"Revert \""*) exit 0 ;;
esac

if ! echo "$first_line" | grep -qE "$pattern"; then
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
