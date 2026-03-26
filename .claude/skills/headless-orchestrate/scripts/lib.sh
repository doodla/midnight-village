#!/usr/bin/env bash
# Shared utilities for headless orchestration scripts.
# Source this file: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# --- Configuration (env vars with defaults) ---
export REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
export FEATURE_SLUG="${FEATURE_SLUG:-}"
export IMPL_MODEL="${IMPL_MODEL:-sonnet}"
export REVIEW_MODEL="${REVIEW_MODEL:-sonnet}"
export ANALYZE_MODEL="${ANALYZE_MODEL:-opus}"
export IMPL_BUDGET="${IMPL_BUDGET:-10.00}"
export REVIEW_BUDGET="${REVIEW_BUDGET:-5.00}"
export MAX_RETRIES="${MAX_RETRIES:-2}"
export PARALLEL="${PARALLEL:-false}"
export PLANNING_MODEL="${PLANNING_MODEL:-opus}"
export PLANNING_BUDGET="${PLANNING_BUDGET:-5.00}"
export SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export LOG_DIR="${LOG_DIR:-$REPO_ROOT/.claude/skills/headless-orchestrate/logs}"
export LOCK_DIR="$REPO_ROOT/.claude/skills/headless-orchestrate/.state-lock.d"

# --- Logging ---
# Preserve LOG_FILE if already set by parent process (child scripts source this)
LOG_FILE="${LOG_FILE:-}"

init_log() {
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/orchestration-$(date +%Y%m%d-%H%M%S).log"
  export LOG_FILE
  log "ORCHESTRATE" "Log file: $LOG_FILE"
}

log() {
  local tag="$1"; shift
  local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$tag] $*"
  if [[ "${QUIET:-false}" != "true" ]]; then
    echo "$msg"
  fi
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

# Log to file only (never stdout). Use for routine progress lines.
logq() {
  local tag="$1"; shift
  local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$tag] $*"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

# --- File Locking (serializes spec-kitty state mutations) ---
# Uses mkdir for POSIX-portable atomic locking (works on macOS + Linux).
acquire_lock() {
  # Check for stale lock from a crashed process
  if [[ -d "$LOCK_DIR" && -f "$LOCK_DIR/pid" ]]; then
    local stale_pid
    stale_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
    if [[ -n "$stale_pid" ]] && ! kill -0 "$stale_pid" 2>/dev/null; then
      log "LOCK" "Removing stale lock from dead process $stale_pid"
      rm -rf "$LOCK_DIR" 2>/dev/null || true
    fi
  fi

  local deadline=$(($(date +%s) + 30))
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if (( $(date +%s) >= deadline )); then
      log "LOCK" "Failed to acquire lock after 30s"
      return 1
    fi
    sleep 0.5
  done
  echo $$ > "$LOCK_DIR/pid"
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# --- Safe state command (lock + retry on git conflict) ---
safe_state_cmd() {
  local max_attempts=3
  local exit_code=0
  for attempt in $(seq 1 "$max_attempts"); do
    acquire_lock
    exit_code=0
    "$@" 2>&1 || exit_code=$?
    release_lock
    if (( exit_code == 0 )); then
      return 0
    fi
    if (( attempt < max_attempts )); then
      log "STATE" "Command failed (exit=$exit_code, attempt $attempt/$max_attempts), pulling and retrying: $*"
      git -C "$REPO_ROOT" pull --rebase --quiet 2>/dev/null || true
      sleep 1
    fi
  done
  log "STATE" "Command failed after $max_attempts attempts: $*"
  return 1
}

# --- Feature detection ---
detect_feature() {
  if [[ -n "$FEATURE_SLUG" ]]; then
    echo "$FEATURE_SLUG"
    return 0
  fi
  local json
  json=$(spec-kitty agent tasks list-tasks --json 2>>"${LOG_FILE:-/dev/null}") || {
    # Write to stderr — this function is called in $() so stdout = return value
    echo "[DETECT] Failed to list tasks" >&2
    return 1
  }
  local path
  path=$(echo "$json" | jq -r '.tasks[0].path // empty')
  if [[ -z "$path" ]]; then
    echo "[DETECT] No tasks found" >&2
    return 1
  fi
  # Path: .../kitty-specs/SLUG/tasks/WP##-name.md -> extract SLUG
  FEATURE_SLUG=$(echo "$path" | sed 's|.*/kitty-specs/||;s|/tasks/.*||')
  export FEATURE_SLUG
  echo "$FEATURE_SLUG"
}

# --- State queries (via orchestrator-api) ---
get_feature_state_json() {
  spec-kitty orchestrator-api feature-state --feature "$FEATURE_SLUG" 2>>"${LOG_FILE:-/dev/null}"
}

get_wp_lane() {
  local wp_id="$1"
  get_feature_state_json \
    | jq -r --arg wp "$wp_id" '.data.work_packages[] | select(.wp_id == $wp) | .lane'
}

get_ready_wps() {
  local result
  result=$(spec-kitty orchestrator-api list-ready --feature "$FEATURE_SLUG" 2>>"$LOG_FILE") || {
    log "STATE" "list-ready failed: $result"
    return 1
  }
  echo "$result" | jq -r '.data.ready_work_packages[].wp_id'
}

# --- Run claude -p with stderr capture ---
# Usage: run_claude_session LABEL [claude -p args...]
# Returns: exit code. Sets CLAUDE_STDOUT to captured JSON output.
# Stderr is saved to $LOG_DIR/${LABEL}.stderr
run_claude_session() {
  local label="$1"; shift
  local stderr_file="$LOG_DIR/${label}.stderr"
  local exit_code=0

  CLAUDE_STDOUT=$(claude "$@" 2>"$stderr_file") || exit_code=$?

  if (( exit_code != 0 )); then
    log "$label" "claude -p exited with code $exit_code"
    if [[ -s "$stderr_file" ]]; then
      log "$label" "stderr: $(head -5 "$stderr_file")"
    fi
  fi

  local cost
  cost=$(echo "$CLAUDE_STDOUT" | jq -r '.total_cost_usd // "unknown"' 2>/dev/null || echo "unknown")
  log "$label" "cost=\$$cost"

  # Append cost to running total
  if [[ "$cost" != "unknown" ]]; then
    echo "$cost" >> "$LOG_DIR/costs.txt"
  fi

  return $exit_code
}

# --- Cost summary ---
get_total_cost() {
  if [[ -f "$LOG_DIR/costs.txt" ]]; then
    awk '{s+=$1} END {printf "%.2f", s}' "$LOG_DIR/costs.txt"
  else
    echo "0.00"
  fi
}

# --- Parse spec-kitty workflow output ---
parse_prompt_file() {
  local output="$1"
  echo "$output" | grep -oE '/[^ ]*spec-kitty-[^ ]*\.md' | head -1 || true
}

parse_workspace_path() {
  local output="$1"
  echo "$output" | grep -oE '\.worktrees/[^ ]+' | head -1 || true
}

parse_feedback_file() {
  local output="$1"
  echo "$output" | grep -oE '/[^ ]*spec-kitty-review-feedback[^ ]*\.md' | head -1 || true
}
