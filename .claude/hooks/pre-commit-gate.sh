#!/usr/bin/env bash
# PreToolUse hook on Bash: a `git commit` goes through only when the checks for
# what it commits pass. Routing (lib/gate.sh, tested by test_gate_routing.sh):
#   backend/** (not .md), contract_samples/**, recommended-setups.md -> backend: just check + just test
#   frontend/** (not .md), contract_samples/**  -> frontend: just analyze + format-check + test
#   .claude/** (not skills)                     -> just test-guardrails
#   documentation only                          -> no suites
# Every commit: the subject format and tool/check_instruction_links.sh.
# Blocks run in parallel. A block that passed on exactly the same content is
# not run again (its record is kept in the git dir, see lib/gate.sh).

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$INPUT" | jq -r '.cwd')
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! echo "$COMMAND" | grep -qE 'git(\s+-C\s+\S+)?\s+commit'; then
  exit 0
fi

if echo "$COMMAND" | grep -q -- "--no-verify"; then
  echo "BLOCKED: --no-verify is not allowed. Fix the failing checks instead." >&2
  exit 2
fi

cd "$CWD" || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0
# shellcheck source=lib/gate.sh
source "$HOOKS/lib/gate.sh"

FAILED=0

MSG_ERR=$(echo "$COMMAND" | python3 "$HOOKS/lib/commit_msg.py")
if [ $? -ne 0 ]; then
  echo "$MSG_ERR" >&2
  FAILED=1
fi

LINKS_OUT=$(tool/check_instruction_links.sh 2>&1)
if [ $? -ne 0 ]; then
  echo "BLOCKED: an instruction file names a path or recipe that does not exist." >&2
  echo "$LINKS_OUT" | tail -20 >&2
  FAILED=1
fi

# What this commit takes: the staged paths, plus everything changed when the
# same command stages (git add ... && git commit, commit -a).
PATHS=$(git diff --cached --name-only 2>/dev/null)
if echo "$COMMAND" | grep -qE 'git\s+add|commit\s+(-[a-zA-Z]*a[a-zA-Z]*|--all)\b'; then
  PATHS="$PATHS
$(git diff --name-only 2>/dev/null)
$(git ls-files --others --exclude-standard 2>/dev/null)"
fi

BLOCKS=$(echo "$PATHS" | gate_route)
TO_RUN=()
declare -A KEY_COMMIT KEY_TESTS
for block in $BLOCKS; do
  hash=$(gate_hash "$block")
  KEY_COMMIT[$block]="$block-commit-$hash"
  KEY_TESTS[$block]="$block-tests-$hash"
  if gate_passed "${KEY_COMMIT[$block]}"; then
    echo "gate: $block already passed on this content" >&2
  else
    TO_RUN+=("$block")
  fi
done

if [ ${#TO_RUN[@]} -gt 0 ]; then
  OUT=$(mktemp -d)
  gate_run_blocks "$ROOT" "$OUT" commit "${TO_RUN[@]}"
  for block in "${TO_RUN[@]}"; do
    status=$(cat "$OUT/$block.status" 2>/dev/null || echo 1)
    if [ "$status" = "0" ]; then
      gate_record "${KEY_COMMIT[$block]}"
      gate_record "${KEY_TESTS[$block]}"
    else
      [ "$status" = "124" ] && echo "BLOCKED: $block checks ran out of time." >&2
      echo "BLOCKED: $block checks are failing. Fix them before committing." >&2
      echo "" >&2
      tail -25 "$OUT/$block.log" >&2
      FAILED=1
    fi
  done
  rm -rf "$OUT"
fi

[ $FAILED -ne 0 ] && exit 2
exit 0
