#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down opencode-acp 2>/dev/null || true
}
trap cleanup EXIT

echo "=== opencode-acp socat binary present ==="
docker compose run --rm opencode-acp sh -c 'which socat && socat -V'
echo "PASS: socat is installed in acp container"

echo "=== opencode-acp opencode binary present ==="
docker compose run --rm opencode-acp sh -c 'which opencode && opencode --version'
echo "PASS: opencode is installed in acp container"

echo "=== opencode-acp TCP listener on port 4097 ==="
docker compose up -d opencode-acp
sleep 2
echo "" | nc -w 3 localhost 4097 && echo "PASS: TCP port 4097 is reachable" || echo "FAIL: TCP port 4097 not reachable"