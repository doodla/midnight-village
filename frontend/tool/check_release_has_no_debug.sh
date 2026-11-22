#!/usr/bin/env bash
# Fails if the /debug toolbar is in a web build made with NO --dart-define at all (what a
# forgotten flag gives): the safe state is the default, a bare build is prod.
# With a directory argument it checks that already-built output instead of building one
# (the Vercel build passes build/web).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-}"
if [ -z "$OUT" ]; then
  OUT="$(mktemp -d)"
  flutter build web --release --output "$OUT" >/dev/null
fi
# 'Debug Toolbar' is the toolbar screen's title; 'debug-create-table' one of its widget keys.
if grep -rlE "Debug Toolbar|debug-create-table" "$OUT" --include='*.js' | grep -q .; then
  echo "FAIL: this web build contains the debug toolbar" >&2
  exit 1
fi
echo "ok: no debug toolbar in this web build"
