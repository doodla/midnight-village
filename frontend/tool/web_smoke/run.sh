#!/usr/bin/env bash
# `just web-smoke`: builds the web app for release (as tool/vercel_build.sh does, against
# a server that is not there: the page opens on 01 with nothing signed in), then opens the
# built page in Chromium through tool/web_smoke/smoke.cjs: a first visit, a return and a
# deploy (a second build served in the first one's place).
# First runs routes.test.cjs: frontend/vercel.json compiled by Vercel's own `@vercel/routing-utils`.
# Needs node, `@vercel/routing-utils` and the `playwright` package with its Chromium: installed beside this script
# (CI: npm install there), or on NODE_PATH (the cloud container's /opt/node-tools).
# usage: tool/web_smoke/run.sh [existing build/web]   (run from frontend/)
set -euo pipefail
cd "$(dirname "$0")/../.."
here=tool/web_smoke
if [ ! -d "$here/node_modules/playwright" ] && [ -z "${NODE_PATH:-}" ] \
  && [ -d /opt/node-tools/node_modules/playwright ]; then
  export NODE_PATH=/opt/node-tools/node_modules
fi
if ! node -e "require('@vercel/routing-utils')" 2>/dev/null \
  && ! (cd "$here" && node -e "require('@vercel/routing-utils')") 2>/dev/null; then
  echo "web-smoke: @vercel/routing-utils is missing (just web-smoke-setup installs it beside this script)" >&2
  exit 2
fi
# What Vercel does with vercel.json (compiled by its own routing-utils), before any build.
node --test "$here/routes.test.cjs"
out="${1:-}"
cleanup() { if [ -n "${tmp:-}" ]; then rm -rf "$tmp"; fi; }
trap cleanup EXIT
if [ -z "$out" ]; then
  tmp="$(mktemp -d)"
  out="$tmp/web"
  flutter build web --release --dart-define=ENV=prod \
    --dart-define=API_ORIGIN=http://127.0.0.1:9 \
    --dart-define=BUILD_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --output "$out" >/dev/null
fi
node "$here/smoke.cjs" "$out"
