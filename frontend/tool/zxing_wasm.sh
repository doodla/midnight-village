#!/usr/bin/env bash
# Makes (or checks) web/zxing/: the QR decoder the web scanner falls back to in browsers
# without a built-in barcode detector, served from the app's own origin so the scanner makes
# no third-party request and runs no script nobody pinned.
#
#   tool/zxing_wasm.sh          write web/zxing/ from the pinned npm package (needs curl)
#   tool/zxing_wasm.sh --check  fail unless web/zxing/ is exactly what the pin makes
#
# The pin: zxing-wasm 3.1.6 (MIT; it carries zxing-cpp, Apache-2.0). The files are checked
# against the SHA-256 below as they are fetched. web/zxing/zxing-wasm-reader.js is the
# package's dist/iife/reader/index.js with ONE snippet appended: it points the library at the
# .wasm beside the script instead of at jsDelivr. To move to a new version: change VERSION and
# the three sums, run this, and re-check the scanner in a browser with no BarcodeDetector.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="3.1.6"
SUM_JS="ffd72d59d54082194f7c086b384dcd930bdeb0c5b39fbb13779694e69bb0d344"
SUM_WASM="5003fb4b88c4fbd1fd518a2fd8c8ad365c519e183a08c03a322dddfea3cea84e"
SUM_LICENSE="fb506e4ade12d7a9efa67c9d76a9a28c8e15d347ca49a69e48e29b40b34ad2ab"
BASE="https://cdn.jsdelivr.net/npm/zxing-wasm@${VERSION}"
OUT="web/zxing"

SNIPPET='
/* Midnight Village: load the .wasm from beside this script, not from jsDelivr (tool/zxing_wasm.sh). */
(function () {
  var here = document.currentScript && document.currentScript.src;
  if (!here || typeof ZXingWASM === "undefined") return;
  ZXingWASM.setZXingModuleOverrides({
    locateFile: function (file) { return new URL(file, here).href; },
  });
})();
'

sum() { sha256sum "$1" | cut -d' ' -f1; }

fetch() { # url sum dest
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "$1" -o "$tmp"
  if [ "$(sum "$tmp")" != "$2" ]; then
    echo "FAIL: $1 is not the pinned file (sha256 $(sum "$tmp"))" >&2
    rm -f "$tmp"
    exit 1
  fi
  mv "$tmp" "$3"
}

if [ "${1:-}" = "--check" ]; then
  work="$(mktemp -d)"
  fetch "$BASE/dist/iife/reader/index.js" "$SUM_JS" "$work/index.js"
  { cat "$work/index.js"; printf '%s' "$SNIPPET"; } > "$work/zxing-wasm-reader.js"
  for f in zxing-wasm-reader.js; do
    cmp -s "$work/$f" "$OUT/$f" || { echo "FAIL: $OUT/$f is not what the pin makes" >&2; exit 1; }
  done
  [ "$(sum "$OUT/zxing_reader.wasm")" = "$SUM_WASM" ] || { echo "FAIL: $OUT/zxing_reader.wasm is not the pinned file" >&2; exit 1; }
  [ "$(sum "$OUT/LICENSE-zxing-wasm.txt")" = "$SUM_LICENSE" ] || { echo "FAIL: $OUT/LICENSE-zxing-wasm.txt is not the pinned file" >&2; exit 1; }
  echo "ok: $OUT is zxing-wasm $VERSION as pinned"
  exit 0
fi

mkdir -p "$OUT"
work="$(mktemp -d)"
fetch "$BASE/dist/iife/reader/index.js" "$SUM_JS" "$work/index.js"
{ cat "$work/index.js"; printf '%s' "$SNIPPET"; } > "$OUT/zxing-wasm-reader.js"
fetch "$BASE/dist/reader/zxing_reader.wasm" "$SUM_WASM" "$OUT/zxing_reader.wasm"
fetch "$BASE/LICENSE" "$SUM_LICENSE" "$OUT/LICENSE-zxing-wasm.txt"
echo "ok: wrote $OUT (zxing-wasm $VERSION)"
