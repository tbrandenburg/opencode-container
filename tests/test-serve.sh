#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down opencode-serve 2>/dev/null || true
}
trap cleanup EXIT

echo "=== opencode-serve --help passthrough ==="
docker compose run --rm opencode-serve --help 2>&1 | grep -qi "opencode serve\|Usage:\|--help"
echo "PASS: --help returns opencode serve help"

echo "=== opencode-serve health check ==="
docker compose up -d opencode-serve
sleep 3
response=$(curl -u "opencode:changeme" -s http://localhost:4096/global/health 2>&1)
echo "$response" | grep -q '"healthy":true'
echo "PASS: health check returned healthy response"