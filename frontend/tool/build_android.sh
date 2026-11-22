#!/usr/bin/env bash
# Builds the release APK (what is sideloaded). It needs both addresses, and stops
# here, saying what to pass, when one is missing: a build without the web app's
# address would draw no QR code and share no link.
#
#   API_ORIGIN=https://<server host> PUBLIC_ORIGIN=https://<web app host> tool/build_android.sh
#
# CHECK_ONLY=1 checks the two and builds nothing (the test uses it).
# Needs the Android SDK (platform 36, build-tools 36.0.0) and ANDROID_HOME.
# The key it is signed with is public: android/release-key/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -n "${API_ORIGIN:-}" ] ||
  fail "API_ORIGIN is not set: pass the server's origin, e.g. API_ORIGIN=https://midnight-village-anthelion.vercel.app"
[ -n "${PUBLIC_ORIGIN:-}" ] ||
  fail "PUBLIC_ORIGIN is not set: pass the web app's origin, e.g. PUBLIC_ORIGIN=https://midnight-village-app-anthelion.vercel.app (the QR code, Share and the links that open this app use it)"
case "$PUBLIC_ORIGIN" in
  https://?*) ;;
  *) fail "PUBLIC_ORIGIN must be an https origin (got '$PUBLIC_ORIGIN'): Android opens only verified https links in the app" ;;
esac

if [ "${CHECK_ONLY:-}" = "1" ]; then
  echo "ok: API_ORIGIN and PUBLIC_ORIGIN are set"
  exit 0
fi

exec flutter build apk --release \
  --dart-define=ENV=prod \
  --dart-define="API_ORIGIN=$API_ORIGIN" \
  --dart-define="PUBLIC_ORIGIN=$PUBLIC_ORIGIN"
