import 'package:web/web.dart' as web;

/// The fallback decoder (zxing-wasm, `web/zxing/`, pinned by
/// `tool/zxing_wasm.sh`), served from the app's own origin so the scanner
/// makes no third-party request. Resolved against the page's base, never its
/// address: `/join/<code>` is a page too.
String? ownDecoderUrl() => Uri.parse(
  web.document.baseURI,
).resolve('zxing/zxing-wasm-reader.js').toString();
