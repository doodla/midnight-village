import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Navigation assertion helpers for GoRouter integration tests.
///
/// Available as extensions on [WidgetTester]:
/// ```dart
/// tester.expectRoute('/home');
/// await tester.waitForNavigation('/home');
/// tester.expectScreen<HomeScreen>();
/// ```
extension NavigationAssertions on WidgetTester {
  /// Asserts the current GoRouter route matches [path].
  ///
  /// Reads the route from the nearest [GoRouter] in the widget tree.
  void expectRoute(String path) {
    // GoRouter is provided to the widgets the router builds, not to the
    // Router widget itself, so look it up from the Navigator beneath it.
    final context = element(find.byType(Navigator).first);
    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.fullPath;
    expect(
      currentLocation,
      equals(path),
      reason: 'Expected route "$path" but got "$currentLocation"',
    );
  }

  /// Waits until the current route equals [path], pumping every 100ms.
  ///
  /// Fails with a clear message if navigation does not complete within
  /// [timeout] (default 5 seconds).
  Future<void> waitForNavigation(
    String path, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await pump(const Duration(milliseconds: 100));
      try {
        expectRoute(path);
        return;
      } catch (_) {
        // Not there yet — keep pumping.
      }
    }
    fail('Navigation to "$path" did not complete within $timeout');
  }

  /// Asserts a screen is visible by finding a widget of type [T].
  ///
  /// Use as a fallback when the GoRouter location is not inspectable (e.g.
  /// when the router is configured with a nested navigator or redirect logic
  /// makes the path hard to predict).
  void expectScreen<T extends Widget>() {
    expect(
      find.byType(T),
      findsOneWidget,
      reason: 'Expected to find screen widget ${T.toString()}',
    );
  }
}
