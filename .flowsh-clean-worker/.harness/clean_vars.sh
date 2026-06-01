#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_NAME='clean_vars.sh'
WORKFLOW_NAME="${SCRIPT_NAME%.sh}"
WORKFLOW_SLUG=$(printf '%s' "$WORKFLOW_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
LOG_TIMESTAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
LOG_BASENAME="flowsh-${WORKFLOW_SLUG}-${LOG_TIMESTAMP}-$$.log"

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
DRY_RUN=false
if [[ $# -eq 1 && "$1" == "--dry-run" ]]; then
  DRY_RUN=true
elif [[ $# -gt 0 ]]; then
  printf "Usage: %s [--dry-run]\n" "$0" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# refuse_symlink_path() - keep generated logs inside plain relative paths
# ---------------------------------------------------------------------------
refuse_symlink_path() {
  local target="$1"

  if [[ -z "$target" ]]; then
    printf "ERROR: Log directory must not be empty\n" >&2
    return 1
  fi
  if [[ "$target" == /* ]]; then
    printf "ERROR: Log directory must be relative: %s\n" "$target" >&2
    return 1
  fi

  local current=
  local part
  IFS=/ read -r -a path_parts <<< "$target"
  for part in "${path_parts[@]}"; do
    if [[ -z "$part" || "$part" == "." ]]; then
      continue
    fi
    if [[ "$part" == ".." ]]; then
      printf '%s: %s\n' "ERROR: Log directory must not contain .. path segments" "$target" >&2
      return 1
    fi
    current="${current:+${current}/}${part}"
    if [[ -L "$current" ]]; then
      printf "ERROR: Refusing to write logs through symlinked path: %s\n" "$current" >&2
      return 1
    fi
  done
}

# ---------------------------------------------------------------------------
# Log file setup - local by default, override with FLOWSH_LOG_DIR
# ---------------------------------------------------------------------------
LOG_DIR="${FLOWSH_LOG_DIR:-.flowsh/logs}"
LOG_FILE=
if [[ "$DRY_RUN" == false ]]; then
  refuse_symlink_path "$LOG_DIR" || exit 1
  if [[ -e "$LOG_DIR" && ! -d "$LOG_DIR" ]]; then
    printf "ERROR: Log path exists but is not a directory: %s\n" "$LOG_DIR" >&2
    exit 1
  fi
  if ! mkdir -p "$LOG_DIR"; then
    printf "ERROR: Cannot create log directory: %s\n" "$LOG_DIR" >&2
    exit 1
  fi
  refuse_symlink_path "$LOG_DIR" || exit 1
  if [[ ! -d "$LOG_DIR" ]]; then
    printf "ERROR: Log path exists but is not a directory: %s\n" "$LOG_DIR" >&2
    exit 1
  fi
  if ! chmod 700 "$LOG_DIR"; then
    printf "ERROR: Cannot set log directory permissions: %s\n" "$LOG_DIR" >&2
    exit 1
  fi
  LOG_FILE="${LOG_DIR}/${LOG_BASENAME}"
  if ! : > "$LOG_FILE"; then
    printf "ERROR: Cannot create log file: %s\n" "$LOG_FILE" >&2
    exit 1
  fi
  if ! chmod 600 "$LOG_FILE"; then
    printf "ERROR: Cannot set log file permissions: %s\n" "$LOG_FILE" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# log() - ISO-8601 UTC timestamps, INFO/ERROR, stderr + log file
# ---------------------------------------------------------------------------
log() {
  local level="$1"; shift
  local message
  message="$(date -u +'%Y-%m-%dT%H:%M:%SZ') [${level}] $*"
  printf '%s\n' "$message" >&2
  if [[ -n "$LOG_FILE" ]]; then
    if ! printf '%s\n' "$message" >> "$LOG_FILE"; then
      printf "ERROR: Cannot write log file: %s\n" "$LOG_FILE" >&2
      exit 1
    fi
  fi
}

# ---------------------------------------------------------------------------
# catch() - centralized step failure hook
# ---------------------------------------------------------------------------
catch() {
  local step_name="$1"
  local exit_code="$2"
  log ERROR "Step failed: ${step_name} (exit=${exit_code})"
}

# ---------------------------------------------------------------------------
# run_step() - dry-run and failure handling; streams output via tee
# ---------------------------------------------------------------------------
run_step() {
  local step_name="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "[DRY-RUN] would run: ${step_name}"
    return 0
  fi

  log INFO "Running step: ${step_name}"

  set +e
  if ( : >> "$LOG_FILE" ) 2>/dev/null; then
    "$step_name" > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
    local status=$?
  else
    "$step_name"
    local status=$?
  fi
  set -e

  if [[ $status -ne 0 ]]; then
    catch "$step_name" "$status"
  fi
  return "$status"
}

# ---------------------------------------------------------------------------
# run_stateful_step() - dry-run and failure handling without subshells
# ---------------------------------------------------------------------------
run_stateful_step() {
  local step_name="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "[DRY-RUN] would run: ${step_name}"
    return 0
  fi

  log INFO "Running step: ${step_name}"

  set +e
  "$step_name"
  local status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    catch "$step_name" "$status"
  fi
  return "$status"
}

# ---------------------------------------------------------------------------
# run_agent() - prompt handling and OpenCode CLI invocation
# ---------------------------------------------------------------------------
run_agent() {
  local prompt="$1"
  local agent="${2:-}"

  local cmd=(opencode run --format json)
  if [[ -n "$agent" ]]; then
    cmd+=(--agent "$agent")
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "[DRY-RUN] would run: $(printf '%q ' "${cmd[@]}") (with prompt)"
    return 0
  fi

  if ! command -v opencode >/dev/null 2>&1; then
    log ERROR "opencode CLI not found in PATH"
    return 127
  fi

  "${cmd[@]}" -- "$prompt"
}

# ---------------------------------------------------------------------------
# Starting workflow: Clean Vars
# ---------------------------------------------------------------------------
log INFO 'Starting workflow: Clean Vars'

# ---------------------------------------------------------------------------
# Step 1 (vars): Gather facts
# ---------------------------------------------------------------------------
step_gather_facts() {
  local status=0
  BRANCH_NAME=$(bash -euo pipefail <<'VARS_BRANCH_NAME_EOF'
git branch --show-current
VARS_BRANCH_NAME_EOF
  )
  status=$?
  if [[ $status -ne 0 ]]; then
    return "$status"
  fi
  export BRANCH_NAME
  README_HEADING=$(bash -euo pipefail <<'VARS_README_HEADING_EOF'
sed -n '1p' README.md
VARS_README_HEADING_EOF
  )
  status=$?
  if [[ $status -ne 0 ]]; then
    return "$status"
  fi
  export README_HEADING
}
run_stateful_step step_gather_facts

# ---------------------------------------------------------------------------
# Step 2 (bash): Print facts
# ---------------------------------------------------------------------------
step_print_facts() {
  bash -euo pipefail <<'BASH_EOF'
printf 'branch=%s\n' "$BRANCH_NAME"
printf 'heading=%s\n' "$README_HEADING"
BASH_EOF
}
run_step step_print_facts

# ---------------------------------------------------------------------------
# Workflow finished: Clean Vars
# ---------------------------------------------------------------------------
log INFO 'Workflow finished: Clean Vars'

