#!/usr/bin/env bash
# SessionStart hook: Injects current project state into Claude's context.
# Fires on startup, resume, clear, and compact.
# This is the "bootstrap ritual" — mechanical context recovery.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')
cd "$CWD" || exit 0

# Collect state
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null || echo "no commits")
GIT_STATUS=$(git status --short 2>/dev/null || echo "unknown")

# Check for plan state
PLAN_STATE="No .plan/ directory — greenfield project."
if [ -f ".plan/STATUS.yaml" ]; then
  PLAN_STATE=$(cat .plan/STATUS.yaml 2>/dev/null)
fi

# Build context message
CONTEXT="PROJECT STATE (injected by bootstrap hook):
Branch: $BRANCH
Session source: $SOURCE

Recent commits:
$RECENT_COMMITS

Uncommitted changes:
${GIT_STATUS:-clean}

Plan state:
$PLAN_STATE

REMINDER: Quality gates are enforced by hooks. Commits are blocked unless \`just check\` and \`just test\` pass. You do NOT need to remember to run them — they will block you if they fail."

# Output as additionalContext
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $(echo "$CONTEXT" | jq -Rs .)
  }
}
EOF
exit 0
