#!/usr/bin/env bash
# `just phone-frames [args for phone_frames.py]`: a whole game on a slowed phone,
# every screen, transition and tap measured against budgets (phone_frames.py).
# Starts its own backend (`just harness-serve`), builds the release web app as
# Vercel does (tool/vercel_build.sh's flags: dart2js, CanvasKit) for it, serves it,
# plays with a headless Chrome phone and three bots, and stops what it started.
# A build is kept in frontend/build/phone_frames/ and reused while what it is built
# from (lib, web, assets, the pubspec: their content, not the commit) and the backend
# port are the same (PHONE_FRAMES_PORT pins the port; PHONE_FRAMES_REBUILD=1 forces a build).
# PHONE_FRAMES_FRONTEND=<a frontend folder> measures another checkout's app, and
# PHONE_FRAMES_BACKEND=<a checkout> serves another checkout's server
# (`just speed-verdict` uses both: one checkout per side).
# It stops everything it started when it ends, however it ends.
# Not in the required checks: it needs Chrome, a web build and a few minutes.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
case " $* " in
  # The moments, from the script itself: nothing to build or serve.
  *" --list "*) exec python3 "$root/tool/phone_frames/script.py" ;;
esac
front=${PHONE_FRAMES_FRONTEND:-$root/frontend}
free() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
# The backend's own port, a free one, so two runs never meet on one backend
# (the build names its server: a new port is a new build unless pinned).
api_port=${PHONE_FRAMES_PORT:-$(free)}
app_port=$(free)
work=$(mktemp -d)
backend=""
server=""
# Stops what this run started (done, failed, Ctrl-C or killed): the backend's
# whole process group (just, uv, runserver) by its own pid, with a hard kill
# after a short grace, and the app's file server. Nothing else.
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

echo "[phone-frames] backend on $api_port"
# Job control on: the backend gets a process group of its own (its pid).
set -m
(cd "${PHONE_FRAMES_BACKEND:-$root}" && HARNESS_PORT=$api_port exec just harness-serve > "$work/backend.log" 2>&1) &
backend=$!
set +m

web="$front/build/phone_frames/web"
# PHONE_FRAMES_DEFINES="NAME=value ...": more --dart-define's for the build, e.g.
# FIELD_QUIET=true for the live app's quiet field recorder (a build here has no
# commit, so it is off unless asked: lib/design_system/perf/perf_strip.dart).
defines=()
for define in ${PHONE_FRAMES_DEFINES:-}; do defines+=("--dart-define=$define"); done
inputs=(lib web pubspec.yaml pubspec.lock assets)
tree=$(cd "$front" && git rev-parse "${inputs[@]/#/HEAD:./}" | sha1sum | cut -c1-12)
stamp="$tree-$(git -C "$front" status --porcelain -- "${inputs[@]}" | sha1sum | cut -c1-8)-$api_port-${PHONE_FRAMES_DEFINES:-}"
if [ "${PHONE_FRAMES_REBUILD:-}" = 1 ] || [ "$(cat "$web/.phone_frames" 2>/dev/null)" != "$stamp" ]; then
  echo "[phone-frames] building the web app (release, as tool/vercel_build.sh) for it"
  rm -rf "$web"
  (cd "$front" && flutter build web --release --dart-define=ENV=prod \
    --dart-define=API_ORIGIN="http://127.0.0.1:$api_port" --dart-define=BUILD_COMMIT= \
    ${defines[@]+"${defines[@]}"} \
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
uv run --no-project --with playwright --with httpx --with pillow python tool/phone_frames/phone_frames.py \
  --api "http://127.0.0.1:$api_port" --app "http://127.0.0.1:$app_port" \
  ${chrome:+--chrome "$chrome"} "$@"
