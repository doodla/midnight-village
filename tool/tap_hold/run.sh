#!/usr/bin/env bash
# `just tap-hold [part,...] [check.py args]`: quick touches tap and held ones hold on the
# real game (check.py). Starts its own backend (`just harness-serve`), builds the
# release web app (cached: frontend/tool/web_build_cached.sh), serves it, plays with a
# headless Chrome phone and three bots, and stops what it started.
# The backend's port is TAP_HOLD_PORT, else 18777 while free (so the cached build is
# reused), else any free one (a new build).
# TAP_HOLD_BREAK=1: the recorded break. The build under test takes a hold at the first
# frame after its timer, slow page or not (finger_hold.dart, `_waitOnSlowPage`), and the
# check must fail.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
free() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
taken() { python3 -c 'import socket, sys; s = socket.socket(); sys.exit(s.connect_ex(("127.0.0.1", int(sys.argv[1]))) != 0)' "$1"; }
api_port=${TAP_HOLD_PORT:-18777}
if [ -z "${TAP_HOLD_PORT:-}" ] && taken "$api_port"; then api_port=$(free); fi
app_port=$(free)
work=$(mktemp -d)
backend=""
server=""
cleanup() {
  if [ -n "$backend" ] && kill -0 -- "-$backend" 2>/dev/null; then
    kill -TERM -- "-$backend" 2>/dev/null || true
    for _ in $(seq 1 50); do
      kill -0 -- "-$backend" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL -- "-$backend" 2>/dev/null || true
  fi
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

parts=()
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then parts=(--parts "$1"); shift; fi

echo "[tap-hold] backend on $api_port"
set -m
(cd "$root" && HARNESS_PORT=$api_port exec just harness-serve > "$work/backend.log" 2>&1) &
backend=$!
set +m

defines=(--dart-define=ENV=prod "--dart-define=API_ORIGIN=http://127.0.0.1:$api_port" --dart-define=BUILD_COMMIT=)
if [ "${TAP_HOLD_BREAK:-}" = 1 ]; then
  echo "[tap-hold] TAP_HOLD_BREAK=1: the build waits for no lift on a slow page"
  defines+=(--dart-define=tap_hold_break=true)
fi
echo "[tap-hold] the release web app (built once per change: web_build_cached.sh)"
web=$(cd "$root/frontend" && tool/web_build_cached.sh --release "${defines[@]}" 2> "$work/build.log") ||
  { tail -30 "$work/build.log"; exit 2; }

python3 -I -c '
import http.server, os, sys
root, port = sys.argv[1], int(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s, *a, **k): super().__init__(*a, directory=root, **k)
    def send_head(s):
        if not os.path.exists(s.translate_path(s.path)): s.path = "/index.html"
        return super().send_head()
    def log_message(s, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
' "$web" "$app_port" &
server=$!

for _ in $(seq 1 120); do
  curl -sf "http://127.0.0.1:$api_port/api/health/" > /dev/null && break
  sleep 1
done

chrome=""
for c in /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
  [ -x "$c" ] && chrome=$c && break
done
cd "$root"
uv run --no-project --with playwright --with httpx --with pillow python tool/tap_hold/check.py \
  --api "http://127.0.0.1:$api_port" --app "http://127.0.0.1:$app_port" \
  ${chrome:+--chrome "$chrome"} ${parts[@]+"${parts[@]}"} "$@"
