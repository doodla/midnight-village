{{flutter_js}}
{{flutter_build_config}}

// The launch mark in index.html stays under Flutter's view until the app's
// first frame is painted, then goes (nothing is waited for).
window.addEventListener('flutter-first-frame', function () {
  var launch = document.getElementById('launch');
  if (launch) launch.remove();
}, { once: true });

// As Flutter's own default bootstrap (`flutter build web`, offline-first).
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
