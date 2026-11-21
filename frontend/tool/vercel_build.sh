#!/usr/bin/env bash
# Builds the web app on Vercel (its build machines have no Flutter): fetches the pinned
# Flutter, then builds for production against the server named by API_ORIGIN.
# Vercel settings: root directory `frontend`, build command `bash tool/vercel_build.sh`,
# output directory `build/web`, environment variable API_ORIGIN (https://<server host>).
set -euo pipefail
FLUTTER_VERSION="3.38.10"
: "${API_ORIGIN:?set API_ORIGIN to the server origin, e.g. https://midnight-village-anthelion.vercel.app}"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
flutter build web --release --dart-define=ENV=prod --dart-define="API_ORIGIN=$API_ORIGIN"
