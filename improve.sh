#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE="$(cd "$(dirname "$0")" && pwd)/prompt.md"
MAX_RUNS="${1:-0}"  # 0 = infinite
RUN=0

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Missing $PROMPT_FILE" >&2
  exit 1
fi

prompt="$(cat "$PROMPT_FILE")"

trap 'echo -e "\nStopped after $RUN runs."; exit 0' INT

while true; do
  RUN=$((RUN + 1))
  echo "━━━ Run $RUN $(date '+%H:%M:%S') ━━━"

  if claude -p "$prompt" --dangerously-skip-permissions; then
    echo "✓ Run $RUN succeeded"
  else
    echo "✗ Run $RUN failed (exit $?)"
  fi

  if [[ "$MAX_RUNS" -gt 0 && "$RUN" -ge "$MAX_RUNS" ]]; then
    echo "Reached $MAX_RUNS runs. Done."
    break
  fi
done
