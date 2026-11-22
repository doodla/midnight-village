#!/usr/bin/env bash
# Fails if the /debug toolbar is in a web build made with NO --dart-define at all (what a
# forgotten flag gives): the safe state is the default, a bare build is prod.
# With a directory argument it checks that already-built output instead of building one
# (the Vercel build passes build/web).
# The check looks for ONE marker, `debugToolbarShipMarker`, a constant that lives in the
# toolbar's source and ships only with it; env_default_test.dart keeps it there.
set -euo pipefail
cd "$(dirname "$0")/.."
MARKER="$(sed -n "s/^const String debugToolbarShipMarker = '\\(.*\\)';/\\1/p" \
  lib/features/debug/presentation/debug_toolbar_screen.dart)"
if [ -z "$MARKER" ]; then
  echo "FAIL: debugToolbarShipMarker is gone from the toolbar source; the check has nothing to look for" >&2
  exit 1
fi
OUT="${1:-}"
if [ -z "$OUT" ]; then
  OUT="$(mktemp -d)"
  flutter build web --release --output "$OUT" >/dev/null
fi
if [ ! -f "$OUT/main.dart.js" ]; then
  echo "FAIL: $OUT/main.dart.js is missing, so there is no build to check" >&2
  exit 1
fi
if grep -rqF -- "$MARKER" "$OUT"; then
  echo "FAIL: this web build contains the debug toolbar" >&2
  exit 1
fi
echo "ok: no debug toolbar in this web build"
