import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/integration_test_helper.dart';
import 'helpers/navigation_helpers.dart';

void main() {
  IntegrationTestSetup.initialize();

  testWidgets(
    'Auth flow: launch → unauthenticated welcome → enter name → authenticated',
    (tester) async {
      await IntegrationTestSetup.launchApp(tester);

      // After launch the app settles to the unauthenticated welcome view
      // (no stored tokens → AuthUnauthenticated).
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);

      // Verify we start on the home route.
      tester.expectRoute('/');

      // Enter a display name.
      await tester.enterText(find.byType(TextField), 'TestPlayer');
      await tester.pumpAndSettle();

      // Tap the Continue button to trigger guest account creation.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // The mock returns display_name = 'TestPlayer' — verify authenticated view.
      expect(find.textContaining('Hello, TestPlayer!'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Logout'),
        findsOneWidget,
      );

      // Verify we remain on the home route after authentication.
      tester.expectRoute('/');
    },
  );

  testWidgets(
    'Auth flow: launch with no name → authenticated with server-generated name',
    (tester) async {
      await IntegrationTestSetup.launchApp(tester);

      // Skip entering a name — tap Continue with empty field.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Mock always returns 'TestPlayer' — just verify we reached authenticated state.
      expect(find.textContaining('Hello,'), findsOneWidget);
    },
  );
}
