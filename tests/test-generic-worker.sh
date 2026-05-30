#!/usr/bin/env bash
set -euo pipefail

echo "=== opencode-generic-worker validates REPO_URL ==="
output=$(docker compose run --rm opencode-generic-worker 2>&1 || true)
echo "$output" | grep -q "REPO_URL"
echo "PASS: missing REPO_URL triggers error"

echo "=== opencode-generic-worker clones and inspects ==="
GH_TOKEN=${GH_TOKEN:-dummy} \
docker compose run --rm \
  -e REPO_URL=https://github.com/tbrandenburg/pyrag.git \
  -e ISSUE=99 \
  opencode-generic-worker \
  sh -c 'git log --oneline -1 && head -3 README.md' 2>&1 | grep -q "PyRAG"
echo "PASS: clone and inspect produces expected output"