#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down opencode-web 2>/dev/null || true
}
trap cleanup EXIT

echo "=== opencode-web --help passthrough ==="
docker compose run --rm opencode-web --help 2>&1 | grep -qi "opencode web\|Usage:\|--help"
echo "PASS: --help returns opencode web help"

echo "=== opencode-web health check ==="
docker compose up -d opencode-web
sleep 3
response=$(curl -u "opencode:changeme" -s http://localhost:4098/global/health 2>&1)
echo "$response" | grep -q '"healthy":true'
echo "PASS: health check returned healthy response"