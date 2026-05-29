#!/usr/bin/env bash
set -euo pipefail

REPOS=(
  "tbrandenburg/made"
  "tbrandenburg/pyrag"
)

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
