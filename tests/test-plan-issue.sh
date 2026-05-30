#!/usr/bin/env bash
set -euo pipefail

echo "=== opencode-plan-issue validates ISSUE_URL ==="
output=$(docker compose run --rm opencode-plan-issue 2>&1 || true)
echo "$output" | grep -qi "ISSUE_URL"
echo "PASS: missing ISSUE_URL triggers error"