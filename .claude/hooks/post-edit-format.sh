#!/usr/bin/env bash
# PostToolUse hook on Edit|Write: Auto-formats Python and Dart files after edits.
# Mechanical — doesn't rely on the model remembering to format.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Skip if no file path (shouldn't happen, but guard)
if [ -z "$FILE" ] || [ "$FILE" = "null" ]; then
  exit 0
fi

# Format Python files
if [[ "$FILE" == *.py ]]; then
  BACKEND_DIR="$CWD"
  if [ -d "$CWD/backend" ]; then
    BACKEND_DIR="$CWD/backend"
  fi

  cd "$BACKEND_DIR" 2>/dev/null || exit 0

  uv run ruff format "$FILE" 2>/dev/null
  uv run ruff check --fix "$FILE" 2>/dev/null
  exit 0
fi

# Format Dart files
if [[ "$FILE" == *.dart ]]; then
  dart format "$FILE" 2>/dev/null
  exit 0
fi

exit 0
