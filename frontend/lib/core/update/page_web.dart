import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The commit the live site was built from (`/commit.txt`, written by
/// `tool/vercel_build.sh`), asked of the network itself (`no-store`): the
/// service worker lists no such file, so it never answers it from its cache.
/// Null when it cannot be read, or the host answers with its page instead
/// (a local run has no such file).
Future<String?> fetchLiveBuild() async {
  try {
    final response = await web.window
        .fetch(
          '/commit.txt'.toJS,
          web.RequestInit(cache: 'no-store', method: 'GET'),
        )
        .toDart;
    if (!response.ok) return null;
    final text = (await response.text().toDart).toDart.trim();
    final isCommit = RegExp(r'^[0-9a-f]{7,64}$').hasMatch(text);
    return isCommit ? text : null;
  } catch (_) {
    return null;
  }
}

/// Reloads the page so it runs the live build. The service worker and its
/// cache are let go first: the reload is then a plain visit to the network
/// (the page, then every file), never the old worker's copy of the old app,
/// and the page registers the new build's worker as a first visit does
/// (`web/flutter_bootstrap.js`). The seat is the server's: the app opens at
/// the same screen (`HomeGate`, `/me/table/`).
Future<void> reloadPage() async {
  try {
    final workers = web.window.navigator.serviceWorker;
    final registrations = (await workers.getRegistrations().toDart).toDart;
    for (final registration in registrations) {
      await registration.unregister().toDart;
    }
    final names = (await web.window.caches.keys().toDart).toDart;
    for (final name in names) {
      await web.window.caches.delete(name.toDart).toDart;
    }
  } catch (_) {
    // Reload all the same: the loader's own check still updates the worker.
  }
  web.window.location.reload();
}
