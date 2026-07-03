import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared setup + target constants for the integration harness (contract §D4).
///
/// The harness targets the BOOTED HARNESS BACKEND on `127.0.0.1:8001` (DB
/// `midnight_village_harness`), NOT the dev `:8000` — `Env` points at dev and
/// is intentionally not used here.
class HarnessConfig {
  HarnessConfig._();

  /// REST base (Dio prepends paths like `/auth/guest/`).
  static const String apiBaseUrl = 'http://127.0.0.1:8001/api';

  /// WebSocket base for `/ws/game/<id>/` etc.
  static const String wsBaseUrl = 'ws://127.0.0.1:8001';

  /// Origin header for WS handshakes — must match the harness backend's
  /// ALLOWED_HOSTS (channels' OriginValidator 403s a no-Origin handshake).
  static const String origin = 'http://127.0.0.1:8001';

  /// Health endpoint the §D5 runner polls before starting tests.
  static const String healthUrl = 'http://127.0.0.1:8001/api/health/';

  static bool _setUpDone = false;
  static bool _fontsLoaded = false;

  /// Per-file network setup (call once in `main()`/`setUpAll` before any test):
  /// `HttpOverrides.global = null` — flutter_test installs an override that
  /// returns HTTP 400 with no real request; clearing it enables real Dio/WS to
  /// the harness backend.
  ///
  /// Fonts are NOT loaded here. The API runner uses plain `test()` and renders
  /// nothing, so it needs no fonts (and the font path requires the widget test
  /// binding, which `test()` does not stand up). The UI runner calls
  /// [loadFonts] separately, inside a `testWidgets` body where the binding is
  /// guaranteed up.
  static Future<void> setUp() async {
    if (_setUpDone) return;
    _setUpDone = true;
    // Real network instead of flutter_test's 400-returning override. (Pooled
    // HTTP connections leave a bounded ~3s keep-alive idle timer; the UI runner
    // drains those by advancing the fake clock at teardown — see
    // UiHarness.tearDownHarness. We do NOT shorten the idle timeout here because
    // that races GoogleFonts' in-build weight fetches.)
    HttpOverrides.global = null;
  }

  /// Loads the app's three font families to real glyphs so the UI runner's PNG
  /// filmstrips render readable text rather than Ahem boxes. UI-runner only;
  /// requires the widget test binding to be initialized (true inside
  /// `testWidgets`). Best-effort: assertions read the oracle (not pixels), so a
  /// font miss degrades filmstrip legibility but never fails a scenario.
  ///
  /// GoogleFonts with `allowRuntimeFetching` fetches the TTF over HTTP (fine —
  /// real network is available here) and then writes it to the app-support dir
  /// via `path_provider`. There is NO path_provider plugin on the headless host
  /// Dart VM, so that save throws `MissingPluginException` out of un-awaited
  /// futures and crashes the test. We stub the `path_provider` platform channel
  /// to a real temp dir so the save succeeds and the fetched glyphs register.
  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;
    _fontsLoaded = true;
    try {
      _stubPathProvider();
      GoogleFonts.config.allowRuntimeFetching = true;
      // Preload EVERY (family, weight) the app's typography uses (w400/500/600/
      // 700 across Epilogue / DM Sans / Space Grotesk). Touching each kicks off
      // its FontLoader; `pendingFonts` awaits them all. Preloading the full set
      // matters: a weight fetched lazily during a later widget build instead
      // leaves an in-flight HTTP connection that the teardown's fake-clock drain
      // disrupts (`Bad file descriptor`).
      const weights = [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ];
      for (final w in weights) {
        GoogleFonts.epilogue(fontWeight: w);
        GoogleFonts.dmSans(fontWeight: w);
        GoogleFonts.spaceGrotesk(fontWeight: w);
      }
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // CDN unreachable or save failed: text falls back to the default test
      // glyph. Oracle-based assertions are unaffected; only filmstrip
      // legibility degrades.
    } finally {
      // All used weights are now cached, so disable runtime fetching: any weight
      // the preload somehow missed falls back to a cached one rather than
      // triggering a late in-build HTTP fetch that would race teardown.
      GoogleFonts.config.allowRuntimeFetching = false;
    }
  }

  /// Routes `path_provider`'s directory queries to a real temp dir so
  /// GoogleFonts' on-device font cache write succeeds on the host VM (no plugin
  /// is registered there otherwise).
  static void _stubPathProvider() {
    final fontCacheDir = Directory.systemTemp.createTempSync(
      'harness_font_cache',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => fontCacheDir.path,
        );
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
