#!/usr/bin/env bash
# `just gate-full [backend|frontend|guardrails ...]`: every required GitHub check that
# can run here, on demand, in parallel: the steps are `gate_run_blocks`' "full" ones in
# lib/gate.sh, and what only GitHub runs is GATE_FULL_SKIPS there (it says so at the
# end; guardrails/tests/test_gate_full.py holds both to the workflows). A pass is
# recorded, so the next commit on the same content skips its fast checks. Minutes.
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/gate.sh
if ! source "$HOOKS/lib/gate.sh" 2>/dev/null || ! gate_require; then
  echo "The commit gate (.claude/hooks/lib/gate.sh) is broken or missing." >&2
  exit 2
fi
gate_full "$@"
