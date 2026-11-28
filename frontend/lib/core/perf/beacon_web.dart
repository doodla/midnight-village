import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands [body] to the browser for [url] as `text/plain` (no preflight; the
/// server reads the JSON inside). The browser sends it on its own time, also
/// once the tab is gone. False when it would not take it.
bool sendBeacon(String url, String body) {
  try {
    final blob = web.Blob(
      [body.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain'),
    );
    return web.window.navigator.sendBeacon(url, blob);
  } catch (_) {
    return false;
  }
}

/// Calls [then] each time the tab is hidden (switched away, the phone
/// locked) and as the page goes.
void whenHidden(void Function() then) {
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') then();
    }).toJS,
  );
  web.window.addEventListener('pagehide', ((web.Event _) => then()).toJS);
}
