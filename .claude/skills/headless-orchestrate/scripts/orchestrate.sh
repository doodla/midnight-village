#!/usr/bin/env bash
# Main orchestration loop: preflight -> analyze -> waves -> accept -> merge.
# Usage: orchestrate.sh [FEATURE_SLUG]
# All configuration via environment variables (see lib.sh for defaults).

source "$(dirname "$0")/lib.sh"
init_log

FEATURE_SLUG="${1:-$(detect_feature)}" || {
  log "ORCHESTRATE" "FATAL: Could not detect feature slug. Pass it as argument or set FEATURE_SLUG."
  exit 1
}
export FEATURE_SLUG

log "ORCHESTRATE" "Feature: $FEATURE_SLUG"
log "ORCHESTRATE" "Config: impl_model=$IMPL_MODEL review_model=$REVIEW_MODEL parallel=$PARALLEL max_retries=$MAX_RETRIES"
log "ORCHESTRATE" "Budgets: impl=\$$IMPL_BUDGET review=\$$REVIEW_BUDGET"

TOTAL_START=$(date +%s)
FAILED_WPS=()

# ===============================================================================
# Phase 0: Preflight
# ===============================================================================
log "ORCHESTRATE" "=== Phase 0: Preflight ==="

# Check claude CLI is available
if ! command -v claude &>/dev/null; then
  log "ORCHESTRATE" "FATAL: claude CLI not found in PATH"
  exit 1
fi

# Check spec-kitty CLI is available
if ! command -v spec-kitty &>/dev/null; then
  log "ORCHESTRATE" "FATAL: spec-kitty CLI not found in PATH"
  exit 1
fi

# List current state
LANES_JSON=$(get_all_wp_lanes)
log "ORCHESTRATE" "Current WP lanes: $LANES_JSON"

# Reset stuck "doing" WPs back to planned
STUCK_WPS=$(spec-kitty agent tasks list-tasks --lane doing --json 2>/dev/null \
  | jq -r '.tasks[].work_package_id' 2>/dev/null) || true

for wp in $STUCK_WPS; do
  log "ORCHESTRATE" "Resetting stuck WP $wp (doing -> planned)"
  FEEDBACK_TMP=$(mktemp)
  echo "Reset from stuck 'doing' state by headless orchestrator (no active process found)." > "$FEEDBACK_TMP"
  safe_state_cmd spec-kitty agent tasks move-task "$wp" --to planned \
    --review-feedback-file "$FEEDBACK_TMP" --force \
    --note "Reset stuck WP" 2>/dev/null || {
    log "ORCHESTRATE" "WARNING: Could not reset $wp, skipping"
  }
  rm -f "$FEEDBACK_TMP"
done

# Count planned WPs
PLANNED_COUNT=$(spec-kitty agent tasks list-tasks --lane planned --json 2>/dev/null \
  | jq -r '.count // 0' 2>/dev/null) || PLANNED_COUNT=0

if (( PLANNED_COUNT == 0 )); then
  # Check if everything is already done
  DONE_COUNT=$(spec-kitty agent tasks list-tasks --lane done --json 2>/dev/null \
    | jq -r '.count // 0' 2>/dev/null) || DONE_COUNT=0
  TOTAL_COUNT=$(spec-kitty agent tasks list-tasks --json 2>/dev/null \
    | jq -r '.count // 0' 2>/dev/null) || TOTAL_COUNT=0

  if (( DONE_COUNT == TOTAL_COUNT && TOTAL_COUNT > 0 )); then
    log "ORCHESTRATE" "All $TOTAL_COUNT WPs already done -- skipping to accept & merge"
  else
    log "ORCHESTRATE" "No planned WPs found (done=$DONE_COUNT, total=$TOTAL_COUNT)"
    exit 1
  fi
fi

log "ORCHESTRATE" "Preflight complete: $PLANNED_COUNT planned WPs to process"

# ===============================================================================
# Phase 1: Analysis Gate
# ===============================================================================
log "ORCHESTRATE" "=== Phase 1: Analysis Gate ==="

if "$SCRIPTS_DIR/analyze.sh" "$FEATURE_SLUG"; then
  log "ORCHESTRATE" "Analysis gate passed"
else
  log "ORCHESTRATE" "FATAL: Analysis gate failed -- aborting orchestration"
  exit 1
fi

# ===============================================================================
# Phase 2: Compute Execution Waves
# ===============================================================================
log "ORCHESTRATE" "=== Phase 2: Compute Waves ==="

WAVE_NUM=0
WAVES=()
while IFS= read -r wave_line; do
  [[ -z "$wave_line" ]] && continue
  WAVES[$WAVE_NUM]="$wave_line"
  log "ORCHESTRATE" "Wave $WAVE_NUM: $wave_line"
  WAVE_NUM=$((WAVE_NUM + 1))
done < <(compute_waves)

if (( WAVE_NUM == 0 )); then
  log "ORCHESTRATE" "No waves to execute (all WPs may already be done)"
fi

# --- Helper: check if a value is in an indexed array ---
# Usage: array_contains "value" "${array[@]}"
array_contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# ===============================================================================
# Phase 3: Execute Waves
# ===============================================================================
log "ORCHESTRATE" "=== Phase 3: Execute Waves ==="

for wave_idx in $(seq 0 $((WAVE_NUM - 1))); do
  # Split wave line into array (intentional word splitting, WP IDs have no spaces/globs)
  read -ra wave_wps <<< "${WAVES[$wave_idx]}"
  log "ORCHESTRATE" "--- Wave $wave_idx: ${wave_wps[*]} ---"

  # Filter out already-done WPs
  todo_wps=()
  for wp in "${wave_wps[@]}"; do
    lane=$(get_wp_lane "$wp")
    if [[ "$lane" == "done" ]]; then
      log "$wp" "Already done, skipping"
    else
      todo_wps+=("$wp")
    fi
  done

  if (( ${#todo_wps[@]} == 0 )); then
    log "ORCHESTRATE" "Wave $wave_idx: all WPs already done"
    continue
  fi

  # --- Implement ---
  IMPL_FAILED=()
  if [[ "$PARALLEL" == "true" ]] && (( ${#todo_wps[@]} > 1 )); then
    log "ORCHESTRATE" "Implementing ${#todo_wps[@]} WPs in parallel"
    # Parallel: launch all, collect PIDs in indexed arrays
    IMPL_WP_ORDER=()
    IMPL_PID_LIST=()
    for wp in "${todo_wps[@]}"; do
      "$SCRIPTS_DIR/implement-wp.sh" "$wp" &
      IMPL_WP_ORDER+=("$wp")
      IMPL_PID_LIST+=($!)
    done
    for i in $(seq 0 $((${#IMPL_WP_ORDER[@]} - 1))); do
      if ! wait "${IMPL_PID_LIST[$i]}"; then
        IMPL_FAILED+=("${IMPL_WP_ORDER[$i]}")
      fi
    done
  else
    for wp in "${todo_wps[@]}"; do
      if ! "$SCRIPTS_DIR/implement-wp.sh" "$wp"; then
        IMPL_FAILED+=("$wp")
      fi
    done
  fi

  # Remove implementation failures from review queue
  review_wps=()
  for wp in "${todo_wps[@]}"; do
    if (( ${#IMPL_FAILED[@]} > 0 )) && array_contains "$wp" "${IMPL_FAILED[@]}"; then
      log "$wp" "Skipping review (implementation failed)"
      FAILED_WPS+=("$wp")
    else
      review_wps+=("$wp")
    fi
  done

  # --- Review ---
  if (( ${#review_wps[@]} > 0 )); then
    # Collect review exit codes in parallel indexed arrays
    REVIEW_WP_ORDER=()
    REVIEW_EXIT_LIST=()

    if [[ "$PARALLEL" == "true" ]] && (( ${#review_wps[@]} > 1 )); then
      log "ORCHESTRATE" "Reviewing ${#review_wps[@]} WPs in parallel"
      REVIEW_PID_LIST=()
      for wp in "${review_wps[@]}"; do
        "$SCRIPTS_DIR/review-wp.sh" "$wp" &
        REVIEW_WP_ORDER+=("$wp")
        REVIEW_PID_LIST+=($!)
      done
      for i in $(seq 0 $((${#REVIEW_WP_ORDER[@]} - 1))); do
        wait "${REVIEW_PID_LIST[$i]}" && REVIEW_EXIT_LIST+=("0") || REVIEW_EXIT_LIST+=("$?")
      done
    else
      for wp in "${review_wps[@]}"; do
        REVIEW_WP_ORDER+=("$wp")
        "$SCRIPTS_DIR/review-wp.sh" "$wp" && REVIEW_EXIT_LIST+=("0") || REVIEW_EXIT_LIST+=("$?")
      done
    fi

    # --- Handle rejections (retry loop) ---
    for i in $(seq 0 $((${#REVIEW_WP_ORDER[@]} - 1))); do
      wp="${REVIEW_WP_ORDER[$i]}"
      exit_code="${REVIEW_EXIT_LIST[$i]:-1}"
      if (( exit_code == 0 )); then
        log "$wp" "Wave $wave_idx: approved"
        continue
      fi

      if (( exit_code == 2 )); then
        # Rejected -- retry
        log "$wp" "Rejected -- entering retry loop"
        approved=false
        for attempt in $(seq 1 "$MAX_RETRIES"); do
          log "$wp" "Retry $attempt/$MAX_RETRIES"
          if "$SCRIPTS_DIR/implement-wp.sh" "$wp"; then
            "$SCRIPTS_DIR/review-wp.sh" "$wp" && { approved=true; break; } || {
              review_exit=$?
              if (( review_exit != 2 )); then
                log "$wp" "Review error on retry (exit=$review_exit)"
                break
              fi
            }
          else
            log "$wp" "Implementation failed on retry"
          fi
        done
        if ! $approved; then
          log "$wp" "FAILED after $MAX_RETRIES retries"
          FAILED_WPS+=("$wp")
        fi
      else
        log "$wp" "Review error (exit=$exit_code)"
        FAILED_WPS+=("$wp")
      fi
    done
  fi

  log "ORCHESTRATE" "Wave $wave_idx complete"
done

# ===============================================================================
# Phase 4: Accept & Merge
# ===============================================================================
log "ORCHESTRATE" "=== Phase 4: Accept & Merge ==="

if (( ${#FAILED_WPS[@]} > 0 )); then
  log "ORCHESTRATE" "WARNING: ${#FAILED_WPS[@]} WPs failed: ${FAILED_WPS[*]}"
  log "ORCHESTRATE" "Checking if remaining WPs allow acceptance..."
fi

# Check if all WPs are done
ALL_DONE=true
while IFS= read -r line; do
  wp_id=$(echo "$line" | jq -r '.work_package_id')
  lane=$(echo "$line" | jq -r '.lane')
  if [[ "$lane" != "done" ]]; then
    ALL_DONE=false
    log "ORCHESTRATE" "WP $wp_id is in lane '$lane' (not done)"
  fi
done < <(spec-kitty agent tasks list-tasks --json 2>/dev/null | jq -c '.tasks[]')

if ! $ALL_DONE; then
  log "ORCHESTRATE" "Cannot accept -- not all WPs are done"
  log "ORCHESTRATE" "Final status:"
  spec-kitty agent tasks status 2>&1 | tee -a "$LOG_FILE"
  exit 1
fi

# Accept
log "ORCHESTRATE" "Running acceptance..."
spec-kitty agent feature accept --json --lenient 2>&1 | tee -a "$LOG_FILE" || {
  log "ORCHESTRATE" "Acceptance failed -- check output above"
  exit 1
}

# Merge (dry run first)
log "ORCHESTRATE" "Merge dry-run..."
spec-kitty merge --feature "$FEATURE_SLUG" --dry-run --json 2>&1 | tee -a "$LOG_FILE"

log "ORCHESTRATE" "Executing merge..."
spec-kitty merge --feature "$FEATURE_SLUG" 2>&1 | tee -a "$LOG_FILE" || {
  log "ORCHESTRATE" "Merge failed -- check output above"
  exit 1
}

# ===============================================================================
# Phase 5: Summary
# ===============================================================================
TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))
TOTAL_MINUTES=$(( TOTAL_DURATION / 60 ))
TOTAL_REMAINDER_SECS=$(( TOTAL_DURATION % 60 ))

log "ORCHESTRATE" "=== Complete ==="
log "ORCHESTRATE" "Feature: $FEATURE_SLUG"
log "ORCHESTRATE" "Duration: ${TOTAL_MINUTES}m ${TOTAL_REMAINDER_SECS}s"
if (( ${#FAILED_WPS[@]} > 0 )); then
  log "ORCHESTRATE" "Failed WPs: ${#FAILED_WPS[@]} ${FAILED_WPS[*]}"
else
  log "ORCHESTRATE" "Failed WPs: 0 (none)"
fi
log "ORCHESTRATE" "Log: $LOG_FILE"

spec-kitty agent tasks status 2>&1 | tee -a "$LOG_FILE"
