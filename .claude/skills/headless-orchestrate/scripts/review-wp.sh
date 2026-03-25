#!/usr/bin/env bash
# Review a single work package via headless claude -p.
# Usage: review-wp.sh WP_ID
# Exit 0 = approved (done), Exit 1 = error, Exit 2 = rejected (planned)

source "$(dirname "$0")/lib.sh"

WP_ID="${1:?Usage: review-wp.sh WP_ID}"

log "$WP_ID" "Starting review (model=$REVIEW_MODEL, budget=\$$REVIEW_BUDGET)"

cd "$REPO_ROOT"
START_TIME=$(date +%s)

# Step 1: Get review prompt via spec-kitty
# Use locking because spec-kitty does git commits internally, and parallel
# calls race on the git index lock.
acquire_lock
OUTPUT=$(spec-kitty agent workflow review "$WP_ID" --agent headless-reviewer 2>&1) || {
  release_lock
  log "$WP_ID" "Failed to start review: $OUTPUT"
  exit 1
}
release_lock

PROMPT_FILE=$(parse_prompt_file "$OUTPUT")
WORKSPACE=$(parse_workspace_path "$OUTPUT")
FEEDBACK_FILE=$(parse_feedback_file "$OUTPUT")

if [[ -z "$PROMPT_FILE" || -z "$WORKSPACE" ]]; then
  log "$WP_ID" "Could not parse workspace or prompt file from review output"
  log "$WP_ID" "Output was: $OUTPUT"
  exit 1
fi

WORKSPACE_ABS="$REPO_ROOT/$WORKSPACE"
log "$WP_ID" "Workspace: $WORKSPACE_ABS"
log "$WP_ID" "Prompt: $PROMPT_FILE"
log "$WP_ID" "Feedback file: ${FEEDBACK_FILE:-none}"

# Step 2: Run headless claude for review
cd "$WORKSPACE_ABS"

REVIEW_RESULT=$(claude -p \
  --dangerously-skip-permissions \
  --model "$REVIEW_MODEL" \
  --max-budget-usd "$REVIEW_BUDGET" \
  --max-turns "$MAX_REVIEW_TURNS" \
  --output-format json \
  --append-system-prompt "You are a STRICT code reviewer for work package $WP_ID.
Your job is to find problems, not approve quickly. Be rigorous:
1. Check EVERY subtask requirement against the actual implementation
2. Run quality checks (flutter analyze, just check, or appropriate tooling)
3. Run tests (flutter test, just test)
4. Verify no hardcoded values, proper patterns used
5. Only approve if the implementation genuinely meets ALL success criteria

If approved: spec-kitty agent tasks move-task $WP_ID --to done --note 'Review passed: <summary>'
If rejected: Write feedback to ${FEEDBACK_FILE:-/tmp/spec-kitty-review-feedback-$WP_ID.md}, then:
  spec-kitty agent tasks move-task $WP_ID --to planned --review-feedback-file <that-file-path>

You MUST run exactly one of these completion commands." \
  < "$PROMPT_FILE" \
  2>/dev/null) || true

cd "$REPO_ROOT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

COST=$(echo "$REVIEW_RESULT" | jq -r '.cost_usd // "unknown"' 2>/dev/null || echo "unknown")
log "$WP_ID" "Review claude -p finished (duration=${DURATION}s, cost=\$$COST)"

# Step 3: Check result
LANE=$(get_wp_lane "$WP_ID")

case "$LANE" in
  done)
    log "$WP_ID" "Review APPROVED"
    exit 0
    ;;
  planned)
    log "$WP_ID" "Review REJECTED — feedback embedded in WP prompt"
    exit 2
    ;;
  doing)
    log "$WP_ID" "Review incomplete — WP still in doing (reviewer did not run completion command)"
    # Don't try to force a decision — let the orchestrator handle retry
    exit 1
    ;;
  for_review)
    log "$WP_ID" "Review incomplete — WP still in for_review"
    exit 1
    ;;
  *)
    log "$WP_ID" "Unexpected lane after review: $LANE"
    exit 1
    ;;
esac
