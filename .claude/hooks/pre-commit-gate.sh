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

# Check if backend directory exists (might be running from root or backend/)
BACKEND_DIR="$CWD"
if [ -d "$CWD/backend" ]; then
  BACKEND_DIR="$CWD/backend"
fi

# Run quality checks
cd "$BACKEND_DIR" || exit 0

CHECK_OUTPUT=$(just check 2>&1)
CHECK_EXIT=$?

if [ $CHECK_EXIT -ne 0 ]; then
  echo "BLOCKED: \`just check\` is failing. Fix lint/format/type errors before committing." >&2
  echo "" >&2
  echo "$CHECK_OUTPUT" | tail -20 >&2
  exit 2
fi

TEST_OUTPUT=$(just test 2>&1)
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
  echo "BLOCKED: Tests are failing. Fix them before committing." >&2
  echo "" >&2
  echo "$TEST_OUTPUT" | tail -20 >&2
  exit 2
fi

exit 0
