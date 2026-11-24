import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
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
      // "Start a table" is the one amber plaque (no code typed): with no
      // name a tap leads to the name; with one it starts a table.
      final start = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, JoinCopy.startTable),
      );
      expect(start.phase, ButtonPhase.ready);

      await tester.enterText(find.byType(TextField), 'TestPlayer');
      await tester.pumpAndSettle();

      expect(way(JoinCopy.joinTable).onPressed, isNotNull);
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, JoinCopy.startTable),
            )
            .phase,
        ButtonPhase.ready,
      );
      tester.expectRoute('/');
    },
  );

  testWidgets(
    '01 Join: a name and "Start a table" make this device\'s guest account; '
    'a table that cannot be opened says "Not sent."',
    (tester) async {
      await IntegrationTestSetup.launchApp(
        tester,
        httpMocks: {
          // No answer (a 5xx): the table is not opened.
          'POST:/lobbies/': Response<dynamic>(
            requestOptions: RequestOptions(path: '/lobbies/'),
            statusCode: 503,
            data: 'Server Error',
          ),
        },
      );

      await tester.enterText(find.byType(TextField), 'TestPlayer');
      await tester.pumpAndSettle();
      await tester.tap(find.text(JoinCopy.startTable));
      // The guest account's tokens are stored (in the browser, not at once)
      // before the table is asked for: wait for the banner the step ends on.
      await tester.pumpUntilFound(find.text(BannerCopy.notSent));

      final guest = IntegrationTestSetup.mockHttp.requests.where(
        (r) => r.method == 'POST' && r.path == '/auth/guest/',
      );
      expect(guest.single.data, {'display_name': 'TestPlayer'});
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(find.text(BannerCopy.tryAgain), findsOneWidget);
      tester.expectRoute('/');
    },
  );
}
