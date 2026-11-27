#!/usr/bin/env bash
# A web build, built once: the tools that measure the built app (frames, the
# scenes, a smoke) each ran `flutter build web` again, about a minute, for a
# build that had not changed.
#
#   out=$(tool/web_build_cached.sh --release -t test_screens/scene_demo_main.dart)
#
# The arguments are `flutter build web`'s own, without `--output`. It prints the
# folder of the finished build and nothing else on stdout (the build's own
# output goes to stderr). The folder is the caller's to READ, never to write.
#
# Built again only when what goes into the build changed: lib/, web/, assets/,
# test_screens/, pubspec.yaml, pubspec.lock, the arguments, or Flutter's
# version. Tracked or not, committed or not: the files' contents are hashed.
# Kept under build/web_cache/ (ignored by git), the newest KEEP builds only.
# WEB_BUILD_CACHE moves the cache; WEB_BUILD_COMMAND replaces the build (tests).
set -euo pipefail
cd "$(dirname "$0")/.."
KEEP=4
cache="${WEB_BUILD_CACHE:-build/web_cache}"
for arg in "$@"; do
  case "$arg" in --output | --output=* | -o)
    echo "web_build_cached: no --output; the folder is printed" >&2
    exit 2
    ;;
  esac
done
inputs() {
  # every file the build reads, by content, in one fixed order
  find lib web assets test_screens pubspec.yaml pubspec.lock -type f -print0 2>/dev/null |
    LC_ALL=C sort -z | xargs -0 sha256sum
}
# no Flutter here (a test with a stand-in build): no version, and the build says so itself
version="$({ flutter --version --machine 2>/dev/null || true; } | sha256sum)"
key="$({
  inputs
  printf 'args:%s\n' "$@"
  printf 'flutter:%s\n' "$version"
} | sha256sum | cut -c1-20)"
out="$cache/$key"
if [ ! -f "$out/.built" ]; then
  mkdir -p "$cache"
  # built beside its place and moved in whole: a run that is stopped leaves no
  # half build, and of two runs building the same thing the first to end stays
  tmp="$(mktemp -d "$cache/.building.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  if [ -n "${WEB_BUILD_COMMAND:-}" ]; then
    $WEB_BUILD_COMMAND "$tmp/web" "$@" >&2
  else
    # a build is heavy: it waits its turn in the queue (tool/heavy.py; inside a heavy command it runs at once)
    ../tool/heavy.py -- flutter build web "$@" --output "$tmp/web" >&2
  fi
  touch "$tmp/web/.built"
  if [ ! -f "$out/.built" ]; then
    rm -rf "$out"
    mv "$tmp/web" "$out" 2>/dev/null || [ -f "$out/.built" ]
  fi
  echo "web_build_cached: built $out" >&2
else
  touch "$out/.built" # the newest used is the last to go
  echo "web_build_cached: unchanged, using $out" >&2
fi
# the oldest builds go
ls -1dt "$cache"/*/.built 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -rf "$(dirname "$old")"
done
(cd "$out" && pwd)
