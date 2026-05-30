#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
echo "=== Test Suite: opencode-generic-worker ==="

# ---------------------------------------------------------------------------
# Test 1: Agent invocation via generated flowsh harness
#
# Bootstraps a custom agent definition and runs a flowsh-generated harness
# that invokes: opencode run --agent test 'What is your name?'
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 1: Agent invocation via flowsh harness ---"

REPO_URL=https://github.com/tbrandenburg/pyrag.git \
  ISSUE=42 \
  GH_TOKEN=$(gh auth token 2>/dev/null || echo "") \
  docker compose run --rm \
  -v "$(pwd)/tests/generic-worker/agent:/opencode-config/agent:ro" \
  -v "$(pwd)/tests/generic-worker/.harness/agent_test.sh:/workflow.sh:ro" \
  opencode-generic-worker \
  /workflow.sh 2>&1 && echo "PASS: Test 1 (agent harness) exited 0" || echo "FAIL: Test 1 exited $?"

# ---------------------------------------------------------------------------
# Test 2: Non-destructive repo inspection via generated flowsh harness
#
# Runs read-only bash steps (git log, file count, README check)
# on the cloned repository.
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 2: Repo inspection via flowsh harness ---"

REPO_URL=https://github.com/tbrandenburg/pyrag.git \
  ISSUE=99 \
  GH_TOKEN=$(gh auth token 2>/dev/null || echo "") \
  docker compose run --rm \
  -v "$(pwd)/tests/generic-worker/.harness/repo_inspect.sh:/workflow.sh:ro" \
  opencode-generic-worker \
  /workflow.sh 2>&1 && echo "PASS: Test 2 (repo inspect) exited 0" || echo "FAIL: Test 2 exited $?"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "=== Test Suite Complete ==="
