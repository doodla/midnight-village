#!/usr/bin/env bash
# `just gate-full [backend|frontend|guardrails ...]`: the whole local suite, on demand.
# The commit gate only runs what takes seconds; this runs the rest the way GitHub
# does (minus what needs a browser or a build: integration tests, the release
# build, the end-to-end harness, which only GitHub runs): the instruction-link
# check, then backend (`just check`, `just test`), frontend (analyze, format,
# tests, generated code current, screens strict at 360 and 390) and the hook
# tests, in parallel. A pass is recorded, so the next commit on the same content
# skips its fast checks. Takes minutes.
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/gate.sh
if ! source "$HOOKS/lib/gate.sh" 2>/dev/null || ! gate_require; then
  echo "The commit gate (.claude/hooks/lib/gate.sh) is broken or missing." >&2
  exit 2
fi
gate_full "$@"
