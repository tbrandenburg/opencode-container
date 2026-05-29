#!/usr/bin/env bash
set -euo pipefail

ISSUE_URL="${ISSUE_URL:-}"
if [ -z "$ISSUE_URL" ]; then
  echo "Usage: ISSUE_URL=<url> $0"
  echo "Example: ISSUE_URL=https://github.com/tbrandenburg/pyrag/issues/30 $0"
  exit 1
fi

OWNER=$(echo "$ISSUE_URL" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)/issues/\([0-9]*\).*|\1|p')
REPO=$(echo "$ISSUE_URL" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)/issues/\([0-9]*\).*|\2|p')
ISSUE_NUM=$(echo "$ISSUE_URL" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)/issues/\([0-9]*\).*|\3|p')

echo "=== Cloning $OWNER/$REPO ==="
git clone "https://github.com/$OWNER/$REPO.git" /repo
cd /repo

echo "=== Processing issue #$ISSUE_NUM ==="
echo "Read issue #$ISSUE_NUM from $OWNER/$REPO, understand the codebase, propose detailed implementation steps in a comment on the issue using gh issue comment" | opencode run --format json 2>&1

echo "=== Done ==="
