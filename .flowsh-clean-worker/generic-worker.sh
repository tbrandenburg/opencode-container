#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-}"
if [[ -z "$REPO_URL" ]]; then
  printf 'ERROR: REPO_URL is required\n' >&2
  exit 1
fi

WORK_DIR="${WORK_DIR:-/repo}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-/opencode-config}"
OPENCODE_GLOBAL_DIR="${OPENCODE_GLOBAL_DIR:-/root/.config/opencode}"

printf '=== Cloning %s ===\n' "$REPO_URL"
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

if [[ -d "$OPENCODE_CONFIG_DIR" ]]; then
  printf '=== Bootstrapping opencode config to %s ===\n' "$OPENCODE_GLOBAL_DIR"
  mkdir -p "$OPENCODE_GLOBAL_DIR"
  cp -r "$OPENCODE_CONFIG_DIR/." "$OPENCODE_GLOBAL_DIR/"
fi

if [[ $# -eq 0 ]]; then
  printf 'No command provided. Repo cloned at %s\n' "$WORK_DIR"
  exit 0
fi

printf '=== Executing:'
printf ' %q' "$@"
printf ' ===\n'
exec "$@"
