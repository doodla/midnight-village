import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'worker_renewal.dart';

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

/// Brings the service worker up to date before the reload (`renewWorker`):
/// nothing is unregistered and no cache is deleted, so a connection that
/// drops now leaves the old build running. The generated worker skips
/// waiting and claims its clients, so the new one serves the reload.
/// Where the browser has no service worker there is nothing to renew.
Future<bool> renewServiceWorker() => renewWorker(
  registration: () async {
    if (!(web.window.navigator as JSObject).has('serviceWorker')) return null;
    final registration = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart;
    return registration == null ? null : _Registration(registration);
  },
);

class _Registration implements WorkerRegistration {
  _Registration(this._registration);

  final web.ServiceWorkerRegistration _registration;

  @override
  Future<void> update() async {
    await _registration.update().toDart;
  }

  @override
  Future<void> untilCurrent() {
    final coming = _registration.installing ?? _registration.waiting;
    if (coming == null || coming.state == 'activated') return Future.value();
    final done = Completer<void>();
    coming.addEventListener(
      'statechange',
      ((web.Event _) {
        if (done.isCompleted) return;
        if (coming.state == 'activated') done.complete();
        if (coming.state == 'redundant') {
          done.completeError(StateError('the new worker was discarded'));
        }
      }).toJS,
    );
    return done.future;
  }
}

/// Reloads the page so it runs the live build: a plain visit to the network
/// for the page (the shell is `no-cache`), and the files from the worker that
/// has just taken over. The seat is the server's: the app opens at the same
/// screen (`HomeGate`, `/me/table/`).
Future<void> reloadPage() async => web.window.location.reload();
