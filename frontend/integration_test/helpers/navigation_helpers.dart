import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Navigation assertion helpers for GoRouter integration tests.
///
/// Available as extensions on [WidgetTester]:
/// ```dart
/// tester.expectRoute('/');
/// await tester.waitForNavigation('/');
/// tester.expectScreen<JoinScreen>();
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

  /// Pumps every 100ms until [finder] finds something.
  ///
  /// In a real browser the app's work is not only microtasks: this device's
  /// token store (WebCrypto, browser storage) answers in later tasks, and no
  /// frame is scheduled while it does, so `pumpAndSettle` can return halfway
  /// through a tap's requests. Wait for what the step ends on instead.
  /// Fails with a clear message, listing the texts on screen, if [finder]
  /// finds nothing within [timeout] (default 10 seconds).
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await pumpAndSettle();
        return;
      }
    }
    final shown = widgetList<Text>(
      find.byType(Text),
    ).map((t) => t.data ?? t.textSpan?.toPlainText()).nonNulls.join(' | ');
    fail('$finder found nothing within $timeout. On screen: $shown');
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
