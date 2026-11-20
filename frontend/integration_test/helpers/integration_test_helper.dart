import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:midnight_village/app.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';

import 'mock_http_client.dart';
import 'server_bodies.dart';

export 'mock_http_client.dart' show MockHttpClient;

/// Bootstrap utility for integration tests.
///
/// Initializes the Flutter integration test binding, wires the mock HTTP
/// client into the app's provider graph, and provides a [launchApp] function
/// so individual tests stay concise.
///
/// Usage:
/// ```dart
/// void main() {
///   IntegrationTestSetup.initialize();
///
///   testWidgets('my test', (tester) async {
///     await IntegrationTestSetup.launchApp(tester);
///     // test body...
///   });
/// }
/// ```
class IntegrationTestSetup {
  IntegrationTestSetup._();

  static late IntegrationTestWidgetsFlutterBinding binding;
  static late MockHttpClient mockHttp;

  /// Must be called once per test file, outside of any test group.
  ///
  /// Initialises [IntegrationTestWidgetsFlutterBinding] and creates a shared
  /// [MockHttpClient] instance.
  static void initialize() {
    binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    mockHttp = MockHttpClient();
  }

  /// Sets up automatic screenshot capture after each test.
  ///
  /// Call once per test file (e.g. at the top of `main()`) after [initialize].
  /// Screenshots are written to `integration_test/screenshots/` when the test
  /// driver collects them; the directory is preserved in git via `.gitkeep`
  /// and excluded from tracking via `.gitignore`.
  ///
  /// On web, screenshots are captured as PNG bytes via the browser canvas.
  /// The filename includes a millisecond timestamp to avoid collisions.
  ///
  /// Note: To capture only on failure, wrap calls to [launchApp] in try/catch
  /// and call [captureScreenshot] in the catch block instead.
  static void setupFailureScreenshots() {
    tearDown(() async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await captureScreenshot('teardown_$timestamp');
    });
  }

  /// Captures a screenshot with the given [name].
  ///
  /// Returns the PNG bytes. On headless Chrome these bytes are forwarded to
  /// the integration test driver for storage.
  static Future<List<int>> captureScreenshot(String name) async {
    return binding.takeScreenshot(name);
  }

  /// Pumps the full app widget tree with mock HTTP wired in.
  ///
  /// Creates a fresh [MockHttpClient] per launch so mocks do not bleed between
  /// tests. Registers default mock responses for common auth endpoints, then
  /// merges in any [httpMocks] provided by the caller.
  ///
  /// [httpMocks] keys use the format `"METHOD:path"`, e.g. `"POST:/auth/guest/"`.
  /// Keys must contain exactly one colon separating method and path — paths
  /// containing colons (e.g. full URLs) are not supported by this helper.
  static Future<void> launchApp(
    WidgetTester tester, {
    Map<String, Response<dynamic>>? httpMocks,
  }) async {
    // Fresh MockHttpClient per launch so mocks don't bleed between tests.
    mockHttp = MockHttpClient();
    _registerDefaultMocks();

    // Register any test-specific mocks on top of the defaults.
    httpMocks?.forEach((key, response) {
      final parts = key.split(':');
      if (parts.length == 2) {
        mockHttp.when(method: parts[0], path: parts[1]).thenReturn(response);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(dio: mockHttp.dio)),
        ],
        child: const App(),
      ),
    );

    // Allow the app to settle after launch (resolves AuthInitial → next state).
    await tester.pumpAndSettle();
  }

  /// Registers mock responses for endpoints all integration tests need.
  static void _registerDefaultMocks() {
    // If stored tokens exist from a prior run, tryRestoreSession() hits the
    // refresh endpoint. Return 401 so it clears tokens and transitions to
    // AuthUnauthenticated — ensuring each test run starts from a clean state.
    mockHttp
        .when(method: 'POST', path: '/auth/token/refresh/')
        .thenReturn(
          Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/auth/token/refresh/'),
            statusCode: 401,
            data: ServerBodies.refreshRefused,
          ),
        );

    // Default guest registration response.
    mockHttp
        .when(method: 'POST', path: '/auth/guest/')
        .thenReturn(
          Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/auth/guest/'),
            statusCode: 201,
            data: ServerBodies.guestCreated,
          ),
        );
  }
}
