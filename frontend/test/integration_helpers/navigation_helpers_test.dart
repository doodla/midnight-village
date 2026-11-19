import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../integration_test/helpers/navigation_helpers.dart';

// The integration tests only run in a browser on CI. This keeps their
// navigation helper honest in the ordinary test run.
void main() {
  testWidgets('expectRoute reads the route from a real GoRouter app', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/lobby/:code', builder: (_, _) => const Text('lobby')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    tester.expectRoute('/');
    router.go('/lobby/MOON');
    await tester.pumpAndSettle();
    tester.expectRoute('/lobby/:code');
  });
}
