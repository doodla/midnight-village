#!/usr/bin/env bash
# Analysis gate: run spec-kitty analyze, fix HIGH/CRITICAL issues via --resume.
# Usage: analyze.sh [FEATURE_SLUG]
# Exit 0 = clean, Exit 1 = unfixable issues remain

source "$(dirname "$0")/lib.sh"

FEATURE_SLUG="${1:-$(detect_feature)}"
FIX_MODEL="${FIX_MODEL:-$ANALYZE_MODEL}"
FIX_BUDGET="${FIX_BUDGET:-5.00}"
MAX_FIX_ATTEMPTS="${MAX_FIX_ATTEMPTS:-2}"

log "ANALYZE" "Running analysis for feature: $FEATURE_SLUG"

cd "$REPO_ROOT"

# Step 1: Run analysis, capture session ID for --resume
ANALYZE_STDERR="$LOG_DIR/analyze-initial.stderr"
ANALYZE_RESULT=$(claude -p "Run /spec-kitty.analyze for feature $FEATURE_SLUG.
After the analysis completes, output a summary line in this exact format:
SEVERITY_SUMMARY: critical=N high=N medium=N low=N
where N is the count of issues at each severity level.
If there are zero issues at every level, output: SEVERITY_SUMMARY: critical=0 high=0 medium=0 low=0" \
  --dangerously-skip-permissions \
  --model "$FIX_MODEL" \
  --max-budget-usd "$FIX_BUDGET" \
  --output-format json \
  2>"$ANALYZE_STDERR") || {
  log "ANALYZE" "claude -p failed (exit=$?)"
  if [[ -s "$ANALYZE_STDERR" ]]; then
    log "ANALYZE" "stderr: $(head -5 "$ANALYZE_STDERR")"
  fi
}

# Extract the text result
RESULT_TEXT=$(echo "$ANALYZE_RESULT" | jq -r '.result // empty' 2>/dev/null)
SESSION_ID=$(echo "$ANALYZE_RESULT" | jq -r '.session_id // empty' 2>/dev/null)

# Track cost
ANALYZE_COST=$(echo "$ANALYZE_RESULT" | jq -r '.total_cost_usd // empty' 2>/dev/null)
if [[ -n "$ANALYZE_COST" ]]; then
  echo "$ANALYZE_COST" >> "$LOG_DIR/costs.txt"
  log "ANALYZE" "cost=\$$ANALYZE_COST"
fi

if [[ -z "$RESULT_TEXT" ]]; then
  log "ANALYZE" "Failed to get analysis output"
  exit 1
fi

# Parse severity counts from the summary line
parse_severity() {
  local text="$1" level="$2"
  echo "$text" | grep -oE "${level}=[0-9]+" | grep -oE '[0-9]+' | tail -1 || echo "0"
}

CRITICAL=$(parse_severity "$RESULT_TEXT" "critical")
HIGH=$(parse_severity "$RESULT_TEXT" "high")

log "ANALYZE" "Initial analysis: critical=$CRITICAL high=$HIGH"

if (( CRITICAL == 0 && HIGH == 0 )); then
  log "ANALYZE" "Analysis clean — no critical/high issues"
  exit 0
fi

# Step 2: Fix issues using --resume (same session has full context)
for attempt in $(seq 1 "$MAX_FIX_ATTEMPTS"); do
  log "ANALYZE" "Fix attempt $attempt/$MAX_FIX_ATTEMPTS"

  if [[ -z "$SESSION_ID" ]]; then
    log "ANALYZE" "No session ID from analysis — cannot resume for fix"
    exit 1
  fi

  FIX_STDERR="$LOG_DIR/analyze-fix-$attempt.stderr"
  FIX_RESULT=$(claude -p "Fix all CRITICAL and HIGH severity issues you found in the analysis.
Edit the spec.md, plan.md, and/or tasks.md files in-place to resolve the issues.
Do NOT regenerate tasks with /spec-kitty.tasks -- that would destroy existing work packages.
After fixing, re-run /spec-kitty.analyze and output the updated summary line:
SEVERITY_SUMMARY: critical=N high=N medium=N low=N" \
    --dangerously-skip-permissions \
    --resume "$SESSION_ID" \
    --max-budget-usd "$FIX_BUDGET" \
    --output-format json \
    2>"$FIX_STDERR") || {
    log "ANALYZE" "Fix session failed (exit=$?)"
    if [[ -s "$FIX_STDERR" ]]; then
      log "ANALYZE" "stderr: $(head -5 "$FIX_STDERR")"
    fi
  }

  FIX_TEXT=$(echo "$FIX_RESULT" | jq -r '.result // empty' 2>/dev/null)

  # Track cost
  FIX_COST=$(echo "$FIX_RESULT" | jq -r '.total_cost_usd // empty' 2>/dev/null)
  if [[ -n "$FIX_COST" ]]; then
    echo "$FIX_COST" >> "$LOG_DIR/costs.txt"
    log "ANALYZE" "fix cost=\$$FIX_COST"
  fi

  CRITICAL=$(parse_severity "$FIX_TEXT" "critical")
  HIGH=$(parse_severity "$FIX_TEXT" "high")

  log "ANALYZE" "After fix attempt $attempt: critical=$CRITICAL high=$HIGH"

  if (( CRITICAL == 0 && HIGH == 0 )); then
    log "ANALYZE" "All critical/high issues resolved"
    exit 0
  fi
done

log "ANALYZE" "FATAL: $CRITICAL critical and $HIGH high issues persist after $MAX_FIX_ATTEMPTS fix attempts"
exit 1
