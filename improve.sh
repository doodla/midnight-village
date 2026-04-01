#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE="$(cd "$(dirname "$0")" && pwd)/prompt.md"
MAX_RUNS="${1:-0}"  # 0 = infinite
WAIT_MINUTES="${2:-5}"  # how long to wait on rate limit
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

  output=$(claude -p "$prompt" --dangerously-skip-permissions 2>&1) && rc=0 || rc=$?

  if echo "$output" | grep -qi "rate limit\|usage limit\|too many requests\|429\|overloaded"; then
    RUN=$((RUN - 1))  # don't count a rate-limited run
    echo "⏳ Rate limited. Waiting ${WAIT_MINUTES}m before retrying... ($(date '+%H:%M:%S'))"
    sleep "$((WAIT_MINUTES * 60))"
    continue
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "✓ Run $RUN succeeded"
  else
    echo "✗ Run $RUN failed (exit $rc)"
    echo "$output" | tail -5
  fi

  if [[ "$MAX_RUNS" -gt 0 && "$RUN" -ge "$MAX_RUNS" ]]; then
    echo "Reached $MAX_RUNS runs. Done."
    break
  fi
done
