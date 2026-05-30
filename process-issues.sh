#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GH_TOKEN:-}" ]; then
  echo "FATAL: GH_TOKEN is required. Run with: GH_TOKEN=\$(gh auth token) $0"
  exit 1
fi

REPOS_ENV="${REPOS:-}"
if [ -n "$REPOS_ENV" ]; then
  IFS=',' read -r -a REPOS <<< "$REPOS_ENV"
else
  REPOS=(
    "tbrandenburg/made"
    "tbrandenburg/pyrag"
  )
fi

for REPO in "${REPOS[@]}"; do
  gh issue list \
    --repo "$REPO" \
    --state open \
    --limit 1000 \
    --json number \
    --jq '.[].number' |
  while read -r ISSUE_ID; do
    echo "[$REPO] issue #$ISSUE_ID"

    echo "Say issue #$ISSUE_ID from $REPO" | opencode run
  done
done
