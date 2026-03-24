#!/usr/bin/env bash
# PostToolUse hook on Edit|Write: Auto-formats Python files after edits.
# Mechanical — doesn't rely on the model remembering to format.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Skip if no file path (shouldn't happen, but guard)
if [ -z "$FILE" ] || [ "$FILE" = "null" ]; then
  exit 0
fi

# Only format Python files
if [[ "$FILE" != *.py ]]; then
  exit 0
fi

# Find the backend directory for uv context
BACKEND_DIR="$CWD"
if [ -d "$CWD/backend" ]; then
  BACKEND_DIR="$CWD/backend"
fi

cd "$BACKEND_DIR" 2>/dev/null || exit 0

# Auto-format (silent — don't clutter output)
uv run ruff format "$FILE" 2>/dev/null
uv run ruff check --fix "$FILE" 2>/dev/null

exit 0
