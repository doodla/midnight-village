#!/usr/bin/env bash
# Stop hook: an agent may not finish with uncommitted code whose tests fail.
# What only this hook does: it looks at work that is NOT committed (staged,
# unstaged or untracked code). It runs the tests of the blocks that work
# touches (routing in lib/gate.sh), in parallel, and skips a block whose
# tests already passed on exactly this content (by the commit gate or an
# earlier stop), so it never repeats a run the gate just did.

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
source "$HOOKS/lib/gate.sh"

# Uncommitted code only (.py, .dart): documentation never blocks a stop.
CHANGED=$(git status --porcelain --untracked-files=all 2>/dev/null | cut -c4- | sed 's/.* -> //' | grep -E '\.(py|dart)$')
[ -z "$CHANGED" ] && exit 0

TO_RUN=()
declare -A KEY
for block in $(echo "$CHANGED" | gate_route); do
  KEY[$block]="$block-tests-$(gate_hash "$block")"
  gate_passed "${KEY[$block]}" || TO_RUN+=("$block")
done
[ ${#TO_RUN[@]} -eq 0 ] && exit 0

OUT=$(mktemp -d)
gate_run_blocks "$ROOT" "$OUT" tests "${TO_RUN[@]}"
FAILED=0
for block in "${TO_RUN[@]}"; do
  if [ "$(cat "$OUT/$block.status" 2>/dev/null || echo 1)" = "0" ]; then
    gate_record "${KEY[$block]}"
  else
    echo "$block tests are failing with your uncommitted changes. Fix them before finishing." >&2
    echo "" >&2
    tail -10 "$OUT/$block.log" >&2
    FAILED=1
  fi
done
rm -rf "$OUT"

[ $FAILED -ne 0 ] && exit 2
exit 0
