import 'dart:js_interop';

@JS('mvStarted')
external JSFunction? get _started;

/// Tells the page the app's own start is in (its first picture and the
/// secrets' art: `SkinLoader.prepare`). On a first visit the page then
/// registers Flutter's service worker for the next visits
/// (`web/flutter_bootstrap.js`), whose install downloads the app again: done
/// any sooner, that download competes with the start on a slow line.
void webStartDone() => _started?.callAsFunction();
