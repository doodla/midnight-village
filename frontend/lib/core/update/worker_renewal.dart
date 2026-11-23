/// The page's service worker as far as renewing is concerned (the browser's
/// `ServiceWorkerRegistration`; a test brings a fake).
abstract interface class WorkerRegistration {
  /// Asks the browser to look for a new worker (`registration.update()`).
  Future<void> update();

  /// Completes when the worker that is being installed or is waiting has
  /// taken over (Flutter's generated worker skips waiting and claims its
  /// clients, so it does as soon as it is installed); completes at once when
  /// no new worker is on its way (this one is the newest).
  Future<void> untilCurrent();
}

/// How long the browser is given to bring a new worker up.
const workerBound = Duration(seconds: 10);

/// Brings the page's service worker up to date, before the page reloads for
/// a new build, WITHOUT letting go of anything: the worker and its caches
/// stay as they are until the new worker has taken over, so a connection
/// that drops now leaves the old build running, never the browser's
/// offline page. True: the reload may go (the new worker serves it, or there
/// is no worker). False: the update did not happen within [bound] or
/// failed; nothing was changed, and the app tries again at its next look.
Future<bool> renewWorker({
  required Future<WorkerRegistration?> Function() registration,
  Duration bound = workerBound,
}) async {
  try {
    Future<bool> renew() async {
      final current = await registration();
      if (current == null) return true;
      await current.update();
      await current.untilCurrent();
      return true;
    }

    return await renew().timeout(bound);
  } catch (_) {
    return false;
  }
}
