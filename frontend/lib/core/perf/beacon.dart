// How a summary leaves the phone, and when the tab is hidden: the browser's
// own (`navigator.sendBeacon`, `visibilitychange`) on the web, nothing
// elsewhere (the installed app sends no summary).
export 'beacon_stub.dart' if (dart.library.js_interop) 'beacon_web.dart';
