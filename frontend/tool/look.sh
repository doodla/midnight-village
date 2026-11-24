#!/usr/bin/env bash
# One screen state at the size of a real phone, full resolution, main beside the
# working tree: what a player will see, before and after this change.
#
#   just look <state> [width] [height]      e.g. just look 11-end-board 412 915
#
# <state> is a catalogue id (test_screens/screen_catalogue.dart), or part of one
# when at most eight ids hold it. Default phone: 412 x 915 at 3 device pixels per
# point (a common large Android phone; the sweep and the gallery use 360 and 390).
#
# Writes, per state, into build/look/:
#   <state>-w<width>.png          before | after | what changed (changed pixels in red)
#   after/<state>.png             the working tree's picture alone
#   before/<state>.png            main's picture alone (absent for a new state)
# Pictures of states looked at earlier stay (a state drawn again replaces its own).
# "Before" is the commit this branch left main at, drawn in a checkout kept in
# build/look/base (made once, reused while that commit stays the same).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

state="${1:?usage: just look <state> [width] [height]   (ids: test_screens/screen_catalogue.dart)}"
width="${2:-412}"
height="${3:-915}"
for n in "$width" "$height"; do
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "just look: width and height are whole numbers of points, got '$n'" >&2; exit 2; }
done
out=build/look
# This run draws into its own folder, so the pictures of states looked at
# earlier are neither wiped nor compared again.
run="$out/run"
rm -rf "$run"
mkdir -p "$out/after" "$out/before" "$run"

draw() {  # draw <checkout's frontend folder> <where its pictures go>
  ( cd "$1" && flutter test test_screens/look_test.dart --reporter failures-only \
      --dart-define=ENV=dev --dart-define=LOOK_STATE="$state" \
      --dart-define=LOOK_WIDTH="$width" --dart-define=LOOK_HEIGHT="$height" \
      --dart-define=LOOK_OUT="$2" )
}

echo "look: drawing '$state' at ${width}x${height} from the working tree..."
draw . "$PWD/$run/after"

# Before: the commit this branch left main at.
base="$(git merge-base origin/main HEAD 2>/dev/null || true)"
if [ -z "$base" ]; then
  echo "look: no origin/main here, so no 'before' picture."
elif git diff --quiet "$base" -- . && [ -z "$(git ls-files --others --exclude-standard -- .)" ]; then
  echo "look: the app is the same as main here, so 'before' is the same picture."
else
  held="$out/base"
  if [ "$(git -C "$held" rev-parse HEAD 2>/dev/null || true)" != "$base" ]; then
    git worktree remove --force "$held" >/dev/null 2>&1 || rm -rf "$held"
    git worktree prune
    echo "look: checking out main ($(git rev-parse --short "$base")) into $out/base (once per commit)..."
    git worktree add -q --detach "$held" "$base"
  fi
  # main may not have this file yet: it stands on its own, so the same one is used
  cp test_screens/look_test.dart "$held/frontend/test_screens/look_test.dart"
  echo "look: drawing it from main..."
  if ! draw "$held/frontend" "$PWD/$run/before"; then
    echo "look: main could not draw '$state' (a new state?): no 'before' picture."
  fi
fi

uv run --quiet --with pillow python tool/look_compare.py "$run" "$width" "$out"
for side in after before; do
  [ -d "$run/$side" ] && cp "$run/$side"/*.png "$out/$side/" 2>/dev/null || true
done
rm -rf "$run"
