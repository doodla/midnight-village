import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:midnight_village/features/lobby/presentation/scan/code_scanner.dart';
import 'package:midnight_village/features/lobby/presentation/scan/scan_session.dart';
import 'package:midnight_village/features/lobby/presentation/scan/scan_view.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/fake_code_scanner.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// 01's scan action and the scanner (01b), through the app's routes with a
// camera the test drives. What it sees is text, as a camera gives it; the
// server's answers are recorded payloads (test/helpers/table_setup.dart).

final _scanAction = find.byWidgetPredicate(
  (w) => w is GlyphButton && w.semanticLabel == ScanCopy.scan,
);

Future<void> _tapScan(WidgetTester tester, TableSetup setup) async {
  await tester.ensureVisible(_scanAction);
  await tester.pump();
  await pressLikeAFinger(tester, _scanAction);
  await setup.settle(tester);
}

/// Ben, signed in, with the server ready to seat him at Ana's table.
Future<TableSetup> _benAtTheDoor(
  WidgetTester tester, {
  FakeCodeScanner Function()? scanner,
  bool named = true,
}) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: named ? 'Ben' : null,
    realAuth: !named,
    userId: 42,
    scanner: scanner,
  );
  if (!named) {
    setup.http.answer(
      'POST',
      '/auth/guest/',
      ContractSamples.map('http/auth/guest_created'),
      status: 201,
    );
  }
  setup.http.answer(
    'POST',
    '/lobbies/V9YC2J/join/',
    ContractSamples.map('http/lobby/joined'),
  );
  setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
  return setup;
}

void main() {
  group('01 has a scan action, and uses no camera until it is tapped', () {
    testWidgets('a glyph beside "Join a table", with no word and a label for '
        'a screen reader', (tester) async {
      final setup = await TableSetup.pump(tester);

      expect(_scanAction, findsOneWidget);
      expect(find.byType(ScanGlyph), findsOneWidget);
      expect(
        tester.getSemantics(_scanAction),
        matchesSemantics(
          label: ScanCopy.scan,
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
        ),
      );
      // No camera was made, let alone started.
      expect(setup.scanners, isEmpty);
      await setup.close(tester);
    });

    testWidgets('it works before a name is typed (scanning is the natural '
        'first move)', (tester) async {
      final setup = await TableSetup.pump(tester);
      final button = tester.widget<GlyphButton>(_scanAction);
      expect(button.onPressed, isNotNull);
      await setup.close(tester);
    });

    testWidgets('a table\'s link names its table: no scan action', (
      tester,
    ) async {
      final setup = await TableSetup.pump(tester, route: '/join/V9YC2J');
      expect(_scanAction, findsNothing);
      await setup.close(tester);
    });

    testWidgets('the tap opens one camera, started; nothing before', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(tester);
      expect(setup.scanners, isEmpty);

      await _tapScan(tester, setup);

      expect(setup.scanners, hasLength(1));
      expect(setup.scanners.single.started, isTrue);
      expect(find.byType(ScanView), findsOneWidget);
      expect(find.byType(Viewfinder), findsOneWidget);
      // While it looks, there are no words on the screen at all.
      expect(find.byType(Text), findsNothing);
      await setup.close(tester);
    });
  });

  group('the scan glyph keeps the code whole', () {
    for (final (width, beside) in [
      (390.0, true),
      (360.0, true),
      (320.0, false),
    ]) {
      testWidgets(
        'at $width wide: ${beside ? 'beside the code' : 'left to the '
                  'closed row'}, and the whole code shows',
        (tester) async {
          tester.view
            ..physicalSize = Size(width, 800)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
          await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
          await setup.settle(tester);
          await tester.enterText(find.byType(TextField).last, 'V9YC2J');
          await tester.pump();

          expect(_scanAction, beside ? findsOneWidget : findsNothing);
          // The field shows all six characters and the caret, none scrolled out
          // of sight.
          final editable = tester.widget<EditableText>(
            find.byType(EditableText).last,
          );
          final room = tester.renderObject<RenderBox>(
            find.byType(EditableText).last,
          );
          final painter = TextPainter(
            text: TextSpan(text: 'V9YC2J', style: editable.style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout();
          expect(painter.width + 2, lessThanOrEqualTo(room.size.width));
          await setup.close(tester);
        },
      );
    }
  });

  group('a code is read and the table is joined as typing joins it', () {
    for (final (what, seen) in [
      ('a link in the path form', 'https://midnight.example/join/V9YC2J'),
      ('a link of another origin', 'https://elsewhere.example/join/V9YC2J'),
      ('a link in lower case', 'https://midnight.example/join/v9yc2j'),
      ('a bare code', 'V9YC2J'),
      ('a bare code in lower case', 'v9yc2j'),
      ('a bare code with spaces', ' v9y c2j '),
    ]) {
      testWidgets('$what: one join, the table shows, the camera is gone', (
        tester,
      ) async {
        final setup = await _benAtTheDoor(tester);
        // The join waits for the test, so the scanner can be seen joining.
        final join = setup.http.hold(
          method: 'POST',
          path: '/lobbies/V9YC2J/join/',
        );
        await _tapScan(tester, setup);
        final camera = setup.scanners.single;

        camera.see(seen);
        // The camera stops the moment the code is read, the join is sent
        // (the test holds its answer), and the window shows the code the
        // table is being joined with.
        expect(camera.stopped, isTrue);
        await setup.settle(tester);
        expect(find.text('V9YC2J'), findsOneWidget);
        expect(find.byType(ScanView), findsOneWidget);
        expect(join.length, 1);

        join.releaseAll();
        await setup.settle(tester);

        expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
        expect(
          find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
          findsOneWidget,
        );
        expect(find.byType(ScanView), findsNothing);
        expect(camera.disposed, isTrue);
        await setup.close(tester);
      });
    }

    testWidgets('a second sighting of the same code joins once', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(tester);
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;

      camera
        ..see('V9YC2J')
        ..see('V9YC2J')
        ..see('https://midnight.example/join/V9YC2J');
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
      await setup.close(tester);
    });
  });

  group('anything else is ignored calmly', () {
    for (final junk in [
      'https://example.com',
      'https://example.com/join/V9YC2JK',
      'WIFI:T:WPA;S:cafe;P:secret;;',
      'hello there',
      '',
      '12345',
      '123456',
      'https://midnight.example/join/V9YC1J',
    ]) {
      testWidgets('"$junk": nothing happens, the camera keeps looking', (
        tester,
      ) async {
        final setup = await _benAtTheDoor(tester);
        await _tapScan(tester, setup);
        final camera = setup.scanners.single;

        camera.see(junk);
        await setup.settle(tester);

        expect(find.byType(ScanView), findsOneWidget);
        expect(camera.started, isTrue);
        expect(camera.stopped, isFalse);
        expect(find.byType(Text), findsNothing);
        expect(setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
        await setup.close(tester);
      });
    }

    testWidgets('junk, then a table\'s code: the code is still read', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(tester);
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;

      camera.see('https://example.com');
      camera.see('V9YC2J');
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
      await setup.close(tester);
    });
  });

  group('without a name, the code waits for one', () {
    testWidgets('01 is back with the code in its field and the name field '
        'asking; Join comes with the name', (tester) async {
      final setup = await _benAtTheDoor(tester, named: false);
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;

      camera.see('https://midnight.example/join/V9YC2J');
      await setup.settle(tester);

      expect(find.byType(ScanView), findsNothing);
      expect(camera.disposed, isTrue);
      expect(setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.map((f) => f.controller!.text), ['', 'V9YC2J']);
      expect(fields.first.focusNode!.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField).first, 'Ben');
      await tester.pump();
      await pressLikeAFinger(tester, find.text(JoinCopy.join));
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
      await setup.close(tester);
    });
  });

  group('a join that is refused', () {
    testWidgets('leaves the scanner for 01, which says why', (tester) async {
      final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
      setup.http.answer(
        'POST',
        '/lobbies/ZZZZZZ/join/',
        ContractSamples.map('http/lobby/join_not_found'),
        status: 404,
      );
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;

      camera.see('ZZZZZZ');
      await setup.settle(tester);

      expect(find.byType(ScanView), findsNothing);
      expect(camera.disposed, isTrue);
      expect(find.text(BannerCopy.lobbyNotFound), findsOneWidget);
      // 01 is back with the code still in its field.
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller!.text),
        contains('ZZZZZZ'),
      );
      await setup.close(tester);
    });
  });

  group(
    'a scanned join is the one join of the app: it fails and retries as one',
    () {
      testWidgets('"Not sent." with "Try again", the very same join, and the '
          'code still in its field', (tester) async {
        final setup = await TableSetup.pump(
          tester,
          signedInAs: 'Ben',
          before: (s) => s.http.answer(
            'POST',
            '/lobbies/V9YC2J/join/',
            'Server Error',
            status: 503,
          ),
        );
        await _tapScan(tester, setup);
        setup.scanners.single.see('https://midnight.example/join/V9YC2J');
        await setup.settle(tester);

        expect(find.byType(ScanView), findsNothing);
        expect(find.text(BannerCopy.notSent), findsOneWidget);
        expect(find.text(BannerCopy.tryAgain), findsOneWidget);
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .map((f) => f.controller!.text),
          contains('V9YC2J'),
        );
        expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);

        // The server is back: Try again sends the same join, and it seats him.
        setup.http.answer(
          'POST',
          '/lobbies/V9YC2J/join/',
          ContractSamples.map('http/lobby/joined'),
        );
        setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
        await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
        await setup.settle(tester);

        expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 2);
        expect(
          find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
          findsOneWidget,
        );
        await setup.close(tester);
      });
    },
  );

  group('a typed join that is refused keeps its code too', () {
    for (final (sample, status, banner) in [
      ('join_not_found', 404, BannerCopy.lobbyNotFound),
      ('join_full', 400, BannerCopy.lobbyFull),
      ('join_closed', 400, BannerCopy.lobbyClosed),
    ]) {
      testWidgets(banner, (tester) async {
        final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
        setup.http.answer(
          'POST',
          '/lobbies/ZZZZZZ/join/',
          ContractSamples.map('http/lobby/$sample'),
          status: status,
        );
        await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
        await setup.settle(tester);
        await tester.enterText(find.byType(TextField).last, 'ZZZZZZ');
        await tester.pump();
        await plainTap(
          tester,
          find.text(JoinCopy.join),
          why:
              'the 01 Join bug: pressed by a finger, a refused or unsent Join shows no refusal (fixed on branch fix-join-refusal)',
        );
        await setup.settle(tester);

        expect(find.text(banner), findsOneWidget);
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .map((f) => f.controller!.text),
          contains('ZZZZZZ'),
        );
        await setup.close(tester);
      });
    }
  });

  group('where the camera cannot be used, typing is the way on', () {
    for (final problem in ScanProblem.values) {
      testWidgets('$problem: one calm line and "Type the code", which opens '
          'the code field', (tester) async {
        final setup = await _benAtTheDoor(
          tester,
          scanner: () => FakeCodeScanner(problem: problem),
        );
        await _tapScan(tester, setup);

        expect(find.text(ScanCopy.cameraOff), findsOneWidget);
        expect(find.text(ScanCopy.typeCode), findsOneWidget);
        // The one line and the one button: nothing else says anything.
        expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data), [
          ScanCopy.cameraOff,
          ScanCopy.typeCode,
        ]);
        expect(
          tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
          isNotNull,
        );

        await pressLikeAFinger(tester, find.text(ScanCopy.typeCode));
        await setup.settle(tester);

        expect(find.byType(ScanView), findsNothing);
        expect(setup.scanners.single.disposed, isTrue);
        expect(find.text(JoinCopy.codeHint), findsOneWidget);
        final code = tester.widgetList<TextField>(find.byType(TextField)).last;
        expect(code.focusNode!.hasFocus, isTrue);

        // And typing joins, as ever.
        await tester.enterText(find.byType(TextField).last, 'V9YC2J');
        await tester.pump();
        await plainTap(
          tester,
          find.text(JoinCopy.join),
          why:
              'the 01 Join bug: pressed by a finger, a refused or unsent Join shows no refusal (fixed on branch fix-join-refusal)',
        );
        await setup.settle(tester);
        expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
        await setup.close(tester);
      });
    }

    testWidgets('the camera is off: Back from there is still 01', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(
        tester,
        scanner: () => FakeCodeScanner(problem: ScanProblem.refused),
      );
      await _tapScan(tester, setup);
      await pressLikeAFinger(
        tester,
        find.byWidgetPredicate(
          (w) => w is GlyphButton && w.semanticLabel == ScanCopy.back,
        ),
      );
      await setup.settle(tester);

      expect(find.byType(ScanView), findsNothing);
      expect(find.text(JoinCopy.joinTable), findsOneWidget);
      expect(setup.scanners.single.disposed, isTrue);
      await setup.close(tester);
    });
  });

  group('the light', () {
    testWidgets('where the camera has one, a glyph switches it', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(
        tester,
        scanner: () => FakeCodeScanner(lit: LightState.off),
      );
      await _tapScan(tester, setup);
      final light = find.byWidgetPredicate(
        (w) => w is GlyphButton && w.semanticLabel == ScanCopy.light,
      );

      expect(light, findsOneWidget);
      await pressLikeAFinger(tester, light);
      await tester.pump();

      expect(setup.scanners.single.lightToggles, 1);
      expect(tester.widget<GlyphButton>(light).lit, isTrue);
      await setup.close(tester);
    });

    testWidgets('where it has none (the web), there is no glyph', (
      tester,
    ) async {
      final setup = await _benAtTheDoor(tester);
      await _tapScan(tester, setup);

      expect(
        find.byWidgetPredicate(
          (w) => w is GlyphButton && w.semanticLabel == ScanCopy.light,
        ),
        findsNothing,
      );
      await setup.close(tester);
    });
  });

  group('only a tap starts the camera, never the building of 01', () {
    testWidgets('a scanner left open when 01 goes away is gone, and 01 built '
        'again shows no camera', (tester) async {
      final setup = await _benAtTheDoor(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(JoinScreen)),
      );
      await _tapScan(tester, setup);
      expect(container.read(scanSessionProvider).open, isTrue);
      expect(setup.scanners, hasLength(1));

      // The server seats the player: 02 takes the screen, the scanner with it.
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/joined'),
      );
      container.invalidate(myTableProvider);
      await setup.settle(tester);
      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      expect(setup.scanners.single.disposed, isTrue);
      expect(container.read(scanSessionProvider).open, isFalse);

      // The player is at no table again: 01, with no camera and no scanner.
      setup.lobby = null;
      setup.viewerId = null;
      setup.answerTable();
      container.invalidate(myTableProvider);
      await setup.settle(tester);
      expect(find.text(JoinCopy.joinTable), findsOneWidget);
      expect(find.byType(ScanView), findsNothing);
      expect(setup.scanners, hasLength(1));
      await setup.close(tester);
    });

    testWidgets('01 opened from a table\'s link shows no scanner, whatever '
        'was left open', (tester) async {
      final setup = await _benAtTheDoor(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(JoinScreen)),
      );
      await _tapScan(tester, setup);
      expect(container.read(scanSessionProvider).open, isTrue);

      GoRouter.of(tester.element(find.byType(ScanView))).go('/join/V9YC2J');
      await setup.settle(tester);

      expect(find.byType(ScanView), findsNothing);
      expect(find.text(JoinCopy.join), findsOneWidget);
      expect(container.read(scanSessionProvider).open, isFalse);
      expect(setup.scanners, hasLength(1));
      expect(setup.scanners.single.disposed, isTrue);
      await setup.close(tester);
    });

    testWidgets('building 01 never makes a camera', (tester) async {
      final setup = await _benAtTheDoor(tester);
      expect(setup.scanners, isEmpty);
      await setup.close(tester);
    });
  });

  group('the camera stops the moment the screen leaves', () {
    testWidgets('when the app moves on to the table', (tester) async {
      final setup = await _benAtTheDoor(tester);
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;
      expect(camera.disposed, isFalse);

      camera.see('V9YC2J');
      await setup.settle(tester);

      expect(camera.disposed, isTrue);
      expect(camera.started, isFalse);
      await setup.close(tester);
    });

    testWidgets('when the app is closed with the scanner open', (tester) async {
      final setup = await _benAtTheDoor(tester);
      await _tapScan(tester, setup);
      final camera = setup.scanners.single;

      await setup.close(tester);

      expect(camera.disposed, isTrue);
    });
  });
}
