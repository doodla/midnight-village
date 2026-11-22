{{flutter_js}}
{{flutter_build_config}}

// The launch mark in index.html stays under Flutter's view until the app's
// first frame is painted, then goes (nothing is waited for).
window.addEventListener('flutter-first-frame', function () {
  var launch = document.getElementById('launch');
  if (launch) launch.remove();
}, { once: true });

// Flutter's service worker serves repeat visits from its cache. This script
// is inlined in index.html (which the worker always fetches from the network
// first), so it always knows this build's version.
(function () {
  var version = {{flutter_service_worker_version}};
  var workers = navigator.serviceWorker;
  if (workers && workers.controller) {
    // A returning phone: Flutter's own check. When the worker is this
    // build's (the usual open), there is nothing to wait for; after a deploy
    // the worker is updated first (Flutter's loader, at most 4 s), so the new
    // build loads, not the one in the cache.
    _flutter.loader.load({
      serviceWorkerSettings: { serviceWorkerVersion: version }
    });
    return;
  }
  // A first visit: the app loads at once, nothing waited for. The worker,
  // for the next visits, is registered once the app's own start is in (its
  // first picture and the secrets' art: lib/core/web/start_done_web.dart
  // calls this), since installing it downloads the app again.
  _flutter.loader.load();
  if (workers && version) {
    window.mvStarted = function () {
      window.mvStarted = undefined;
      workers.register('flutter_service_worker.js?v=' + version)
        .catch(function () {});
    };
  }
})();
