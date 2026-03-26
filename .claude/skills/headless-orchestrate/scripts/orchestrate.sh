#!/usr/bin/env bash
# Main orchestration loop: plan -> analyze -> implement -> review -> accept -> merge.
# Drives the full spec-kitty lifecycle after /spec-kitty.specify.
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
log "ORCHESTRATE" "Budgets: impl=\$$IMPL_BUDGET review=\$$REVIEW_BUDGET planning=\$$PLANNING_BUDGET"

TOTAL_START=$(date +%s)
FAILED_WPS=()

# ===============================================================================
# Phase 0: Preflight
# ===============================================================================
log "ORCHESTRATE" "=== Phase 0: Preflight ==="

# Check required CLIs
if ! command -v claude &>/dev/null; then
  log "ORCHESTRATE" "FATAL: claude CLI not found in PATH"
  exit 1
fi

if ! command -v spec-kitty &>/dev/null; then
  log "ORCHESTRATE" "FATAL: spec-kitty CLI not found in PATH"
  exit 1
fi

spec-kitty constitution sync 2>>"$LOG_FILE" | grep -q "synced" && log "ORCHESTRATE" "Constitution synced" || true

# ===============================================================================
# Phase 1: Planning (drive spec-kitty next through plan → tasks_finalize)
# ===============================================================================
log "ORCHESTRATE" "=== Phase 1: Planning ==="

# The spec-kitty next state machine walks: specify → plan → tasks_outline →
# tasks_packages → tasks_finalize → implement. We start from wherever the
# feature currently is, skipping specify (user's responsibility), and run
# each planning step as a headless claude -p session until we reach the
# implement phase.

MAX_PLANNING_ITERATIONS=20
PLANNING_ITERATION=0
PREV_RESULT=""

# Clear cost tracking for this run
rm -f "$LOG_DIR/costs.txt"

while true; do
  PLANNING_ITERATION=$((PLANNING_ITERATION + 1))
  if (( PLANNING_ITERATION > MAX_PLANNING_ITERATIONS )); then
    log "ORCHESTRATE" "FATAL: Planning loop exceeded $MAX_PLANNING_ITERATIONS iterations — aborting"
    exit 1
  fi

  # Call spec-kitty next (capture stderr for diagnostics)
  NEXT_ARGS=(--agent claude --feature "$FEATURE_SLUG" --json)
  if [[ -n "$PREV_RESULT" ]]; then
    NEXT_ARGS+=(--result "$PREV_RESULT")
  fi
  NEXT_JSON=$(spec-kitty next "${NEXT_ARGS[@]}" 2>>"$LOG_FILE") || {
    log "ORCHESTRATE" "FATAL: spec-kitty next failed: $NEXT_JSON"
    exit 1
  }

  # Validate JSON
  if ! echo "$NEXT_JSON" | jq -e '.' &>/dev/null; then
    log "ORCHESTRATE" "FATAL: spec-kitty next returned invalid JSON: $NEXT_JSON"
    exit 1
  fi

  NEXT_KIND=$(echo "$NEXT_JSON" | jq -r '.kind')
  NEXT_ACTION=$(echo "$NEXT_JSON" | jq -r '.action // empty')
  NEXT_STATE=$(echo "$NEXT_JSON" | jq -r '.mission_state // empty')
  NEXT_PROMPT=$(echo "$NEXT_JSON" | jq -r '.prompt_file // empty')
  NEXT_REASON=$(echo "$NEXT_JSON" | jq -r '.reason // empty')
  NEXT_QUESTION=$(echo "$NEXT_JSON" | jq -r '.question // empty')
  NEXT_DECISION_ID=$(echo "$NEXT_JSON" | jq -r '.decision_id // empty')

  log "ORCHESTRATE" "next[$PLANNING_ITERATION]: kind=$NEXT_KIND state=$NEXT_STATE action=$NEXT_ACTION"

  # Reached implement phase — planning is done
  if [[ "$NEXT_STATE" == "implement" || "$NEXT_STATE" == "implementing" ]]; then
    log "ORCHESTRATE" "Reached implement phase — planning complete"
    break
  fi

  # Skip specify and discovery (user's responsibility)
  if [[ "$NEXT_STATE" == "specify" || "$NEXT_STATE" == "discovery" || \
        "$NEXT_ACTION" == "specify" || "$NEXT_ACTION" == "discovery" ]]; then
    log "ORCHESTRATE" "Skipping $NEXT_STATE (user responsibility)"
    PREV_RESULT="success"
    continue
  fi

  # Decision required — pause for user input
  if [[ "$NEXT_KIND" == "decision_required" || "$NEXT_KIND" == "input" ]]; then
    DECISION_FILE="$LOG_DIR/decision-needed.json"
    NEXT_OPTIONS=$(echo "$NEXT_JSON" | jq -r '.options // empty')
    echo "$NEXT_JSON" | jq '{
      question: .question,
      decision_id: .decision_id,
      options: .options,
      mission_state: .mission_state,
      feature_slug: "'"$FEATURE_SLUG"'"
    }' > "$DECISION_FILE"
    log "ORCHESTRATE" "PAUSED: Decision required (see $DECISION_FILE)"
    log "ORCHESTRATE" "  Question: $NEXT_QUESTION"
    log "ORCHESTRATE" "  Decision ID: $NEXT_DECISION_ID"
    if [[ -n "$NEXT_OPTIONS" && "$NEXT_OPTIONS" != "null" ]]; then
      log "ORCHESTRATE" "  Options: $NEXT_OPTIONS"
    fi
    # Exit 10 = paused for decision (not a failure)
    exit 10
  fi

  # Blocked or error
  if [[ "$NEXT_KIND" == "blocked" ]]; then
    log "ORCHESTRATE" "BLOCKED at state=$NEXT_STATE: $NEXT_REASON"
    exit 1
  fi

  if [[ "$NEXT_KIND" == "done" ]]; then
    log "ORCHESTRATE" "Mission reports done — nothing to do"
    exit 0
  fi

  # Must have a prompt file for planning steps
  if [[ -z "$NEXT_PROMPT" || "$NEXT_PROMPT" == "null" ]]; then
    log "ORCHESTRATE" "No prompt file for action=$NEXT_ACTION, skipping"
    PREV_RESULT="success"
    continue
  fi

  log "ORCHESTRATE" "Running planning step: $NEXT_ACTION (prompt=$NEXT_PROMPT)"

  # Run headless claude with the planning prompt
  CLAUDE_STDOUT=""
  if run_claude_session "planning-$NEXT_ACTION" -p \
    --dangerously-skip-permissions \
    --model "$PLANNING_MODEL" \
    --max-budget-usd "$PLANNING_BUDGET" \
    --output-format json \
    --append-system-prompt "You are executing planning step '$NEXT_ACTION' for feature '$FEATURE_SLUG' in a headless session.
Follow the prompt instructions exactly. Write all required artifacts.
When done, report what you produced." \
    < "$NEXT_PROMPT"; then
    log "ORCHESTRATE" "Planning step $NEXT_ACTION succeeded"
    PREV_RESULT="success"
  else
    log "ORCHESTRATE" "Planning step $NEXT_ACTION FAILED (see $LOG_DIR/planning-$NEXT_ACTION.stderr)"
    PREV_RESULT="failed"
  fi
done

# ===============================================================================
# Phase 2: Analysis Gate
# ===============================================================================
log "ORCHESTRATE" "=== Phase 2: Analysis Gate ==="

if "$SCRIPTS_DIR/analyze.sh" "$FEATURE_SLUG"; then
  log "ORCHESTRATE" "Analysis gate passed"
else
  log "ORCHESTRATE" "FATAL: Analysis gate failed -- aborting orchestration"
  exit 1
fi

# ===============================================================================
# Phase 3: Preflight for Implementation
# ===============================================================================
log "ORCHESTRATE" "=== Phase 3: Implementation Preflight ==="

# Get current feature state (tasks should now exist)
STATE_JSON=$(get_feature_state_json)
if [[ -z "$STATE_JSON" ]] || ! echo "$STATE_JSON" | jq -e '.success' &>/dev/null; then
  log "ORCHESTRATE" "FATAL: Could not get feature state after planning"
  exit 1
fi

SUMMARY=$(echo "$STATE_JSON" | jq -r '.data.summary')
log "ORCHESTRATE" "Current state: $(echo "$SUMMARY" | jq -c '.')"

# Reset stuck WPs back to planned
# Reset WPs stuck in any active lane (doing, in_progress, claimed) back to planned
STUCK_WPS=$(echo "$STATE_JSON" \
  | jq -r '.data.work_packages[] | select(.lane == "in_progress" or .lane == "claimed" or .lane == "doing") | .wp_id')

for wp in $STUCK_WPS; do
  log "ORCHESTRATE" "Resetting stuck WP $wp -> planned"
  safe_state_cmd spec-kitty orchestrator-api transition \
    --feature "$FEATURE_SLUG" --wp "$wp" --to planned \
    --actor "headless-orchestrator" --force \
    --note "Reset from stuck state by headless orchestrator" 2>/dev/null || {
    log "ORCHESTRATE" "WARNING: Could not reset $wp, skipping"
  }
done

# Transition orphaned approved WPs to done (from crashed runs)
APPROVED_WPS=$(echo "$STATE_JSON" \
  | jq -r '.data.work_packages[] | select(.lane == "approved") | .wp_id')

for wp in $APPROVED_WPS; do
  log "ORCHESTRATE" "Transitioning orphaned approved WP $wp -> done"
  safe_state_cmd spec-kitty orchestrator-api transition \
    --feature "$FEATURE_SLUG" --wp "$wp" --to done \
    --actor "headless-orchestrator" --force \
    --review-ref "headless-review-approved" \
    --note "Orphaned approved WP transitioned to done by headless orchestrator" 2>/dev/null || {
    log "ORCHESTRATE" "WARNING: Could not transition $wp to done, skipping"
  }
done

# Review orphaned for_review WPs (from crashed runs)
ORPHAN_REVIEW_WPS=$(echo "$STATE_JSON" \
  | jq -r '.data.work_packages[] | select(.lane == "for_review") | .wp_id')

for wp in $ORPHAN_REVIEW_WPS; do
  log "ORCHESTRATE" "Reviewing orphaned for_review WP $wp"
  if "$SCRIPTS_DIR/review-wp.sh" "$wp"; then
    log "ORCHESTRATE" "Orphaned WP $wp review passed"
  else
    review_exit=$?
    if (( review_exit == 2 )); then
      log "ORCHESTRATE" "Orphaned WP $wp rejected — will retry in execution phase"
    else
      log "ORCHESTRATE" "WARNING: Orphaned WP $wp review failed (exit=$review_exit)"
    fi
  fi
done

# Refresh state after orphan handling
STATE_JSON=$(get_feature_state_json)
SUMMARY=$(echo "$STATE_JSON" | jq -r '.data.summary')

# Check if there's work to do
PLANNED_COUNT=$(echo "$SUMMARY" | jq -r '.planned // 0')
DONE_COUNT=$(echo "$SUMMARY" | jq -r '.done // 0')
TOTAL_COUNT=$(echo "$STATE_JSON" | jq -r '.data.work_packages | length')

if (( TOTAL_COUNT == 0 )); then
  log "ORCHESTRATE" "FATAL: No WPs found after planning. Tasks generation may have failed."
  exit 1
fi

if (( PLANNED_COUNT == 0 && DONE_COUNT == TOTAL_COUNT )); then
  log "ORCHESTRATE" "All $TOTAL_COUNT WPs already done -- skipping to accept & merge"
fi

log "ORCHESTRATE" "Implementation preflight complete: $PLANNED_COUNT planned, $DONE_COUNT done, $TOTAL_COUNT total"

# ===============================================================================
# Phase 4: Execute (poll list-ready until no WPs remain)
# ===============================================================================
log "ORCHESTRATE" "=== Phase 4: Execute ==="

MAX_ROUNDS=50
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3
ROUND=0
while true; do
  if (( ROUND >= MAX_ROUNDS )); then
    log "ORCHESTRATE" "FATAL: Exceeded $MAX_ROUNDS rounds — aborting"
    FAILED_WPS+=("MAX_ROUNDS_EXCEEDED")
    break
  fi
  READY_WPS=$(get_ready_wps)

  if [[ -z "$READY_WPS" ]]; then
    # Check: are we done, or stuck?
    REMAINING=$(get_feature_state_json \
      | jq -r '[.data.work_packages[] | select(.lane != "done")] | length')
    if (( REMAINING == 0 )); then
      log "ORCHESTRATE" "All WPs done"
      break
    else
      log "ORCHESTRATE" "STUCK: $REMAINING WPs remain but none are ready"
      get_feature_state_json \
        | jq -r '.data.work_packages[] | select(.lane != "done") | "\(.wp_id): \(.lane)"' \
        | while IFS= read -r line; do log "ORCHESTRATE" "  $line"; done
      FAILED_WPS+=("STUCK")
      break
    fi
  fi

  # Convert to array
  read -ra round_wps <<< "$READY_WPS"
  log "ORCHESTRATE" "--- Round $ROUND: ${round_wps[*]} ---"

  # --- Implement ---
  IMPL_FAILED=()
  if [[ "$PARALLEL" == "true" ]] && (( ${#round_wps[@]} > 1 )); then
    log "ORCHESTRATE" "Implementing ${#round_wps[@]} WPs in parallel"
    IMPL_WP_ORDER=()
    IMPL_PID_LIST=()
    for wp in "${round_wps[@]}"; do
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
    for wp in "${round_wps[@]}"; do
      if ! "$SCRIPTS_DIR/implement-wp.sh" "$wp"; then
        IMPL_FAILED+=("$wp")
      fi
    done
  fi

  # Build review queue (exclude implementation failures)
  review_wps=()
  for wp in "${round_wps[@]}"; do
    impl_failed=false
    if [[ ${IMPL_FAILED[@]+x} ]]; then
      for failed in "${IMPL_FAILED[@]}"; do
        [[ "$failed" == "$wp" ]] && { impl_failed=true; break; }
      done
    fi
    if $impl_failed; then
      log "$wp" "Skipping review (implementation failed)"
      FAILED_WPS+=("$wp")
    else
      review_wps+=("$wp")
    fi
  done

  # --- Review ---
  if (( ${#review_wps[@]} > 0 )); then
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
        log "$wp" "Round $ROUND: approved"
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

  # Track consecutive failures
  if [[ ${IMPL_FAILED[@]+x} ]]; then
    ROUND_FAILURES=${#IMPL_FAILED[@]}
  else
    ROUND_FAILURES=0
  fi
  if (( ROUND_FAILURES == ${#round_wps[@]} )); then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    log "ORCHESTRATE" "All WPs failed this round (consecutive=$CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES)"
    if (( CONSECUTIVE_FAILURES >= MAX_CONSECUTIVE_FAILURES )); then
      log "ORCHESTRATE" "FATAL: $MAX_CONSECUTIVE_FAILURES consecutive all-fail rounds — aborting"
      break
    fi
  else
    CONSECUTIVE_FAILURES=0
  fi

  log "ORCHESTRATE" "Round $ROUND complete"
  ROUND=$((ROUND + 1))
done

# ===============================================================================
# Phase 5: Accept & Merge
# ===============================================================================
log "ORCHESTRATE" "=== Phase 5: Accept & Merge ==="

if [[ ${FAILED_WPS[@]+x} ]]; then
  FAILED_COUNT=${#FAILED_WPS[@]}
else
  FAILED_COUNT=0
fi
if (( FAILED_COUNT > 0 )); then
  log "ORCHESTRATE" "WARNING: $FAILED_COUNT WPs failed: ${FAILED_WPS[*]}"
  log "ORCHESTRATE" "Cannot accept -- not all WPs completed successfully"
  spec-kitty agent tasks status >> "$LOG_FILE" 2>&1
  exit 1
fi

# Accept
log "ORCHESTRATE" "Running acceptance..."
spec-kitty orchestrator-api accept-feature \
  --feature "$FEATURE_SLUG" --actor "headless-orchestrator" \
  >> "$LOG_FILE" 2>&1 || {
  log "ORCHESTRATE" "Acceptance failed — see $LOG_FILE for details"
  exit 1
}

# Merge
log "ORCHESTRATE" "Executing merge..."
spec-kitty orchestrator-api merge-feature \
  --feature "$FEATURE_SLUG" >> "$LOG_FILE" 2>&1 || {
  log "ORCHESTRATE" "Merge failed — see $LOG_FILE for details"
  exit 1
}

# ===============================================================================
# Phase 6: Summary
# ===============================================================================
TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))
TOTAL_MINUTES=$(( TOTAL_DURATION / 60 ))
TOTAL_REMAINDER_SECS=$(( TOTAL_DURATION % 60 ))

log "ORCHESTRATE" "=== Complete ==="
log "ORCHESTRATE" "Feature: $FEATURE_SLUG"
log "ORCHESTRATE" "Duration: ${TOTAL_MINUTES}m ${TOTAL_REMAINDER_SECS}s"
log "ORCHESTRATE" "Rounds: $ROUND"
log "ORCHESTRATE" "Total cost: \$$(get_total_cost)"
log "ORCHESTRATE" "Log: $LOG_FILE"

spec-kitty agent tasks status >> "$LOG_FILE" 2>&1
