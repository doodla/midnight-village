import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';

import 'helpers/integration_test_helper.dart';
import 'helpers/navigation_helpers.dart';

void main() {
  IntegrationTestSetup.initialize();
  IntegrationTestSetup.setupFailureScreenshots();

  testWidgets(
    '01 Join: a new phone opens on an empty name, and a name unlocks the ways '
    'in',
    (tester) async {
      await IntegrationTestSetup.launchApp(tester);

      // No stored account: 01, the name empty (never someone else's).
      tester.expectRoute('/');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(JoinCopy.nameHint), findsOneWidget);
      SecondaryButton way(String label) => tester.widget<SecondaryButton>(
        find.widgetWithText(SecondaryButton, label),
      );
      expect(way(JoinCopy.joinTable).onPressed, isNull);
      expect(way(JoinCopy.startTable).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'TestPlayer');
      await tester.pumpAndSettle();

      expect(way(JoinCopy.joinTable).onPressed, isNotNull);
      expect(way(JoinCopy.startTable).onPressed, isNotNull);
      tester.expectRoute('/');
    },
  );
}
