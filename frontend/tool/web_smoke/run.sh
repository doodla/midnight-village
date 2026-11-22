#!/usr/bin/env bash
# `just web-smoke`: builds the web app for release (as tool/vercel_build.sh does, against
# a server that is not there: the page opens on 01 with nothing signed in), then opens the
# built page in Chromium through tool/web_smoke/smoke.cjs: a first visit, a return and a
# deploy (a second build served in the first one's place), and that /api/ (the API
# through the page's own origin) is never answered by the service worker.
# Needs node and the `playwright` package with its Chromium: installed beside this script
# (CI: npm install there), or on NODE_PATH (the cloud container's /opt/node-tools).
# usage: tool/web_smoke/run.sh [existing build/web]   (run from frontend/)
set -euo pipefail
cd "$(dirname "$0")/../.."
here=tool/web_smoke
if [ ! -d "$here/node_modules/playwright" ] && [ -z "${NODE_PATH:-}" ] \
  && [ -d /opt/node-tools/node_modules/playwright ]; then
  export NODE_PATH=/opt/node-tools/node_modules
fi
out="${1:-}"
cleanup() { [ -n "${tmp:-}" ] && rm -rf "$tmp"; }
trap cleanup EXIT
if [ -z "$out" ]; then
  tmp="$(mktemp -d)"
  out="$tmp/web"
  flutter build web --release --dart-define=ENV=prod \
    --dart-define=API_ORIGIN=http://127.0.0.1:9 --dart-define=API_SAME_ORIGIN=true --output "$out" >/dev/null
fi
node "$here/smoke.cjs" "$out"
