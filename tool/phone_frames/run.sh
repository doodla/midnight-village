#!/usr/bin/env bash
# `just phone-frames [args for phone_frames.py]`: a whole game on a slowed phone,
# every screen, transition and tap measured against budgets (phone_frames.py).
# Starts its own backend (`just harness-serve`), builds the release web app as
# Vercel does (tool/vercel_build.sh's flags: dart2js, CanvasKit) for it, serves it,
# plays with a headless Chrome phone and three bots, and stops what it started.
# A build is kept in frontend/build/phone_frames/ and reused while the frontend's
# commit and the backend port are the same (PHONE_FRAMES_REBUILD=1 forces one).
# PHONE_FRAMES_FRONTEND=<a frontend folder> measures another checkout (main).
# PHONE_FRAMES_PROFILE=1 builds a profile build (names kept, for `--trace`).
# Not in the required checks: it needs Chrome, a web build and a few minutes.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
front=${PHONE_FRAMES_FRONTEND:-$root/frontend}
free() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
taken() { python3 -c 'import socket,sys; s = socket.socket(); sys.exit(s.connect_ex(("127.0.0.1", int(sys.argv[1]))) != 0)' "$1"; }
# A steady port, so the build (which names its server) is reused run to run.
api_port=${PHONE_FRAMES_PORT:-8797}
if taken "$api_port"; then api_port=$(free); fi
app_port=$(free)
work=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT

echo "[phone-frames] backend on $api_port"
(cd "$root" && HARNESS_PORT=$api_port just harness-serve > "$work/backend.log" 2>&1) &
pids+=($!)

mode=release
[ "${PHONE_FRAMES_PROFILE:-}" = 1 ] && mode=profile
web="$front/build/phone_frames/web-$mode"
stamp="$mode-$(git -C "$front" rev-parse HEAD)-$(git -C "$front" status --porcelain -- lib web pubspec.yaml assets | sha1sum | cut -c1-8)-$api_port"
if [ "${PHONE_FRAMES_REBUILD:-}" = 1 ] || [ "$(cat "$web/.phone_frames" 2>/dev/null)" != "$stamp" ]; then
  echo "[phone-frames] building the web app (release, as tool/vercel_build.sh) for it"
  rm -rf "$web"
  (cd "$front" && flutter build web --$mode --dart-define=ENV=prod \
    --dart-define=API_ORIGIN="http://127.0.0.1:$api_port" --dart-define=BUILD_COMMIT= \
    --output "$web" > "$work/build.log" 2>&1) || { tail -30 "$work/build.log"; exit 2; }
  echo "$stamp" > "$web/.phone_frames"
fi

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
uv run --no-project --with playwright --with httpx --with pillow python tool/phone_frames/phone_frames.py \
  --api "http://127.0.0.1:$api_port" --app "http://127.0.0.1:$app_port" \
  ${chrome:+--chrome "$chrome"} "$@"
