#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-}"
if [ -z "$REPO_URL" ]; then
  echo "Usage: REPO_URL=<git-url> $0 [script-or-command...]"
  echo ""
  echo "Mount a config directory at /opencode-config to bootstrap"
  echo "opencode global config at /root/.config/opencode."
  echo ""
  echo "Examples:"
  echo "  Mount a script and execute it in the cloned repo:"
  echo "    docker compose run --rm opencode-generic-worker \\"
  echo "      -e REPO_URL=https://github.com/user/repo.git \\"
  echo "      -e ISSUE=42 \\"
  echo "      -v ./my-script.sh:/script.sh:ro \\"
  echo "      /script.sh"
  echo ""
  echo "  Pass an inline command:"
  echo "    docker compose run --rm opencode-generic-worker \\"
  echo "      -e REPO_URL=https://github.com/user/repo.git \\"
  echo "      -e ISSUE=42 \\"
  echo "      sh -c 'echo \$ISSUE && cat README.md'"
  exit 1
fi

ISSUE="${ISSUE:-}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-/opencode-config}"
WORK_DIR="${WORK_DIR:-/repo}"

echo "=== Cloning $REPO_URL ==="
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

OPENCODE_GLOBAL_DIR="${OPENCODE_GLOBAL_DIR:-/root/.config/opencode}"
if [ -d "$OPENCODE_CONFIG_DIR" ]; then
  echo "=== Bootstrapping opencode config to $OPENCODE_GLOBAL_DIR ==="
  mkdir -p "$OPENCODE_GLOBAL_DIR"
  cp -r "$OPENCODE_CONFIG_DIR/." "$OPENCODE_GLOBAL_DIR/"
fi

export ISSUE

if [ $# -eq 0 ]; then
  echo "No command provided. Container ready at $WORK_DIR"
  echo "ISSUE=$ISSUE"
  exit 0
fi

echo "=== Executing: $* ==="
exec "$@"
