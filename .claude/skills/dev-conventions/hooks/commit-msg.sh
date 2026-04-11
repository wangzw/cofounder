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
