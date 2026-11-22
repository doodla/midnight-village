#!/usr/bin/env bash
# Browser check of the dusk and the dawn: builds the standalone demo that hosts both on the real
# primitives and art (test_screens/scene_demo_main.dart), serves it on a free port, and drives it in
# headless Chrome at 1x and 4x CPU throttle (Playwright), printing the requestAnimationFrame deltas
# of each scene next to today's crossfade. Headless Chrome here has no GPU (software rendering), so
# the numbers are for comparing the scenes with the crossfade, not a phone's frame rate.
# Needs Chrome (CHROME, default /usr/bin/google-chrome) and `npm`. Usage: tool/scene_web_check.sh [outdir]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-$(mktemp -d)}"
export CHROME="${CHROME:-/usr/bin/google-chrome}"
flutter build web --release -t test_screens/scene_demo_main.dart --no-web-resources-cdn \
  --output "$OUT/web" >/dev/null
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1])')"
(cd "$OUT/web" && python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
mkdir -p "$OUT/pw"
cp tool/scene_web_measure.js "$OUT/pw/measure.js"
(cd "$OUT/pw" && npm init -y >/dev/null 2>&1 && npm i playwright-core >/dev/null 2>&1)
sleep 1
(cd "$OUT/pw" && node measure.js "http://localhost:$PORT/" "$OUT/web-shot")
