#!/usr/bin/env bash
# Implement a single work package via headless claude -p.
# Usage: implement-wp.sh WP_ID
# Exit 0 = WP in for_review, Exit 1 = failure

source "$(dirname "$0")/lib.sh"

WP_ID="${1:?Usage: implement-wp.sh WP_ID}"

log "$WP_ID" "Starting implementation (model=$IMPL_MODEL, budget=\$$IMPL_BUDGET)"

cd "$REPO_ROOT"
START_TIME=$(date +%s)

# Step 1: Create worktree and get prompt via spec-kitty
acquire_lock
OUTPUT=$(spec-kitty agent workflow implement "$WP_ID" --feature "$FEATURE_SLUG" --agent headless-impl 2>>"$LOG_FILE") || {
  release_lock
  log "$WP_ID" "Failed to create workspace: $OUTPUT"
  exit 1
}
release_lock

PROMPT_FILE=$(parse_prompt_file "$OUTPUT")
WORKSPACE=$(parse_workspace_path "$OUTPUT")

if [[ -z "$PROMPT_FILE" || -z "$WORKSPACE" ]]; then
  log "$WP_ID" "Could not parse workspace or prompt file from output"
  log "$WP_ID" "Output was: $OUTPUT"
  exit 1
fi

WORKSPACE_ABS="$REPO_ROOT/$WORKSPACE"
if [[ ! -d "$WORKSPACE_ABS" ]]; then
  log "$WP_ID" "Workspace directory does not exist: $WORKSPACE_ABS"
  exit 1
fi

log "$WP_ID" "Workspace: $WORKSPACE_ABS"
log "$WP_ID" "Prompt: $PROMPT_FILE"

# Step 2: Run headless claude in the worktree
cd "$WORKSPACE_ABS"

CLAUDE_STDOUT=""
if run_claude_session "$WP_ID-impl" -p \
  --dangerously-skip-permissions \
  --model "$IMPL_MODEL" \
  --max-budget-usd "$IMPL_BUDGET" \
  --output-format json \
  --append-system-prompt "You are implementing work package $WP_ID in a headless session.
After completing the implementation, you MUST do ALL of these steps:
1. Run quality checks (flutter analyze, just check, or appropriate tooling)
2. Stage ONLY your deliverable files (never use git add -A or git add .)
3. Commit: git commit -m 'feat($WP_ID): <brief description>'
4. Mark subtasks done: spec-kitty agent tasks mark-status T### T### ... --status done
5. Move to review: spec-kitty agent tasks move-task $WP_ID --to for_review --note 'Ready for review: <summary>'
If any step fails, try to fix it. Do not stop until all 5 steps are complete." \
  < "$PROMPT_FILE"; then
  log "$WP_ID" "claude -p session completed successfully"
else
  log "$WP_ID" "claude -p session failed (see $LOG_DIR/$WP_ID-impl.stderr)"
fi

cd "$REPO_ROOT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log "$WP_ID" "Implementation duration: ${DURATION}s"

# Step 3: Verify WP reached for_review
LANE=$(get_wp_lane "$WP_ID")

if [[ "$LANE" == "for_review" ]]; then
  log "$WP_ID" "Implementation complete — moved to for_review"
  exit 0
fi

# Fallback: if WP is still in doing/in_progress, the agent didn't complete the lifecycle.
# Try to move it ourselves if there are commits in the worktree.
if [[ "$LANE" == "doing" || "$LANE" == "in_progress" ]]; then
  log "$WP_ID" "WP still in $LANE — checking for commits"
  COMMITS=$(git -C "$WORKSPACE_ABS" log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  if (( COMMITS > 0 )); then
    log "$WP_ID" "Found $COMMITS commits, moving to for_review as fallback"
    safe_state_cmd spec-kitty orchestrator-api transition \
      --feature "$FEATURE_SLUG" --wp "$WP_ID" --to for_review \
      --actor "headless-orchestrator" \
      --note "Moved by orchestrator (agent did not complete lifecycle)" || true
    LANE=$(get_wp_lane "$WP_ID")
    if [[ "$LANE" == "for_review" ]]; then
      exit 0
    fi
  fi
fi

log "$WP_ID" "FAILED: WP in lane '$LANE' after implementation"
exit 1
