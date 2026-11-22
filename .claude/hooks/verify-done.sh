#!/usr/bin/env bash
# Stop hook: an agent may not finish with uncommitted code that fails the fast checks.
# What only this hook does: it looks at work that is NOT committed (staged,
# unstaged or untracked code). It runs the fast checks of the blocks that work
# touches (lint, format, types, analyze; routing in lib/gate.sh), in parallel,
# and skips a block that already passed on exactly this content (by the commit
# gate, `just gate-full` or an earlier stop). The test suites are GitHub's job
# (and `just gate-full`): this hook takes seconds.

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd')
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Loop guard: if this hook already blocked once, let the agent stop.
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

cd "$CWD" || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0
# shellcheck source=lib/gate.sh
if ! source "$HOOKS/lib/gate.sh" 2>/dev/null || ! gate_require; then
  echo "The commit gate (.claude/hooks/lib/gate.sh) is broken or missing; fix it before finishing." >&2
  exit 2
fi

# Uncommitted code only (.py, .dart): documentation never blocks a stop.
CHANGED=$(git status --porcelain --no-renames --untracked-files=all 2>/dev/null | cut -c4- | grep -E '\.(py|dart)$')
[ -z "$CHANGED" ] && exit 0

TO_RUN=()
declare -A KEY
for block in $(echo "$CHANGED" | gate_route); do
  hash=$(gate_hash "$block")
  KEY[$block]="$block-fast-$hash"
  gate_block_passed "$block" "$hash" || TO_RUN+=("$block")
done
[ ${#TO_RUN[@]} -eq 0 ] && exit 0

OUT=$(mktemp -d)
gate_run_blocks "$ROOT" "$OUT" fast "${TO_RUN[@]}"
FAILED=0
for block in "${TO_RUN[@]}"; do
  if [ "$(cat "$OUT/$block.status" 2>/dev/null || echo 1)" = "0" ]; then
    gate_record "${KEY[$block]}"
  else
    echo "$block checks are failing with your uncommitted changes. Fix them before finishing." >&2
    echo "" >&2
    tail -10 "$OUT/$block.log" >&2
    FAILED=1
  fi
done
rm -rf "$OUT"

[ $FAILED -ne 0 ] && exit 2
exit 0
