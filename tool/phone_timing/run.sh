#!/usr/bin/env bash
# `just phone-timing [rounds] [args for phone_timing.py]`: tap to guest screen on a
# slowed phone (CPU 4x slower, 150 ms latency), the deal and play again, against
# a budget (phone_timing.py). Starts its own backend on a free port (`just
# harness-serve`), builds the release web app for it, serves it, runs a headless
# Chrome guest, and stops what it started. About five minutes, most of it the
# build. Not in the required checks: it needs Chrome and a web build.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
rounds=${1:-3}
shift || true
free() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
api_port=$(free)
app_port=$(free)
work=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT

echo "[phone-timing] backend on $api_port"
(cd "$root" && HARNESS_PORT=$api_port just harness-serve > "$work/backend.log" 2>&1) &
pids+=($!)

echo "[phone-timing] building the web app (release) for it"
(cd "$root/frontend" && flutter build web --release --dart-define=ENV=prod \
  --dart-define=API_ORIGIN="http://127.0.0.1:$api_port" --output "$work/web" > "$work/build.log" 2>&1) ||
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
' "$work/web" "$app_port" &
pids+=($!)

for _ in $(seq 1 120); do
  curl -sf "http://127.0.0.1:$api_port/api/health/" > /dev/null && break
  sleep 1
done

chrome=""
for c in /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
  [ -x "$c" ] && chrome=$c && break
done
cd "$root"
uv run --no-project --with playwright --with httpx python tool/phone_timing/phone_timing.py \
  --api "http://127.0.0.1:$api_port" --app "http://127.0.0.1:$app_port" \
  --rounds "$rounds" ${chrome:+--chrome "$chrome"} "$@"
