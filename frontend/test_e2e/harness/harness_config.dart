import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/test_fonts.dart';

/// Shared setup + target constants for the integration harness (contract §D4).
///
/// The harness targets the BOOTED HARNESS BACKEND on `127.0.0.1:<port>` (DB
/// `midnight_village_harness`), NOT the dev `:8000` — `Env` points at dev and
/// is intentionally not used here. The port is the run's own
/// (`tool/run_harness.sh` picks a free one and passes it as
/// `--dart-define=HARNESS_PORT=<port>`; also read from the `HARNESS_PORT`
/// environment variable, else 8001), so parallel runs never share a backend.
class HarnessConfig {
  HarnessConfig._();

  /// The harness backend's port for this run.
  static final int port = _port();

  static int _port() {
    const defined = String.fromEnvironment('HARNESS_PORT');
    final raw = defined.isNotEmpty
        ? defined
        : Platform.environment['HARNESS_PORT'] ?? '8001';
    return int.parse(raw);
  }

  /// REST base (Dio prepends paths like `/auth/guest/`).
  static String get apiBaseUrl => 'http://127.0.0.1:$port/api';

  /// WebSocket base for `/ws/game/<id>/` etc.
  static String get wsBaseUrl => 'ws://127.0.0.1:$port';

  /// Origin header for WS handshakes — must match the harness backend's
  /// ALLOWED_HOSTS (channels' OriginValidator 403s a no-Origin handshake).
  static String get origin => 'http://127.0.0.1:$port';

  /// Health endpoint the §D5 runner polls before starting tests.
  static String get healthUrl => 'http://127.0.0.1:$port/api/health/';

  static bool _setUpDone = false;
  static bool _fontsLoaded = false;

  /// Per-file network setup (call once in `main()`/`setUpAll` before any test):
  /// `HttpOverrides.global = null` — flutter_test installs an override that
  /// returns HTTP 400 with no real request; clearing it enables real Dio/WS to
  /// the harness backend.
  ///
  /// Fonts are NOT loaded here. The API runner uses plain `test()` and renders
  /// nothing, so it needs no fonts. The UI runners call [loadFonts]
  /// separately, where the widget test binding is up.
  static Future<void> setUp() async {
    if (_setUpDone) return;
    _setUpDone = true;
    // Real network instead of flutter_test's 400-returning override. (Pooled
    // HTTP connections leave a bounded ~3s keep-alive idle timer; the UI runner
    // drains those by advancing the fake clock at teardown — see
    // UiHarness.tearDownHarness.)
    HttpOverrides.global = null;
  }

  /// Loads the app's bundled fonts (Gloock, Figtree, the icons) so the UI
  /// runners' PNG filmstrips draw real glyphs. Nothing is fetched.
  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;
    _fontsLoaded = true;
    await loadAppFonts();
  }

  static bool _secureStorageStubbed = false;
  static final Map<String, String> _secureStore = {};

  /// Clears the in-memory secure store. Call at the START of each UI scenario:
  /// the store is a static singleton, so a prior scenario's adopted JWT/user
  /// would otherwise survive into the next test's app boot, where
  /// `tryRestoreSession` picks up that STALE token and 403s (the backend rotates
  /// + blacklists on refresh), throwing an `UnmountedRefException` as the dying
  /// provider chain unwinds.
  static void clearSecureStorage() => _secureStore.clear();

  /// Backs `flutter_secure_storage` with an in-memory map. The app stores the
  /// JWT + user there (TokenStorage / UserStorage), and the AuthInterceptor
  /// reads the token per request. On the host VM there is NO secure-storage
  /// plugin, so every `read`/`write` would otherwise throw or hang — which is
  /// why the UI runner stalled before this stub. UI-runner only; the API runner
  /// uses the explicit-per-token client and never touches storage.
  static void stubSecureStorage() {
    if (_secureStorageStubbed) return;
    _secureStorageStubbed = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args =
                (call.arguments as Map?)?.cast<String, Object?>() ?? {};
            final key = args['key'] as String?;
            switch (call.method) {
              case 'write':
                if (key != null) _secureStore[key] = args['value'] as String;
                return null;
              case 'read':
                return key == null ? null : _secureStore[key];
              case 'delete':
                if (key != null) _secureStore.remove(key);
                return null;
              case 'deleteAll':
                _secureStore.clear();
                return null;
              case 'readAll':
                return Map<String, String>.from(_secureStore);
              case 'containsKey':
                return key != null && _secureStore.containsKey(key);
              default:
                return null;
            }
          },
        );
  }
}
