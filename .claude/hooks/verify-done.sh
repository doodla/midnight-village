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

# Only enforce if there are uncommitted code changes (not just docs/plans)
cd "$CWD" || exit 0
CODE_CHANGES=$(git diff --name-only 2>/dev/null | grep -E '\.(py|dart)$' | head -1)

if [ -z "$CODE_CHANGES" ]; then
  # No code changes — don't block (might just be planning or docs)
  exit 0
fi

# Find backend directory
BACKEND_DIR="$CWD"
if [ -d "$CWD/backend" ]; then
  BACKEND_DIR="$CWD/backend"
fi

cd "$BACKEND_DIR" 2>/dev/null || exit 0

# Run tests silently
TEST_OUTPUT=$(just test 2>&1)
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
  echo "Tests are failing. You have uncommitted code changes — fix the tests before finishing." >&2
  echo "" >&2
  echo "$TEST_OUTPUT" | tail -10 >&2
  exit 2
fi

exit 0
