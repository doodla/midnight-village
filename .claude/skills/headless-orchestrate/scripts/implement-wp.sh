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
OUTPUT=$(spec-kitty agent workflow implement "$WP_ID" --agent headless-impl 2>&1) || {
  log "$WP_ID" "Failed to create workspace: $OUTPUT"
  exit 1
}

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

IMPL_RESULT=$(claude -p \
  --dangerously-skip-permissions \
  --model "$IMPL_MODEL" \
  --max-budget-usd "$IMPL_BUDGET" \
  --max-turns "$MAX_IMPL_TURNS" \
  --output-format json \
  --append-system-prompt "You are implementing work package $WP_ID in a headless session.
After completing the implementation, you MUST do ALL of these steps:
1. Run quality checks (flutter analyze, just check, or appropriate tooling)
2. Stage ONLY your deliverable files (never use git add -A or git add .)
3. Commit: git commit -m 'feat($WP_ID): <brief description>'
4. Mark subtasks done: spec-kitty agent tasks mark-status T### T### ... --status done
5. Move to review: spec-kitty agent tasks move-task $WP_ID --to for_review --note 'Ready for review: <summary>'
If any step fails, try to fix it. Do not stop until all 5 steps are complete." \
  < "$PROMPT_FILE" \
  2>/dev/null) || true

cd "$REPO_ROOT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Extract cost from JSON output
COST=$(echo "$IMPL_RESULT" | jq -r '.cost_usd // "unknown"' 2>/dev/null || echo "unknown")
log "$WP_ID" "claude -p finished (duration=${DURATION}s, cost=\$$COST)"

# Step 3: Verify WP reached for_review
LANE=$(get_wp_lane "$WP_ID")

if [[ "$LANE" == "for_review" ]]; then
  log "$WP_ID" "Implementation complete — moved to for_review"
  exit 0
fi

# Fallback: if WP is still in "doing", the agent didn't complete the lifecycle.
# Try to move it ourselves if there are commits in the worktree.
if [[ "$LANE" == "doing" ]]; then
  log "$WP_ID" "WP still in doing — checking for commits"
  COMMITS=$(git -C "$WORKSPACE_ABS" log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  if (( COMMITS > 0 )); then
    log "$WP_ID" "Found $COMMITS commits, moving to for_review as fallback"
    safe_state_cmd spec-kitty agent tasks move-task "$WP_ID" --to for_review \
      --note "Moved by orchestrator (agent did not complete lifecycle)" || true
    LANE=$(get_wp_lane "$WP_ID")
    if [[ "$LANE" == "for_review" ]]; then
      exit 0
    fi
  fi
fi

log "$WP_ID" "FAILED: WP in lane '$LANE' after implementation"
exit 1
