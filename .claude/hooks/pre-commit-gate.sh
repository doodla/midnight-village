#!/usr/bin/env bash
# PreToolUse hook on Bash: Blocks git commit unless quality checks pass.
# This mechanically enforces what the model might skip.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Only gate git commit commands
if ! echo "$COMMAND" | grep -qE "git\s+commit"; then
  exit 0
fi

# Block --no-verify (model tries this when hooks fail)
if echo "$COMMAND" | grep -q "\-\-no-verify"; then
  echo "BLOCKED: --no-verify is not allowed. Fix the failing checks instead." >&2
  exit 2
fi

cd "$CWD" || exit 0

# Determine what's staged
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

HAS_BACKEND=$(echo "$STAGED_FILES" | grep -v '^frontend/' | grep -v '^$' | head -1)
HAS_FRONTEND=$(echo "$STAGED_FILES" | grep '^frontend/' | head -1)

FAILED=0

# --- Backend checks ---
if [ -n "$HAS_BACKEND" ]; then
  BACKEND_DIR="$CWD"
  if [ -d "$CWD/backend" ]; then
    BACKEND_DIR="$CWD/backend"
  fi

  cd "$BACKEND_DIR" || exit 0

  CHECK_OUTPUT=$(just check 2>&1)
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Backend \`just check\` is failing. Fix lint/format/type errors before committing." >&2
    echo "" >&2
    echo "$CHECK_OUTPUT" | tail -20 >&2
    FAILED=1
  fi

  TEST_OUTPUT=$(just test 2>&1)
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Backend tests are failing. Fix them before committing." >&2
    echo "" >&2
    echo "$TEST_OUTPUT" | tail -20 >&2
    FAILED=1
  fi
fi

# --- Frontend checks ---
if [ -n "$HAS_FRONTEND" ]; then
  FRONTEND_DIR="$CWD"
  if [ -d "$CWD/frontend" ]; then
    FRONTEND_DIR="$CWD/frontend"
  fi

  cd "$FRONTEND_DIR" || exit 0

  ANALYZE_OUTPUT=$(just analyze 2>&1)
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Frontend \`just analyze\` is failing. Fix analysis errors before committing." >&2
    echo "" >&2
    echo "$ANALYZE_OUTPUT" | tail -20 >&2
    FAILED=1
  fi

  FORMAT_OUTPUT=$(just format-check 2>&1)
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Frontend formatting check is failing. Run \`dart format\` before committing." >&2
    echo "" >&2
    echo "$FORMAT_OUTPUT" | tail -20 >&2
    FAILED=1
  fi

  FTEST_OUTPUT=$(just test 2>&1)
  if [ $? -ne 0 ]; then
    echo "BLOCKED: Frontend tests are failing. Fix them before committing." >&2
    echo "" >&2
    echo "$FTEST_OUTPUT" | tail -20 >&2
    FAILED=1
  fi
fi

if [ $FAILED -ne 0 ]; then
  exit 2
fi

exit 0
