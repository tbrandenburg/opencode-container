#!/usr/bin/env bash
set -euo pipefail

echo "=== opencode-issue-processor validates GH_TOKEN ==="
output=$(docker compose run --rm opencode-issue-processor 2>&1 || true)
echo "$output" | grep -qi "GH_TOKEN"
echo "PASS: missing GH_TOKEN triggers error"