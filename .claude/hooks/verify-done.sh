#!/usr/bin/env bash
# Stop hook: Prevents Claude from finishing if tests are failing.
# Guards against premature "done" claims.

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# CRITICAL: Prevent infinite loop. If stop hook already fired once, let it pass.
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Check for uncommitted code changes by component
cd "$CWD" || exit 0
PY_CHANGES=$(git diff --name-only 2>/dev/null | grep -E '\.py$' | head -1)
DART_CHANGES=$(git diff --name-only 2>/dev/null | grep -E '\.dart$' | head -1)

if [ -z "$PY_CHANGES" ] && [ -z "$DART_CHANGES" ]; then
  # No code changes — don't block (might just be planning or docs)
  exit 0
fi

FAILED=0

# --- Backend tests ---
if [ -n "$PY_CHANGES" ]; then
  BACKEND_DIR="$CWD"
  if [ -d "$CWD/backend" ]; then
    BACKEND_DIR="$CWD/backend"
  fi

  cd "$BACKEND_DIR" 2>/dev/null || exit 0

  TEST_OUTPUT=$(just test 2>&1)
  if [ $? -ne 0 ]; then
    echo "Backend tests are failing. You have uncommitted Python changes — fix the tests before finishing." >&2
    echo "" >&2
    echo "$TEST_OUTPUT" | tail -10 >&2
    FAILED=1
  fi
fi

# --- Frontend tests ---
if [ -n "$DART_CHANGES" ]; then
  FRONTEND_DIR="$CWD"
  if [ -d "$CWD/frontend" ]; then
    FRONTEND_DIR="$CWD/frontend"
  fi

  cd "$FRONTEND_DIR" 2>/dev/null || exit 0

  FTEST_OUTPUT=$(just test 2>&1)
  if [ $? -ne 0 ]; then
    echo "Frontend tests are failing. You have uncommitted Dart changes — fix the tests before finishing." >&2
    echo "" >&2
    echo "$FTEST_OUTPUT" | tail -10 >&2
    FAILED=1
  fi
fi

if [ $FAILED -ne 0 ]; then
  exit 2
fi

exit 0
