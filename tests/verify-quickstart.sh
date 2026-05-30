#!/usr/bin/env bash
# Quickstart verification: make build && make serve && curl health check
set -euo pipefail

echo "=== Step 1: make build ==="
make build
echo "PASS: build completed"

echo ""
echo "=== Step 2: make serve ==="
make serve
echo "PASS: serve started"

echo ""
echo "=== Step 3: curl health check ==="
sleep 3
response=$(curl -u "opencode:changeme" -s http://localhost:4096/global/health 2>&1)
echo "$response"
echo "$response" | grep -q '"healthy":true'
echo "PASS: health check returned healthy response"

echo ""
echo "=== Step 4: Cleanup ==="
make stop
echo "PASS: cleanup completed"

echo ""
echo "=== QUICKSTART VERIFIED SUCCESSFULLY ==="