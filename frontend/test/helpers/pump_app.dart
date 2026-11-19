import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';

import 'mock_http_client.dart';
import 'mock_websocket.dart';

/// Full-app bootstrap extension for integration-style widget tests.
///
/// Boots the entire app with routing, theming, and all providers. For lighter
/// single-widget tests that don't need routing context, prefer
/// [pumpAuthenticated] or [pumpWithGameState] from [test_harness.dart].
///
/// Example — boot to the home screen with a pre-authenticated user:
/// ```dart
/// await tester.pumpApp(
///   auth: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
/// );
/// expect(find.text('Hello, Alice!'), findsOneWidget);
/// ```
extension PumpAppExtension on WidgetTester {
  /// Boots the full app with a test-scoped router and optional mock services.
  ///
  /// Creates an isolated [GoRouter] so [initialRoute] can be controlled
  /// without mutating the global [appRouter] used by production code.
  ///
  /// [httpClient] and [webSocket] are accepted for forward compatibility —
  /// they are available for use in [overrides] once real HTTP and WebSocket
  /// providers exist in the app.
  ///
  /// [auth] is the signed-in state the app starts with. It defaults to
  /// unauthenticated so token storage is never accessed during startup.
  ///
  /// [overrides] allows any other provider to be substituted for the test
  /// (not `authProvider`: a provider may be overridden only once).
  Future<void> pumpApp({
    MockHttpClient? httpClient,
    MockWebSocketChannel? webSocket,
    String? initialRoute,
    AuthState auth = const AuthState.unauthenticated(),
    List<Override>? overrides,
  }) async {
    // Capture for use in overrides when callers need them.
    // ignore: unused_local_variable
    final mockHttp = httpClient ?? MockHttpClient();
    // ignore: unused_local_variable
    final mockWs = webSocket ?? MockWebSocketChannel();

    // Test-scoped router so initialLocation can be set per test without
    // touching the global appRouter singleton.
    final router = GoRouter(
      routes: $appRoutes,
      initialLocation: initialRoute ?? '/',
      debugLogDiagnostics: false,
    );

    await pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWithValue(auth), ...?overrides],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ref.watch(activeThemeDataProvider),
            routerConfig: router,
          ),
        ),
      ),
    );
    await pumpAndSettle();
  }
}
