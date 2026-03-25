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
export MAX_IMPL_TURNS="${MAX_IMPL_TURNS:-30}"
export MAX_REVIEW_TURNS="${MAX_REVIEW_TURNS:-15}"
export PARALLEL="${PARALLEL:-false}"
export SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export LOG_DIR="${LOG_DIR:-$REPO_ROOT/.claude/skills/headless-orchestrate/logs}"
export LOCK_DIR="$REPO_ROOT/.claude/skills/headless-orchestrate/.state-lock.d"

# --- Logging ---
LOG_FILE=""

init_log() {
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/orchestration-$(date +%Y%m%d-%H%M%S).log"
  export LOG_FILE
  log "ORCHESTRATE" "Log file: $LOG_FILE"
}

log() {
  local tag="$1"; shift
  local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$tag] $*"
  echo "$msg"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

# --- File Locking (serializes spec-kitty state mutations) ---
# Uses mkdir for POSIX-portable atomic locking (works on macOS + Linux).
acquire_lock() {
  local deadline=$(($(date +%s) + 30))
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if (( $(date +%s) >= deadline )); then
      log "LOCK" "Failed to acquire lock after 30s"
      return 1
    fi
    sleep 0.5
  done
  # Record PID so stale locks can be detected
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
  json=$(spec-kitty agent tasks list-tasks --json 2>/dev/null) || {
    log "DETECT" "Failed to list tasks"
    return 1
  }
  # Extract feature slug from the first task's path
  local path
  path=$(echo "$json" | jq -r '.tasks[0].path // empty')
  if [[ -z "$path" ]]; then
    log "DETECT" "No tasks found"
    return 1
  fi
  # Path: .../kitty-specs/SLUG/tasks/WP##-name.md -> extract SLUG
  FEATURE_SLUG=$(echo "$path" | sed 's|.*/kitty-specs/||;s|/tasks/.*||')
  export FEATURE_SLUG
  echo "$FEATURE_SLUG"
}

# --- WP lane queries ---
get_all_wp_lanes() {
  # Outputs JSON: {"WP01": "done", "WP02": "planned", ...}
  spec-kitty agent tasks list-tasks --json 2>/dev/null \
    | jq -r '[.tasks[] | {(.work_package_id): .lane}] | add'
}

get_wp_lane() {
  local wp_id="$1"
  spec-kitty agent tasks list-tasks --json 2>/dev/null \
    | jq -r --arg wp "$wp_id" '.tasks[] | select(.work_package_id == $wp) | .lane'
}

# --- Dependency parsing + wave computation ---
compute_waves() {
  # Reads WP frontmatter, builds dependency graph, outputs waves.
  # Prints one line per wave: "WP02 WP03" (space-separated WP IDs)
  local feature_dir="$REPO_ROOT/kitty-specs/$FEATURE_SLUG/tasks"

  # Build deps and lanes as temp files for awk processing
  local deps_file lanes_file
  deps_file=$(mktemp)
  lanes_file=$(mktemp)
  trap "rm -f \"$deps_file\" \"$lanes_file\"" RETURN

  for wp_file in "$feature_dir"/WP*.md; do
    [[ -f "$wp_file" ]] || continue
    local wp_id lane dep_line
    wp_id=$(grep -m1 '^work_package_id:' "$wp_file" | awk '{print $2}' | tr -d '"')
    lane=$(grep -m1 '^lane:' "$wp_file" | sed 's/lane: *//;s/"//g;s/ *$//')
    dep_line=$(grep -m1 '^dependencies:' "$wp_file" | sed 's/dependencies: *//;s/\[//;s/\]//;s/,/ /g;s/"//g')

    echo "$wp_id $dep_line" >> "$deps_file"
    echo "$wp_id $lane" >> "$lanes_file"
  done

  # Topological sort into waves using Python (simpler than bash).
  # File paths passed as arguments to avoid shell injection in string literals.
  python3 -c "
import sys

deps = {}
lanes = {}

with open(sys.argv[1]) as f:
    for line in f:
        parts = line.strip().split()
        wp = parts[0]
        deps[wp] = [d for d in parts[1:] if d]

with open(sys.argv[2]) as f:
    for line in f:
        parts = line.strip().split()
        lanes[parts[0]] = parts[1] if len(parts) > 1 else 'planned'

done = {wp for wp, lane in lanes.items() if lane == 'done'}
remaining = {wp for wp in deps if wp not in done}
waves = []

while remaining:
    ready = {wp for wp in remaining if all(d in done for d in deps.get(wp, []))}
    if not ready:
        print(f'ERROR: circular or unresolvable deps in: {remaining}', file=sys.stderr)
        sys.exit(1)
    waves.append(sorted(ready))
    done |= ready
    remaining -= ready

for wave in waves:
    print(' '.join(wave))
" "$deps_file" "$lanes_file"
}

# --- Parse spec-kitty workflow output ---
parse_prompt_file() {
  # Extracts the temp prompt file path from spec-kitty workflow output.
  # Matches any absolute path ending in a spec-kitty .md temp file.
  local output="$1"
  echo "$output" | grep -oE '/[^ ]*spec-kitty-[^ ]*\.md' | head -1 || true
}

parse_workspace_path() {
  # Extracts the worktree path from spec-kitty workflow output
  local output="$1"
  echo "$output" | grep -oE '\.worktrees/[^ ]+' | head -1 || true
}

parse_feedback_file() {
  # Extracts the review feedback file path from spec-kitty review output.
  # Matches any absolute path ending in a spec-kitty review feedback .md temp file.
  local output="$1"
  echo "$output" | grep -oE '/[^ ]*spec-kitty-review-feedback[^ ]*\.md' | head -1 || true
}
