import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/host/app_download.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

import '../../../helpers/finger.dart';
import '../../../helpers/table_setup.dart';

// 01's quiet "Get the app": offered only to a page in an Android browser, on
// 01 alone, never amber, 48 to touch, and its address (`/app`) is the host's,
// never a route of the app.

Finder get _link => find.text(JoinCopy.getApp);

void main() {
  group('where the app is offered', () {
    test('only the web build on Android', () {
      for (final platform in TargetPlatform.values) {
        expect(
          offersAppDownload(web: true, platform: platform),
          platform == TargetPlatform.android,
          reason: 'web on $platform',
        );
        // Inside the Android app (or any native build): never.
        expect(
          offersAppDownload(web: false, platform: platform),
          isFalse,
          reason: 'native $platform',
        );
      }
    });

    test('a test run (not the web) is offered nothing by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appDownloadProvider), isNull);
    });

    test('the router has no /app of its own: the host answers it', () {
      final paths = [for (final r in $appRoutes) (r as GoRoute).path];
      expect(paths, isNot(contains('/app')));
      expect(paths.where((p) => p.startsWith('/app')), isEmpty);
    });
  });

  group('01', () {
    testWidgets(
      'in an Android browser: one quiet "Get the app" on the at-tables row, quiet '
      'ink (never amber), 48 to touch, and a tap opens the download',
      (tester) async {
        final setup = await TableSetup.pump(tester, androidWeb: true);

        expect(_link, findsOneWidget);
        expect(
          tester.getSize(find.byType(TextAction)).height,
          greaterThanOrEqualTo(48),
        );
        final ink = tester.widget<Text>(_link).style!.color;
        final context = tester.element(_link);
        // 01 is dressed in paper: the kit's quiet action, plain serif words
        // with no underline and no paper, never amber, never a button.
        expect(ink, isNot(context.ground.accent));
        expect(
          tester.widget<Text>(_link).style!.decoration,
          isNot(TextDecoration.underline),
        );
        expect(
          find.widgetWithText(PrimaryButton, JoinCopy.getApp),
          findsNothing,
        );

        // On the "at tables" row, at its right end.
        final line = find.textContaining('at tables');
        expect(
          tester.getCenter(_link).dy,
          closeTo(tester.getCenter(line).dy, 8),
        );
        expect(
          tester.getTopRight(find.byType(TextAction)).dx,
          greaterThan(tester.getTopRight(line).dx),
        );

        // The words end on the column's edge, as the Start button does.
        expect(
          tester.getTopRight(_link).dx,
          closeTo(
            tester
                .getTopRight(
                  find
                      .ancestor(
                        of: find.text(JoinCopy.startTable),
                        matching: find.byType(PrimaryButton),
                      )
                      .first,
                )
                .dx,
            0.5,
          ),
        );

        await pressLikeAFinger(tester, _link);
        expect(setup.appDownloads, 1);
        await setup.close(tester);
      },
    );

    testWidgets('on a table\'s link too (still 01)', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        route: '/join/V9YC2J',
        androidWeb: true,
      );
      expect(_link, findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('not in an Android browser (the Android app, iOS, a desktop): '
        'no link', (tester) async {
      final setup = await TableSetup.pump(tester, lastWon: true);
      expect(_link, findsNothing);
      await setup.close(tester);
    });

    testWidgets('not on the scanner (01b)', (tester) async {
      final setup = await TableSetup.pump(tester, androidWeb: true);
      await pressLikeAFinger(
        tester,
        find.byWidgetPredicate(
          (w) => w is GlyphButton && w.semanticLabel == ScanCopy.scan,
        ),
      );
      await setup.settle(tester);
      expect(_link, findsNothing);
      await setup.close(tester);
    });

    testWidgets('not on any other screen: the table (02)', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('created_with_defaults'),
        viewer: 'Ana',
        androidWeb: true,
      );
      expect(_link, findsNothing);
      await setup.close(tester);
    });
  });
}
